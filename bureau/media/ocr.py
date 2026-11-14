"""图片文字识别。

- ``mode="windows"``（默认）：Windows 自带 OCR（WinRT ``Windows.Media.Ocr``），由
  ``scripts/tools/ocr.ps1`` 完成，本机离线。图片先用 Pillow 统一转成 PNG：太小的放大 2 倍；宽度超过
  ``OcrEngine.MaxImageDimension`` 的等比缩小；长截图按高度切成有重叠的几段分别识别后拼接。
- ``mode="llm"``：DeepSeek 视觉（``deepseek-flash``，OpenAI 兼容 Chat Completions，``image_url`` 用
  data URL，按 https://api-docs.deepseek.com/guides/vision 核实）。只有 ``privacy.cloud_llm_consent``
  为真且有 key 时才调用，否则返回空串。
- ``mode="off"``：返回空串。

不抛异常：失败时返回空串并记日志。
"""

from __future__ import annotations

import asyncio
import base64
import io
import json
import logging
import os
import re
import shutil
import subprocess
import tempfile
from pathlib import Path
from typing import Any

import httpx

log = logging.getLogger("bureau.media")

PROJECT_ROOT = Path(__file__).resolve().parents[2]
OCR_SCRIPT = PROJECT_ROOT / "scripts" / "tools" / "ocr.ps1"
DEFAULT_LANG = "zh-Hans-CN"
WIN_MAX_DIM = 4096            # 保守值；脚本会报告本机的真实上限（通常 10000），超出时自动再缩
TILE_OVERLAP = 80
MIN_UPSCALE_WIDTH = 600
OCR_TIMEOUT = 60.0
VISION_URL = "https://api.deepseek.com/chat/completions"
VISION_MODEL = "deepseek-flash"
VISION_MAX_SIDE = 2048
VISION_TIMEOUT = 90.0
VISION_PROMPT = ("请把这张图片里的全部文字按阅读顺序原样转写出来，不要翻译、不要总结、不要补充说明。"
                 "表格逐行输出，单元格之间用 | 分隔。没有文字时只输出：（无文字）")

_CJK = r"[　-〿㐀-鿿豈-﫿＀-￯]"
_FW_PUNCT = r"[　-〿＀-￯]"
_CJK_SPACE = re.compile(rf"(?<={_CJK}) +(?={_CJK})|(?<={_FW_PUNCT}) +|  *(?={_FW_PUNCT})")


def _join_cjk(line: str) -> str:
    """Windows OCR 会在相邻汉字之间、全角标点前后插空格，去掉这些空格；汉字与英文数字之间的空格保留。"""
    return _CJK_SPACE.sub("", line).strip()


def _privacy_ok(settings: dict | None) -> bool:
    s = settings or {}
    privacy = s.get("privacy") if isinstance(s.get("privacy"), dict) else {}
    return bool(privacy.get("cloud_llm_consent", s.get("cloud_llm_consent", False)))


def _vision_key(secrets: dict | None) -> str:
    sec = secrets or {}
    key = str(((sec.get("research") or {}).get("deepseek_api_key")) or "").strip()
    return key or str((((sec.get("llm") or {}).get("openai_compat") or {}).get("api_key")) or "").strip()


def _load_rgb(path: Path):
    from PIL import Image, ImageOps
    img = Image.open(path)
    img.load()
    img = ImageOps.exif_transpose(img)
    if img.mode in ("RGBA", "LA") or (img.mode == "P" and "transparency" in img.info):
        rgba = img.convert("RGBA")
        bg = Image.new("RGB", rgba.size, (255, 255, 255))
        bg.paste(rgba, mask=rgba.split()[-1])
        return bg
    return img.convert("RGB")


def _prepare_tiles(path: Path, work: Path, max_dim: int) -> int:
    """把图片转成 1 张或多张 PNG（000.png、001.png…），返回张数。"""
    from PIL import Image
    img = _load_rgb(path)
    w, h = img.size
    if w < MIN_UPSCALE_WIDTH and h < max_dim // 2:
        img = img.resize((w * 2, h * 2), Image.LANCZOS)
        w, h = img.size
    if w > max_dim:
        h = max(1, int(h * max_dim / w))
        w = max_dim
        img = img.resize((w, h), Image.LANCZOS)
    if h <= max_dim:
        img.save(work / "000.png")
        return 1
    step = max_dim - TILE_OVERLAP
    n = 0
    top = 0
    while top < h and n < 50:
        bottom = min(top + max_dim, h)
        img.crop((0, top, w, bottom)).save(work / f"{n:03d}.png")
        n += 1
        if bottom >= h:
            break
        top += step
    return n


def _run_ps(target: Path, lang: str, timeout: float) -> dict[str, Any]:
    flags = getattr(subprocess, "CREATE_NO_WINDOW", 0)
    proc = subprocess.run(
        ["powershell.exe", "-NoProfile", "-NonInteractive", "-ExecutionPolicy", "Bypass",
         "-File", str(OCR_SCRIPT), "-Path", str(target), "-Lang", lang],
        capture_output=True, timeout=timeout, creationflags=flags, stdin=subprocess.DEVNULL,
    )
    out = (proc.stdout or b"").decode("utf-8", "replace").strip().lstrip("﻿")
    start = out.find("{")
    try:
        return json.loads(out[start:]) if start >= 0 else {"ok": False, "error": "OCR 脚本没有输出"}
    except ValueError:
        return {"ok": False, "error": "OCR 脚本输出格式不正确"}


def _merge_lines(items: list[dict[str, Any]]) -> str:
    """拼接各段结果；相邻两段重叠区的重复行只保留一次。"""
    lines: list[str] = []
    for it in items:
        cur = [_join_cjk(str(x)) for x in it.get("lines") or [] if str(x).strip()]
        if lines and cur:
            for k in range(min(4, len(cur)), 0, -1):
                if lines[-k:] == cur[:k]:
                    cur = cur[k:]
                    break
        lines.extend(cur)
    return "\n".join(lines).strip()


async def _ocr_windows(path: Path, settings: dict | None) -> str:
    if os.name != "nt":
        # Windows 自带 OCR 只在 Windows 上可用；macOS / Linux 上请把 media.ocr 设为 llm（视觉模型，需同意云端）
        # 或 off。这里不抛异常，只记一条日志，报告里该图片就没有 OCR 文本。
        log.warning("当前系统没有 Windows 自带 OCR：请把「设置 → 媒体 → OCR」改成 llm 或 off")
        return ""
    if not OCR_SCRIPT.is_file():
        log.warning("找不到 OCR 脚本：%s", OCR_SCRIPT)
        return ""
    media = (settings or {}).get("media") if isinstance((settings or {}).get("media"), dict) else {}
    lang = str((media or {}).get("ocr_lang") or DEFAULT_LANG)
    if not re.fullmatch(r"[A-Za-z]{2,3}(?:-[A-Za-z0-9]{2,8}){0,3}", lang):
        lang = DEFAULT_LANG
    max_dim = WIN_MAX_DIM
    for _attempt in range(2):
        work = Path(tempfile.mkdtemp(prefix="bureau-ocr-"))
        try:
            n = await asyncio.to_thread(_prepare_tiles, path, work, max_dim)
            res = await asyncio.to_thread(_run_ps, work, lang, OCR_TIMEOUT + 15.0 * n)
        except subprocess.TimeoutExpired:
            log.warning("Windows OCR 超时")
            return ""
        except (OSError, ValueError) as exc:
            log.warning("Windows OCR 无法处理图片：%s", type(exc).__name__)
            return ""
        except Exception as exc:  # noqa: BLE001 — Pillow 的各种解码错误
            log.warning("Windows OCR 无法读取图片：%s", type(exc).__name__)
            return ""
        finally:
            shutil.rmtree(work, ignore_errors=True)
        if res.get("ok"):
            return _merge_lines(res.get("items") or [])
        if res.get("code") == "too_large" and int(res.get("max") or 0) and int(res["max"]) < max_dim:
            max_dim = int(res["max"])
            continue
        if res.get("code") == "no_engine":
            log.warning("本机没有 %s 的 OCR 识别器，请在「设置 → 时间和语言 → 语言」里安装对应语言包", lang)
        else:
            log.warning("Windows OCR 失败：%s", str(res.get("error") or "未知错误")[:120])
        return ""
    return ""


def _vision_data_url(path: Path) -> str:
    from PIL import Image
    img = _load_rgb(path)
    w, h = img.size
    scale = min(1.0, VISION_MAX_SIDE / max(w, h))
    if scale < 1.0:
        img = img.resize((max(1, int(w * scale)), max(1, int(h * scale))), Image.LANCZOS)
    buf = io.BytesIO()
    img.save(buf, format="PNG", optimize=True)
    data, mime = buf.getvalue(), "image/png"
    if len(data) > 6 * 1024 * 1024:
        buf = io.BytesIO()
        img.save(buf, format="JPEG", quality=90)
        data, mime = buf.getvalue(), "image/jpeg"
    return f"data:{mime};base64," + base64.b64encode(data).decode("ascii")


async def _ocr_llm(path: Path, settings: dict | None, secrets: dict | None,
                   transport: httpx.AsyncBaseTransport | None) -> str:
    if not _privacy_ok(settings):
        log.info("跳过视觉模型识别：未同意使用云端服务（privacy.cloud_llm_consent=false）")
        return ""
    key = _vision_key(secrets)
    if not key:
        log.info("跳过视觉模型识别：没有配置 DeepSeek API Key")
        return ""
    try:
        data_url = await asyncio.to_thread(_vision_data_url, path)
    except Exception as exc:  # noqa: BLE001
        log.warning("视觉模型识别无法读取图片：%s", type(exc).__name__)
        return ""
    body = {"model": VISION_MODEL, "thinking": {"type": "disabled"}, "temperature": 0, "max_tokens": 4096,
            "messages": [{"role": "user", "content": [
                {"type": "text", "text": VISION_PROMPT},
                {"type": "image_url", "image_url": {"url": data_url}}]}]}
    try:
        async with httpx.AsyncClient(transport=transport, timeout=httpx.Timeout(VISION_TIMEOUT, connect=10.0)) as client:
            resp = await client.post(VISION_URL, json=body, headers={"Authorization": f"Bearer {key}"})
    except httpx.HTTPError as exc:
        log.warning("视觉模型识别请求失败：%s", type(exc).__name__)
        return ""
    if resp.status_code != 200:
        log.warning("视觉模型识别失败：HTTP %s", resp.status_code)
        return ""
    try:
        text = str(resp.json()["choices"][0]["message"]["content"] or "").strip()
    except (ValueError, KeyError, IndexError, TypeError):
        log.warning("视觉模型返回格式不正确")
        return ""
    return "" if text in ("（无文字）", "(无文字)") else text


async def ocr_image(path: Path, *, mode: str = "windows", settings: dict | None = None,
                    secrets: dict | None = None, transport: httpx.AsyncBaseTransport | None = None) -> str:
    """识别图片里的文字，返回纯文本（多行）。失败或关闭时返回空串。transport 仅供测试注入。"""
    mode = str(mode or "windows").strip().lower()
    if mode in ("off", "none", "false", ""):
        return ""
    p = Path(path)
    if not p.is_file():
        log.warning("OCR：图片不存在")
        return ""
    if mode == "windows":
        return await _ocr_windows(p, settings)
    if mode == "llm":
        return await _ocr_llm(p, settings, secrets, transport)
    log.warning("未知的 OCR 模式：%s，已跳过", mode[:20])
    return ""

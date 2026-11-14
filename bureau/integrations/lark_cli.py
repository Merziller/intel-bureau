"""飞书官方 lark-cli 的查找、调用与错误转中文。

已按 lark-cli 1.0.97/1.0.98 的内置技能文档和源码核实（larksuite/cli main 分支，2026-10-28）：
- 默认输出 JSON。成功信封写 stdout：``{"ok": true, "identity": "...", "data": {...}, "meta": {...}}``；
  错误信封写 stderr：``{"ok": false, "identity": "...", "error": {"type","subtype","code","message","hint",...}}``。
  判断成功看 ``ok == true`` 或退出码 0，不能看 ``code == 0``。
- ``auth status --json`` 输出的是扁平对象（appId、identity、identities.bot/user、note）。
- 退出码 10 表示高风险写操作需要人工确认；本项目不自动追加 ``--yes``。
- ``@file`` / ``--file`` 只接受当前目录下的相对路径。

查找顺序：设置项 cli_path → PATH 上的 lark-cli → third_party/tools/lark-cli（get-lark-cli.ps1 安装处）
→ 本机其它工具自带的 lark-cli。找到 npm 的 .cmd 外壳时优先改用同目录包里的原生 lark-cli.exe，
避免经过 cmd.exe 解析参数。
"""

from __future__ import annotations

import asyncio
import json
import os
import re
import shutil
import subprocess
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any, Awaitable, Callable, Sequence

PROJECT_ROOT = Path(__file__).resolve().parents[2]
LOCAL_INSTALL_DIR = PROJECT_ROOT / "third_party" / "tools" / "lark-cli"
_IS_WIN = os.name == "nt"
# Windows 上是 npm 生成的 .cmd 外壳；macOS / Linux 上 npm 装的是同目录下的 lark-cli 可执行文件（无扩展名）
LOCAL_CMD = LOCAL_INSTALL_DIR / "node_modules" / ".bin" / ("lark-cli.cmd" if _IS_WIN else "lark-cli")
# macOS 包里的安装位置：直接把官方 darwin tar.gz 解到这里（没有 npm 依赖）
LOCAL_BIN = LOCAL_INSTALL_DIR / "bin" / ("lark-cli.exe" if _IS_WIN else "lark-cli")
WORKBUDDY_EXE = (Path.home() / ".workbuddy-ai" / "binaries" / "node" / "cli-connector-packages"
                 / "node_modules" / "@larksuite" / "cli" / "bin" / ("lark-cli.exe" if _IS_WIN else "lark-cli"))
# 提示语里的安装脚本：Windows 是 PowerShell，macOS 是 shell 脚本
INSTALL_HINT = "scripts\\tools\\get-lark-cli.ps1" if _IS_WIN else "scripts/tools/install-bundled-tools-mac.sh"

_PKG_BIN = Path("@larksuite") / "cli" / "bin"
_PKG_EXE = "lark-cli.exe" if _IS_WIN else "lark-cli"
_CMD_META = re.compile(r'[&|<>^%!"\r\n]')
_NOTIFIER_ENV = {"LARKSUITE_CLI_NO_UPDATE_NOTIFIER": "1", "LARKSUITE_CLI_NO_SKILLS_NOTIFIER": "1"}


class LarkCliError(Exception):
    """lark-cli 调用失败。message 是中文，hint 是下一步怎么做。"""

    def __init__(self, message: str, *, hint: str | None = None, kind: str | None = None,
                 code: Any = None, retryable: bool = False, exit_code: int | None = None) -> None:
        super().__init__(message)
        self.message = message
        self.hint = hint
        self.kind = kind
        self.code = code
        self.retryable = retryable
        self.exit_code = exit_code


@dataclass
class CliResult:
    returncode: int
    payload: Any
    stdout: str = ""
    stderr: str = ""
    warnings: list[str] = field(default_factory=list)


def _native_for_shim(path: Path) -> Path | None:
    """npm 生成的 .cmd 外壳 → 同一安装里的原生 lark-cli 可执行文件（存在时）。"""
    if path.suffix.lower() not in (".cmd", ".bat", ".ps1", ""):
        return None
    parent = path.parent
    candidates = []
    if parent.name == ".bin":                       # <prefix>/node_modules/.bin/lark-cli.cmd
        candidates.append(parent.parent / _PKG_BIN / _PKG_EXE)
    candidates.append(parent / "node_modules" / _PKG_BIN / _PKG_EXE)   # 全局安装：<npm>/lark-cli.cmd
    return next((c for c in candidates if c.is_file()), None)


def find_lark_cli(cli_path: str | None = None) -> tuple[str | None, list[str]]:
    """按约定顺序查找 lark-cli，返回 (路径或 None, 中文提示列表)。"""
    notes: list[str] = []
    ordered: list[Path] = []
    if cli_path and cli_path.strip():
        p = Path(os.path.expandvars(os.path.expanduser(cli_path.strip().strip('"'))))
        if p.is_file():
            ordered.append(p)
        else:
            notes.append(f"设置里的 lark-cli 路径不存在：{p}，已改用自动查找")
    found = shutil.which("lark-cli")
    if found:
        ordered.append(Path(found))
    ordered += [LOCAL_CMD, LOCAL_BIN, WORKBUDDY_EXE]
    for cand in ordered:
        if not cand.is_file():
            continue
        native = _native_for_shim(cand)
        return str(native or cand), notes
    return None, notes


Runner = Callable[[Sequence[str], float, str | None, dict[str, str] | None], Awaitable[tuple[int, str, str]]]


async def default_runner(argv: Sequence[str], timeout: float, cwd: str | None,
                         env: dict[str, str] | None) -> tuple[int, str, str]:
    """按项目约定调用子进程：to_thread + subprocess.run + 超时 + CREATE_NO_WINDOW。"""
    flags = getattr(subprocess, "CREATE_NO_WINDOW", 0)
    try:
        proc = await asyncio.to_thread(
            subprocess.run, list(argv), capture_output=True, encoding="utf-8", errors="replace",
            timeout=timeout, creationflags=flags, cwd=cwd, env=env, stdin=subprocess.DEVNULL,
        )
    except subprocess.TimeoutExpired:
        raise LarkCliError(f"lark-cli 执行超时（{timeout:g} 秒）", hint="检查网络，或在设置里调大超时",
                           kind="timeout", retryable=True) from None
    except FileNotFoundError:
        raise LarkCliError("找不到 lark-cli 可执行文件", kind="not_found",
                           hint=f"运行 {INSTALL_HINT} 安装，或在设置里填写 cli_path") from None
    except OSError as exc:
        raise LarkCliError(f"无法启动 lark-cli（{type(exc).__name__}）", kind="os_error") from None
    return proc.returncode, proc.stdout or "", proc.stderr or ""


def extract_json(text: str) -> Any:
    """从可能混有日志行的输出里取出第一个 JSON 对象/数组；没有时返回 None。"""
    s = (text or "").strip()
    if not s:
        return None
    try:
        return json.loads(s)
    except ValueError:
        pass
    dec = json.JSONDecoder()
    for m in re.finditer(r"[{\[]", s):
        try:
            obj, _ = dec.raw_decode(s, m.start())
        except ValueError:
            continue
        if isinstance(obj, (dict, list)):
            return obj
    return None


_RATE_LIMIT_CODES = {99991400, 11232, 230020}
_BOT_NOT_IN_CHAT_CODES = {230002, 232011, 232033}


def error_from_envelope(err: dict[str, Any], identity: str | None, exit_code: int | None) -> LarkCliError:
    """把 lark-cli 的错误信封翻译成中文 LarkCliError。"""
    etype = str(err.get("type") or "")
    sub = str(err.get("subtype") or "")
    code = err.get("code")
    raw_msg = str(err.get("message") or "").strip()
    raw_hint = str(err.get("hint") or "").strip()
    scopes = err.get("missing_scopes") or []
    who = "机器人" if identity == "bot" else "用户"
    if etype == "authentication" or sub in ("token_missing", "token_expired", "need_user_authorization"):
        if identity == "bot":
            return LarkCliError("机器人身份认证失败，应用凭证可能已失效", kind="auth", code=code, exit_code=exit_code,
                                hint="运行 `lark-cli config init` 检查应用配置")
        return LarkCliError("飞书用户授权已过期或尚未登录", kind="auth", code=code, exit_code=exit_code,
                            hint="在终端运行 `lark-cli auth login` 重新授权")
    if etype == "authorization" or sub == "missing_scope":
        need = "、".join(str(s) for s in scopes) if scopes else "相关权限"
        hint = ("在飞书开发者后台为应用开通权限：" + need) if identity == "bot" else (
            f"在终端运行 `lark-cli auth login --scope \"{' '.join(map(str, scopes))}\"` 补充授权" if scopes
            else "在终端运行 `lark-cli auth login` 重新授权")
        return LarkCliError(f"{who}身份缺少权限：{need}", kind="scope", code=code, hint=hint, exit_code=exit_code)
    if exit_code == 10:
        return LarkCliError("lark-cli 要求人工确认这项高风险操作，工作台不会自动确认", kind="confirm",
                            code=code, exit_code=exit_code, hint="如确需执行，请在终端手动运行该命令")
    try:
        icode = int(code) if code is not None else None
    except (TypeError, ValueError):
        icode = None
    if icode in _RATE_LIMIT_CODES or "frequency" in raw_msg.lower() or "rate limit" in raw_msg.lower():
        return LarkCliError("飞书接口限流，请稍后再试", kind="rate_limit", code=code, retryable=True, exit_code=exit_code)
    if icode in _BOT_NOT_IN_CHAT_CODES or "not in the chat" in raw_msg.lower() or "not in chat" in raw_msg.lower():
        return LarkCliError(f"{who}不在该会话中", kind="not_in_chat", code=code, exit_code=exit_code,
                            hint="把机器人拉进目标群，或改用用户身份")
    if etype in ("network", "internal") or sub in ("network", "timeout"):
        return LarkCliError(f"lark-cli 网络错误：{raw_msg[:160]}", kind="network", code=code, retryable=True,
                            exit_code=exit_code)
    msg = raw_msg[:200] or f"lark-cli 返回错误（{etype or '未知'}）"
    return LarkCliError(f"飞书返回错误：{msg}" + (f"（错误码 {code}）" if code else ""), kind=etype or "api",
                        code=code, hint=raw_hint[:200] or None, exit_code=exit_code)


class LarkCli:
    """lark-cli 封装。runner 可注入（测试用假实现，不启动子进程）。"""

    def __init__(self, path: str | None = None, *, cli_path: str | None = None, runner: Runner | None = None,
                 timeout: float = 60.0) -> None:
        self.notes: list[str] = []
        if path is None:
            path, self.notes = find_lark_cli(cli_path)
        self.path = path
        self.runner = runner or default_runner
        self.timeout = timeout

    @property
    def available(self) -> bool:
        return bool(self.path)

    def _env(self) -> dict[str, str]:
        env = dict(os.environ)
        env.update(_NOTIFIER_ENV)
        return env

    async def run_raw(self, args: Sequence[str], *, timeout: float | None = None,
                      cwd: str | None = None) -> CliResult:
        if not self.path:
            raise LarkCliError("没有找到 lark-cli", kind="not_found",
                               hint=f"运行 {INSTALL_HINT} 安装，或在设置里填写 cli_path")
        if Path(self.path).suffix.lower() in (".cmd", ".bat") and any(_CMD_META.search(a) for a in args):
            raise LarkCliError("当前 lark-cli 是 .cmd 外壳，参数里含有命令行特殊字符，已拒绝执行",
                               kind="unsafe_args", hint=f"改用原生 lark-cli.exe（运行 {INSTALL_HINT} 安装）")
        rc, out, err = await self.runner([self.path, *args], float(timeout or self.timeout), cwd, self._env())
        payload = extract_json(out)
        if payload is None:
            payload = extract_json(err)
        return CliResult(returncode=rc, payload=payload, stdout=out, stderr=err)

    async def run(self, args: Sequence[str], *, timeout: float | None = None, cwd: str | None = None,
                  identity: str | None = None) -> Any:
        """执行命令并返回成功信封里的 data；失败抛 LarkCliError（中文）。"""
        res = await self.run_raw(args, timeout=timeout, cwd=cwd)
        p = res.payload
        if isinstance(p, dict) and p.get("ok") is True and res.returncode == 0:
            return p.get("data")
        if isinstance(p, dict) and isinstance(p.get("error"), dict):
            raise error_from_envelope(p["error"], identity or p.get("identity"), res.returncode)
        if res.returncode == 0 and p is not None:
            return p
        tail = (res.stderr or res.stdout).strip().splitlines()
        reason = tail[-1][:200] if tail else "无输出"
        if res.returncode == 10:
            raise error_from_envelope({}, identity, 10)
        raise LarkCliError(f"lark-cli 执行失败（退出码 {res.returncode}）：{reason}", kind="exit",
                           exit_code=res.returncode)

    async def auth_status(self, *, verify: bool = False, timeout: float = 15.0) -> dict[str, Any]:
        args = ["auth", "status", "--json"] + (["--verify"] if verify else [])
        res = await self.run_raw(args, timeout=timeout)
        if isinstance(res.payload, dict) and "identities" in res.payload:
            return res.payload
        if isinstance(res.payload, dict) and isinstance(res.payload.get("error"), dict):
            raise error_from_envelope(res.payload["error"], None, res.returncode)
        raise LarkCliError(f"无法读取 lark-cli 登录状态（退出码 {res.returncode}）", kind="auth_status",
                           hint="在终端运行 `lark-cli auth status` 查看详情")

    async def version(self, *, timeout: float = 10.0) -> str | None:
        res = await self.run_raw(["--version"], timeout=timeout)
        m = re.search(r"(\d+\.\d+\.\d+)", res.stdout or res.stderr)
        return m.group(1) if m else None


_STATUS_CN = {
    "ready": "可用", "valid": "可用", "missing": "未登录", "expired": "授权已过期",
    "refresh_expired": "刷新令牌已过期", "invalid": "凭证无效", "unconfigured": "未配置",
    "needs_refresh": "访问令牌已过期，下次调用时自动续期",
}


def _refresh_still_valid(ident: dict[str, Any]) -> bool:
    """needs_refresh 时，刷新令牌（7 天）是否还没过期。读不到时间就按「还没过期」处理，真正的失败会在调用时暴露。"""
    from datetime import datetime, timezone

    raw = str(ident.get("refreshExpiresAt") or "").strip()
    if not raw:
        return True
    try:
        dt = datetime.fromisoformat(raw)
    except ValueError:
        return True
    if dt.tzinfo is None:
        dt = dt.astimezone()
    return dt > datetime.now(timezone.utc)


@dataclass
class IdentityState:
    identity: str
    available: bool
    status: str
    detail: str
    open_id: str | None = None
    user_name: str | None = None
    scopes: frozenset[str] = frozenset()


def identity_state(status: dict[str, Any], identity: str) -> IdentityState:
    """从 ``auth status --json`` 结果里取某个身份（bot/user）的状态，并给出中文说明。"""
    ident = ((status or {}).get("identities") or {}).get(identity) or {}
    raw = str(ident.get("status") or "unknown")
    available = bool(ident.get("available")) and raw in ("ready", "valid", "ok")
    msg = str(ident.get("message") or "")
    cn = _STATUS_CN.get(raw, raw)
    refresh_dead = "refresh token expired" in msg.lower()
    if raw != "needs_refresh" and str(ident.get("tokenStatus")) == "expired":
        refresh_dead = True
    # needs_refresh 下 tokenStatus 很可能就是 expired（指访问令牌），不能据此判定刷新令牌失效；只看报错文字和刷新令牌到期时间
    if raw == "needs_refresh" and not _refresh_still_valid(ident):
        refresh_dead = True
    if raw == "needs_refresh" and not refresh_dead:
        # 访问令牌（2 小时）过期是正常现象：lark-cli 在下一次真实调用时会用刷新令牌（7 天）自动续期，
        # 并把刷新令牌的有效期顺延。只看本地状态的健康检查不会触发续期，所以不能把它当成故障。
        available = True
    if refresh_dead:
        cn = "授权已过期（刷新令牌失效）"
    who = "机器人身份" if identity == "bot" else "用户身份"
    scope_str = str(ident.get("scope") or "")
    return IdentityState(
        identity=identity, available=available, status=raw, detail=f"{who}：{cn}",
        open_id=str(ident.get("openId") or "") or None, user_name=str(ident.get("userName") or "") or None,
        scopes=frozenset(scope_str.split()) if scope_str else frozenset(),
    )


def sanitize_arg(text: str, *, max_len: int = 200) -> str:
    """用于标题等命令行参数：去掉换行和 cmd 特殊字符（换成全角或空格），限制长度。"""
    table = str.maketrans({"|": "｜", "&": "＆", "<": "＜", ">": "＞", "^": "＾", "%": "％", "!": "！",
                           '"': "“", "\r": " ", "\n": " "})
    return (text or "").translate(table).strip()[:max_len]
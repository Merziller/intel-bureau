"""脚本文件的编码 / 行尾 / 可解析性。

都是踩过的坑：

- `.ps1` 里写了中文，必须带 **恰好一个** UTF-8 BOM，否则 Windows PowerShell 5.1 会按 GBK 解码，
  中文变乱码、引号被吃掉，最后报 `Missing closing '}'`；BOM 重复两个同样会解析失败。
- `.sh` / `.command` 不能带 BOM，否则 macOS 报 `#!/bin/bash: No such file or directory`。
- `.sh` / `.command` 必须是 LF，CRLF 会让 shebang 失效。

`.bat` 的检查在 `test_launchers.py`，macOS 入口的行尾检查在 `test_launchers_mac.py`；
这里只管 `.ps1`（连同 PS 5.1 的真实解析）。
"""

from __future__ import annotations

import os
import shutil
import subprocess
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[1]
PS1 = sorted(p for p in ROOT.rglob("*.ps1") if "node_modules" not in p.parts)
BOM = b"\xef\xbb\xbf"


def _powershell() -> str | None:
    exe = shutil.which("powershell.exe") or shutil.which("powershell")
    return exe if exe and os.name == "nt" else None


@pytest.mark.parametrize("path", PS1, ids=lambda p: p.name)
def test_ps1_has_exactly_one_bom(path: Path):
    raw = path.read_bytes()
    assert raw.startswith(BOM), f"{path.name} 缺少 UTF-8 BOM：Windows PowerShell 5.1 会按 GBK 解码，中文变乱码"
    assert not raw.startswith(BOM * 2), f"{path.name} 有两个 BOM，PowerShell 会解析失败"
    assert BOM not in raw[3:], f"{path.name} 中间还有 BOM 字符，可能是拼接时重复写入"
    assert b"\x00" not in raw, f"{path.name} 像是 UTF-16，请存成带 BOM 的 UTF-8"


@pytest.mark.parametrize("path", PS1, ids=lambda p: p.name)
def test_ps1_parses_in_powershell(path: Path):
    """真的让 PowerShell 解析一遍：中文被解码错时这里会报 Missing closing '}'。只在 Windows 上跑。"""
    exe = _powershell()
    if not exe:
        pytest.skip("只在 Windows 上用 PowerShell 检查 .ps1 语法")
    script = (
        "$err = $null; "
        f"[void][System.Management.Automation.Language.Parser]::ParseFile('{path}', [ref]$null, [ref]$err); "
        "if ($err.Count -gt 0) { $err | ForEach-Object { $_.Message }; exit 1 } else { exit 0 }"
    )
    res = subprocess.run([exe, "-NoProfile", "-NonInteractive", "-Command", script],
                         capture_output=True, timeout=120)
    out = (res.stdout + res.stderr).decode("mbcs", errors="replace")
    assert res.returncode == 0, f"{path.name} 解析失败：{out[:400]}"

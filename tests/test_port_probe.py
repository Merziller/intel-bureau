"""启动 / 停止脚本的端口探测方式。

背景：在部分 Windows（实测 10.0.26300 / Windows 11 家庭版中文）上，真实监听的 socket
用 `Get-NetTCPConnection -State Listen` 查不到（状态列是空值），
`netstat -ano` 的状态列也是空白。结果是：

- `scripts/stop.ps1` 误报「端口上没有在运行的工作台」，服务其实还活着；
- `scripts/start.ps1` 的端口占用检查失效。

所以两个脚本都必须用「连一下」来判断端口（TcpClient.BeginConnect），
不能把 `-State Listen` 当唯一依据。这里做静态检查，防止以后改回去。
"""

from __future__ import annotations

import re
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[1]
SCRIPTS = ROOT / "scripts"
STOP = SCRIPTS / "stop.ps1"
START = SCRIPTS / "start.ps1"

# macOS 包不带 .ps1（入口是 .command 与 *-mac.sh），这里整体跳过
if not (STOP.is_file() and START.is_file()):
    pytest.skip("当前目录没有 PowerShell 启动脚本（macOS 侧用 .command），跳过", allow_module_level=True)

# 只要出现「-State Listen」并且是拿来当唯一判断依据，就是回归
STATE_LISTEN = re.compile(r"Get-NetTCPConnection[^\r\n]*-State\s+Listen", re.IGNORECASE)


def test_scripts_exist():
    assert STOP.is_file(), "scripts/stop.ps1 不见了"
    assert START.is_file(), "scripts/start.ps1 不见了"


def test_stop_does_not_rely_on_state_listen():
    text = STOP.read_text("utf-8-sig")
    assert not STATE_LISTEN.search(text), (
        "stop.ps1 又用 Get-NetTCPConnection -State Listen 判断端口了。"
        "部分 Windows 上监听 socket 的状态是空值，会误报「没有在运行」。请用 Test-PortInUse。"
    )
    assert "Test-PortInUse" in text, "stop.ps1 应该用 Test-PortInUse（TcpClient 连接探测）"
    assert "BeginConnect" in text, "stop.ps1 的 Test-PortInUse 应该用 TcpClient.BeginConnect"


def test_start_does_not_rely_on_state_listen():
    text = START.read_text("utf-8-sig")
    assert not STATE_LISTEN.search(text), (
        "start.ps1 又用 Get-NetTCPConnection -State Listen 做端口占用检查了，请改用 Test-PortInUse。"
    )
    assert "Test-PortInUse" in text, "start.ps1 应该用 Test-PortInUse（TcpClient 连接探测）"


def test_stop_only_kills_bureau_serve():
    """stop.ps1 只能杀真的 `python -m bureau serve`，不能碰用户其它程序。"""
    text = STOP.read_text("utf-8-sig")
    assert re.search(r"bureau\\s\+serve", text), "stop.ps1 应该用 CommandLine 匹配 bureau serve 才允许杀进程"
    assert "taskkill" in text.lower(), "stop.ps1 应该用 taskkill 结束进程树"


def test_stop_uses_netstat_fallback():
    """netstat 是 -State Listen 之外的第二个来源，不能只有 Get-NetTCPConnection。"""
    text = STOP.read_text("utf-8-sig")
    assert "netstat" in text.lower(), "stop.ps1 应该先解析 netstat -ano 找 pid"

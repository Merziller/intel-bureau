"""macOS 启动器（*.command / scripts/*-mac.sh）：Finder 双击的就是这些文件，格式一错就「一闪而过」。

规则（和 .bat 那套一样，都是踩过的坑）：
- 必须是 UTF-8（macOS 终端默认 UTF-8，中文没问题），且不能有 BOM；
- 行尾必须全是 LF：CRLF 会让 `#!/bin/bash` 变成 `bash\\r`，报 bad interpreter；
- 第一行必须是 `#!/bin/bash`；
- 引用的脚本要真的存在（`bash scripts/xxx.sh`）；
- 能拿到 bash 时做一次 `bash -n` 语法检查。
"""

from __future__ import annotations

import re
import shutil
import subprocess
from pathlib import Path

import pytest

ROOT = Path(__file__).resolve().parents[1]
ENTRY = sorted(ROOT.glob("*.command"))
MAC_SH = sorted((ROOT / "scripts").glob("*-mac.sh")) + sorted((ROOT / "scripts" / "tools").glob("*-mac.sh"))
ALL = ENTRY + MAC_SH
IDS = [p.relative_to(ROOT).as_posix() for p in ALL]

# 没有 .command 入口时整体跳过（Windows 那边是 .bat / .ps1），Windows 入口见 test_launchers.py
if not ALL:
    pytest.skip("这个包里没有 macOS 入口（.command / *-mac.sh），跳过", allow_module_level=True)


def _bash() -> str | None:
    """找一个能读 Windows 路径的 bash。

    注意：不能用 shutil.which('bash') —— 在 Windows 上它常常先找到
    C:\\Windows\\System32\\bash.EXE，那是 WSL 的转发壳，遇到 E:\\... 这种盘符路径会直接报
    「No such file or directory」。所以要优先 Git Bash。
    """
    for cand in (r"D:\Git\bin\bash.exe", r"D:\Git\usr\bin\bash.exe",
                 r"C:\Program Files\Git\bin\bash.exe", r"C:\Program Files\Git\usr\bin\bash.exe",
                 "/bin/bash", "/usr/bin/bash"):
        if Path(cand).is_file():
            return cand
    found = shutil.which("bash")
    if found and "system32" not in found.lower():
        return found
    return None


def test_there_are_mac_entrypoints():
    assert ENTRY, "根目录应该有 .command 双击入口（启动 / 一键安装 / 停止 / 安装接入工具 / 飞书重新授权）"
    assert MAC_SH, "scripts 里应该有 *-mac.sh"


@pytest.mark.parametrize("path", ALL, ids=IDS)
def test_mac_script_is_utf8_lf_and_has_shebang(path: Path):
    raw = path.read_bytes()
    assert not raw.startswith(b"\xef\xbb\xbf"), f"{path.name} 不要带 UTF-8 BOM"
    text = raw.decode("utf-8")  # 不是 UTF-8 会在这里抛错
    assert b"\r\n" not in raw, f"{path.name} 行尾必须是 LF（CRLF 会让 #!/bin/bash 变成 bash\\r）"
    assert text.startswith("#!/bin/bash\n"), f"{path.name} 第一行必须是 #!/bin/bash"
    assert text.endswith("\n"), f"{path.name} 末尾要有换行"


@pytest.mark.parametrize("path", ALL, ids=IDS)
def test_mac_script_referenced_files_exist(path: Path):
    text = path.read_text("utf-8")
    for m in re.finditer(r"bash\s+\"?\$(?:ROOT)?/?([\w./-]+\.sh)\"?", text):
        target = m.group(1)
        # 脚本里会拼 $ROOT/... 或直接相对路径；两种都按项目根解析
        assert (ROOT / target).is_file() or (ROOT / "scripts" / target).is_file(), \
            f"{path.name} 引用了不存在的脚本：{target}"


@pytest.mark.parametrize("path", ALL, ids=IDS)
def test_mac_script_syntax(path: Path):
    bash = _bash()
    if not bash:
        pytest.skip("这台机器上没有 bash，跳过语法检查")
    res = subprocess.run([bash, "-n", str(path)], capture_output=True, timeout=60)
    assert res.returncode == 0, f"{path.name} 语法错误：{(res.stdout + res.stderr).decode('utf-8', 'replace')[:400]}"


def test_mac_setup_does_not_build_web_when_dist_exists():
    """web/dist 已构建时，安装脚本不应该再跑 npm（用户机器上不一定有 Node）。"""
    text = (ROOT / "scripts" / "setup-mac.sh").read_text("utf-8")
    assert 'web/dist/index.html' in text
    assert "npm ci" in text, "没有 dist 时仍要能构建"
    # 有 dist 的分支要在 npm 之前，并且直接跳过
    head = text.split("npm ci")[0]
    assert "跳过构建" in head

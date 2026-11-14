#!/bin/bash
# 个人情报局 · macOS 安装（第一次运行用）
# 由「一键安装并启动.command」调用；也可以手动：bash scripts/setup-mac.sh
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
VENV_PY="$ROOT/.venv/bin/python"

say()  { printf '%s\n' "$*"; }
step() { printf '\n==> %s\n' "$*"; }
fail() { printf '\n[出错了] %s\n' "$*"; printf '看不懂的话，把这段文字截图发给给你这个包的人。\n'; exit 1; }

say ''
say '=== 个人情报局 · 安装（macOS）==='
say "安装位置：$ROOT"

case "$ROOT" in
  *" "*|*"（"*|*"）"*)
    say ''
    say '提醒：这个文件夹路径里有空格或中文括号。多数情况没问题，但如果安装失败，'
    say '建议把整个文件夹移到 用户目录/IntelBureau 这样简单的位置再试。'
    ;;
esac

# ---- 1. 找 Python 3.12 ----
step '检查 Python 3.12'
PY=""
for c in python3.12 python3 python; do
  if command -v "$c" >/dev/null 2>&1; then
    if "$c" -c 'import sys; raise SystemExit(0 if sys.version_info[:2] == (3, 12) else 1)' 2>/dev/null; then
      PY="$c"; break
    fi
  fi
done
if [ -z "$PY" ]; then
  say '没有找到 Python 3.12。'
  if command -v brew >/dev/null 2>&1; then
    say '检测到 Homebrew，正在安装 Python 3.12（需要几分钟）...'
    brew install python@3.12 || fail 'Homebrew 安装 Python 3.12 失败。可以手动运行：brew install python@3.12'
    PY="$(brew --prefix)/bin/python3.12"
  else
    say ''
    say '请先安装 Python 3.12，两种方法任选一种：'
    say '  1）打开 https://www.python.org/downloads/macos/ 下载 "Python 3.12.x macOS installer" 安装；'
    say '  2）先装 Homebrew（https://brew.sh），再重新双击「一键安装并启动.command」。'
    fail '缺少 Python 3.12'
  fi
fi
say "Python 3.12 已就绪：$("$PY" -c 'import sys; print(sys.version.split()[0])')"

# ---- 2. 虚拟环境 + 依赖 ----
if [ ! -x "$VENV_PY" ]; then
  step '创建虚拟环境 .venv'
  "$PY" -m venv .venv || fail '创建虚拟环境失败'
else
  step '已有虚拟环境 .venv，更新依赖'
fi

step '安装 Python 依赖（第一次大约 2~5 分钟，需要联网）'
"$VENV_PY" -m pip install --disable-pip-version-check -q --upgrade pip || fail '升级 pip 失败'
"$VENV_PY" -m pip install --disable-pip-version-check -q -r requirements.txt || fail '安装依赖失败，请检查网络后重试'
say '依赖安装完成。'

# ---- 3. 前端：仓库里已经有构建好的 web/dist 就跳过 ----
if [ -f "$ROOT/web/dist/index.html" ]; then
  step '前端已经构建好（web/dist），跳过构建'
elif [ -f "$ROOT/web/package.json" ] && command -v npm >/dev/null 2>&1; then
  step '构建前端（npm ci && npm run build）'
  ( cd "$ROOT/web" && npm ci && npm run build ) || fail '前端构建失败'
else
  say '提醒：没有 web/dist，也没有可用的 npm，访问工作台时会看到提示页。'
fi

# ---- 4. 初始化 ----
step '初始化配置与数据库'
PYTHONIOENCODING=utf-8 "$VENV_PY" -X utf8 -m bureau init || fail '初始化失败'

say ''
say '安装完成。'
say "  体检：   .venv/bin/python -X utf8 -m bureau doctor"
say "  启动：   双击根目录的「启动情报局.command」"

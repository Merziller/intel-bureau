#!/bin/bash
# 双击「一键安装并启动.command」时执行：安装（如果还没装）+ 写入演示数据 + 启动
# 保持这个终端窗口显示结果；出问题时停在这里等你看清楚。
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
VENV_PY="$ROOT/.venv/bin/python"

pause() {
  printf '\n按回车键关闭这个窗口...'
  read -r _ || true
}

if [ ! -x "$VENV_PY" ]; then
  echo '检测到第一次运行，先安装（需要联网，大约 2~5 分钟），请不要关闭这个窗口。'
  bash "$ROOT/scripts/setup-mac.sh" || { pause; exit 1; }
fi

if [ ! -f "$ROOT/data/bureau.db" ]; then
  echo ''
  echo '写入演示数据（全是虚构的群和对话），并生成一份演示报告...'
  PYTHONIOENCODING=utf-8 "$VENV_PY" -X utf8 -m bureau demo seed || echo '演示数据没有写入成功（不影响使用）。'
  PYTHONIOENCODING=utf-8 "$VENV_PY" -X utf8 -m bureau run --demo --dry-run || echo '演示报告没有生成（不影响使用）。'
fi

bash "$ROOT/scripts/start-mac.sh"
rc=$?
if [ $rc -ne 0 ]; then
  echo ''
  echo "启动失败（退出码 $rc）。日志在 $ROOT/data/logs/。"
  pause
else
  echo ''
  echo '大屏窗口已打开。这个终端窗口可以直接关掉，不影响工作台。'
  echo '关闭大屏窗口约 20 秒后，后台服务会自动停止。'
  sleep 2
fi

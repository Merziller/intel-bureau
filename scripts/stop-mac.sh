#!/bin/bash
# 个人情报局 · macOS 停止后台服务
# 双击根目录「停止情报局.command」，或手动：bash scripts/stop-mac.sh
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PORT="${BUREAU_PORT:-8765}"

if ! /usr/sbin/lsof -nP -iTCP:"$PORT" -sTCP:LISTEN >/dev/null 2>&1; then
  echo "端口 $PORT 上没有在运行的工作台。"
  exit 0
fi
PIDS="$(/usr/sbin/lsof -nP -iTCP:"$PORT" -sTCP:LISTEN -t 2>/dev/null)"
for pid in $PIDS; do
  cmd="$(ps -o command= -p "$pid" 2>/dev/null)"
  case "$cmd" in
    *"bureau serve"*) kill "$pid" 2>/dev/null && echo "已停止工作台（pid $pid）" ;;
    *) echo "端口 $PORT 被别的程序占用（pid $pid），不是情报局工作台，没有动它。" ;;
  esac
done
sleep 1
if /usr/sbin/lsof -nP -iTCP:"$PORT" -sTCP:LISTEN >/dev/null 2>&1; then
  echo '没能停止，请重试，或者在「活动监视器」里结束 python 进程。'
  exit 1
fi
echo '工作台已停止。'

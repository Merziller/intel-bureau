#!/bin/bash
# 个人情报局 · macOS 启动
# 双击根目录「启动情报局.command」即可；也可以手动：bash scripts/start-mac.sh
#
# 行为与 Windows 版一致：服务在后台运行（没有终端窗口），用 Edge/Chrome 的「应用窗口」或默认浏览器打开大屏；
# 所有大屏页面关闭后约 20 秒，服务自己停止（有任务在跑时会等它跑完）。
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
PORT="${BUREAU_PORT:-8765}"
VENV_PY="$ROOT/.venv/bin/python"
URL="http://127.0.0.1:$PORT"
DATA_DIR="${BUREAU_DATA_DIR:-$ROOT/data}"
LOG_DIR="$DATA_DIR/logs"
LAUNCHER_LOG="$LOG_DIR/launcher.log"
SERVER_OUT="$LOG_DIR/server-console.log"
SERVER_ERR="$LOG_DIR/server-console.err.log"
mkdir -p "$LOG_DIR"

log() { printf '%s  %s\n' "$(date '+%m-%d %H:%M:%S')" "$*" >>"$LAUNCHER_LOG" 2>/dev/null; }

# 没有终端窗口时，用系统弹窗告诉用户出了什么事
popup() {
  local msg="$1"
  /usr/bin/osascript -e "display alert \"个人情报局\" message \"${msg//\"/\\\"}\" as critical" >/dev/null 2>&1 || true
}

healthy() {
  curl -fsS --max-time 2 "$URL/api/health" >/dev/null 2>&1
}

open_app_window() {
  local app=""
  # 优先用 Edge / Chrome 的「应用模式」，看起来像独立程序，没有地址栏
  for p in "/Applications/Microsoft Edge.app/Contents/MacOS/Microsoft Edge" \
           "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"; do
    [ -x "$p" ] && { app="$p"; break; }
  done
  if [ -n "$app" ]; then
    "$app" --app="$URL" --user-data-dir="$DATA_DIR/app-profile" \
           --no-first-run --no-default-browser-check >/dev/null 2>&1 &
    log "已打开应用窗口（$app）"
  else
    /usr/bin/open "$URL"
    log '没有 Edge / Chrome，用默认浏览器打开'
  fi
}

log "启动 Port=$PORT"
[ -x "$VENV_PY" ] || { popup "还没有安装。请先双击「一键安装并启动.command」。"; exit 1; }

if healthy; then
  log '工作台已在运行，只打开窗口'
  open_app_window
  exit 0
fi

# 端口被别的程序占用
if /usr/sbin/lsof -nP -iTCP:"$PORT" -sTCP:LISTEN >/dev/null 2>&1; then
  popup "端口 $PORT 已被别的程序占用，工作台没法启动。关闭那个程序，或双击「停止情报局.command」后再试。"
  log "端口 $PORT 被占用"
  exit 1
fi

export PYTHONIOENCODING=utf-8
nohup "$VENV_PY" -X utf8 -m bureau serve --port "$PORT" --exit-when-idle 20 \
  >"$SERVER_OUT" 2>"$SERVER_ERR" &
SRV=$!
log "服务进程已启动 pid=$SRV"

for _ in $(seq 1 180); do          # 最多等 90 秒（第一次启动、系统安全扫描会慢）
  if ! kill -0 "$SRV" 2>/dev/null; then break; fi
  if healthy; then break; fi
  sleep 0.5
done

if ! healthy; then
  kill "$SRV" 2>/dev/null
  tail_txt="$(tail -n 6 "$SERVER_ERR" 2>/dev/null)"
  popup "服务没能启动。可以重新双击「一键安装并启动.command」修复安装。
详细日志：$SERVER_ERR
$tail_txt"
  log '服务没能启动'
  exit 1
fi
log '服务已就绪'

open_app_window
exit 0

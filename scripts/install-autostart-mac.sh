#!/bin/bash
# 安装 macOS 开机自启：登录后在后台常驻运行工作台（不开大屏窗口）
# 用法：bash scripts/install-autostart-mac.sh
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LABEL="com.intelbureau.workbench"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
VENV_PY="$ROOT/.venv/bin/python"
LOG_DIR="$ROOT/data/logs"

say() { printf '%s\n' "$*"; }
die() { printf '错误：%s\n' "$*" >&2; exit 1; }

if [ "$(uname -s)" != "Darwin" ]; then
  die "这个脚本只能在 macOS 上运行。"
fi

if [ ! -x "$VENV_PY" ]; then
  die "还没有安装依赖，请先双击「一键安装并启动.command」。"
fi

mkdir -p "$(dirname "$PLIST")" "$LOG_DIR"

cat > "$PLIST" <<PLIST_EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>$LABEL</string>
  <key>ProgramArguments</key>
  <array>
    <string>$VENV_PY</string>
    <string>-X</string>
    <string>utf8</string>
    <string>-m</string>
    <string>bureau</string>
    <string>serve</string>
    <string>--port</string>
    <string>8765</string>
  </array>
  <key>WorkingDirectory</key>
  <string>$ROOT</string>
  <key>EnvironmentVariables</key>
  <dict>
    <key>PYTHONIOENCODING</key>
    <string>utf-8</string>
  </dict>
  <key>RunAtLoad</key>
  <true/>
  <key>KeepAlive</key>
  <false/>
  <key>StandardOutPath</key>
  <string>$LOG_DIR/service.log</string>
  <key>StandardErrorPath</key>
  <string>$LOG_DIR/service.err.log</string>
</dict>
</plist>
PLIST_EOF

say "已写入 $PLIST"

# 如果已经加载过，先卸载再加载，保证配置生效
launchctl unload "$PLIST" >/dev/null 2>&1 || true
if launchctl load "$PLIST" 2>/dev/null; then
  say "开机自启已启用：登录后工作台会在后台启动，大屏不用开着。"
  say "日志：$LOG_DIR/service.log"
  say "取消：bash scripts/uninstall-autostart-mac.sh"
else
  die "写入配置成功，但 launchctl load 失败。可以重启一次再试，或手动运行：launchctl load \"$PLIST\""
fi

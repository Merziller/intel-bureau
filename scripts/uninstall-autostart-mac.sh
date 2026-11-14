#!/bin/bash
# 取消 macOS 开机自启
# 用法：bash scripts/uninstall-autostart-mac.sh
set -u

LABEL="com.intelbureau.workbench"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"

say() { printf '%s\n' "$*"; }

if [ "$(uname -s)" != "Darwin" ]; then
  printf '这个脚本只能在 macOS 上运行。\n' >&2
  exit 1
fi

if [ ! -f "$PLIST" ]; then
  say "没有找到开机自启配置（$PLIST），可能本来就没装。"
  exit 0
fi

launchctl unload "$PLIST" >/dev/null 2>&1 || true
if rm -f "$PLIST"; then
  say "已取消开机自启，并删除 $PLIST。"
  say "如果后台服务还在跑，可以双击「停止情报局.command」，或运行 bash scripts/stop-mac.sh"
else
  printf '删除失败：%s\n' "$PLIST" >&2
  exit 1
fi

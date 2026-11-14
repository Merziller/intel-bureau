#!/bin/bash
# Double-click to stop the background workbench service.
cd "$(dirname "$0")" || exit 1
bash scripts/stop-mac.sh
printf '\n按回车键关闭这个窗口...'
read -r _ || true

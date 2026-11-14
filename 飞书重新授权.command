#!/bin/bash
# Double-click to re-authorise Feishu (user identity: messages + docs).
cd "$(dirname "$0")" || exit 1
bash scripts/feishu-reauth-mac.sh "$@"
printf '\n按回车键关闭这个窗口...'
read -r _ || true

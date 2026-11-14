#!/bin/bash
# Double-click to start the Intel Bureau workbench on macOS.
# A console window flashes up and closes by itself; the dashboard opens in its own app window.
cd "$(dirname "$0")" || exit 1
if [ ! -x .venv/bin/python ]; then
  echo 'Still setting up (or not installed yet). Running the one-click setup first...'
  bash scripts/first-run-mac.sh
  exit $?
fi
bash scripts/start-mac.sh
exit $?

#!/bin/bash
# Double-click on a fresh copy: install everything, then start. Keeps the window open if something fails.
cd "$(dirname "$0")" || exit 1
bash scripts/first-run-mac.sh

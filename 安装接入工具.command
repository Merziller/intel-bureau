#!/bin/bash
# Double-click to prepare the three data-source tools bundled with this copy.
cd "$(dirname "$0")" || exit 1
bash scripts/tools/install-bundled-tools-mac.sh "$@"

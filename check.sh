#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
forge fmt --check
forge build
forge test
python3 scripts/artifacts.py --check

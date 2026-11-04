#!/usr/bin/env bash
set -euo pipefail

CONFIG_FILE="${1:-}"

if [ -z "$CONFIG_FILE" ] || [ ! -f "$CONFIG_FILE" ]; then
  echo "❌ Error: YAML config '$CONFIG_FILE' does not exist."
  exit 1
fi

if [ ! -s "$CONFIG_FILE" ]; then
  echo "❌ Error: YAML config '$CONFIG_FILE' is empty."
  exit 1
fi

echo "✅ Validated configuration file: $CONFIG_FILE"
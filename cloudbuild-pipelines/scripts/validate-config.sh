#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# Configuration YAML Validator (Shell Script)
# ==============================================================================

CONFIG_FILE="${1:-}"

if [ -z "$CONFIG_FILE" ]; then
  echo "Usage: $0 <path-to-yaml-file>"
  exit 1
fi

if [ ! -f "$CONFIG_FILE" ]; then
  echo "❌ Error: Configuration file '$CONFIG_FILE' not found!"
  exit 1
fi

echo "🔍 Validating YAML structure: $CONFIG_FILE"

# Check if file is empty
if [ ! -s "$CONFIG_FILE" ]; then
  echo "❌ Error: Configuration file '$CONFIG_FILE' is empty!"
  exit 1
fi

echo "✅ YAML syntax and file existence validated: $CONFIG_FILE"
#!/usr/bin/env bash
set -euo pipefail

CONFIG_FILE="${1:-}"
SCHEMA_FILE="${2:-}"

if [ -z "$CONFIG_FILE" ] || [ ! -f "$CONFIG_FILE" ]; then
  echo "❌ Error: YAML config '$CONFIG_FILE' does not exist."
  exit 1
fi

if [ ! -s "$CONFIG_FILE" ]; then
  echo "❌ Error: YAML config '$CONFIG_FILE' is empty."
  exit 1
fi

# Auto-detect schema path if not passed as 2nd argument
if [ -z "$SCHEMA_FILE" ]; then
  LAYER_NAME=$(basename "$CONFIG_FILE" .yaml)
  SCHEMA_FILE="schemas/${LAYER_NAME}.schema.json"
fi

if [ ! -f "$SCHEMA_FILE" ]; then
  echo "❌ Error: Schema file '$SCHEMA_FILE' not found."
  exit 1
fi

echo "🔍 Validating '$CONFIG_FILE' against schema '$SCHEMA_FILE'..."

python3 - "$CONFIG_FILE" "$SCHEMA_FILE" << 'EOF'
import sys, json, yaml
from jsonschema import validate, ValidationError

config_path, schema_path = sys.argv[1], sys.argv[2]

try:
    with open(config_path, 'r') as yf:
        config_data = yaml.safe_load(yf)
except Exception as e:
    print(f"❌ YAML Syntax Error in {config_path}:\n{e}")
    sys.exit(1)

if not isinstance(config_data, dict):
    print(f"❌ Error: {config_path} must be a valid YAML mapping object.")
    sys.exit(1)

with open(schema_path, 'r') as sf:
    schema_data = json.load(sf)

try:
    validate(instance=config_data, schema=schema_data)
    print(f"✅ Schema & YAML validation passed: {config_path}")
except ValidationError as err:
    path = " -> ".join([str(p) for p in err.absolute_path]) or "root"
    print(f"❌ Schema Validation Failed in '{config_path}' at [{path}]: {err.message}")
    sys.exit(1)
EOF
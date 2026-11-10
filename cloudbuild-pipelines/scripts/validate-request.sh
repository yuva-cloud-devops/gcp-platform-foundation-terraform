#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# PR Deployment Request Validator & Mapping Engine (Pure Bash - No jq dependency)
# ==============================================================================

PAYLOAD_FILE="${1:-pr_body.txt}"
OUTPUT_JSON="deployment_scope.json"

if [ ! -f "$PAYLOAD_FILE" ]; then
  echo "❌ Error: Payload file '$PAYLOAD_FILE' not found!"
  exit 1
fi

echo "🔍 Parsing deployment request from: $PAYLOAD_FILE"

# 1. Extract environment (dev, qat, prod)
ENV=$(grep -E '^[[:space:]]*environment:' "$PAYLOAD_FILE" | head -n 1 | awk '{print $2}' | tr -d '\r"' || true)

if [ -z "$ENV" ]; then
  echo "❌ Error: Missing 'environment' in deployment_request."
  exit 1
fi

case "$ENV" in
  dev|qat|prod)
    echo "✅ Environment: $ENV"
    ;;
  *)
    echo "❌ Error: Invalid environment '$ENV'. Must be one of: dev, qat, prod"
    exit 1
    ;;
esac

# 2. Extract requested infrastructure items
INFRAS=()
READING_INFRA=false

while IFS= read -r line || [ -n "$line" ]; do
  line=$(echo "$line" | tr -d '\r')

  if [[ "$line" =~ ^[[:space:]]*infrastructure: ]]; then
    READING_INFRA=true
    continue
  fi

  if [ "$READING_INFRA" = true ]; then
    if [[ "$line" =~ ^[[:space:]]*[a-zA-Z0-9_]+: ]] || [[ "$line" =~ ^\`\`\` ]]; then
      READING_INFRA=false
      continue
    fi

    if [[ "$line" =~ ^[[:space:]]*-[[:space:]]*([a-zA-Z0-9_-]+) ]]; then
      ITEM="${BASH_REMATCH[1]}"
      INFRAS+=("$ITEM")
    fi
  fi
done < "$PAYLOAD_FILE"

if [ ${#INFRAS[@]} -eq 0 ]; then
  echo "❌ Error: No infrastructure items found in deployment_request."
  exit 1
fi

echo "📋 Infrastructure requested: ${INFRAS[*]}"

# 3. Resolve directory & YAML paths (Pure Bash array construction)
TARGET_ENTRIES=()

for infra in "${INFRAS[@]}"; do
  case "$infra" in
    network)
      DIR="1-network-infrastructure"
      CONFIG_FILE="environments/${ENV}/network.yaml"
      SCHEMA_FILE="schemas/network.schema.json"
      ORDER=1
      ;;
    security)
      DIR="2-security-infrastructure"
      CONFIG_FILE="environments/${ENV}/security.yaml"
      SCHEMA_FILE="schemas/security.schema.json"
      ORDER=2
      ;;
    compute)
      DIR="3-compute-infrastructure"
      CONFIG_FILE="environments/${ENV}/compute.yaml"
      SCHEMA_FILE="schemas/compute.schema.json"
      ORDER=3
      ;;
    availability)
      DIR="4-availability-infrastructure"
      CONFIG_FILE="environments/${ENV}/availability.yaml"
      SCHEMA_FILE="schemas/availability.schema.json"
      ORDER=4
      ;;
    *)
      echo "❌ Error: Unsupported infrastructure type '$infra'"
      exit 1
      ;;
  esac

  if [ ! -d "$DIR" ]; then
    echo "❌ Error: Directory '$DIR' not found."
    exit 1
  fi

  if [ ! -f "$CONFIG_FILE" ]; then
    echo "❌ Error: Config file '$CONFIG_FILE' not found."
    exit 1
  fi

  ENTRY=$(cat <<EOF
    {
      "name": "$infra",
      "dir": "$DIR",
      "config": "$CONFIG_FILE",
      "schema": "$SCHEMA_FILE",
      "order": $ORDER
    }
EOF
)
  TARGET_ENTRIES+=("$ENTRY")
done

# 4. Construct deployment_scope.json without jq
cat <<EOF > "$OUTPUT_JSON"
{
  "environment": "$ENV",
  "targets": [
$(IFS=,; echo "${TARGET_ENTRIES[*]}")
  ]
}
EOF

echo "=========================================================="
echo "✅ deployment_scope.json generated successfully:"
echo "=========================================================="
cat "$OUTPUT_JSON"
echo ""
echo "=========================================================="
#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# PR Deployment Request Validator & Mapping Engine (Shell Script)
# ==============================================================================

PAYLOAD_FILE="${1:-pr_body.txt}"
OUTPUT_JSON="deployment_scope.json"

if [ ! -f "$PAYLOAD_FILE" ]; then
  echo "❌ Error: Payload file '$PAYLOAD_FILE' not found!"
  exit 1
fi

echo "🔍 Parsing deployment request from: $PAYLOAD_FILE"

# 1. Extract environment using grep/awk/sed
ENV=$(grep -E '^[[:space:]]*environment:' "$PAYLOAD_FILE" | head -n 1 | awk '{print $2}' | tr -d '\r"' || true)

if [ -z "$ENV" ]; then
  echo "❌ Error: Missing 'environment' in deployment_request."
  echo "Expected: environment: dev | qat | prod"
  exit 1
fi

# Validate allowed environment
case "$ENV" in
  dev|qat|prod)
    echo "✅ Environment selected: $ENV"
    ;;
  *)
    echo "❌ Error: Invalid environment '$ENV'. Must be one of: dev, qat, prod"
    exit 1
    ;;
esac

# 2. Extract infrastructure list
# Reads lines following 'infrastructure:' until the next top-level key
INFRAS=()
READING_INFRA=false

while IFS= read -r line || [ -n "$line" ]; do
  # Remove carriage return
  line=$(echo "$line" | tr -d '\r')

  if [[ "$line" =~ ^[[:space:]]*infrastructure: ]]; then
    READING_INFRA=true
    continue
  fi

  if [ "$READING_INFRA" = true ]; then
    # Stop reading if line is another top-level key or closing fence
    if [[ "$line" =~ ^[[:space:]]*[a-zA-Z0-9_]+: ]] || [[ "$line" =~ ^\`\`\` ]]; then
      READING_INFRA=false
      continue
    fi

    # Match list item: - network / - compute
    if [[ "$line" =~ ^[[:space:]]*-[[:space:]]*([a-zA-Z0-9_-]+) ]]; then
      ITEM="${BASH_REMATCH[1]}"
      INFRAS+=("$ITEM")
    fi
  fi
done < "$PAYLOAD_FILE"

if [ ${#INFRAS[@]} -eq 0 ]; then
  echo "❌ Error: No infrastructure items found in 'infrastructure:' list."
  echo "Expected format:"
  echo "deployment_request:"
  echo "  infrastructure:"
  echo "    - network"
  echo "  environment: $ENV"
  exit 1
fi

echo "📋 Infrastructure requested: ${INFRAS[*]}"

# 3. Mapping Dictionary & Directory Validation
# Array to build targets JSON
TARGETS_JSON="[]"

for infra in "${INFRAS[@]}"; do
  DIR=""
  CONFIG_FILE=""
  SCHEMA_FILE=""
  ORDER=0

  case "$infra" in
    network)
      DIR="1-network-infrastructure"
      CONFIG_FILE="environments/${ENV}/network.yaml"
      SCHEMA_FILE="schemas/network.schema.json"
      ORDER=1
      ;;
    compute)
      DIR="2-compute-infrastructure"
      CONFIG_FILE="environments/${ENV}/compute.yaml"
      SCHEMA_FILE="schemas/compute.schema.json"
      ORDER=2
      ;;
    security)
      DIR="3-security-infrastructure"
      CONFIG_FILE="environments/${ENV}/security.yaml"
      SCHEMA_FILE="schemas/security.schema.json"
      ORDER=3
      ;;
    availability)
      DIR="4-availability-infrastructure"
      CONFIG_FILE="environments/${ENV}/availability.yaml"
      SCHEMA_FILE="schemas/availability.schema.json"
      ORDER=4
      ;;
    *)
      echo "❌ Error: Unsupported infrastructure type: '$infra'"
      echo "Allowed: network, compute, security, availability"
      exit 1
      ;;
  esac

  # Verify target folder and YAML file existence
  if [ ! -d "$DIR" ]; then
    echo "❌ Error: Target directory '$DIR' does not exist in repository."
    exit 1
  fi

  if [ ! -f "$CONFIG_FILE" ]; then
    echo "❌ Error: Configuration file '$CONFIG_FILE' does not exist."
    exit 1
  fi

  # Append to targets JSON array
  TARGET_ENTRY=$(cat <<EOF
{
  "name": "$infra",
  "dir": "$DIR",
  "config": "$CONFIG_FILE",
  "schema": "$SCHEMA_FILE",
  "order": $ORDER
}
EOF
)
  TARGETS_JSON=$(echo "$TARGETS_JSON" | jq ". += [$TARGET_ENTRY]")
done

# 4. Sort targets by execution order (network -> compute -> security -> availability)
SORTED_TARGETS=$(echo "$TARGETS_JSON" | jq 'sort_by(.order)')

# 5. Build final deployment_scope.json
cat <<EOF > "$OUTPUT_JSON"
{
  "environment": "$ENV",
  "targets": $SORTED_TARGETS
}
EOF

echo "=========================================================="
echo "✅ deployment_scope.json successfully generated:"
echo "=========================================================="
cat "$OUTPUT_JSON" | jq .
echo "=========================================================="
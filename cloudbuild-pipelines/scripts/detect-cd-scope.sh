#!/usr/bin/env bash
set -euo pipefail

# ==============================================================================
# CD Scope Detector (Pure Bash, Zero PAT Required)
# Extracts PR Number & Changed Infrastructures from Git
# Strict Hierarchy: Network -> Security -> Compute -> Availability
# ==============================================================================

OUTPUT_FILE="${1:-deployment_scope.json}"
REPO_OWNER="${2:-yuva-cloud-devops}"
REPO_NAME="${3:-gcp-platform-foundation-terraform}"

echo "🔍 Analyzing latest merge commit on main..."

# 1. Extract PR Number from the merge commit message
COMMIT_MSG=$(git log -1 --pretty=%B || true)
PR_NUMBER=$(echo "$COMMIT_MSG" | grep -oE '#[0-9]+' | head -n 1 | tr -d '#' || echo "N/A")
echo "Merged PR Number: #$PR_NUMBER"

# 2. Detect which environments/<env>/<infra>.yaml files were modified in this commit
CHANGED_FILES=$(git diff-tree --no-commit-id --name-only -r HEAD || git diff --name-only HEAD~1 HEAD || true)

ENV=""
DETECTED_INFRAS=()

for file in $CHANGED_FILES; do
  if [[ "$file" =~ ^environments/([^/]+)/([^/]+)\.ya?ml$ ]]; then
    DETECTED_ENV="${BASH_REMATCH[1]}"
    INFRA_NAME="${BASH_REMATCH[2]}"

    if [ -z "$ENV" ]; then
      ENV="$DETECTED_ENV"
    fi
    DETECTED_INFRAS+=("$INFRA_NAME")
  fi
done

# Fallback: Default to 'dev' / 'network' if no specific environment YAML was modified
ENV="${ENV:-dev}"
if [ ${#DETECTED_INFRAS[@]} -eq 0 ]; then
  DETECTED_INFRAS=("network")
fi

# 3. Enforce Architectural Execution Hierarchy (Bootstrap excluded):
# 1. network -> 2. security -> 3. compute -> 4. availability
ORDERED_HIERARCHY=("network" "security" "compute" "availability")

TARGETS_JSON="[]"
for ordered_name in "${ORDERED_HIERARCHY[@]}"; do
  for detected in "${DETECTED_INFRAS[@]}"; do
    if [ "$ordered_name" = "$detected" ]; then
      case "$detected" in
        network)      DIR="1-network-infrastructure" ;;
        security)     DIR="3-security-infrastructure" ;;
        compute)      DIR="2-compute-infrastructure" ;;
        availability) DIR="4-availability-infrastructure" ;;
        *) DIR="" ;;
      esac

      if [ -n "$DIR" ] && [ -d "$DIR" ]; then
        TARGETS_JSON=$(echo "$TARGETS_JSON" | jq --arg name "$detected" --arg dir "$DIR" \
          '. += [{"name": $name, "dir": $dir}] | unique_by(.name)')
      fi
    fi
  done
done

# 4. Generate deployment_scope.json
jq -n \
  --arg env "$ENV" \
  --arg pr "$PR_NUMBER" \
  --argjson targets "$TARGETS_JSON" \
  '{environment: $env, pr_number: $pr, targets: $targets, action: "apply"}' > "$OUTPUT_FILE"

echo "✅ Generated CD Scope (Zero PAT Needed):"
cat "$OUTPUT_FILE"
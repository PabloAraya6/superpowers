#!/usr/bin/env bash
# run-advisor.sh — Invoke an external AI advisor and persist a structured artifact.
#
# Usage: run-advisor.sh <provider> <prompt> [original_task]
#   provider:       codex | gemini
#   prompt:         The full prompt to send (self-contained with context)
#   original_task:  (optional) The user's original request for artifact metadata
#
# Output: Writes artifact to .ccg/artifacts/<provider>-<timestamp>.md
#         Prints the raw advisor output to stdout.
#
# Exit codes: 0 = success, 1 = missing binary, 2 = advisor error

set -euo pipefail

PROVIDER="${1:?Usage: run-advisor.sh <provider> <prompt> [original_task]}"
PROMPT="${2:?Usage: run-advisor.sh <provider> <prompt> [original_task]}"
ORIGINAL_TASK="${3:-$PROMPT}"
TIMEOUT="${CCG_TIMEOUT:-120}"

# --- Verify binary ---
check_binary() {
  command -v "$1" >/dev/null 2>&1
}

case "$PROVIDER" in
  codex)
    if ! check_binary codex; then
      echo "ERROR: codex CLI not found. Install with: npm install -g @openai/codex" >&2
      exit 1
    fi
    ;;
  gemini)
    if ! check_binary gemini; then
      echo "ERROR: gemini CLI not found. Install with: npm install -g @google/gemini-cli" >&2
      exit 1
    fi
    ;;
  *)
    echo "ERROR: Unknown provider '$PROVIDER'. Use 'codex' or 'gemini'." >&2
    exit 1
    ;;
esac

# --- Run advisor ---
TIMESTAMP=$(date -u +"%Y%m%d-%H%M%S")
RAW_OUTPUT=""
EXIT_CODE=0

case "$PROVIDER" in
  codex)
    # Strip Rust env vars that pollute stderr
    RAW_OUTPUT=$(env -u RUST_LOG -u RUST_BACKTRACE -u RUST_LIB_BACKTRACE \
      timeout "$TIMEOUT" codex exec --dangerously-bypass-approvals-and-sandbox "$PROMPT" 2>&1) || EXIT_CODE=$?
    ;;
  gemini)
    RAW_OUTPUT=$(timeout "$TIMEOUT" gemini -p "$PROMPT" --yolo 2>&1) || EXIT_CODE=$?
    ;;
esac

# --- Print raw output to stdout ---
echo "$RAW_OUTPUT"

# --- Write artifact ---
ARTIFACT_DIR=".ccg/artifacts"
mkdir -p "$ARTIFACT_DIR"

SLUG=$(echo "$ORIGINAL_TASK" | tr '[:upper:]' '[:lower:]' | tr -cs '[:alnum:]' '-' | head -c 40 | sed 's/-$//')
ARTIFACT_FILE="$ARTIFACT_DIR/${PROVIDER}-${SLUG}-${TIMESTAMP}.md"

cat > "$ARTIFACT_FILE" <<ARTIFACT
# ${PROVIDER} advisor artifact
- Provider: ${PROVIDER}
- Exit code: ${EXIT_CODE}
- Created: $(date -u +"%Y-%m-%dT%H:%M:%SZ")

## Original task
${ORIGINAL_TASK}

## Prompt sent
${PROMPT}

## Raw output
${RAW_OUTPUT}
ARTIFACT

echo "" >&2
echo "Artifact saved: $ARTIFACT_FILE" >&2

exit $EXIT_CODE

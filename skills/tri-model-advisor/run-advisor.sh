#!/usr/bin/env bash
# run-advisor.sh — Run Codex and Gemini advisors in parallel, persist artifacts.
#
# Usage:
#   run-advisor.sh <codex-prompt-file> <gemini-prompt-file> [original-task]
#
# Both prompt files are paths to markdown files containing the full prompt.
# Output: Writes artifacts to .ccg/artifacts/ and prints both outputs.
#
# Environment variables:
#   CCG_TIMEOUT      Timeout per advisor in seconds (default: 120)
#   CCG_CODEX_MODEL  Codex model override (default: o4-mini)
#   CCG_GEMINI_MODEL Gemini model override (default: auto)
#
# Exit: 0 if at least one advisor succeeded, 1 if both failed.

set -uo pipefail

CODEX_PROMPT_FILE="${1:?Usage: run-advisor.sh <codex-prompt-file> <gemini-prompt-file> [original-task]}"
GEMINI_PROMPT_FILE="${2:?Usage: run-advisor.sh <codex-prompt-file> <gemini-prompt-file> [original-task]}"
ORIGINAL_TASK="${3:-Tri-model advisor query}"

TIMEOUT="${CCG_TIMEOUT:-120}"
CODEX_MODEL="${CCG_CODEX_MODEL:-o4-mini}"
GEMINI_MODEL="${CCG_GEMINI_MODEL:-auto}"
TIMESTAMP=$(date -u +"%Y%m%d-%H%M%S")
ARTIFACT_DIR=".ccg/artifacts"

mkdir -p "$ARTIFACT_DIR"

# --- Temp files for output ---
CODEX_OUT=$(mktemp /tmp/ccg-codex-XXXXXX.txt)
GEMINI_OUT=$(mktemp /tmp/ccg-gemini-XXXXXX.txt)
trap 'rm -f "$CODEX_OUT" "$GEMINI_OUT"' EXIT

# --- Check binaries ---
CODEX_AVAILABLE=false
GEMINI_AVAILABLE=false

if command -v codex >/dev/null 2>&1; then
  CODEX_AVAILABLE=true
fi

if command -v gemini >/dev/null 2>&1; then
  GEMINI_AVAILABLE=true
fi

if [ "$CODEX_AVAILABLE" = false ] && [ "$GEMINI_AVAILABLE" = false ]; then
  echo "ERROR: Neither codex nor gemini CLI found." >&2
  echo "Install: npm install -g @openai/codex @google/gemini-cli" >&2
  exit 1
fi

# --- Run advisors in parallel ---
CODEX_PID=""
GEMINI_PID=""
CODEX_EXIT="-1"
GEMINI_EXIT="-1"

if [ "$CODEX_AVAILABLE" = true ]; then
  CODEX_PROMPT=$(cat "$CODEX_PROMPT_FILE")
  (
    env -u RUST_LOG -u RUST_BACKTRACE -u RUST_LIB_BACKTRACE \
      timeout "$TIMEOUT" codex exec --full-auto -m "$CODEX_MODEL" "$CODEX_PROMPT" \
      > "$CODEX_OUT" 2>&1
  ) &
  CODEX_PID=$!
fi

if [ "$GEMINI_AVAILABLE" = true ]; then
  GEMINI_PROMPT=$(cat "$GEMINI_PROMPT_FILE")
  (
    timeout "$TIMEOUT" gemini -p "$GEMINI_PROMPT" --approval-mode=yolo -m "$GEMINI_MODEL" \
      > "$GEMINI_OUT" 2>&1
  ) &
  GEMINI_PID=$!
fi

# --- Wait and collect ---
if [ -n "$CODEX_PID" ]; then
  wait "$CODEX_PID" 2>/dev/null
  CODEX_EXIT=$?
fi

if [ -n "$GEMINI_PID" ]; then
  wait "$GEMINI_PID" 2>/dev/null
  GEMINI_EXIT=$?
fi

# --- Write artifacts ---
write_artifact() {
  local provider="$1"
  local model="$2"
  local exit_code="$3"
  local prompt_file="$4"
  local output_file="$5"

  local artifact_file="$ARTIFACT_DIR/${provider}-${TIMESTAMP}.md"

  cat > "$artifact_file" <<ARTIFACT
# ${provider} advisor artifact
- Provider: ${provider}
- Model: ${model}
- Exit code: ${exit_code}
- Created: $(date -u +"%Y-%m-%dT%H:%M:%SZ")

## Task
${ORIGINAL_TASK}

## Prompt sent
$(cat "$prompt_file")

## Response
$(cat "$output_file")
ARTIFACT

  echo "$artifact_file"
}

if [ "$CODEX_AVAILABLE" = true ]; then
  CODEX_ARTIFACT=$(write_artifact "codex" "$CODEX_MODEL" "$CODEX_EXIT" "$CODEX_PROMPT_FILE" "$CODEX_OUT")
fi

if [ "$GEMINI_AVAILABLE" = true ]; then
  GEMINI_ARTIFACT=$(write_artifact "gemini" "$GEMINI_MODEL" "$GEMINI_EXIT" "$GEMINI_PROMPT_FILE" "$GEMINI_OUT")
fi

# --- Print results ---
echo "=========================================="
echo "  CCG Tri-Model Advisor Results"
echo "=========================================="
echo ""

if [ "$CODEX_AVAILABLE" = true ]; then
  echo "--- CODEX (model: $CODEX_MODEL, exit: $CODEX_EXIT) ---"
  cat "$CODEX_OUT"
  echo ""
  echo "Artifact: $CODEX_ARTIFACT"
else
  echo "--- CODEX: NOT AVAILABLE ---"
fi

echo ""

if [ "$GEMINI_AVAILABLE" = true ]; then
  echo "--- GEMINI (model: $GEMINI_MODEL, exit: $GEMINI_EXIT) ---"
  cat "$GEMINI_OUT"
  echo ""
  echo "Artifact: $GEMINI_ARTIFACT"
else
  echo "--- GEMINI: NOT AVAILABLE ---"
fi

echo ""
echo "=========================================="

# Exit 0 if at least one succeeded
if [ "$CODEX_EXIT" = "0" ] || [ "$GEMINI_EXIT" = "0" ]; then
  exit 0
else
  exit 1
fi

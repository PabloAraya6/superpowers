#!/usr/bin/env bash
# run-advisor.sh — Orchestrate parallel Codex + Gemini advisor execution.
#
# Usage:
#   run-advisor.sh <codex-prompt-file> <gemini-prompt-file> [options]
#
# Options:
#   --task <string>          Original task description for artifact metadata
#   --mode <string>          Mode: review|architecture|security|brainstorm|general (default: general)
#   --codex-model <string>   Codex model override (default: $CCG_CODEX_MODEL or o4-mini)
#   --gemini-model <string>  Gemini model override (default: $CCG_GEMINI_MODEL or pro)
#   --timeout <seconds>      Per-advisor timeout (default: $CCG_TIMEOUT or 120)
#   --review-base <branch>   For REVIEW mode: use codex review --base <branch> instead of exec
#   --review-uncommitted     For REVIEW mode: use codex review --uncommitted
#   --skip-codex             Skip Codex advisor
#   --skip-gemini            Skip Gemini advisor
#   --debug                  Print debug information
#
# Environment:
#   CCG_TIMEOUT, CCG_CODEX_MODEL, CCG_GEMINI_MODEL
#
# Output:
#   Writes artifacts to .ccg/artifacts/
#   Prints both advisor outputs to stdout with separators.
#   Exit 0 if at least one advisor succeeded, 1 if both failed.

set -uo pipefail

# --- macOS-compatible timeout ---
# macOS doesn't have GNU timeout; use perl fallback
if command -v gtimeout >/dev/null 2>&1; then
  TIMEOUT_CMD="gtimeout"
elif command -v timeout >/dev/null 2>&1; then
  TIMEOUT_CMD="timeout"
else
  # Perl-based fallback for macOS
  _timeout() {
    local secs="$1"; shift
    perl -e 'alarm shift; exec @ARGV' "$secs" "$@"
  }
  TIMEOUT_CMD="_timeout"
fi

# --- Parse arguments ---
CODEX_PROMPT_FILE=""
GEMINI_PROMPT_FILE=""
TASK="Tri-model advisor query"
MODE="general"
CODEX_MODEL="${CCG_CODEX_MODEL:-o3}"
GEMINI_MODEL="${CCG_GEMINI_MODEL:-gemini-2.5-pro}"
TIMEOUT="${CCG_TIMEOUT:-120}"
REVIEW_BASE=""
REVIEW_UNCOMMITTED=false
SKIP_CODEX=false
SKIP_GEMINI=false
DEBUG=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --task) TASK="$2"; shift 2 ;;
    --mode) MODE="$2"; shift 2 ;;
    --codex-model) CODEX_MODEL="$2"; shift 2 ;;
    --gemini-model) GEMINI_MODEL="$2"; shift 2 ;;
    --timeout) TIMEOUT="$2"; shift 2 ;;
    --review-base) REVIEW_BASE="$2"; shift 2 ;;
    --review-uncommitted) REVIEW_UNCOMMITTED=true; shift ;;
    --skip-codex) SKIP_CODEX=true; shift ;;
    --skip-gemini) SKIP_GEMINI=true; shift ;;
    --debug) DEBUG=true; shift ;;
    *)
      if [ -z "$CODEX_PROMPT_FILE" ]; then
        CODEX_PROMPT_FILE="$1"
      elif [ -z "$GEMINI_PROMPT_FILE" ]; then
        GEMINI_PROMPT_FILE="$1"
      fi
      shift
      ;;
  esac
done

if [ -z "$CODEX_PROMPT_FILE" ] || [ -z "$GEMINI_PROMPT_FILE" ]; then
  echo "Usage: run-advisor.sh <codex-prompt-file> <gemini-prompt-file> [options]" >&2
  exit 1
fi

# --- Debug helper ---
debug() {
  if [ "$DEBUG" = true ]; then
    echo "[DEBUG] $*" >&2
  fi
}

# --- Check binaries ---
CODEX_AVAILABLE=false
GEMINI_AVAILABLE=false

if [ "$SKIP_CODEX" = false ] && command -v codex >/dev/null 2>&1; then
  CODEX_AVAILABLE=true
  debug "codex: $(codex --version 2>/dev/null || echo 'version unknown')"
fi

if [ "$SKIP_GEMINI" = false ] && command -v gemini >/dev/null 2>&1; then
  GEMINI_AVAILABLE=true
  debug "gemini: $(gemini --version 2>/dev/null || echo 'version unknown')"
fi

if [ "$CODEX_AVAILABLE" = false ] && [ "$GEMINI_AVAILABLE" = false ]; then
  echo "ERROR: No advisors available." >&2
  echo "Install: npm install -g @openai/codex @google/gemini-cli" >&2
  exit 1
fi

# --- Setup ---
TIMESTAMP=$(date -u +"%Y%m%d-%H%M%S")
ARTIFACT_DIR=".ccg/artifacts"
mkdir -p "$ARTIFACT_DIR"

CODEX_OUT=$(mktemp /tmp/ccg-codex-XXXXXX.txt)
GEMINI_OUT=$(mktemp /tmp/ccg-gemini-XXXXXX.txt)
trap 'rm -f "$CODEX_OUT" "$GEMINI_OUT"' EXIT

CODEX_PID=""
GEMINI_PID=""
CODEX_EXIT="-1"
GEMINI_EXIT="-1"
CODEX_QUALITY="SKIPPED"
GEMINI_QUALITY="SKIPPED"

# --- Launch advisors in parallel ---
debug "Mode: $MODE | Timeout: ${TIMEOUT}s"
debug "Codex model: $CODEX_MODEL | Gemini model: $GEMINI_MODEL"

START_TIME=$(date +%s)

if [ "$CODEX_AVAILABLE" = true ]; then
  if [ "$MODE" = "review" ] && { [ -n "$REVIEW_BASE" ] || [ "$REVIEW_UNCOMMITTED" = true ]; }; then
    # REVIEW mode: use codex review subcommand
    REVIEW_FLAGS=""
    if [ -n "$REVIEW_BASE" ]; then
      REVIEW_FLAGS="--base $REVIEW_BASE"
    elif [ "$REVIEW_UNCOMMITTED" = true ]; then
      REVIEW_FLAGS="--uncommitted"
    fi
    debug "Running: codex review $REVIEW_FLAGS"
    (
      env -u RUST_LOG -u RUST_BACKTRACE -u RUST_LIB_BACKTRACE \
        $TIMEOUT_CMD "$TIMEOUT" codex review --skip-git-repo-check $REVIEW_FLAGS \
        > "$CODEX_OUT" 2>&1
    ) &
    CODEX_PID=$!
  else
    CODEX_PROMPT=$(cat "$CODEX_PROMPT_FILE")
    debug "Running: codex exec --full-auto -m $CODEX_MODEL"
    (
      env -u RUST_LOG -u RUST_BACKTRACE -u RUST_LIB_BACKTRACE \
        $TIMEOUT_CMD "$TIMEOUT" codex exec --full-auto --skip-git-repo-check -m "$CODEX_MODEL" "$CODEX_PROMPT" \
        > "$CODEX_OUT" 2>&1
    ) &
    CODEX_PID=$!
  fi
fi

if [ "$GEMINI_AVAILABLE" = true ]; then
  GEMINI_PROMPT=$(cat "$GEMINI_PROMPT_FILE")
  debug "Running: gemini -p ... --approval-mode=yolo -m $GEMINI_MODEL"
  (
    $TIMEOUT_CMD "$TIMEOUT" gemini -p "$GEMINI_PROMPT" \
      --approval-mode=yolo -m "$GEMINI_MODEL" --output-format text \
      > "$GEMINI_OUT" 2>&1
  ) &
  GEMINI_PID=$!
fi

# --- Wait for completion ---
if [ -n "$CODEX_PID" ]; then
  wait "$CODEX_PID" 2>/dev/null
  CODEX_EXIT=$?
  debug "Codex finished with exit code: $CODEX_EXIT"
fi

if [ -n "$GEMINI_PID" ]; then
  wait "$GEMINI_PID" 2>/dev/null
  GEMINI_EXIT=$?
  debug "Gemini finished with exit code: $GEMINI_EXIT"
fi

END_TIME=$(date +%s)
ELAPSED=$((END_TIME - START_TIME))
debug "Total wall time: ${ELAPSED}s"

# --- Validate output quality ---
validate_output() {
  local file="$1"
  local exit_code="$2"

  if [ "$exit_code" = "-1" ]; then
    echo "SKIPPED"
    return
  fi

  if [ ! -s "$file" ]; then
    echo "FAILED"
    return
  fi

  local lines
  lines=$(wc -l < "$file" | tr -d ' ')
  local chars
  chars=$(wc -c < "$file" | tr -d ' ')

  if [ "$exit_code" != "0" ] && [ "$chars" -lt 50 ]; then
    echo "FAILED"
    return
  fi

  # Check if output is mostly error messages
  local error_lines
  error_lines=$(grep -cEi '(error|exception|traceback|panic|fatal)' "$file" 2>/dev/null || echo 0)
  if [ "$error_lines" -gt "$((lines / 2))" ] && [ "$lines" -gt 2 ]; then
    echo "FAILED"
    return
  fi

  # Check for truncation (ends mid-sentence without punctuation)
  local last_char
  last_char=$(tail -c 1 "$file" 2>/dev/null)
  if [ "$lines" -gt 10 ] && echo "$last_char" | grep -qv '[.!?}\])`"]'; then
    echo "PARTIAL"
    return
  fi

  if [ "$chars" -lt 200 ] && [ "$lines" -lt 5 ]; then
    echo "LOW-QUALITY"
    return
  fi

  echo "OK"
}

CODEX_QUALITY=$(validate_output "$CODEX_OUT" "$CODEX_EXIT")
GEMINI_QUALITY=$(validate_output "$GEMINI_OUT" "$GEMINI_EXIT")
debug "Quality — Codex: $CODEX_QUALITY | Gemini: $GEMINI_QUALITY"

# --- Write artifacts ---
write_artifact() {
  local provider="$1"
  local model="$2"
  local exit_code="$3"
  local quality="$4"
  local prompt_file="$5"
  local output_file="$6"

  local artifact_file="$ARTIFACT_DIR/${provider}-${TIMESTAMP}.md"

  cat > "$artifact_file" <<ARTIFACT
# ${provider} advisor artifact

| Field | Value |
|---|---|
| Provider | ${provider} |
| Model | ${model} |
| Mode | ${MODE} |
| Exit code | ${exit_code} |
| Quality | ${quality} |
| Created | $(date -u +"%Y-%m-%dT%H:%M:%SZ") |
| Wall time | ${ELAPSED}s (parallel) |
| Debate | none |

## Task
${TASK}

## Prompt Sent
$(cat "$prompt_file" 2>/dev/null || echo "(review mode — no custom prompt)")

## Response
$(cat "$output_file" 2>/dev/null || echo "(no output)")
ARTIFACT

  echo "$artifact_file"
}

CODEX_ARTIFACT=""
GEMINI_ARTIFACT=""

if [ "$CODEX_AVAILABLE" = true ]; then
  CODEX_ARTIFACT=$(write_artifact "codex" "$CODEX_MODEL" "$CODEX_EXIT" "$CODEX_QUALITY" "$CODEX_PROMPT_FILE" "$CODEX_OUT")
fi

if [ "$GEMINI_AVAILABLE" = true ]; then
  GEMINI_ARTIFACT=$(write_artifact "gemini" "$GEMINI_MODEL" "$GEMINI_EXIT" "$GEMINI_QUALITY" "$GEMINI_PROMPT_FILE" "$GEMINI_OUT")
fi

# --- Print results ---
echo "══════════════════════════════════════════"
echo "  CCG Tri-Model Advisor Results"
echo "  Mode: ${MODE} | Time: ${ELAPSED}s"
echo "══════════════════════════════════════════"
echo ""

if [ "$CODEX_AVAILABLE" = true ]; then
  echo "── CODEX (model: $CODEX_MODEL | exit: $CODEX_EXIT | quality: $CODEX_QUALITY) ──"
  cat "$CODEX_OUT"
  echo ""
  [ -n "$CODEX_ARTIFACT" ] && echo "📄 Artifact: $CODEX_ARTIFACT"
else
  echo "── CODEX: SKIPPED ──"
fi

echo ""

if [ "$GEMINI_AVAILABLE" = true ]; then
  echo "── GEMINI (model: $GEMINI_MODEL | exit: $GEMINI_EXIT | quality: $GEMINI_QUALITY) ──"
  cat "$GEMINI_OUT"
  echo ""
  [ -n "$GEMINI_ARTIFACT" ] && echo "📄 Artifact: $GEMINI_ARTIFACT"
else
  echo "── GEMINI: SKIPPED ──"
fi

echo ""
echo "══════════════════════════════════════════"

# Exit 0 if at least one advisor produced usable output
if [ "$CODEX_QUALITY" = "OK" ] || [ "$CODEX_QUALITY" = "PARTIAL" ] || \
   [ "$GEMINI_QUALITY" = "OK" ] || [ "$GEMINI_QUALITY" = "PARTIAL" ]; then
  exit 0
else
  exit 1
fi

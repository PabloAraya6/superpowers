---
name: tri-model-advisor
description: Use when the user invokes /ccg or requests multi-model perspectives on a problem, wanting parallel input from Codex and Gemini synthesized by Claude into a unified recommendation
---

# Tri-Model Advisor (CCG)

Claude decomposes the request, sends specialized prompts to Codex and Gemini **in parallel**, collects structured artifacts, then synthesizes all three perspectives into one unified answer.

Both Codex and Gemini can read files from the working directory — you do NOT need to paste entire files into prompts. Reference file paths and let the advisors read them.

## When to Use

- User explicitly invokes `/ccg`
- Architecture + UX/DX review needed in one pass
- Cross-validation where multiple model perspectives add value
- Code review from multiple angles (correctness vs. design vs. alternatives)

## Requirements

- **Codex CLI**: `codex` in PATH (`npm install -g @openai/codex`)
- **Gemini CLI**: `gemini` in PATH (`npm install -g @google/gemini-cli`)

## Execution Protocol

### Step 1: Verify Providers

```bash
codex --version 2>/dev/null && echo "codex: OK" || echo "codex: MISSING"
gemini --version 2>/dev/null && echo "gemini: OK" || echo "gemini: MISSING"
```

Continue with whatever is available.

### Step 2: Gather Context

Before decomposing, identify:

- The files involved (paths the advisors should read)
- The project language, framework, and structure
- The specific question or decision

**Key insight:** Both CLIs operate in the project's working directory and can read files autonomously. Instead of pasting code into prompts, tell the advisors which files to examine. Only embed short snippets when highlighting a specific concern.

### Step 3: Decompose the Request

Split into two **self-contained** prompts. Each must include:
- What the task is
- Which files to read (by path)
- What specific aspects to focus on
- What format you want the answer in (bullet points, trade-offs table, etc.)

**Codex focus areas:**
- Architecture and system design
- Correctness, logic errors, edge cases
- Security risks and vulnerabilities
- Performance bottlenecks
- Test strategy and coverage gaps

**Gemini focus areas:**
- Alternative approaches and trade-offs
- Design patterns and best practices
- UX/DX clarity and readability
- Documentation quality
- Edge-case usability

Define a **synthesis plan**: what conflicts you expect and how you will resolve them.

### Step 4: Invoke Advisors in Parallel

Write each prompt to a temp file (avoids shell escaping issues with large prompts) and run both advisors simultaneously:

```bash
# Write prompts to temp files
cat > /tmp/ccg-codex-prompt.md << 'CODEX_PROMPT'
<your codex prompt here>
CODEX_PROMPT

cat > /tmp/ccg-gemini-prompt.md << 'GEMINI_PROMPT'
<your gemini prompt here>
GEMINI_PROMPT

# Run both in parallel, capture output
codex exec --full-auto "$(cat /tmp/ccg-codex-prompt.md)" > /tmp/ccg-codex-output.txt 2>&1 &
CODEX_PID=$!

gemini -p "$(cat /tmp/ccg-gemini-prompt.md)" --approval-mode=yolo > /tmp/ccg-gemini-output.txt 2>&1 &
GEMINI_PID=$!

# Wait for both
wait $CODEX_PID 2>/dev/null; CODEX_EXIT=$?
wait $GEMINI_PID 2>/dev/null; GEMINI_EXIT=$?

echo "Codex exited: $CODEX_EXIT | Gemini exited: $GEMINI_EXIT"
```

**CLI flags rationale:**
- `codex exec --full-auto`: autonomous execution with sandbox protection (safer than `--dangerously-bypass-approvals-and-sandbox`). Use `--dangerously-bypass-approvals-and-sandbox` only if `--full-auto` fails due to sandbox restrictions.
- `gemini -p --approval-mode=yolo`: headless mode, auto-approve all actions. `--yolo` flag is deprecated, use `--approval-mode=yolo`.
- **Env cleanup for Codex**: if you see Rust stderr noise, prefix with `env -u RUST_LOG -u RUST_BACKTRACE -u RUST_LIB_BACKTRACE`

**Model override** (optional):
- Codex: add `-m gpt-4.1` or `-m o4-mini` (default: `o4-mini`)
- Gemini: add `-m pro` or `-m flash` (default: `auto` resolves to `gemini-2.5-pro`)

### Step 5: Collect and Read Output

```bash
echo "=== CODEX OUTPUT ==="
cat /tmp/ccg-codex-output.txt
echo ""
echo "=== GEMINI OUTPUT ==="
cat /tmp/ccg-gemini-output.txt
```

Validate output quality:
- If empty or only error messages: mark that advisor as failed
- If truncated (cut off mid-sentence): note it in Advisor Notes
- If clearly garbage/hallucinated: discard and note it

### Step 6: Persist Artifacts

```bash
mkdir -p .ccg/artifacts
TIMESTAMP=$(date -u +"%Y%m%d-%H%M%S")
```

Write each artifact to `.ccg/artifacts/<provider>-<timestamp>.md`:

```markdown
# <Provider> Advisor Artifact
- Provider: codex | gemini
- Model: <model used>
- Exit code: <code>
- Created: <ISO timestamp>

## Task
<the user's original request>

## Prompt Sent
<the exact prompt>

## Response
<complete output>

## Key Recommendations
<3-5 bullet distillation>
```

### Step 7: Synthesize

Combine both advisor outputs with your own Claude analysis. Produce a response with these sections:

#### Agreed
Recommendations where all three perspectives align. High-confidence items.

#### Conflicting
For each disagreement:
- **Claude**: <position>
- **Codex**: <position>
- **Gemini**: <position>
- **Resolution**: which perspective wins and why

#### Final Direction
Your chosen recommendation. When advisors disagree, state which you weighted more and why. Common resolution patterns:
- Codex and Gemini agree, Claude disagrees → likely go with the majority unless Claude has conversation context they lack
- All three disagree → go with the most conservative/safe option, flag for user decision
- One advisor produced garbage → weight the other two

#### Action Checklist
Ordered, actionable next steps. Each item concrete enough to execute immediately.

#### Advisor Notes
Caveats: unavailable advisors, timeouts, truncated output, low-confidence areas, which advisor seemed most relevant for this particular request.

## Prompt Engineering Guidelines

1. **Reference files, don't paste them.** Say "Read src/auth/middleware.ts and analyze the session handling" — the advisor can read it.
2. **Be specific about what to analyze.** "Check for SQL injection in the query builder at lines 45-80 of db/queries.ts" beats "review this file."
3. **State the decision explicitly.** "Should we use Redis or PostgreSQL for session storage given: 50k concurrent users, <10ms read latency requirement, existing PostgreSQL infrastructure?"
4. **Constrain the output format.** "Answer as: 1) Recommendation (one sentence), 2) Three strongest arguments for, 3) Three strongest arguments against, 4) Risk assessment."
5. **Match task to provider.** For pure code review, Codex is stronger. For brainstorming alternatives, Gemini often surfaces more diverse options.

## Special Modes

### Code Review Mode
If the request is specifically about code review, use Codex's dedicated review subcommand:

```bash
codex review --uncommitted  # review uncommitted changes
codex review --base main    # review changes vs main branch
```

This gives more structured review output than a generic prompt. Run Gemini's review in parallel with a prompt-based approach for the complementary perspective.

## Fallbacks

- **One provider missing**: Continue with available provider + Claude analysis. Note the missing perspective and what blind spots it creates.
- **Both missing**: Claude-only analysis. Recommend the user install them.
- **Provider error or timeout**: Note in Advisor Notes. Do not retry — move on.
- **Empty or garbage output**: Discard, note, rely on remaining perspectives.
- **Sandbox restriction blocks Codex**: Retry with `--dangerously-bypass-approvals-and-sandbox` and inform the user.

## Cleanup

After synthesis is complete, clean up temp files:

```bash
rm -f /tmp/ccg-codex-prompt.md /tmp/ccg-gemini-prompt.md /tmp/ccg-codex-output.txt /tmp/ccg-gemini-output.txt
```

Artifacts in `.ccg/artifacts/` are kept for future reference.

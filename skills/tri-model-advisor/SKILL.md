---
name: tri-model-advisor
description: Use when the user invokes /ccg or requests multi-model perspectives on a problem, wanting parallel input from Codex and Gemini synthesized by Claude into a unified recommendation
---

# Tri-Model Advisor (CCG)

Claude decomposes the request, sends specialized prompts to Codex and Gemini, collects structured artifacts, then synthesizes all three perspectives into one unified answer.

## When to Use

- User explicitly invokes `/ccg`
- Architecture + UX review needed in one pass
- Cross-validation where multiple model perspectives add value
- Code review from multiple angles (correctness vs. design vs. alternatives)
- Fast advisor-style parallel input without launching separate agent sessions

## Requirements

- **Codex CLI**: `codex` in PATH (`npm install -g @openai/codex`)
- **Gemini CLI**: `gemini` in PATH (`npm install -g @google/gemini-cli`)

## Execution Protocol

### Step 1: Verify Providers

Before anything, check both CLIs exist:

```bash
codex --version 2>/dev/null && echo "codex: OK" || echo "codex: MISSING"
gemini --version 2>/dev/null && echo "gemini: OK" || echo "gemini: MISSING"
```

Note which providers are available. Continue with whatever is present.

### Step 2: Gather Context

Before decomposing, collect the relevant context the advisors will need:

- Read the files under discussion (or that the user referenced)
- Note the project language, framework, and structure
- Identify the specific question or decision being made

This context MUST be embedded directly in each advisor prompt — the external CLIs have no access to your conversation history.

### Step 3: Decompose the Request

Split the user's request into two specialized prompts. Each prompt must be **self-contained** (include all necessary code snippets, file paths, and context).

**Codex prompt focus areas:**
- Architecture and system design
- Correctness, logic errors, edge cases
- Backend implementation, data flow
- Security risks and vulnerabilities
- Test strategy and coverage gaps
- Performance bottlenecks

**Gemini prompt focus areas:**
- UX/content clarity and readability
- Alternative approaches and trade-offs
- Edge-case usability
- Documentation quality
- Design patterns and best practices
- Developer experience

Also define a **synthesis plan**: what specific conflicts or divergences you expect between the three perspectives (yours, Codex, Gemini) and how you will resolve them.

### Step 4: Invoke Advisors

Run both via Bash. Use the project's working directory.

**Codex:**
```bash
codex exec --dangerously-bypass-approvals-and-sandbox "<codex prompt>"
```

**Gemini:**
```bash
gemini -p "<gemini prompt>" --yolo
```

**Critical rules:**
- Do NOT use the Agent tool — use Bash directly
- Strip `RUST_LOG`, `RUST_BACKTRACE`, `RUST_LIB_BACKTRACE` from env when calling codex to avoid stderr noise: prefix the codex command with `env -u RUST_LOG -u RUST_BACKTRACE -u RUST_LIB_BACKTRACE`
- If a prompt contains special characters, write it to a temp file and use input redirection
- Set a reasonable timeout (120s) — if an advisor hangs, kill it and note the gap

### Step 5: Persist Artifacts

After each advisor responds, write a structured artifact:

```bash
mkdir -p .ccg/artifacts
```

Write each artifact to `.ccg/artifacts/<provider>-<timestamp>.md` with this format:

```markdown
# <Provider> Advisor Artifact
- Provider: codex | gemini
- Exit code: <code>
- Created: <ISO timestamp>

## Original Task
<the user's original request>

## Prompt Sent
<the exact prompt sent to this provider>

## Raw Output
<complete unedited response>

## Key Recommendations
<3-5 bullet distillation>

## Action Items
<concrete next steps from this advisor>
```

### Step 6: Synthesize

Read both artifacts, combine with your own Claude analysis, and produce a unified response with these exact sections:

**## Agreed**
Recommendations where all three perspectives (Claude + Codex + Gemini) align. These are high-confidence.

**## Conflicting**
Points of disagreement. For each conflict:
- What Claude thinks
- What Codex said
- What Gemini said
- Why they differ (different priorities, assumptions, or knowledge)

**## Final Direction**
Your chosen recommendation with explicit rationale for why. When advisors disagree, explain which perspective you weighted more and why.

**## Action Checklist**
Concrete, ordered next steps the user can execute. Each item should be actionable, not vague.

**## Advisor Notes**
Any caveats: which advisors were unavailable, timeouts, truncated output, low-confidence areas.

## Prompt Engineering Guidelines

When composing advisor prompts:

1. **Be specific, not generic.** "Review this React component for performance issues" is better than "Review this code."
2. **Include the actual code.** Paste the relevant code directly into the prompt. The advisor cannot read your files.
3. **State the decision.** "Should we use Redis or PostgreSQL for session storage given these constraints: ..." is better than "What do you think about our storage?"
4. **Constrain the output.** Ask for bullet points, not essays. Ask for trade-offs, not just opinions.
5. **Match prompt to provider strength.** Codex excels at code correctness and architecture. Gemini excels at breadth, alternatives, and documentation quality.

## Fallbacks

- **One provider missing**: Continue with the available provider + Claude's own analysis. Explicitly note the missing perspective and what blind spots that creates.
- **Both providers missing**: Provide Claude-only analysis. State that external advisors were unavailable and recommend the user install them for richer results.
- **Provider errors or timeout**: Note the failure in the Advisor Notes section. Do not retry — move on with available data.
- **Empty or garbage output**: Discard it, note it, and rely on the other advisor + Claude.

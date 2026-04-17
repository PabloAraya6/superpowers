---
name: tri-model-advisor
description: Use when the user invokes /ccg, requests multi-model perspectives, wants cross-validation from different AI providers, or needs parallel advisory input from Codex and Gemini synthesized into a unified recommendation
---

# Tri-Model Advisor (CCG)

```
NEVER SYNTHESIZE WITHOUT READING BOTH ADVISOR OUTPUTS IN FULL.
NEVER SKIP CONFLICT IDENTIFICATION — AGREEMENT WITHOUT TENSION IS SUSPICIOUSLY SHALLOW.
NEVER EMBED FULL FILES IN PROMPTS — ADVISORS CAN READ THE WORKING DIRECTORY.
```

Claude orchestrates a Mixture-of-Agents pattern: Codex and Gemini run as parallel proposers, Claude acts as the aggregator/synthesizer. An optional debate round lets advisors respond to each other's critiques.

## When to Use

- User explicitly invokes `/ccg`
- Architecture + UX/DX review needed in one pass
- Cross-validation where a single perspective has blind spots
- Code review from multiple angles (correctness vs. design vs. alternatives)
- High-stakes decisions where "are we sure?" matters

## Requirements

- **Node.js 18.3+**: required for `util.parseArgs()`
- **Codex CLI**: `codex` in PATH (`npm install -g @openai/codex`)
- **Gemini CLI**: `gemini` in PATH (`npm install -g @google/gemini-cli`)

## Mode Selection

Classify the request before decomposing. The mode determines how prompts are specialized.

```dot
digraph mode_selection {
  rankdir=LR;
  node [shape=diamond, style=filled, fillcolor="#f0f0f0"];
  classify [label="Classify\nrequest"];
  node [shape=box, style=filled, fillcolor="#d4edda"];
  review [label="REVIEW\nmode"];
  arch [label="ARCHITECTURE\nmode"];
  security [label="SECURITY\nmode"];
  brainstorm [label="BRAINSTORM\nmode"];
  general [label="GENERAL\nmode"];
  classify -> review [label="code review\nor PR review"];
  classify -> arch [label="system design\nor trade-offs"];
  classify -> security [label="vulnerabilities\nor auth/data"];
  classify -> brainstorm [label="alternatives\nor new ideas"];
  classify -> general [label="everything\nelse"];
}
```

| Mode | Codex Focus | Gemini Focus | Special |
|---|---|---|---|
| **REVIEW** | Correctness, bugs, logic errors, test gaps | Readability, DX, naming, patterns, alternatives | Use `codex review` subcommand |
| **ARCHITECTURE** | Scalability, data flow, failure modes, performance | Trade-offs, prior art, migration paths, simplicity | Ask for ASCII diagrams |
| **SECURITY** | OWASP top 10, injection, auth bypass, data exposure | Threat modeling, attack surface, compliance, docs | Both focus security |
| **BRAINSTORM** | Feasibility analysis, implementation cost, risks | Creative alternatives, UX angles, novel approaches | Wider temperature |
| **GENERAL** | Architecture, correctness, backend, performance | Alternatives, patterns, DX, documentation | Default split |

## Execution Protocol

### Step 1: Verify and Classify

```bash
codex --version 2>/dev/null && echo "codex: OK" || echo "codex: MISSING"
gemini --version 2>/dev/null && echo "gemini: OK" || echo "gemini: MISSING"
```

Classify the request into a mode. State the mode explicitly before proceeding.

### Step 2: Gather Context

Identify what the advisors need to examine:

- **File paths** they should read (both CLIs can read files from the working directory)
- **Specific line ranges** or functions to focus on
- **Project context**: language, framework, constraints
- **The decision or question** being asked

REQUIRED INTEGRATION: If this is a debugging task, use `superpowers:systematic-debugging` first to identify the root cause, then invoke CCG for solution validation. If this is a brainstorming task, consider whether `superpowers:brainstorming` should run first to generate the option space.

### Step 3: Invoke Advisors

Identify the key information for the advisors:
- **task**: what to analyze or decide (1-3 sentences, from conversation context)
- **files**: which source files are most relevant (comma-separated relative paths)
- **focus** (optional): specific aspects each advisor should emphasize

ccg-compose.js handles preamble injection, project context auto-detection, file content inclusion (with sanitization), CLI spawning, output validation, and artifact persistence.

Run both advisors in parallel:

    node skills/tri-model-advisor/ccg-compose.js codex \
      --mode <MODE> \
      --task "<task description>" \
      --files "<file1,file2,...>" \
      [--focus "<codex-specific focus>"] \
      > /tmp/ccg-codex-out.txt 2>/dev/null &
    CODEX_PID=$!

    node skills/tri-model-advisor/ccg-compose.js gemini \
      --mode <MODE> \
      --task "<task description>" \
      --files "<file1,file2,...>" \
      [--focus "<gemini-specific focus>"] \
      > /tmp/ccg-gemini-out.txt 2>/dev/null &
    GEMINI_PID=$!

    wait $CODEX_PID 2>/dev/null
    wait $GEMINI_PID 2>/dev/null

Read both output files. If an output is empty, check `.ccg/artifacts/` for the artifact which includes stderr logs and quality status.

### Step 4: Synthesize (Aggregator Phase)

This is the core of the MoA pattern. Claude acts as the aggregator.

**Process:**
1. Read both advisor outputs completely — do not skim
2. Form your own independent analysis (you already have conversation context the advisors lacked)
3. Identify every point where perspectives align or diverge
4. For each divergence, determine WHY they disagree (different assumptions? different priorities? one has context the other lacks?)
5. Produce a unified response

**Output format:**

> ### Mode: [REVIEW|ARCHITECTURE|SECURITY|BRAINSTORM|GENERAL]
>
> ### Agreed
> High-confidence recommendations where all three perspectives align.
> Each item as: `recommendation — [Claude, Codex, Gemini all agree]`
>
> ### Conflicting
> For each disagreement:
> - **Point**: what the disagreement is about
> - **Claude**: position + reasoning
> - **Codex**: position + reasoning
> - **Gemini**: position + reasoning
> - **Resolution**: which perspective wins and why
>
> ### Final Direction
> The chosen path with explicit rationale. Reference specific advisor arguments.
>
> ### Action Checklist
> Ordered, immediately actionable steps. Each item concrete enough to execute.
>
> ### Confidence & Caveats
> - Overall confidence: HIGH / MEDIUM / LOW
> - Which advisor was most relevant for this specific request
> - Missing perspectives, timeouts, quality issues

### Step 5: Debate Round (Optional)

Trigger a debate round when:
- Advisors strongly disagree on a critical point
- You are unsure which perspective is correct
- The user explicitly asks for deeper analysis

**Protocol**: Send each advisor the other's key argument and ask them to respond:

Compose a debate prompt that includes the peer's argument and the advisor's original position (see `debate-protocol.md` for the template). Then run through ccg-compose.js:

    node skills/tri-model-advisor/ccg-compose.js codex \
      --mode <MODE> \
      --task "<debate prompt including peer's argument>" \
      > /tmp/ccg-codex-debate-out.txt 2>/dev/null

    node skills/tri-model-advisor/ccg-compose.js gemini \
      --mode <MODE> \
      --task "<debate prompt including peer's argument>" \
      > /tmp/ccg-gemini-debate-out.txt 2>/dev/null

Re-synthesize with the enriched context.

**Limit**: Maximum 1 debate round. More rounds do not reliably improve accuracy (per ICLR 2025 MAD research). The value is in surfacing stronger evidence, not in reaching forced consensus.

### Step 6: Cleanup

```bash
rm -f /tmp/ccg-codex-out.txt /tmp/ccg-gemini-out.txt \
      /tmp/ccg-codex-debate-out.txt /tmp/ccg-gemini-debate-out.txt
```

Artifacts in `.ccg/artifacts/` are kept for future reference.

## Integration with Superpowers

| Situation | Integration |
|---|---|
| Debugging task | Run `superpowers:systematic-debugging` first, then CCG to validate the fix |
| Brainstorming | Run `superpowers:brainstorming` first, then CCG to evaluate top options |
| Implementation plan | Run CCG, then pass the action checklist to `superpowers:writing-plans` |
| Code review | Run CCG in REVIEW mode, then `superpowers:verification-before-completion` |
| Complex implementation | CCG for design, then `superpowers:subagent-driven-development` for execution |

## Red Flags — Stop If You Catch Yourself

- Synthesizing before reading both outputs completely
- Claiming "all three agree" without identifying at least one tension point
- Pasting entire files (>50 lines) into prompts instead of referencing paths
- Skipping mode classification and using GENERAL for everything
- Running debate rounds when advisors already agree (wastes tokens)
- Ignoring a dissenting advisor because the other two agree (the dissent may be the insight)
- Producing an action checklist with vague items like "review the code" or "consider alternatives"

## Rationalization Prevention

| Excuse | Reality |
|---|---|
| "Simple question, don't need multi-model" | If the user invoked /ccg, they want multi-model. Honor the request. |
| "Codex/Gemini will just say the same thing" | Different training data, different biases. Disagreements are the valuable signal. |
| "I'll just ask one advisor to save time" | The whole point is diverse perspectives. One advisor is just a more expensive Claude. |
| "Debate round will improve this" | Only trigger debate on genuine disagreement. Forced debate degrades quality (ICLR 2025). |
| "The advisor output was bad so I'll ignore it" | Mark it as low-quality in Advisor Notes. Never silently discard — the user should know. |
| "I already know the answer, advisors are redundant" | Your confidence is exactly when blind spots are most dangerous. Run the protocol. |

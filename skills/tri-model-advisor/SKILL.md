---
name: tri-model-advisor
description: Use when the user invokes /ccg or requests multi-model perspectives on a problem, wanting parallel input from Codex and Gemini synthesized by Claude into a unified recommendation
---

# Tri-Model Advisor (CCG)

Claude decomposes the request, sends specialized prompts to Codex and Gemini in parallel, then synthesizes all three perspectives into one unified answer.

## When to Use

- User explicitly invokes `/ccg`
- Architecture + UX review needed in one pass
- Cross-validation where multiple model perspectives add value
- Code review from multiple angles (correctness vs. design vs. alternatives)

## Requirements

- **Codex CLI**: `codex` must be available in PATH
- **Gemini CLI**: `gemini` must be available in PATH
- If one CLI is unavailable, continue with the available one and note the gap

## Execution Protocol

### 1. Decompose the Request

Split the user's request into two specialized prompts:

- **Codex prompt**: architecture, correctness, backend logic, security risks, test strategy, performance
- **Gemini prompt**: UX/content clarity, alternative approaches, edge cases, documentation, design patterns

Also define a **synthesis plan**: how you will reconcile conflicts between the three perspectives (yours + both advisors).

### 2. Run Advisors via Bash

Run both commands. Use the project's working directory as context:

```bash
codex exec -q "<codex prompt>"
```

```bash
gemini -p "<gemini prompt>"
```

**Important:**
- Each prompt should include enough context about the problem (paste relevant code, describe the situation)
- Keep prompts focused on the advisor's specialty area
- Run both commands (do NOT use the Agent tool for this - use Bash directly)

### 3. Synthesize

After collecting both responses, produce a unified answer with:

- **Agreed**: recommendations where all perspectives align
- **Conflicting**: points of disagreement, explicitly called out with each model's position
- **Final direction**: your chosen recommendation with rationale for why
- **Action checklist**: concrete next steps

## Fallbacks

- If one provider is unavailable or errors: continue with the available provider + Claude's own analysis. Note the missing perspective.
- If both are unavailable: provide Claude-only analysis and state that external advisors were not available.

## Keep It Practical

- Don't over-decompose simple questions. If the request is straightforward, keep the advisor prompts tight.
- The value is in surfacing disagreements and blind spots, not in generating verbose consensus.

# Debate Protocol

Optional refinement round when advisors strongly disagree. Based on Multi-Agent Debate research (ICLR 2025) with a critical constraint: **maximum 1 debate round** — additional rounds do not reliably improve accuracy and can reverse correct answers.

## When to Trigger

Trigger debate ONLY when:

1. **Strong disagreement on a critical point**: one advisor says "do X" and the other says "definitely don't do X" on something that materially affects the outcome.
2. **Claude is genuinely uncertain**: you cannot resolve the conflict with your own knowledge.
3. **User explicitly requests deeper analysis**: the user says something like "dig deeper" or "I want more detail on this disagreement."

Do NOT trigger debate when:
- Advisors broadly agree (wasted tokens)
- The disagreement is on a minor/cosmetic point
- One advisor clearly had insufficient context (just note it)
- You can resolve the conflict yourself with conversation context the advisors lacked

## Debate Prompt Template

### For the advisor whose position you want to challenge:

```
CONTEXT: You previously analyzed [topic] and recommended [their recommendation].

A peer reviewer independently analyzed the same problem and reached a different conclusion:

---
[Paste the OTHER advisor's key argument, 3-5 sentences max]
---

TASK:
1. Does the peer raise any valid points you missed? If yes, revise your recommendation.
2. If you still disagree, provide stronger evidence: reference specific code, concrete numbers, or documented precedents.
3. Identify any assumptions in your original analysis that you are now less confident about.

Be specific. No generic rebuttals.
```

### For both advisors (symmetric debate):

Send the template above to BOTH advisors, each seeing the other's argument. This produces two refined responses.

## Reading Debate Output

When synthesizing after debate:

1. **Changed positions are high-signal**: if an advisor revises their stance after seeing the counterargument, their new position is likely more reliable than either original.
2. **Strengthened positions are moderate-signal**: the advisor had time to think harder, but confirmation bias exists.
3. **Dismissed counterarguments are low-signal**: the advisor may be stubbornly holding position. Evaluate the dismissal reasoning, not just the conclusion.

## Synthesis After Debate

Update the Conflicting section of your synthesis to include:

```
### Conflicting (post-debate)
- **Point**: <the disagreement>
- **Round 1**: Codex said X, Gemini said Y
- **Debate**: Codex [revised to X' / maintained X because ...], Gemini [revised to Y' / maintained Y because ...]
- **Resolution**: <your final call with reasoning>
- **Confidence**: [HIGHER after debate / UNCHANGED / LOWER — honest assessment]
```

## Research Basis

- Heterogeneous model debate (different providers, different training data) shows improvements over single-model baselines — unlike homogeneous debate which often fails (ICLR 2025).
- The key value is **surfacing stronger evidence**, not achieving consensus. Forced agreement degrades output quality.
- One round captures most of the value. The marginal return of round 2+ is negative in most benchmarks.

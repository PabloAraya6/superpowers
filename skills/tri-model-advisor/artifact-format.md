# Artifact Format

Artifacts persist advisor responses for traceability and future reference.

## Location

```
.ccg/artifacts/<provider>-<YYYYMMDD-HHMMSS>.md
```

Examples:
- `.ccg/artifacts/codex-20260320-143022.md`
- `.ccg/artifacts/gemini-20260320-143022.md`

## Template

```markdown
# <provider> advisor artifact

| Field | Value |
|---|---|
| Provider | codex / gemini |
| Model | <model used> |
| Mode | REVIEW / ARCHITECTURE / SECURITY / BRAINSTORM / GENERAL |
| Exit code | <0 = success, non-zero = error> |
| Quality | OK / PARTIAL / LOW-QUALITY / FAILED |
| Created | <ISO 8601 timestamp> |
| Debate | none / round-1 |

## Task
<the user's original request, verbatim>

## Prompt Sent
<the exact prompt sent to this advisor, including role preamble>

## Response
<complete, unedited advisor output>

## Key Takeaways
<3-5 bullet distillation of the most important points — written by Claude during synthesis>
```

## Notes

- Always write artifacts BEFORE synthesizing — they are the source of truth if you need to re-read.
- The "Key Takeaways" section is written by Claude after reading the full response, not by the advisor.
- Debate round artifacts use the same format with `Debate: round-1`.
- Artifacts are append-only. Never overwrite a previous artifact.
- Add `.ccg/` to `.gitignore` if it isn't there — artifacts are local working state, not source code.

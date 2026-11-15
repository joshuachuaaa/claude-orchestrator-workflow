# Dossier: <task-name>

Written by the main session (the driver) for the judge (Fable). Keep it under about
3,000 words. Point at code instead of pasting it: the judge can open any file
listed here, and nothing else.

## 1. Request
The user's request, verbatim, then one or two sentences on what it is for.

## 2. Repository facts
- Root: <absolute path>
- Language, framework and versions:
- Test command (exact): `<command>`
- Lint/type-check command (exact, if any): `<command>`
- Current test status on HEAD: <passing / failing: which>

## 3. Files the judge should read
List each with why it matters. Use line ranges for large files.
- `path/to/file.ext` (lines 10-120): <what it is, why it matters>

## 4. Interfaces and contracts involved
Signatures, schemas, endpoints, events, config keys the change touches or must not
break. Summarise; the judge reads the files above for detail.

## 5. Conventions to follow
Patterns already used here, each with a file to copy from (naming, error handling,
logging, test layout, dependency injection, and so on).

## 6. Constraints
Performance, compatibility, security, dependencies allowed or forbidden, deadlines,
anything the user said must not change.

## 7. Risks and unknowns
What could go wrong; what the driver could not determine from the code; open questions
for the user (if any are blocking, ask the user BEFORE calling the judge).

## 8. Size and routing estimate
- Estimated new or changed lines:
- Files touched:
- Risky domain (auth, money, data migration, concurrency, security, public API)? yes/no: which
- Can acceptance tests be written before the code? yes/no: where they would live
- Proposed typist: typist subagent / the driver directly, and why

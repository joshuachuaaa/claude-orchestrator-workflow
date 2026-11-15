---
name: fable-orchestrator-workflow
disable-model-invocation: true
description: Plan, build, review and accept a substantial coding task with three Claude seats - Opus 5.5 at xhigh as the driver (the working session), Fable 5.2 at xhigh as the judge (design, sign-off, consult) and Opus 5.5 at high as the typist (a subagent that implements a written brief in its own worktree). No code leaves Claude. Use for implementation work in a git repository that is a new feature, module or endpoint, a refactor across several files, or roughly 150+ lines of new code. Do not use for questions, explanations, reviews of existing code, config changes, or fixes whose cause is already known.
---

# Fable orchestrator workflow

## Seats

- **Driver: you, the main session, Opus 5.5 at xhigh effort.** You explore, write
  the dossier and the acceptance tests, dispatch the typist, review, verify,
  take over when the typist fails, and report. You never switch the main model
  or effort during a task.
- **Judge: `fable-judge` (subagent, Fable 5.2, xhigh effort).** Designs from
  your dossier, signs off the finished change, and answers one consult when you
  are stuck.
- **Typist: `opus-typist` (subagent, Opus 5.5, high effort).** Implements a
  written brief in a git worktree that `delegate` prepares. It cannot ask
  questions.
- **Explore (built-in subagent).** All repository searching.
- **test-runner (subagent, Haiku).** Runs `delegate verify` and returns a short
  result.

Two rules hold throughout. Fable is never the main model or the `/advisor`:
both would make it read the whole conversation, and it should only ever read a
dossier, a sign-off package or a consult file, plus a few named files. And
`.no-fable` in the repository root means no Fable subagent at all.

## The rule behind every step

The gate sets the quality, not the typist. A change is accepted only after it
passes checks at least as strong as the ones you would apply to your own work:
acceptance tests you wrote before any code existed, held-back checks the typist
never saw, your review of the real diff, and the judge's sign-off where the
change is risky. When the typist cannot get through the gate, you do the work
yourself, so the result is never worse than you working alone.

The typist is the same model as you at a lower effort. It earns its seat in two
ways: it builds in a fresh, small context while yours stays short, and several
typists can build independent pieces at the same time. Only the judge can raise
quality above yours, so keep it for design and risk.

## Step 0. Triage: four decisions

Make all four before doing anything else and state them in one line to the user,
for example: `Triage: design=judge, typist=subagent, pieces=2, signoff=yes`.

**A. Is this a task for this skill at all?** No, do it directly without the skill,
if it is a question, explanation, review, config change, or a fix whose cause is
known, or if the change is under about 150 lines in one or two files with an
obvious design.

**B. Who designs?** The judge, if any one of these holds:
1. The request is ambiguous and the code cannot settle it.
2. It creates a new subsystem or changes boundaries between modules.
3. It touches a risky domain: auth or permissions, money, data migrations or
   schema changes, concurrency, security-sensitive code, public APIs.
4. You are not confident of the design after discovery.
Otherwise you design. If the repository root contains `.no-fable`, you design
regardless and say so.

**C. Who types?** The typist, if all of these hold:
1. Roughly 200+ lines of new or changed code, or many similar edits across files.
2. The design can be stated exactly (names, signatures, contracts).
3. The result is machine-checkable: you can write acceptance tests for it before
   any code exists.
4. The brief will be much shorter than the work it replaces. If specifying the
   change takes about as much as writing it, you type.
5. The repository is a git repository with at least one commit.
Otherwise you type.

**D. One piece or several?** (typist path only) If the work divides into pieces
that touch different files and do not need each other's results, make each piece
its own task, with its own name, brief and acceptance tests, and dispatch their
typists together. If two pieces would edit the same file, or one needs the
other's output, keep them as one task or as stages of one task.

**E (follows from B). Sign-off?** Yes if the judge designed, or if the change
touches a risky domain from B3. Otherwise no.

## Step 1. Discover

Use the Explore subagent for searching. Read yourself only the files you need to
understand the change: the modules it touches, their callers and interfaces, how
tests are written and run. Find the exact test command, and the lint and
type-check commands if the project has them. Run the tests once on HEAD (through
test-runner if the output is long) so you know the starting state.

If the request is ambiguous in a way the code cannot settle, ask the user now.

## Step 2. Prepare the task folder and dossier

    delegate prep <task-name>

Task names: lowercase letters, digits, dot, dash, underscore. The command prints
the task directory and creates `dossier.md` from the template. Fill in every
section. Point at files and line ranges instead of pasting code. Keep it under
about 3,000 words.

If you are designing (B = you), skip the dossier and go to Step 3b.

## Step 3a. The judge designs

Call the `fable-judge` subagent with this prompt and nothing else:

    Design: <absolute task dir>

Then:
- If it replies `QUESTIONS:`, ask the user those questions, add the answers to
  the dossier, and call it once more.
- Otherwise read plan.md, brief.md (or each `brief-<piece>.md`) and holdback.md.
  Check that every brief stands alone and matches plan.md. If something is
  wrong, tell the judge exactly what in one follow-up call; do not rewrite its
  design yourself.
- If plan.md sets the typist or the pieces differently from your triage, follow
  plan.md and tell the user.

## Step 3b. You design

Write `brief.md` (eight sections: Goal, Behaviour, Design, Conventions, Tests with
exact command, numbered Acceptance criteria, Out of scope, Stop conditions) and
`holdback.md` (two to five checks the typist will not see) in the task directory.
For several pieces, write one `brief-<piece>.md` each.

## Step 3c. Write the acceptance tests first

Before any code is written, write the acceptance tests yourself: the cases the
plan lists when the judge designed, otherwise the brief's acceptance criteria
turned into tests. Each test must fail on the base commit and pass only when the
behaviour is right.

- **Typist types:** put the test files under `<task dir>/tests/` (for pieces,
  `<task dir>/tests-<piece>/`), each at its repository-relative path, for example
  `<task dir>/tests/backend/tests/test_x.py`. Name these paths in section 5 of
  the brief and say there that they must pass unchanged. If the judge wrote the
  brief, check it names the same paths.
- **You type:** write them in the main checkout before the implementation.

The held-back checks stay in holdback.md. They are not acceptance tests and the
typist never sees them.

## Step 4. Implement

**Typist types.** Open the round:

    delegate start <task> --typist opus --spec <dir>/brief.md --tests <dir>/tests [--plan <dir>/plan.md] [--signoff]

`--tests` commits the acceptance tests into the worktree, and `delegate verify`
refuses if they change afterwards. Pass `--plan` when the judge designed (this
makes sign-off mandatory). Pass `--signoff` when you designed but the change is
risky. The command prints three lines, `Worktree:`, `Brief:` and `Report:`.
Call the `opus-typist` subagent with exactly those three lines as its prompt.
When it has finished, close the round:

    delegate round <task>

This collects the typist's work into a commit and prints the measured diff. Do
not change anything in the main checkout while a round is open: the script
treats that as an isolation breach.

For several pieces (decision D), name the tasks `<task>-<piece>`, start each
with its own brief and tests, and call their typists in one message so they run
at the same time. Copy holdback.md into each piece's task directory so its
sign-off package carries it. Then close each round and take each piece through
Steps 5 to 7 on its own.

For a staged plan, dispatch stage 1 only. Later stages go in as `delegate fix`
rounds with that stage's brief, each verified before the next.

**You type:** implement in the main checkout following brief.md exactly, then
verify with the test command. If sign-off is required, write the package yourself
to `<dir>/signoff-package-1.md`: plan, held-back checks, what you ran and its
result, the full `git diff`.

## Step 5. Review and verify (typist path)

1. Read the diff stat `delegate round` printed. Read in full the files the plan
   marks as risky and any file whose change you did not expect. For the rest,
   read enough to confirm names, signatures and contracts match the brief.
2. Read the tests the typist added. Do they assert behaviour? Was any existing
   test weakened, skipped or deleted?
3. Add the held-back checks: write them into the worktree, then
   `git -C <worktree> add -A && git -C <worktree> commit -m "held-back checks"`.
4. Verify through the `test-runner` subagent with this prompt:

       Directory: <repo root>
       Command: delegate verify <task> -- <gate command>

   The gate command runs the acceptance tests, the held-back tests, and the
   existing suite where practical so regressions show. Where the project has
   lint or type checks, chain them in: `sh -c '<lint> && <type-check> && <tests>'`.
5. Check each acceptance criterion: passed, failed, or could not check.

If `delegate verify` reports that the acceptance tests changed, the typist
altered them and the round failed. If an acceptance test was itself wrong and you
corrected it, re-run with `--allow-test-changes` and say so in the report.

The typist's report is a claim. Where it and the evidence disagree, the evidence
wins and the disagreement goes in your final report.

## Step 6. Correct, then take over

The typist gets one correction per stage. After that you do the work.

1. **One correction round.** Write feedback to `<dir>/feedback-<n>.md`: file and
   line, what is wrong, the failing command and its output, what correct looks
   like. Then:

       delegate fix <task> --feedback <dir>/feedback-<n>.md

   It prints three new lines. Send them to the same typist with SendMessage if
   it can still be continued, otherwise call a new `opus-typist` with them. Then
   `delegate round <task>`, and review and verify again from Step 5.
2. **Take over.** If the gate or your review still fails after that round, do not
   send a third. Record it and finish the task yourself:

       delegate takeover <task> --reason "<what the typist could not do>"

   Edit and commit in the task's worktree, then verify as in Step 5. The script
   refuses further typist rounds on this task, including later stages.
3. **Consult the judge once, if you are stuck.** If two attempts of your own
   still fail the gate, or the design itself looks wrong, write
   `<dir>/consult-1.md`: the problem, what was tried, the failing command and
   its output, the files involved (up to 5), and one question. Call `fable-judge`
   with this prompt and nothing else:

       Consult: <dir>/consult-1.md

   Act on its answer in `<dir>/consult-1-answer.md`. If the repository has
   `.no-fable`, skip this and go to the next point.
4. **Report the blocker.** If the task is still failing after the consult, stop
   and tell the user what blocks it, with the evidence.

You may make a purely mechanical touch-up yourself without taking over (a merge
conflict, a typo) and must say so in the report. The script stops at 6 typist
rounds as a backstop for staged plans.

## Step 7. Sign-off (when required)

After a passing verification on the current commit:

    delegate package <task>

Call `fable-judge` with this prompt and nothing else:

    Sign-off: <path printed by delegate package>
    Verdict file: <dir>/signoff-response-<n>.md

Then record it:

    delegate signoff <task> --verdict ACCEPT|CHANGES --file <dir>/signoff-response-<n>.md

- ACCEPT: go to Step 8.
- CHANGES: fix each blocker and should-fix finding (through the typist's one
  correction if it is unused, otherwise yourself, as in Step 6), verify, package
  and sign off again. After two CHANGES verdicts, stop and report to the user
  with both verdict files.
- Do not argue with a finding inside the same call. If you believe a finding is
  wrong, say why in your report to the user and let them decide.

## Step 8. Integrate

    delegate integrate <task>

It squash-merges into the main checkout as staged, uncommitted changes, and
refuses unless the latest verification passed on the exact commit and, where
required, the latest sign-off is ACCEPT for that commit. If it warns that the main
checkout moved, re-run the tests in the main checkout.

With several pieces, integrate them one after another, then run the whole gate
once in the main checkout, because each piece was verified without the others.

Commit only if the user asked for commits. Then `delegate cleanup <task>`.

## Step 9. Report

Lead with the decision: accepted, accepted with noted risks, or not accepted and
why. Then: triage line; what changed (from the diff); design decisions and allowed
deviations; commands run and real results, including failures along the way;
whether the first verification passed, the number of typist rounds, and whether
you took the task over and why; the sign-off verdict and its findings; remaining
risks and anything you could not verify.

Finish with the task's line from `delegate stats`: it shows the rounds, whether
the first verification passed, and the tokens each seat read and wrote.

After reporting, tell the user to run `/clear` before the next unrelated task.
The token count for a task starts at the session's start, so a fresh session per
task keeps the numbers clean.

## Stop conditions

- **Not a git repository:** do not run `git init` without asking. Type it yourself.
- **`.no-fable`:** no judge. You design, and sign-off and the consult are
  skipped; say so.
- **A seat's model is unavailable** (usage limit, error, or a model fallback
  reported for `fable-judge` or `opus-typist`): stop and ask the user. Do not
  substitute another model silently, and do not quietly do the typist's round
  yourself. This is different from Step 6: a takeover follows a typist that ran
  and failed the gate, and is recorded.
- **Isolation breach reported by `delegate`:** stop everything, inspect the main
  checkout, tell the user.

## Cost rules

- Never change the main session's model or effort during a task.
- Judge calls per task: one design call (plus one for answered questions or a
  correction), one sign-off per verification that needs it, and at most one
  consult. Nothing else.
- Searching goes through Explore; verification output through test-runner.
- Do not paste large files or diffs into your own messages; point at paths.
- Pass work between seats as files in the task directory, never as conversation.
  The judge and the typist get the short prompts above and nothing more.

## Commands

    delegate prep <task>                      task folder and dossier template
    delegate start <task> --typist opus ...   create the worktree, seed the tests, open round 1
    delegate fix <task> --feedback FILE       open a correction round
    delegate round <task>                     close the open round: commit, measured diff
    delegate verify <task> -- <command>       the gate; evidence tied to a commit
    delegate takeover <task> --reason "..."   you take the task over from the typist
    delegate package <task>                   sign-off package for the judge
    delegate signoff <task> --verdict ... --file ...
    delegate integrate <task>
    delegate status [<task>]       rounds, verification, sign-off
    delegate stats                 every task: rounds, first-pass rate, takeovers, tokens by seat
    delegate cleanup <task> --force    discard an unintegrated task (ask the user first)

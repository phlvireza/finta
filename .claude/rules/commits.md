# Commit rules

## Only on request

Never `git commit` or `git push` unless asked. Finishing a task means the working
tree is correct — not that it is committed.

## Message format

Subject line: **imperative mood, no trailing period, ≤ 72 characters.** It completes
the sentence "Applying this commit will…".

```
Fix v4 migration wiping budget category links
```

This project's history uses two shapes — match whichever fits:

- **Phase commits** for a chunk of planned feature work:
  `Phase 7: cashflow and trend analytics`
- **Plain imperative** for fixes, chores, and follow-ups:
  `Ignore markdown docs so they stay local-only`

No Conventional Commits prefixes (`feat:`, `fix:`, `chore:`) — the history does not
use them, so don't start.

## Body

Add a body whenever the subject alone leaves a reviewer guessing. Wrap at ~72
columns, blank line after the subject, and explain **why** the change was needed and
what would break without it — the diff already shows *what* changed. Use `-` bullets
when the commit spans several distinct changes.

Call out explicitly when a commit:

- bumps `DatabaseHelper.dbVersion` or adds a migration — state the version and what
  it does to existing installs;
- changes data that is derived rather than stored;
- fixes a bug that silently corrupted data, and how it was detected.

## Scope

- One logical change per commit. Don't fold an unrelated cleanup into a fix.
- Don't stage `flutter analyze` churn or IDE noise alongside a feature.
- Never commit generated or local-only files: `build/`, `.dart_tool/`, `.agents/`,
  `*.md` other than `README.md` and `.claude/rules/*.md`. `.gitignore` covers these —
  if `git status` shows one, fix the ignore rule rather than the staging.
- `lib/l10n/app_localizations*.dart` is generated but tracked; keep it in sync with
  the ARB files in the same commit that edits them.

## Before committing

- `git status` and `git diff --staged` — read what is actually going in.
- ARB files at key parity (`app_en.arb` and `app_id.arb`).
- Migration change ⇒ `test/migration_test.dart` updated in the same commit.

## Pushing

The project works directly on `main`; there is no PR flow. Confirm the branch before
pushing, and don't force-push.

## Attribution

Claude-authored commits carry the standard Claude Code co-author trailer as the last
line of the message, after a blank line. Nothing else — no badges, no
"generated with" footers, no emoji.

# PR Unblock: #3 - Initial Phoenix/Ecto scaffold

## Git Status
```
On branch codex/initialize-phoenix-project-for-rempost-nspy3t
Your branch is up to date with 'origin/codex/initialize-phoenix-project-for-rempost-nspy3t'.
nothing to commit, working tree clean
```

## Merge Conflict
PR #3 (`codex/initialize-phoenix-project-for-rempost-lhwmmj` → `master`) is **CONFLICTING**.

No unmerged files on current branch (different branch than PR head). To resolve:
```
git checkout codex/initialize-phoenix-project-for-rempost-lhwmmj
git merge master
# fix conflicts
```

## Code Review Issues to Fix (Sourcery)

### 1. `extract/2` nil crash — `deterministic_parser.ex:34`
`extract/2` pipes `Regex.run/2` into `List.first/1` — crashes on nil (no match). Fix: handle nil like `extract_group/3`.

### 2. `on_conflict: :nothing` + `returning: true` — `emails.ex:6`
`Repo.insert(..., on_conflict: :nothing, returning: true)` yields `{:ok, nil}` on conflict. Either upsert or fetch existing row.

### 3. Rescue block uses unbound `email` — `email_parser_worker.ex:6`
If exception before `email` binding (e.g. `Repo.get_by!` fails), rescue crashes again trying to use `email`.

### 4. `inspect(reason)` leaks internals — `inbound_email_controller.ex:18`
Return sanitized error to client, log full reason server-side.

### 5. Oban dashboard unauthenticated — `router.ex:31`
`/oban` only has `:browser` pipe — no auth. Add basic auth or existing auth plug.

## Fix Order
1. Auth (Oban dashboard + error sanitization)
2. Parser nil safety
3. Email ingestion upsert
4. Worker rescue safety

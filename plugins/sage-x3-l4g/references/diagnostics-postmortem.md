# Diagnostics and post-mortem

What to do when production already broke. Reading `adxlog.log`, dumps, lock states, hung pools, batch failures — all the "the customer can't enter orders, fix it now" surfaces. Companion to `debugging-traces.md` (which covers prevention via traces and supervisor tracing).

## Triage order

The first 60 seconds of a P1:

1. **Is it widespread or isolated?** One user vs all users — different paths. Check Syracuse session list (`Administration → Diagnostics → Sessions`).
2. **Is it the runtime or the data?** Engine crashed (sessions all dead) vs business error (one workflow rejects). Different fixes.
3. **What changed recently?** Last patch, last activity-code toggle, last batch run, last folder-parameter change.
4. **Is the database alive?** `Administration → Diagnostics → Database`. If the DB is down or saturated, no L4G fix helps.
5. **Are the locks released?** A stuck `Readlock` blocks every reader. Lock state below.

## Reading `adxlog.log`

The supervisor's master log file lives in `<folder>/TRA/adxlog.log` (rotating) and `<runtime>/log/adxlog_<server>.log` (engine-wide).

Format (approximate):

```
2026-05-08 14:32:11 [USR1234] [GESBPC] [SUBPROG=YCREATE_BPC] ERR fstat=2 line=147 stat1=20 funfat=0
```

Fields you care about:

| Field | What |
|-------|------|
| Timestamp | UTC unless the server is local-tz |
| User | `[V]GUSER` of the session that emitted |
| Function | The screen / batch / service code |
| Subprogram + line | The script that emitted, and the line number — match the source |
| `fstat` | Last DB / file status code |
| `stat1` | Last operation status (often more detailed than `fstat`) |
| `funfat` | Function fatal flag — 1 if the engine bailed |

### `fstat` cheat sheet

Most-seen non-zero values:

| `fstat` | Meaning | First check |
|---------|---------|-------------|
| 0 | OK | (no error) |
| 1 | Generic failure | Read `stat1` for detail |
| 2 | Not found | Key doesn't match any row |
| 3 | Already exists (Write) | Duplicate primary key |
| 4 | Concurrency / lock conflict | Another session holds the row |
| 5 | Deadlock | DB rolled back; retry the transaction |
| 6 | Invalid key / index | Index name in code doesn't match `GESATB` |
| 7 | Invalid table or alias | `Local File` declaration missing or wrong |
| 50+ | Driver-specific | Read `[S]stat1`; usually a DB-level error |

`stat1` carries the SQL state or a finer code on most drivers — log both.

### `funfat` and engine bail-out

When `funfat = 1`, the engine considered the situation fatal and aborted the call stack to the nearest user-recovery point (typically the screen's main loop or the batch's `$MAIN` exit). Possible causes:

- A `Onerrgo` jump landed at a label that doesn't exist
- A division by zero with no `Onerrgo` in scope
- A type mismatch between actual and declared parameter
- An unhandled supervisor signal (memory limit, runtime kill)

### Searching the log

```bash
# All errors for a user in the last hour
grep "USR1234" /<folder>/TRA/adxlog.log | grep "ERR" | awk -v t="$(date -d '1 hour ago' +%Y-%m-%dT%H:%M)" '$1>=t'

# All deadlocks today
grep "$(date +%Y-%m-%d)" /<folder>/TRA/adxlog.log | grep "fstat=5"

# All occurrences of a custom subprogram
grep "SUBPROG=YCREATE_BPC" /<folder>/TRA/adxlog.log
```

For long-running incidents, copy the relevant log to a working file before it rotates — `adxlog.log` rolls when it exceeds the configured size (default 100 MB) and the older rotation is gzipped.

## Stuck locks — find and clear

When users say "the screen freezes" or "save hangs", a stuck row lock is the most common culprit. The session that took the lock crashed, lost its connection, or returned without committing.

### Find the lock

`Administration → Diagnostics → Locks` (or `GESALOCK`):

| Column | What |
|--------|------|
| Table | Locked table |
| Key | Primary key of the locked row |
| User | Who holds the lock |
| Session | Adonix session ID |
| Started | When the lock was taken |

If "Started" is more than a few seconds ago and the session is supposedly idle, the lock is stuck.

### Clear the lock

Three options, ranked by safety:

1. **Wait for the session timeout.** The engine releases stuck locks when the session is detected dead — usually a few minutes. Safest.
2. **Kill the session via Syracuse.** `Administration → Diagnostics → Sessions → kill`. Releases the lock cleanly.
3. **Force-clear at DB level.** Last resort — if the engine doesn't release, a DBA terminates the DB connection. Risk: rolls back the transaction the session was in, may leave application data inconsistent.

Never disable locking globally to "unstick" things. Identify the holder and clear it specifically.

## Hung AWS pool / SOAP timeouts

If SOAP callers see timeouts but the engine logs no errors:

1. Check the pool size (`GESAPO` → status). If `Active = Max` and `Pending > 0`, the pool is saturated.
2. Check what the active sessions are doing — `GESALI` for queued, `GESALOCK` for blocked.
3. If a session is stuck on a slow query, the fix is the query (`performance.md`), not the pool size.
4. If callers are simply more numerous than the pool, increase the pool.

Restart of the pool clears any cached stale state but disconnects every in-flight call. Schedule, don't impulse.

## Batch failure — what to read first

Failed batches surface in `GESAEX` (Batch executions) with status `4` (error) or `3` (aborted). Click into the row:

- **Output log** — the `$MAIN` script's `Print`/`Trace` output captured by the engine
- **Error log** — anything with `ERR` written to `adxlog.log` during the run
- **Parameters used** — what `[V]GPARAM*` actually held

Also check your custom `YBATCHLOG` table (see `batch-scheduling.md`) — it captures `START` / `END` / per-step events the supervisor doesn't.

If the batch is recurrent and the failure halted the schedule:

1. Acknowledge the error in the queue (or the schedule won't refire).
2. Fix the root cause.
3. Manually trigger one run to confirm the fix.
4. Re-enable the recurrent schedule.

## Database-side post-mortem

When the L4G layer is silent but data is wrong:

1. **DB-side query log** — most DBAs keep a slow-query log. Find the bad write by timestamp and trace it back.
2. **Trigger fired?** Database triggers (e.g. on `BPCUSTOMER` insertion) run outside L4G. They can't be traced from L4G, only from DB tools.
3. **Concurrent batch ran?** Cross-reference `GESAEX` with the corruption time — a batch may have rewritten the row.
4. **Replication delay?** If the folder uses read replicas (uncommon but possible), a write may not have propagated yet.

For a row whose value is unexpected, check the audit log table (`YAUDITLOG` if you set one up — see `security-permissions.md`). Without it, the post-mortem stops at "we don't know who wrote it."

## Memory / engine crash

If `adxlog.log` shows entries like:

```
*** SIGSEGV in adonix at 0x...
*** core dumped to /<runtime>/cores/
```

The engine itself crashed. Triage:

1. **Reproduce on a clone.** Don't experiment on prod — copy the folder.
2. **Recent changes?** A custom `.adx` compiled against an old supervisor and run against a new one is a classic trigger.
3. **Memory pressure?** `free -m` on the host. If swap is hot, restart the engine to release leaked memory; investigate which session leaked.
4. **Core dump.** `gdb adonix core` shows where the engine died. Useful for support tickets to Sage; not actionable in L4G alone.

For systematic crashes after a patch, escalate to Sage support — they need the core, the patch chain, and a reproduction case.

## Hung Syracuse / web layer

When Syracuse stops responding (REST 502s, the web UI is white-screened):

1. Check the Node process is alive (`ps -ef | grep node`).
2. Check `<syracuse>/logs/syracuse.log` for stack traces.
3. Check the JVM bridge if you use it (separate process).
4. Restart Syracuse only after capturing the log — restarting clears the symptom but loses the diagnostic.

The L4G layer is fine if `adonix` is alive; only the front falls. Test by hitting the SOAP endpoint directly with `curl` — if it answers, only Syracuse is sick.

## Producing a useful incident report

When handing off to support or a colleague, include:

1. **Timeline** — when first noticed, when escalated, what was tried.
2. **Scope** — affected users, affected functions, error rate.
3. **Logs** — relevant `adxlog.log` slice, custom log slices, screenshots of `GESALI`/`GESAEX`/`GESALOCK` if relevant.
4. **Recent changes** — patch deploys, activity-code toggles, parameter changes in the last 7 days.
5. **Reproduction** — can it be reproduced on demand? Steps?
6. **Patch level** — V12 patch number; matters for `version-caveats.md` cross-checks.
7. **Workaround in place** — what's keeping prod limping while you fix.

Without these, support tickets bounce for days asking the same questions.

## Common pitfalls during triage

- **Restarting the engine before capturing the state** — loses the lock list, the session list, the in-memory log buffer. Capture first, restart second.
- **Killing the wrong session** — read the user code on the lock list before terminating. A lock held by a critical batch that's still progressing should not be killed.
- **Disabling tracing during the incident** — turn it ON during a P1, not off; the trace overhead is nothing compared to the time you save.
- **Patching without a backup** — never deploy a fix patch on the live folder without a rollback plan. Folder copy → fix → verify → swap.
- **Trusting `adxlog.log` alone** — it rotates and truncates. Custom audit tables (`YAUDITLOG`, `YBATCHLOG`, `YINTEGRATIONLOG`) survive longer; use them.
- **Assuming the bug is in custom code** — sometimes it's a Sage standard regression after a patch. Check the patch notes before blaming Y-code.

## Post-mortem template

After resolution, write a short note (one screen) and store it. Useful template:

```
INCIDENT: <one-line summary>
DATE/TIME: <range>
DETECTED BY: <user / monitor / customer>
SCOPE: <affected users, functions, regions>
ROOT CAUSE: <technical, one paragraph>
TRIGGER: <what made the latent issue surface>
FIX: <code change, parameter change, infrastructure change>
DETECTION GAP: <why we didn't catch it earlier>
PREVENTION: <what we'll do differently>
```

Even a five-minute write-up beats none. Patterns emerge after three or four — that's where the next refactor decision comes from.

See also: `debugging-traces.md` (preventive tracing, supervisor trace), `code-review-checklist.md` (catch issues before they ship), `performance.md` (slow query / lock investigation), `batch-scheduling.md` (batch failure handling), `version-caveats.md` (patch-related drifts that surface as crashes), `security-permissions.md` (audit logs that survive `adxlog.log` rotation).

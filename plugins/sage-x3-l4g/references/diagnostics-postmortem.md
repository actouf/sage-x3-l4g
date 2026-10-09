# Diagnostics and post-mortem

What to do when production is already broken: a generic triage order, then the X3 V12 screens that answer
"who is connected", "who holds the lock", "why did the batch fail" and "who changed this row", plus a
database-side checklist and an incident report template. Tracing techniques themselves are in
`debugging-traces.md`; slowness analysis in `performance.md`.

## Contents
- [Triage order](#triage-order)
- [Symptom to first screen](#symptom-to-first-screen)
- [Sessions and users](#sessions-and-users)
- [Locked symbols vs database locks](#locked-symbols-vs-database-locks)
- [Batch failures](#batch-failures)
- [Engine and Syracuse logs](#engine-and-syracuse-logs)
- [Database-side checks](#database-side-checks)
- [Who changed this data?](#who-changed-this-data)
- [Incident report template](#incident-report-template)
- [Gotchas](#gotchas)
- [Sources](#sources)

## Triage order

Generic, tool-independent order for the first minutes of a P1:

1. **Scope** — one user, one function, one site, or everybody? One endpoint (folder) or all of them?
2. **Layer** — browser/Syracuse (pages do not load at all), X3 runtime (functions fail, sessions die), database
   (everything waits), or business logic (one rule rejects)?
3. **Change** — last patch, last activity-code or parameter change, last deployment of specific code, last batch.
4. **Capture before you fix** — session list, lock list, request log, DB blocking chain, screenshots. Restarting a
   service or killing sessions destroys the evidence.
5. **Contain** — workaround (disable a recurring task, ask users to leave a function) before root-causing.
6. **Fix on a copy first** — reproduce in a test folder; deliver the fix as a patch, never by editing production.

## Symptom to first screen

| Symptom | Look first at |
|---|---|
| "Record being modified by another user" style messages on one record | Locked symbols (VERSYMB) |
| Save hangs for several users, no error | Database blocking chain (below), then VERSYMB |
| A batch task shows Error / Warning / stays In progress | Request management (ASYRREQMAN) → Log |
| Everybody slow | Sessions information, then DB waits; `performance.md` |
| SOAP/REST callers fail | X3 session logs (type Web service), integration log — `web-services-integration.md` |
| Wrong values in a record | Audit trail (AUDITH/AUDITL) or custom audit table — `audit-compliance.md` |
| Runtime errors with script/line | Log file of the function (TRA), `errn`/`errl` traces — `debugging-traces.md` |

## Sessions and users

- **Sessions information** (Syracuse administration page; menu Administration > Usage > Sessions management >
  Session information, community-reported for V12 2021 R1 and later): one line per web connection with type
  (Standard, Batch, SOAP), user login, client IP, host/process, endpoint, number of X3 sessions, badges, last access
  and expiry. Actions: **Disconnect** (forces re-authentication) and **Activate session trace** (levels Error,
  Warning, Info, Debug, Silly; written to the Syracuse `logs` folder unless `logpath` is changed in `nodelocal.js`).
- **Session infos**: per web session, the X3 process ids it uses (Classic pages open at least two processes).
- **User monitoring (APSADX)** — the X3-side session list. Community-reported: APSADX has no FCT page; the code
  comes from a Sage support blog post
  (https://communityhub.sage.com/sage-global-solutions/sage_x3/b/sage-x3-uk-support-insights/posts/improved-x3-session-information-in-latest-v12-patch-release),
  which notes that sessions present in APSADX but unknown to Syracuse ("Unknown X3 sessions") may be ghost
  sessions to disconnect manually.
- To match an X3 user to a database session, Sage support suggests Development > Utilities > System monitor >
  Users to read the `sadoss` process id, then filter the DB trace on that client process id (community-reported).

Before disconnecting anything, record user, endpoint, process ids and what the session was running.

## Locked symbols vs database locks

Two different mechanisms produce "locked" symptoms:

| | Symbol lock | Database row lock |
|---|---|---|
| Created by | `Lock SYMBOL` (V6-style object management), stored in table `APLLCK` (`[S]adxtlk`) | `Readlock`, `For … With Lock`, any row modified inside a transaction |
| Lifetime | Until `Unlock`, or until the owning session is ended | Until `Commit` / `Rollback` |
| Visible in | **Locked symbols** function **VERSYMB** | DB tools only (blocking query below) |
| Typical cause | Browser closed without logout ("phantom" session, community-reported), crashed process | Long transaction, user prompt inside a transaction, runaway batch |

VERSYMB (V11 menu Development > Utilities > Verifications > Locks > Locked symbols) lists the symbol,
machine, user, X3 identifier (`adxuid(1)` of the session) and date-time. Object symbols are the object code followed
by the key (e.g. `AUSMARTIN` for user MARTIN; multi-part keys put the second component first, separated by `\`).
The **User Monitor** action jumps to the session holding the symbol; ending that session releases it.
Sage's Lock documentation notes that V7-style code relies on optimistic locking (`Rewritebykey` + UPDTICK)
instead of symbol locks — see `database.md`.

Order of preference to clear a lock: let the user finish/leave the record → end the owning session from the
monitor → database-level kill by a DBA (rolls back that session's open transaction). Never delete APLLCK rows by
hand without Sage support.

## Batch failures

Request management (**ASYRREQMAN**) lists every request sent to the batch server with folder, task, user,
dates, session id, timeout and status (local menu 21): Standby, In progress, Finished, Held, Kill, Canceled,
Error, Overdue, Warning (task ended on a non-blocking code, `GERRBATCH` < 100).

1. Open the request line → **Log**: the request trace `RQT<request number>` from the TRA directory of the runtime's
   SERVX3 directory. The server-level **Log** action shows `server.tra` (server start, request launch, end).
2. Open the function's own log (`F<n>.tra` or your `ALOG` file) via LECTRACE/AREADLOG — `debugging-traces.md`.
3. If the log is empty, reproduce with an *X3 session logs* entry of type **Batch query** (filter on user, task code)
   or with `openlog` around the suspect call.
4. Check **Parameter entry** on the request: the values the task really received.
5. After the fix, relaunch once manually, then re-enable the recurring task (GESABA) — `batch-scheduling.md`.

Since 2025 R1 (V12.0.37) ASYRREQMAN has extra search/sort/filter features and a "Classic function" action giving
access to the classic AREQUETE function.

## Engine and Syracuse logs

- X3 runtime: engine log by code (`openlog`) or by the *Engine trace* administration page; targeted *X3 session
  logs* (written in the runtime `logs` directory, auto-stopped after `MaxLogTime` minutes). Details and flag values:
  `debugging-traces.md`.
- Syracuse: session traces go to the Syracuse `logs` folder (`logpath` in the `collaboration` section of
  `nodelocal.js`). Capture them before restarting the web server.
- There is no `adxlog.log` file to grep: `adxlog` is the transaction-level variable, not a log.

## Database-side checks

Generic DBA queries (not X3-specific) to find who blocks whom. Run them while the problem is happening.

```sql
-- SQL Server: blocked requests and their blocker
SELECT r.session_id, r.blocking_session_id, r.wait_type, r.wait_time,
       s.host_name, s.program_name, s.host_process_id, t.text
FROM sys.dm_exec_requests r
JOIN sys.dm_exec_sessions s ON s.session_id = r.session_id
CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) t
WHERE r.blocking_session_id <> 0;
```

```sql
-- Oracle: blocked sessions and their blocker
SELECT sid, serial#, username, program, machine, blocking_session, event, wait_class
FROM v$session
WHERE blocking_session IS NOT NULL;
```

Then: follow the chain to the head blocker, map it to an X3 process (host/process id), check what it runs
(request management, session list) before any kill. Also check free disk space (TRA, TMP, database logs), DB
log/redo saturation and backups running at the same time.

## Who changed this data?

- **Standard audit**: with activity code AUDIT active and the *Audit* tab of the table dictionary filled, database
  triggers record inserts/updates/deletes (optionally before/after values) in **AUDITH**/**AUDITL**; consult them via
  Usage > Audit > Tables / Fields, and connections via Usage > Audit > Connections. Only tables configured
  *before* the incident are covered.
- **Custom audit table** written by your own code (`YAUDIT`) — `audit-compliance.md`.
- **Batch history**: compare the change time with request management start/end times.
- **Integration log**: inbound calls that could have written the row — `web-services-integration.md`.

## Incident report template

```text
INCIDENT:        <one-line summary>
DATE/TIME:       <start - end, timezone>
DETECTED BY:     <user / monitoring / customer>
SCOPE:           <endpoints (folders), functions, users, sites affected>
X3 CONTEXT:      <V12 patch level, last patch applied, activity codes changed>
EVIDENCE:        <request numbers + RQT logs, TRA files, VERSYMB / session screenshots, DB blocking output>
TIMELINE:        <detection, escalation, actions tried with time>
ROOT CAUSE:      <technical, one paragraph>
TRIGGER:         <what made the latent issue surface>
FIX:             <code / patch / parameter / infrastructure change>
DETECTION GAP:   <why it was not caught earlier>
PREVENTION:      <test added (unit-testing-axunit.md), monitoring, review rule>
```

## Gotchas

- Restarting Syracuse or the runtime before capturing sessions, locks and logs loses the evidence.
- Killing a session that is in the middle of a batch transaction rolls the whole transaction back — check the
  request list first.
- VERSYMB only shows symbol locks; an empty VERSYMB does not mean "no lock" (database row locks are invisible there).
- Do not leave session traces, Engine trace or X3 session logs on after the incident: they cost CPU and disk.
- Audit tables only answer for tables that were configured before the change happened.
- Suspect standard regressions too: compare with the patch notes before blaming specific code.

See also: `debugging-traces.md`, `performance.md`, `batch-scheduling.md`, `database.md`, `audit-compliance.md`,
`web-services-integration.md`, `version-caveats.md`.

## Sources
- https://online-help.sagex3.com/erp/12/en-us/Content/FCT/VERSYMB.htm , https://online-help.sagex3.com/erp/11/en-US/FCT/VERSYMB.htm (menu)
- https://online-help.sagex3.com/erp/12/en-us/Content/V7DEV/4gl_lock.html
- https://online-help.sagex3.com/erp/12/en-us/Content/FCT/ASYRREQMAN.htm
- https://online-help.sagex3.com/erp/12/en-us/Content/V7DEV/administration-reference_sessions-information.html
- https://online-help.sagex3.com/erp/12/en-us/Content/V7DEV/administration-reference_session-infos.html
- https://online-help.sagex3.com/erp/12/en-us/Content/V7DEV/administration-reference_x3-session-logs.html
- https://online-help.sagex3.com/erp/12/en-us/Content/V7DEV/administration-reference_x3-session-configuration.html
- https://online-help.sagex3.com/erp/12/en-us/Content/V7DEV/4gl_adxuid.html
- https://online-help.sagex3.com/erp/11/en-US/OBJ/ACV_AUDIT.htm
- https://communityhub.sage.com/sage-global-solutions/sage_x3/b/sage-x3-uk-support-insights/posts/improved-x3-session-information-in-latest-v12-patch-release (community)
- https://www.greytrix.com/blogs/sagex3/2013/03/16/how-to-unlock-your-process-in-sage-x3/ (community)
- https://communityhub.sage.com/sage-global-solutions/sage_x3/b/sage-x3-support-insights-ame/posts/sage-x3-performance-blueprint-optimization-troubleshooting (community)

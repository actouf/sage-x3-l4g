# Debugging and traces

Canonical home for trace/log files, error trapping, the engine log and the interactive debugger in Sage X3 V12.
Read it when code "does nothing", fails silently in batch, or you must explain a failure after the fact.
Production triage lives in `diagnostics-postmortem.md`; timing and query tuning in `performance.md`.

## Contents
- [Which tool for which question](#which-tool-for-which-question)
- [V12 log files: the ALOG class](#v12-log-files-the-alog-class)
- [Classic trace sub-programs](#classic-trace-sub-programs)
- [Reading log files: LECTRACE and AREADLOG](#reading-log-files-lectrace-and-areadlog)
- [Trapping runtime errors](#trapping-runtime-errors)
- [Engine log: openlog, Engine trace, X3 session logs](#engine-log-openlog-engine-trace-x3-session-logs)
- [Interactive debugger (Eclipse)](#interactive-debugger-eclipse)
- [System variables worth dumping](#system-variables-worth-dumping)
- [Gotchas](#gotchas)
- [Sources](#sources)

## Which tool for which question

| Question | Tool | Where |
|---|---|---|
| What did my batch / long job do, line by line, for the user? | Log file (`.tra`) written by `ALOG` (V7+) or `OUVRE_TRACE`/`ECR_TRACE` (Classic) | below |
| Which statement raised error N, in which script and line? | `Onerrgo` + `errn`, `errl`, `errp`, `errm`, `errmes$` | below, `language-basics.md` |
| Which Gosub/Call/Read did the engine actually execute? | Engine log: `openlog(MODE)` in code, or the "Engine trace" administration page | below |
| Where is the time spent? | `ASYRTIMING.START/STOP` profiler, timestamps | `performance.md` |
| What is the value of X at line N? | Eclipse debugger (`dbgmode` + `Dbgaff`) | below |
| What went in/out of an integration call? | Integration log table | `web-services-integration.md` |
| Which fstat value means what? | fstat constants table | `database.md` |

## V12 log files: the ALOG class

Sage's developer guide states that version 6 used the `OUVRE_TRACE`/`ECR_TRACE` sub-programs, and that V7+ code
should instantiate the supervisor class `ALOG`, which writes the same `.tra` format but fits class/method code.
All methods are called with `fmet`:

| Method | Purpose |
|---|---|
| `ABEGINLOG(TITLE)` | Start the log and set its title. Returns 0. |
| `ASETNAME(FILE_NAME)` | Force the file name (default: `F` + the `[C]NUMIMP` counter). Returns `[V]CST_AERROR` if a name was already assigned. |
| `AGETNAME()` | Return the file name (assigns the default one if needed). |
| `APPENDLOG(FILENAME)` | Re-open an existing log to append lines (creates it if missing). |
| `APUTLINE(TEXT, STAT)` | Write line(s); `TEXT` may be an array. `STAT` = `[V]CST_AWARNING`, `[V]CST_AERROR`, anything else = information. |
| `APUTINSTERRS(INSTANCE)` | Dump the errors attached to a class instance (set by `ASETERROR`, see `v12-classes.md`). |
| `APUTERRS(ERRINSTANCE)` | Dump an `AERROR` instance. |
| `AFLUSHLOG()` | Flush buffered lines to disk (user parameter `NBTRABUFF` sets the buffer size). |
| `AENDLOG()` | Write, close the file. Returns 0. |

The life cycle of a log, from `YCHECKBAL` in `examples/YACCLIB.src` (full subprogram there):

```l4g
Local Instance YLOG Using C_ALOG
Local Integer OK
  YLOG = NewInstance C_ALOG AllocGroup Null
  [L]OK = fmet YLOG.ABEGINLOG("YCHECKBAL - contrôle des soldes")
  [L]LOGNAME = fmet YLOG.AGETNAME()     : # LOGNAME: Variable parameter returned to the caller
  [L]OK = fmet YLOG.APUTLINE("User " + GACTX.USER - "folder " + GACTX.AFOLDER, [V]CST_AINFO)
  For [YACC] Where Y_BALANCE < 0
    [L]OK = fmet YLOG.APUTLINE("Solde négatif : " + [F:YACC]Y_ACCNUM, [V]CST_AWARNING)
  Next
  [L]OK = fmet YLOG.AENDLOG()
  FreeGroup YLOG
```

Call `AFLUSHLOG` after an important error line if the process might die before `AENDLOG`, but not on every line
(the guide warns about the performance cost). `GACTX.USER` / `GACTX.AFOLDER` come from the context instance
(`this.ACTX` inside class code).

## Classic trace sub-programs

Still running in V12 (these are the V6 sub-programs). Host scripts are documented on Sage's
AREADLOG page ("the `OUVRE_TRACE` subprogram of `LECFIC`", counters "incremented in the `GESECRAN` script",
"terminated in `FERME_TRACE`"); the exact call forms and flag values below are community-reported (Greytrix,
Sage Community Hub), except `OUVRE_TRACE(TITLE) From LECFIC` and `CLOSE_LOC From LECFIC`, which appear in Sage's
silent-import sample (GES_AOE1).

| Call | Effect |
|---|---|
| `Call OUVRE_TRACE(TITLE) From LECFIC` | Open a new log file with a title line |
| `Call ECR_TRACE(MSG, FLAG) From GESECRAN` | Write one line; `FLAG` 0 = normal (black), 1 = error (red), -1 = green, -2 = blue |
| `Call FERME_TRACE From LECFIC` | Close the log |
| `Call CLOSE_LOC From LECFIC` | Close the log — the form used by Sage's silent-import sample (GES_AOE1, after `IMPORTSIL`) |
| `Call LEC_TRACE From LECFIC` | Display the log to an interactive user |
| `Call SUPP_TRACE From LECFIC` | Delete the log |

```l4g
# Classic-style trace (V6 sub-programs) - prefer ALOG in new V12 code
Call OUVRE_TRACE("YRECALC - recalcul des soldes") From LECFIC
Call ECR_TRACE("Début du traitement", 0) From GESECRAN
Call ECR_TRACE("Compte YA001 : solde négatif", 1) From GESECRAN
Call ECR_TRACE("Traitement terminé", -1) From GESECRAN
Call FERME_TRACE From LECFIC
Call LEC_TRACE From LECFIC : # interactive sessions only
```

Lines written with flag 1 are counted as errors (the AREADLOG page mentions the `GERRTRACE` variable for the
error count, and a pop-up announces the number of errors before the log is shown, community-reported).
There is no `ECRAN_TRACE`: it does not exist.

**Log already open?** Some entry points run with the standard's log open. ADC_TRTSYN.htm says the `GTRACE`
variable must be tested: `GTRACE <> ""` means a log file is open, `GTRACE = ""` that none is. Write with
`ECR_TRACE` only when `GTRACE <> ""`, and never close a log you did not open.

**Gating verbose traces.** Do not comment code in and out. Define a parameter at **user** level (e.g. `YTRCLVL`)
in GESADP and read it once with `fmet GACTX.APARAM.AGETUSERVALNUM("YTRCLVL")` (V12 context-parameter API).

## Reading log files: LECTRACE and AREADLOG

- Standard long-running and batch functions write their logs in the **TRA** sub-directory of the folder, named
  `F<n>.tra` where `<n>` comes from the `[C]NUMIMP` counter (LECTRACE help). The first line holds a header, date,
  time, user and comment; error lines are prefixed `>` or `<` with an error number.
- **LECTRACE** ("Log reading") opens one file, pages through it (999 lines per page) and can filter error lines.
- **AREADLOG** (recent V12 patch levels; the page gives no patch number) is the V7-style replacement: an `ALOG`
  table/representation listing the TRA files with user, function, module, error and warning counts, plus an
  "Archive logs" action that moves old files to `TRA_HIS`, and a recurring batch task `ALOG` to refresh/archive.
- Batch request logs are `RQT<request number>` and the batch server log is `server.tra` in the TRA directory of
  the runtime's SERVX3 directory (ASYRREQMAN help) — see `diagnostics-postmortem.md`.

## Trapping runtime errors

`Onerrgo LABEL` (or `Onerrgo LABEL From SCRIPT`) branches to a handler when the engine raises an error.
Inside the handler only: `errn` (error number), `errl` (line), `errp` (script), `errm` (extra detail),
`errmes$(N)` (text of error N in the connection language). Leave with `Resume` (continues after the failing
statement; after the `Endif`/`Next`/`Wend` if it was inside a block) or `End`. `Onerrgo` alone cancels the routing.
Language-level details: `language-basics.md`.

```l4g
Funprog YRATIO(NUM, DEN, ERRMSG)
Value Decimal NUM, DEN
Variable Char ERRMSG()
Local Decimal RES
  [L]ERRMSG = ""
  Onerrgo YRATIO_ERR
  [L]RES = [L]NUM / [L]DEN
  Onerrgo
End [L]RES

$YRATIO_ERR
  [L]ERRMSG = "Erreur" - num$(errn) - errmes$(errn) - "ligne" - num$(errl) - "script" - errp - errm
  [L]RES = 0
Resume
```

Rules from the Onerrgo page that bite in debugging sessions:
- An error raised inside the handler is **not** re-routed (to avoid loops): it behaves like an untrapped error.
- A handler cannot `Commit`/`Rollback` a transaction opened by the failing code; if it reaches `End`, the engine
  rolls the transaction back automatically.
- If a called sub-program has no `Onerrgo`, its error surfaces in the caller's handler as if raised on the `Call` line.

## Engine log: openlog, Engine trace, X3 session logs

**From code.** `ST = openlog(MODE)` puts the engine in log mode; the file goes to the `TMP` sub-folder of the
directory given by `ADXDIR`. `ST = closelog()` stops it, `getlogname()` returns the last file name. Status 0 = OK.

| MODE bit | Logged |
|---|---|
| 1 | `Gosub` and `Call` stack |
| 2 | Every instruction |
| 4 | `Read` and `For` database requests |
| 8 | All sadxxx (database driver) requests |
| 16 | JSON exchanges |
| 32 | Classic mode exchanges |
| 64 | sadldap exchanges |
| 128 | opadxd exchanges |

```l4g
Local Integer ST
Local Char YLOGNAME(250), YENGINELOG(250)
[L]ST = openlog(1 + 4) : # call stack + Read/For requests
Call YCHECKBAL([L]YLOGNAME) From YACCLIB
[L]ST = closelog()
[L]YENGINELOG = getlogname()
```

**From the administration pages (no code change).**
- *Engine trace* page: "Enable logging" + a **Flag** that sums 1 (Gosub/Call/Callmet/Fmet), 2 (all instructions),
  4 (Read/For), 8 (engine ↔ database driver), 16 (client JSON), 32 (Classic binary), 64 (LDAP), 128 (Opldap),
  256 (runtime start); a log directory relative to the folder (must be allowed by the sandbox) and the endpoint.
  "Activate X3 log" is global to every session started afterwards — CPU, memory and disk cost; keep it short.
- *X3 session logs* page: targeted logs of type Batch administration, Batch query (user/task), Web service
  (endpoint, SOAP pool, user), Representation, or Function (classic page); `MaxLogTime` auto-stops the log; files land
  in the runtime's `logs` directory; an enabled log must be stopped before it can be edited.
- *Sessions information* page: "Activate session trace" per web session (levels Error, Warning, Info, Debug, Silly)
  — this traces the Syracuse side, written to the Syracuse `logs` folder.

## Interactive debugger (Eclipse)

The V12 debugger is the Eclipse-based workbench. In code, `dbgmode` must be non-zero, then `Dbgaff` hands control
to the Eclipse debugger (inspect variables, step, breakpoints):

```l4g
# Temporary breakpoint - never commit this to a patch
dbgmode = 1
Dbgaff
```

Installing Safe X3 Studio, connecting it to a folder, the user parameters that make Eclipse the debugger
(`AECLIDBG`…) and the debug proxy are in `development-workflow.md`.

## System variables worth dumping

| Variable / function | Meaning (glossary) |
|---|---|
| `nomap` | Current folder name(s) — use it instead of a hard-coded folder |
| `GACTX.USER`, `GACTX.AFOLDER`, `GACTX.LOGIN` | Context: user code, folder, login (`this.ACTX` in classes) |
| `adxlog` | 1 when a transaction is open |
| `fstat` | Status of the last DB / sequential-file / Lock operation |
| `adxuprec`, `adxdlrec`, `adxsqlrec` | Rows touched by the last `Update`, `Delete`, `Execsql` |
| `[S]stat1` | Number of lines returned by the last `System` instruction (negative = shell failure) — **not** a DB error code |
| `adxuid(1)` | Unique id of the connection on the instance (the UID column of VERSYMB locked symbols) |
| `errn`, `errl`, `errp`, `errm` | Only meaningful inside an `Onerrgo` handler |

## Gotchas

- `fstat` is overwritten by the next DB/file statement: copy it to a local before writing a trace line.
- `stat1` is not an error channel and there is no `funfat` variable: use `fstat` for DB, `errn` for runtime errors.
- Always pair `OUVRE_TRACE` with `FERME_TRACE` (Sage's import sample uses `CLOSE_LOC`), and `ABEGINLOG` with
  `AENDLOG`, including on error paths.
- Interactive display (`LEC_TRACE`, `Errbox`, `Infbox`) has no user to show to in batch and web services — write a log.
- Leaving `Dbgaff` in delivered code hands user sessions to a debugger (or raises "Debugger not active",
  community-reported); grep for it before building a patch.
- Engine logs (`openlog`, Engine trace) grow fast; enable them for one reproduction, then switch off.
- Never write secrets or full personal data into traces: TRA files can be opened by any user authorised on
  LECTRACE / AREADLOG.

See also: `development-workflow.md`, `diagnostics-postmortem.md`, `performance.md`, `language-basics.md`, `database.md`,
`web-services-integration.md`, `v12-classes.md`, `unit-testing-axunit.md`.

## Sources
- https://online-help.sagex3.com/erp/12/en-us/Content/V7DEV/developer-guide_managing-log-files.html
- https://online-help.sagex3.com/erp/12/en-us/Content/V7DEV/administration-reference_supervisor-administration-log-file-management.html
- https://online-help.sagex3.com/erp/12/en-us/Content/FCT/LECTRACE.htm
- https://online-help.sagex3.com/erp/12/en-us/Content/FCT/GES_AOE1.htm (OUVRE_TRACE / CLOSE_LOC in the silent-import sample)
- https://online-help.sagex3.com/erp/12/en-us/Content/OBJ/ADC_TRTSYN.htm (GTRACE)
- https://online-help.sagex3.com/erp/12/en-us/Content/FCT/ASYRREQMAN.htm
- https://online-help.sagex3.com/erp/12/en-us/Content/V7DEV/4gl_onerrgo.html (and 4gl_errn, 4gl_errl, 4gl_errp, 4gl_errm, 4gl_errmes$, 4gl_resume)
- https://online-help.sagex3.com/erp/12/en-us/Content/V7DEV/4gl_openlog.html (and 4gl_closelog, 4gl_getlogname)
- https://online-help.sagex3.com/erp/12/en-us/Content/V7DEV/administration-reference_x3-session-configuration.html
- https://online-help.sagex3.com/erp/12/en-us/Content/V7DEV/administration-reference_x3-session-logs.html
- https://online-help.sagex3.com/erp/12/en-us/Content/V7DEV/administration-reference_sessions-information.html
- https://online-help.sagex3.com/erp/12/en-us/Content/V7DEV/4gl_dbgmode.html , …/4gl_dbgaff.html
- https://online-help.sagex3.com/erp/12/en-us/Content/V7DEV/developer-guide_context-parameters.html
- https://online-help.sagex3.com/erp/12/en-us/Content/V7DEV/how-to_how-to-get-information-relating-to-the-current-context.html
- https://online-help.sagex3.com/erp/12/en-us/Content/V7DEV/4gl_stat1.html , …/4gl_nomap.html , …/4gl_fstat.html , …/4gl_adxuid.html
- https://www.greytrix.com/blogs/sagex3/2024/02/27/how-to-customize-the-trace-log-file-for-errors-and-success-messages/ (community)
- https://communityhub.sage.com/sage-global-solutions/sage_x3/f/general-discussion/104603/display-a-trace-file (community)

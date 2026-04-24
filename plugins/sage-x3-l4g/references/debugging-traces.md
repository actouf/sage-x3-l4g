# Debugging and traces

How to find out what your L4G code is actually doing when the user reports "it doesn't work".

## The trace window — first reflex

In Classic and V12, the runtime has a trace channel that any `Call ECR_TRACE` / `Call ECRAN_TRACE` writes to. The user or developer can see it via:

- **Classic UI** — the trace is shown at the end of a function's execution as a popup or separate window
- **V12 / Syracuse** — the trace appears in the UI after the action, or is downloadable as a file from the server

### Writing a trace line

```l4g
Call ECRAN_TRACE("Starting YTRANSFER from=" - ACCOUNT1 - " to=" - ACCOUNT2 + " amt=" + num$(AMOUNT), 0) From GESECRAN
```

Second argument = level (emphasis):

| Level | Effect |
|-------|--------|
| `0` | Plain line |
| `1` | Bold / header |
| `2` | Warning / red |

Use `0` for data, `1` for section separators, `2` for actual problems.

### `ECR_TRACE` vs `ECRAN_TRACE`

Both exist; both work. On most folders `ECR_TRACE` is a short alias. Use whichever your existing codebase uses to stay consistent — the skill uses `ECRAN_TRACE` throughout.

## Conditional / gated traces

Full production code shouldn't spam the trace. Pattern:

```l4g
If [V]YDEBUG
    Call ECRAN_TRACE("DEBUG: state=" - num$([L]STATE), 0) From GESECRAN
Endif
```

Set `[V]YDEBUG = 1` at the start of a test session, unset it afterward. Better: a parameter (`GESADP`) so ops can toggle it without code change.

### Per-module debug flags

For big systems, split:

```l4g
If [V]YDEBUG_IMPORT : Call ECRAN_TRACE(...) : Endif
If [V]YDEBUG_WS     : Call ECRAN_TRACE(...) : Endif
```

Noise cost = zero when disabled; you can enable only the subsystem you're investigating.

## Writing to a log file

When the trace isn't persistent enough (batch jobs, unattended processes):

```l4g
Subprog YLOG(MSG)
Value Char MSG()

Local Char PATH(200), LINE(2000)
PATH = "TMP/ylog_" - num$(date$, "YYYYMMDD") - ".log"
LINE = num$(date$, "J/M/A") - " " - time$ - " [" - [V]GUSER - "] " - MSG

Openo PATH Using 9 Append
If !fstat
    Writeseq LINE Using 9
    Close 9
Endif
End
```

One log per day per process keeps things manageable. Rotate on size when load gets heavy.

## Persistent integration logs — a real table

For integrations, the trace window isn't enough (audit, support). Dedicated table:

```l4g
# YINTEGRATIONLOG — one row per inbound/outbound message
Raz [F:YINTLOG]
[F:YINTLOG]DAT = date$
[F:YINTLOG]TIM = time$
[F:YINTLOG]USR = [V]GUSER
[F:YINTLOG]DIR = "IN"                    # or "OUT"
[F:YINTLOG]ENDPOINT = URL
[F:YINTLOG]REQUEST = left$(BODY, 2000)
[F:YINTLOG]RESPONSE = left$(RESP, 2000)
[F:YINTLOG]HTTP = HTTPCODE
[F:YINTLOG]STATUS = STATUS               # "OK" / "ERR"
Write [YINTLOG]
```

Queryable, filterable, export-able to CSV for post-mortems. See `web-services-integration.md`.

## Supervisor-level tracing

The X3 supervisor has a built-in tracing that captures *everything* L4G does. Enable it per session:

- **Administration → Utilities → Verifications → X3 tracing** — start trace, pick your user, reproduce the issue, stop, download
- Output lives in `<install>/tmp/` as a `.tra` file
- Shows every function call, SQL query issued, and `fstat` value

Use this when:
- You can't figure out which `Read` returned `fstat <> 0`
- You suspect the engine is rewriting your query
- You want to count how many rows a `For` actually loops over

Expensive — don't leave it on in production.

## The error message / `[S]stat1`

After an error, `[S]stat1` holds a numeric error code. Common values:

| stat1 | Meaning |
|-------|---------|
| `0` | No error |
| `2` | File not found |
| `6` | Lock conflict |
| `20` | Unique constraint violation |
| `100` | EOF (sequential read) |
| `250` | Timeout |

The full mapping is in the supervisor docs — look it up rather than guessing.

For the *string* explanation:

```l4g
Errbox "Err: " + num$([S]stat1) + " - " + [S]funfat
```

`[S]funfat` contains a supervisor-formatted error message.

## Runtime introspection

Useful built-ins to dump state when debugging:

| Expression | What it gives you |
|------------|-------------------|
| `[S]curpos` | Current line number in the current script |
| `[S]curnom` | Name of the current script |
| `[S]curtrt` | Current `.trt` / `.src` being executed |
| `[S]clalph` | Current alphabet (locale setting) |
| `adxlog` | 1 if inside a transaction |
| `[V]GUSER` | Current user code |
| `[V]GLANGUE` | Current language code |
| `nomap` | Current folder |

Dump them at the top of a `$ERR_HANDLER` to get full context on every error:

```l4g
$ERR_HANDLER
    Call ECRAN_TRACE("ERR stat1=" + num$([S]stat1) - " script=" - [S]curnom -
                     " line=" + num$([S]curpos) - " user=" - [V]GUSER, 2) From GESECRAN
End
```

## `funfat` — function fatality info

When a function returns an error, `[S]funfat` is the engine's last-message buffer. It's cleared on each call, so read it **immediately** after the failing operation.

```l4g
Call OUVRE_TRT("GESBPC", ...) From GESAUT
If [S]stat1
    Errbox "Open failed: " - [S]funfat
Endif
```

## Remote debugging — the X3 debugger

The X3 editor (Safe X3 or the dedicated Classic editor) ships an interactive debugger:

- Set breakpoints on any line of a `.src` / `.trt`
- Step over / into / out of `Call` and `Gosub`
- Inspect `[L]`, `[V]`, `[F:...]`, `[M:...]` values live
- Evaluate expressions in the current frame

For V12 / Syracuse:

1. Connect the debugger to the Syracuse runtime (port in the instance config).
2. Attach to your session via user code.
3. Trigger the action that runs your script.

The debugger is overkill for simple cases but invaluable when a `For` loop behaves unexpectedly or a `Link` silently fails.

## Strategies for common bug patterns

### "The record doesn't come back, but there's no error"

- Did you check `fstat` **immediately** after the `Read`? Any statement in between can reset it.
- Did you use the right **index name**? `Read [BPC]BPCNUM0 = ...` — `BPCNUM0` is the index, `BPCNUM` is the field.
- Is your `Where` clause pushed to SQL or filtered client-side? Wrap `pat` with `<> 0` (see `builtin-functions.md`).

### "The transaction didn't commit / it was partially written"

- Every `Write`/`Update`/`Delete`/`Rewrite` must be followed by `If fstat : Rollback : End : Endif`.
- Nested transactions: use the `If adxlog` idiom — otherwise your inner `Rollback` undoes the whole outer transaction.
- A `Goto` out of a `Trbegin` block without reaching `Commit`/`Rollback` leaves locks hanging until session end.

### "The grid shows the wrong rows"

- Did you `Raz [M:GRIDNAME]` before repopulating?
- Did you set `[M:GRID]NBLIG` to the real row count?
- Are you writing to `[M:...]` (mask buffer) or `[F:...]` (record buffer) by mistake? See `screens-and-masks.md`.

### "The action works in dev but fails in production"

- Different **folder** = different data, different dictionary, different patches. Run with `nomap` dumped in the trace.
- Different **user role** = different ACL, parameters, workflows.
- Different **patch level** — check `GESADP` for the supervisor version.

### "It runs the first time, then fails"

- Residual `[F:...]` buffer from a prior read polluting the next `Write`. Always `Raz [F:...]` before `Write`.
- Lock leaked from a prior failed transaction. Check session state in the X3 monitor.
- Cached compiled `.adx` — force a recompile (the supervisor only recompiles when the mtime changes; cloning a file in-place doesn't always bump it).

## Performance debugging

### Find the hot path

Inject timings:

```l4g
Local Integer T0, T1
T0 = [S]adxchr                           # current clock in hundredths of seconds
...
T1 = [S]adxchr
Call ECRAN_TRACE("Step took " + num$(T1 - T0) + " cs", 0) From GESECRAN
```

### SQL-level investigation

Turn on SQL tracing at the database layer (Oracle SQL trace, SQL Server profiler) for the session — reveals whether a `For` uses an index, does a table scan, or N+1 via `Link`.

Common culprits:
- `pat(FIELD, "...")` without `<> 0` → full table scan
- `For [TBL] Where ...` with a non-indexed filter → full table scan
- `Link [B] With [F:A]X = [F:B]Y` inside a `For` over A → N+1 queries

Fix pattern: preload via a single set-based query, or add an index.

## Gotchas

- **Traces disabled in production.** `ECRAN_TRACE` is sometimes silenced by a parameter in hardened installs — `Errbox` isn't, but spams users. Use a log table instead.
- **`stat1` gets reset fast.** Any subsequent supervisor call clears it; copy to a `[L]` immediately.
- **`System` exit codes.** `System "cmd"` sets `stat1` to the shell's exit code; 0 = success, non-zero = whatever the command returned. Don't confuse with X3 error codes.
- **Trace file rollover.** Long sessions produce huge traces; the supervisor may truncate at a size limit, losing the middle. Capture the reproduction early.
- **Debugger and transactions.** Breaking inside a `Trbegin` block leaves locks held. Release them (kill the session) or other users block.
- **Log injection.** If your log message contains user input, sanitize — unescaped newlines let an attacker forge log lines. `replace$(MSG, chr$(10), " ")` is the minimum.

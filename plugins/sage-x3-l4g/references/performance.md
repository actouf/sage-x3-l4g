# Performance

How to keep specific L4G code fast on V12: measure first, let the database filter and join, fetch only the columns
you need, work set-based, and keep locks and transactions short. Read it when a screen, batch or web service is
slow, or when reviewing loops over large tables. Statement syntax and the transaction idiom are canonical in
`database.md`; tracing tools in `debugging-traces.md`.

## Contents
- [Measure before tuning](#measure-before-tuning)
- [Index-driven access](#index-driven-access)
- [What the Where clause sends to SQL](#what-the-where-clause-sends-to-sql)
- [Fetch fewer columns: Columns](#fetch-fewer-columns-columns)
- [Joins with Link instead of N+1 reads](#joins-with-link-instead-of-n1-reads)
- [Set-based work](#set-based-work)
- [Locks and transaction granularity](#locks-and-transaction-granularity)
- [Hints](#hints)
- [Anti-patterns](#anti-patterns)
- [Gotchas](#gotchas)
- [Sources](#sources)

## Measure before tuning

**Timestamps.** `timestamp$` returns milliseconds since 1970-01-01 GMT as a string; store it in a `Decimal`
(the value exceeds 2^32). `time` returns seconds since midnight (local time of the process server).

```l4g
Local Decimal YT0, YMS
Local Char YLOGNAME(250)
YT0 = val(timestamp$)
Call YCHECKBAL(YLOGNAME) From YACCLIB
YMS = val(timestamp$) - YT0
```

**Profiler.** `func ASYRTIMING.START(FILE, GOSUB_FLAG)` / `func ASYRTIMING.STOP(CONTEXT, FILE, GOSUB_FLAG, LOGFILE)`.
Empty file name = `<user>_<adxuid(1)>.tra` in `tmp`; flag 1 also profiles `Gosub`. The result lists every
Gosub/Call with call count, total milliseconds and percentage of the run, sorted descending.

```l4g
Local Integer STAT
Local Char YLOGNAME(250), YPROFILE(250)
STAT = func ASYRTIMING.START("", 1)
Call YCHECKBAL(YLOGNAME) From YACCLIB
STAT = func ASYRTIMING.STOP(GACTX, "", 1, YPROFILE) : # YPROFILE = generated report file
```

**Other tools.**
- Engine log with mode 4 (`Read`/`For`) or 8 (driver requests) shows the statements actually sent —
  `debugging-traces.md`.
- For a slow standard screen: user parameter `DBG` = Yes (chapter Supervisor, group DEV) adds a Diagnostic menu
  with "Activation timing" (community-reported, Sage support blog).
- On SQL Server, a Profiler/Extended Events trace filtered on the client process id of the user's `sadoss` process
  (found in Development > Utilities > System monitor > Users, community-reported) gives real execution plans.

## Index-driven access

Keys are declared on the table in the dictionary (GESATB) and are the only access paths the engine can promise.

```l4g
Local File BPCUSTOMER [BPC]
Local Integer YNB
Local Char YCODE(20)
YCODE = "C001"
# 1. One row by its key
Read [BPC]BPC0 = [L]YCODE
If fstat = [V]CST_ANOREC
  YNB = 0
Endif
# 2. Key range: From/To on the key segments
For [BPC]BPC0 From "C000" To "C999"
  YNB += 1
Next
# 3. Filter sent to the database (becomes LIKE 'J%')
For [BPC]BPC0 Where pat(BPCNAM, "J*") <> 0
  YNB += 1
Next
# 4. No ordering needed: let the database choose
For [BPC]reckey Where pat(BPCNAM, "J*") <> 0
  YNB += 1
Next
```

- A `For` on a key reads in that key's order; `[ABV]reckey` asks for no particular order.
- Sorting is declared on `Local File … Order By Key NAME = COL1;COL2` or `Filter … Order By`, never on the `For`
  line. A sort that matches no database index makes the database sort the whole selection — if a custom process
  needs it often, add a key in GESATB (specific keys follow the X/Y/Z naming rules, `conventions-and-naming.md`).
- Nested `For [ABV]KEY(n)` loops on increasing break levels read once and group; only the outer loop accepts
  `Where` / `From … To` (put other filters on `Local File` or `Filter`).

## What the Where clause sends to SQL

Per Sage's Where documentation, expressions that do not involve table columns are evaluated once and sent as
values; supported operators/functions on columns are translated to SQL; everything else is filtered by the engine
**after** the rows were fetched.

| On table columns | Sent to the database? |
|---|---|
| `= < > <= >= <>`, `and or not xor`, `+ - * / ^` (no `-` on strings) | Yes |
| `left$ right$ mid$ seg$ len num$ ctrans tolower toupper val ascii chr$ instr string$ space$ vireblc` | Yes |
| `abs int ar2`, `find min max` (not on dates) | Yes |
| `pat(COL, P) <> 0` / `= 0`, `find(COL, LIST) <> 0` / `= 0` | Yes (`LIKE`, `IN`) |
| `pat(COL, P)` alone, `find(...)` alone | **No** — engine-side |
| Date functions or date arithmetic on columns (`[F:X]D2 - [F:X]D1 >= 5`) | **No** — engine-side |
| Array indexed by a column value | **No** |

Prefer a range (`RANK >= 4 and RANK <= 7`) to `find(RANK,4,5,6,7) <> 0`, and `find` to a chain of `or`.
Compute date bounds in a local variable (or as an expression without columns) instead of on the column.
A `func` call cannot appear in the `Where` of `File`, `Filter` or `For` at all (4gl_func.html: it cannot be
transmitted to the database): call it before and put its result in a local variable.

## Fetch fewer columns: Columns

`Read`/`For` issue `select *` by default. `Columns [ABV](COL1, COL2)` restricts the columns loaded (and those written
back by `Rewrite`/`RewriteByKey`; `Write` still writes the whole `[F]` class). It applies to `For`; it applies to
`Read`/`Readlock` only with `Extended`. `Columns [ABV]` restores all columns. The restriction is scoped to the
`Local File` nesting level.

```l4g
Local File BPARTNER [BPR]
Local Integer YNB
Columns [BPR](BPRNUM, BPRNAM)
For [BPR]
  YNB += 1
Next
Columns [BPR]
```

## Joins with Link instead of N+1 reads

```l4g
Local File BPCUSTOMER [BPC], AUTILIS [AUS]
Local Integer YNB
# N+1: one SELECT for the loop + one SELECT per customer
For [BPC]BPC0
  Read [AUS]CODUSR = [F:BPC]CREUSR
  If fstat = [V]CST_AOK
    YNB += 1
  Endif
Next
# One joined SELECT. ~= inner join (faster, drops customers without user), = left outer join
Link [BPC] With [AUS]CODUSR ~= [BPC]CREUSR As [YBU]
Columns [YBU]([BPC]BPCNUM, [BPC]BPCNAM, [AUS]CODUSR)
For [YBU]
  YNB += 1
Next
```

- Syntax is `Link [MAIN] With [CLASS]KEY = expr, … As [LNK]`; the linked side is named by one of its **keys**.
  Up to 12 tables per link, 8 links per main table, tables on the same server.
- No `Write`/`Rewrite`/`Update`/`Delete` through the link abbreviation; data lands in each table's `[F]` class.
- On an outer join, missing rows are SQL NULLs: `Where [AUS]COL = ""` does **not** select the unmatched rows.
- On SQL Server, declare a join after the joins whose columns it uses. More: `database.md`.

## Set-based work

One statement beats a loop of single-row statements:

| Need | Use |
|---|---|
| Same change on many rows | `Update [ABV] Where … With COL = expr` (check `fstat`, then `adxuprec`) |
| Delete many rows | `Delete [ABV] Where …` (rows in `adxdlrec`) |
| Aggregates, complex joins | `For (Decimal TOTAL) From DBTYPE Sql "select …" As [YSUM]` |
| DDL / technical DML you own | `Execsql From DBTYPE Sql "…"` (rows in `adxsqlrec`) |

```l4g
Local Integer DBTYPE
Local Char YDB(1), YREQ(250)
Local Decimal YTOTAL
DBTYPE = fmet GACTX.APARAM.AGETVALNUM([V]CST_ALEVFOLD, "", "TYPDBA")
YDB = string$(DBTYPE = 1, "O") + string$(DBTYPE = 2, "S")
YREQ = "select sum(Y_BALANCE_0) from YACCOUNT"
For (Decimal TOTAL) From YDB Sql YREQ As [YSUM]
  YTOTAL = [F:YSUM]TOTAL
Next
```

`Sql`/`Execsql` take the database type ("O"/"3" Oracle, "S"/"5" SQL Server) and raw SQL with physical names
(Sage's examples use the indexed column form such as `BPCNAM_0`). They bypass the class layer and standard
logic (rules, entry points, controls); database errors are raised as runtime errors (trap with
`Onerrgo`). Never concatenate user input into them — `security-permissions.md`.

## Locks and transaction granularity

- `Read` to display or validate; `Readlock` only right before a `Rewrite` inside a transaction. `Readlock … With
  lockwait = N` bounds the wait (seconds); the default comes from `[S]lockwait`.
- `For … With Lock` is discouraged by Sage: Oracle locks the whole selection at once, SQL Server row by row.
- Symbol locks (`Lock`, table APLLCK) serialise users and create contention; V7-style code uses optimistic
  `RewriteByKey` with UPDTICK — `database.md`.
- Keep `Trbegin … Commit` free of user dialogs, HTTP calls, file waits and `Sleep`.
- A long batch should commit in small units, never one transaction around everything:

```l4g
##############################################################
# YBLOCK_NEG - one short transaction per account (Y_BLOCKED: specific flag)
##############################################################
Subprog YBLOCK_NEG
Local File YACCOUNT [YACC]
Local Char YCODES(20)(1..)
Local Integer I, N
Local Shortint TRANS_OPEN
  [L]TRANS_OPEN = adxlog
  If [L]TRANS_OPEN <> 0 : End : Endif : # cannot chunk inside the caller's transaction
  Columns [YACC](Y_ACCNUM)
  For [YACC] Where Y_BALANCE < 0
    N += 1
    YCODES(N) = [F:YACC]Y_ACCNUM
  Next
  Columns [YACC]
  For I = 1 To N
    Trbegin [YACC]
    Update [YACC] Where Y_ACCNUM = YCODES(I) and Y_BALANCE < 0 With Y_BLOCKED = 1
    If fstat = 0
      Commit
    Elsif adxlog = 1
      Rollback : # fstat 1/3 on Update: the engine already rolled back
    Endif
  Next I
End
```

## Hints

`For [ABV]KEY Hint Key OTHERKEY …` suggests an index to the database; `With Nohint` (the default) lets it decide.
Sage reserves hints for exceptional cases: the effect differs between Oracle and SQL Server, it freezes a strategy
the optimizer would adapt from statistics, and a database upgrade can make it harmful. Document any hint you keep.

## Anti-patterns

| Anti-pattern | Fix |
|---|---|
| `For [ABV]` then `If` on columns in L4G | Put the condition in `Where` |
| `pat(COL, "x*")` without `<> 0` | `pat(COL, "x*") <> 0` (becomes `LIKE`) |
| Date arithmetic on columns in `Where` | Pre-compute the bound outside the column expression |
| `COL = 1 or COL = 2 or COL = 3` | Range, else `find(COL, 1, 2, 3) <> 0` |
| `Read` of a parent row inside a `For` | `Link` + `Columns` |
| Loops over wide tables loading every column | `Columns` |
| `Readlock` on a read-only path | `Read` |
| `For … With Lock` / Readlock-Rewrite loop for a uniform change | `Update … Where … With` |
| One transaction around a whole batch | Short transactions per unit (above) |
| Frequent sort on a non-indexed order | Key in GESATB matching the order |
| New code relying on symbol `Lock` | Optimistic `RewriteByKey` |
| Hints added "just in case" | Remove; measure |
| Parameter or setup reads inside a hot loop | Read once before the loop |

## Gotchas

- `For (…) From … Sql` and `Execsql` are database-specific SQL: test on the database type of every target folder.
- `Columns` is managed per `Local File` nesting level: a sub-program that re-declares the table with its own
  `Columns` does not change the caller's list. Reset explicitly with `Columns [ABV]` when you are done.
- A `Filter` set inside a called sub-program on a table it did not re-declare stays active for the caller.
- Timings in development folders with small data prove nothing; measure on a copy of production volumes.

See also: `database.md`, `debugging-traces.md`, `diagnostics-postmortem.md`, `batch-scheduling.md`,
`code-review-checklist.md`.

## Sources
- https://online-help.sagex3.com/erp/12/en-us/Content/V7DEV/developer-guide_profiling-code.html
- https://online-help.sagex3.com/erp/12/en-us/Content/V7DEV/4gl_timestamp$.html , …/4gl_time.html
- https://online-help.sagex3.com/erp/12/en-us/Content/V7DEV/4gl_for.html
- https://online-help.sagex3.com/erp/12/en-us/Content/V7DEV/4gl_where.html
- https://online-help.sagex3.com/erp/12/en-us/Content/V7DEV/4gl_func.html (no `func` in a Where)
- https://online-help.sagex3.com/erp/12/en-us/Content/V7DEV/4gl_filter.html
- https://online-help.sagex3.com/erp/12/en-us/Content/V7DEV/4gl_columns.html
- https://online-help.sagex3.com/erp/12/en-us/Content/V7DEV/4gl_link.html
- https://online-help.sagex3.com/erp/12/en-us/Content/V7DEV/4gl_hint.html
- https://online-help.sagex3.com/erp/12/en-us/Content/V7DEV/4gl_readlock.html , …/4gl_lock.html
- https://online-help.sagex3.com/erp/12/en-us/Content/V7DEV/4gl_sql.html , …/4gl_execsql.html , …/4gl_adxsqlrec.html
- https://online-help.sagex3.com/erp/12/en-us/Content/V7DEV/4gl_adxuprec.html , …/4gl_delete.html , …/4gl_adxdlrec.html
- https://communityhub.sage.com/sage-global-solutions/sage_x3/b/sage-x3-support-insights-ame/posts/sage-x3-performance-blueprint-optimization-troubleshooting (community)

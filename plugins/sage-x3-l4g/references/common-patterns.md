# Common L4G patterns — Classic and core recipes

Short, complete recipes that combine several mechanisms (transactions, staging tables, files), plus an
index of the recipes that live next to their mechanism; full versions are in the example scripts. Custom tables used:
`YACCOUNT [YACC]` (`database.md`), the staging table `YTRFSTG [YTS]` (index `YTS0` on `Y_STGID`;
`Y_FROMACC`, `Y_TOACC`, `Y_AMOUNT`, `Y_STA` 1 pending / 2 posted / 3 rejected, `Y_PRCDAT`) and
`YCUSTEXT [YCU]`. V7+/V12 recipes (classes, REST, mail, ALOG) are in `common-patterns-v12.md`.

## Contents
- [Compose transactional routines](#compose-transactional-routines)
- [Per-row transactions over a staging table](#per-row-transactions-over-a-staging-table)
- [Load a CSV file into a staging table](#load-a-csv-file-into-a-staging-table)
- [Where the other recipes live](#where-the-other-recipes-live)
- [Gotchas](#gotchas)
- [Sources](#sources)

## Compose transactional routines

`YTRANSFER` (`database.md`, `examples/YACCLIB.src`) opens its own transaction only when `adxlog` is 0.
A caller that needs two transfers to succeed or fail together owns the transaction with the same idiom:

```l4g
Funprog YSPLIT_PAY(FROM_ACC, TO_A, TO_B, AMT_A, AMT_B)
Value Char    FROM_ACC(), TO_A(), TO_B()
Value Decimal AMT_A, AMT_B
Local Shortint TRANS_OPEN
Local Integer  STA
  Local File YACCOUNT [YACC]                  : # declared before Trbegin
  [L]TRANS_OPEN = adxlog
  If [L]TRANS_OPEN = 0 : Trbegin [YACC] : Endif
  [L]STA = func YACCLIB.YTRANSFER([L]FROM_ACC, [L]TO_A, [L]AMT_A)
  If [L]STA = [V]CST_AOK
    [L]STA = func YACCLIB.YTRANSFER([L]FROM_ACC, [L]TO_B, [L]AMT_B)
  Endif
  If [L]STA <> [V]CST_AOK
    # adxlog = 1 guard: a failed Update inside YTRANSFER may have rolled back already
    If [L]TRANS_OPEN = 0 and adxlog = 1 : Rollback : Endif
    End [V]CST_AERROR
  Endif
  If [L]TRANS_OPEN = 0 : Commit : Endif
End [V]CST_AOK
```

The inner routine returns a status and never commits; only the level that ran `Trbegin` commits or
rolls back. `unit-testing-axunit.md` tests exactly this path (`YTC_CALLER_TRANSACTION`).

## Per-row transactions over a staging table

One short transaction per row: claim the row, post it, commit. A business refusal is rolled back, then
recorded in a second transaction; an infrastructure error (lock, duplicate key, unexpected row state)
stops the run with `Break`, so the row stays pending for the next run. Telling the two apart relies on
`adxlog` after an engine rollback, and committing inside a `For` loop, both undocumented
(`version-caveats.md`). Full version with ALOG log and batch entry: `examples/YTRFPOST.src`.

```l4g
Subprog YTRF_POST_MIN(NBOK, NBKO)
Variable Integer NBOK, NBKO
Local File YTRFSTG [YTS]                      : # read cursor
Local File YTRFSTG [YTU]                      : # second abbreviation for the updates
Local Integer STGID, STA, FATAL
  [L]NBOK = 0 : [L]NBKO = 0
  If adxlog <> 0 : End : Endif                : # cannot commit per row inside a caller transaction
  For [YTS]YTS0 Where Y_STA = 1
    [L]STGID = [F:YTS]Y_STGID
    [L]STA = [V]CST_AERROR
    Trbegin [YTU]
    Update [YTU] Where Y_STGID = [L]STGID and Y_STA = 1 With Y_STA = 2, Y_PRCDAT = date$
    If fstat or adxuprec <> 1
      [L]FATAL = 1
    Else
      [L]STA = func YACCLIB.YTRANSFER([F:YTS]Y_FROMACC, [F:YTS]Y_TOACC, [F:YTS]Y_AMOUNT)
    Endif
    If [L]STA = [V]CST_AOK
      Commit
      [L]NBOK += 1
    Else
      # Business refusal leaves our transaction open (adxlog = 1); a lock or duplicate
      # inside YTRANSFER means the engine already rolled back: stop the run
      If adxlog = 1 : Rollback : Else : [L]FATAL = 1 : Endif
      If [L]FATAL = 0
        Trbegin [YTU]
        Update [YTU] Where Y_STGID = [L]STGID and Y_STA = 1 With Y_STA = 3, Y_PRCDAT = date$
        If fstat or adxuprec <> 1
          [L]FATAL = 1
          If adxlog = 1 : Rollback : Endif
        Else
          Commit
          [L]NBKO += 1
        Endif
      Endif
    Endif
    Break [L]FATAL
  Next
End
```

The `Y_STA = 1` condition in every `Update` makes a rerun harmless. Restart safety and the batch
template: `batch-scheduling.md`; set-based alternatives and lock limits: `performance.md`.

## Load a CSV file into a staging table

```l4g
# "from;to;amount" lines, CRLF, UTF8, one header line; returns the rows loaded or -1
Funprog YTRF_LOAD(FILE_PATH)
Value Char FILE_PATH()
Local File YTRFSTG [YTS]
Local Char    FROMACC(20), TOACC(20), AMOUNT_TXT(30)
Local Integer NB, EOF
  If adxlog <> 0 or filinfo([L]FILE_PATH, 0) < 0 : End -1 : Endif
  Openi [L]FILE_PATH Using [YIN]
  Iomode adxium 0 Using [YIN]                 : # UTF8
  Iomode adxifs ";" Using [YIN]
  Iomode adxirs chr$(13) + chr$(10) Using [YIN] : # CRLF
  Rdseq [L]FROMACC Using [YIN]                : # header line
  Repeat
    Rdseq [L]FROMACC, [L]TOACC, [L]AMOUNT_TXT Using [YIN]
    [L]EOF = fstat                            : # saved: the writes below overwrite fstat
    If [L]EOF = 0 or [L]FROMACC <> ""
      Trbegin [YTS]
      Raz [F:YTS]
      [F:YTS]Y_STGID   = uniqid([YTS])
      [F:YTS]Y_FROMACC = [L]FROMACC
      [F:YTS]Y_TOACC   = [L]TOACC
      [F:YTS]Y_AMOUNT  = val(ctrans([L]AMOUNT_TXT, ",", "."))
      [F:YTS]Y_STA     = 1
      Write [YTS]
      If fstat
        If adxlog = 1 : Rollback : Endif
      Else
        Commit
        [L]NB += 1
      Endif
    Endif
  Until [L]EOF <> 0
  Openi Using [YIN]                           : # close the channel
End [L]NB
```

The last line may lack a final separator (fstat 1 with data), hence the `FROMACC <> ""` test; details in
`sequential-files.md`. For object data, an import template runs the object's controls (`imports-exports.md`).

## Where the other recipes live

Recipes whose mechanism has its own reference are kept there, next to the explanation, rather than
copied here:

| Recipe | Where |
|---|---|
| Refuse a Classic object record (`OK = 0` before the transaction, `GOK = 0` inside it) | `classic-objects.md`, `examples/SPEYCU.src` |
| Hook a standard process with an entry point (GESAPE, `GPOINT`, `GOK`) | `entry-points.md`, `examples/YSUBITM.src` |
| Trap runtime errors with `Onerrgo` / `Resume` | `language-basics.md` (Error trapping with Onerrgo) |
| Classic log file (`OUVRE_TRACE`, `ECR_TRACE`, `FERME_TRACE`) | `debugging-traces.md` (Classic trace sub-programs) |
| Call a subprogram or function in another script; `Value` / `Variable` / `Const` | `language-basics.md` (Subprograms, functions and Gosub) |
| Raw SQL with `For … Sql` and `Execsql` | `database.md` (Raw SQL) |
| Read a general parameter or a miscellaneous table | `data-dictionary.md` |
| Single-instance batch guard with `Lock` / `Unlock` | `batch-scheduling.md` |
| Class rules and events, REST calls, e-mail, ALOG log | `common-patterns-v12.md` |

## Gotchas

- Save `fstat` in a local right after the instruction you test: the next database or file
  instruction (even inside a called routine) overwrites it.
- A routine that commits per row must refuse to run inside a caller's transaction (`adxlog <> 0`):
  `Trbegin` would raise error 49.
- Never `Trbegin`/`Commit`/`Rollback` in object actions, in entry points that run in a
  transaction, or in class events: the caller owns the transaction.
- Labels reached by `Gosub` (object actions, entry points, batch actions) share the caller's locals:
  put `Local` declarations in a `Subprog` / `Funprog` you call.
- Opening a table with `Local File` while a transaction is open is allowed, but Sage's wording on
  tables "opened in write mode by Trbegin" is ambiguous: see `version-caveats.md`.

See also: `common-patterns-v12.md`, `database.md`, `sequential-files.md`, `batch-scheduling.md`,
`code-review-checklist.md`.

## Sources
- https://online-help.sagex3.com/erp/12/en-us/Content/V7DEV/4gl_adxlog.html
- https://online-help.sagex3.com/erp/12/en-us/Content/V7DEV/4gl_trbegin.html
- https://online-help.sagex3.com/erp/12/en-us/Content/V7DEV/4gl_file.html
- https://online-help.sagex3.com/erp/12/en-us/Content/V7DEV/4gl_update.html
- https://online-help.sagex3.com/erp/12/en-us/Content/V7DEV/4gl_uniqid.html
- https://online-help.sagex3.com/erp/12/en-us/Content/V7DEV/4gl_rdseq.html
- https://online-help.sagex3.com/erp/12/en-us/Content/V7DEV/4gl_for.html

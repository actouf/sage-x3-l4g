# Common L4G patterns — Classic and core recipes

Short, complete recipes for tasks that come up in every X3 project; each links to the file that
explains the mechanism, and the full versions live in the example scripts. Custom tables used:
`YACCOUNT [YAC]` (`database.md`), the staging table `YTRFSTG [YTS]` (index `YTS0` on `Y_STGID`;
`Y_FROMACC`, `Y_TOACC`, `Y_AMOUNT`, `Y_STA` 1 pending / 2 posted / 3 rejected, `Y_PRCDAT`) and
`YCUSTEXT [YCU]`. V7+/V12 recipes (classes, REST, mail, ALOG) are in `common-patterns-v12.md`.

## Contents
- [Compose transactional routines](#compose-transactional-routines)
- [Per-row transactions over a staging table](#per-row-transactions-over-a-staging-table)
- [Load a CSV file into a staging table](#load-a-csv-file-into-a-staging-table)
- [Refuse a Classic object record](#refuse-a-classic-object-record)
- [Hook a standard process with an entry point](#hook-a-standard-process-with-an-entry-point)
- [Trap runtime errors](#trap-runtime-errors)
- [Classic log file](#classic-log-file)
- [Call a subprogram or function in another script](#call-a-subprogram-or-function-in-another-script)
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
`adxlog` after an engine rollback, which is undocumented (`version-caveats.md`). Full version with ALOG log and batch entry: `examples/YTRFPOST.src`.

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

## Refuse a Classic object record

In the object's specific script `SPE<OBJ>`, actions that run **before** the transaction refuse with
`OK = 0`; actions **inside** it abort with `GOK = 0` (`classic-objects.md`). From `examples/SPEYCU.src`:

```l4g
$ACTION
  Case ACTION
    When "VERIF_CRE" : Gosub Y_VERIF
    When "VERIF_MOD" : Gosub Y_VERIF
  Endcase
Return

$Y_VERIF
  # Before Trbegin: test the entered values in the screen class
  If vireblc([M:YCU0]YVATNUM, 4) = ""
    GMESSAGE = mess(11, 160, 1)
    OK = 0
  Elsif [M:YCU0]BPCNUM <> "" and func SPEYCU.Y_CUSTOMER_EXISTS([M:YCU0]BPCNUM) = 0
    GMESSAGE = mess(12, 160, 1)
    OK = 0
  Endif
Return
```

Unknown actions fall through; the checks that need tables run in a `Funprog` with its own
`Local File`, because actions share the locals of the object process.

## Hook a standard process with an entry point

Declare the line in GESAPE (standard script, your script, X/Y/Z activity code), then dispatch on
`ACTION` (`entry-points.md`). From `examples/YSUBITM.src`, entry point `BEFWRIITF` of `SUBITM`,
documented as running inside a transaction with `GOK = 0` to abandon it:

```l4g
$ACTION
  Case ACTION
    When "BEFWRIITF" : Gosub Y_BEFWRIITF
  Endcase
Return

$Y_BEFWRIITF
  If func YSUBITM.Y_LOG_ITF([F:ITM]ITMREF, GUSER) <> [V]CST_AOK
    GOK = 0
  Endif
Return
```

Read the entry point's help page (`OBJ/ADC_<SCRIPT>.htm`) for its transaction state, variables and
open tables before writing; `GPE` means something different at each entry point.

## Trap runtime errors

Runtime errors (SQL errors, missing files, unknown keys) are not `fstat` values: they stop the script
unless `Onerrgo` is armed (`language-basics.md`, `debugging-traces.md`).

```l4g
Funprog YCOUNT_NEG(ERRMSG)
Variable Char ERRMSG()
Local Integer DBTYPE, NB, ERR_NUM
Local Char    DBCODE(1)
  [L]ERRMSG = "" : [L]NB = -1
  [L]DBTYPE = fmet GACTX.APARAM.AGETVALNUM([V]CST_ALEVFOLD, "", "TYPDBA")
  [L]DBCODE = string$([L]DBTYPE = 1, "O") + string$([L]DBTYPE = 2, "S")
  Onerrgo YCOUNT_ERR
  For (Integer CNT) From [L]DBCODE Sql "select count(*) from YACCOUNT where Y_BALANCE_0 < 0" As [YSQL]
    [L]NB = [F:YSQL]CNT
  Next
  Onerrgo                                     : # disarm before returning
  If [L]ERR_NUM <> 0 : End -1 : Endif
End [L]NB

$YCOUNT_ERR
  [L]ERR_NUM = errn
  [L]ERRMSG = errmes$(errn) - "line" - num$(errl) - "script" - errp - errm
  Resume                                      : # an error inside the For block resumes after Next
```

Handlers are not inherited: an error in a called routine without its own handler surfaces in the
caller's handler, on the `Call` line. Raw SQL: `database.md`.

## Classic log file

The V6 trace sub-programs still run in V12 (`debugging-traces.md`; call forms community-reported).
New V7+ code uses the `ALOG` class instead (`common-patterns-v12.md`).

```l4g
Subprog YLIST_NEG
Local File YACCOUNT [YACC]
Local Integer NB
  Call OUVRE_TRACE("YLIST_NEG - soldes négatifs") From LECFIC  : # before any ECR_TRACE
  For [YACC] Where Y_BALANCE < 0
    [L]NB += 1
    Call ECR_TRACE("Compte" - [F:YACC]Y_ACCNUM - ":" - num$([F:YACC]Y_BALANCE), 1) From GESECRAN
  Next
  Call ECR_TRACE(num$([L]NB) - "compte(s) en erreur", 0) From GESECRAN
  Call FERME_TRACE From LECFIC                 : # also on every error path
End
```

Flag 1 marks an error line, 0 a normal one. Read the file with LECTRACE; never `LEC_TRACE` in batch.
Sage's silent-import sample closes with `CLOSE_LOC From LECFIC` instead (`imports-exports.md`).

## Call a subprogram or function in another script

```l4g
# Script YBPCLIB
Subprog YGET_CUSTOMER(CUSTNUM, CUSTNAME, FOUND)
Value    Char     CUSTNUM()
Variable Char     CUSTNAME()
Variable Shortint FOUND
Local File BPCUSTOMER [BPC]
  [L]CUSTNAME = ""
  Read [BPC]BPC0 = [L]CUSTNUM
  [L]FOUND = (fstat = 0)
  If [L]FOUND : [L]CUSTNAME = [F:BPC]BPCNAM : Endif
End

Funprog YCUSTOMER_LABEL(CUSTNUM)
Value Char CUSTNUM()
Local Char     NAME(80)
Local Shortint FOUND
  Call YGET_CUSTOMER([L]CUSTNUM, [L]NAME, [L]FOUND) From YBPCLIB
End string$([L]FOUND, [L]CUSTNUM - "-" - [L]NAME)

# Any other script
Local Char     YNAME(80), YLABEL(100)
Local Shortint YFOUND
  Call YGET_CUSTOMER("C0001", YNAME, YFOUND) From YBPCLIB  : # constant only for the Value parameter
  YLABEL = func YBPCLIB.YCUSTOMER_LABEL("C0001")
```

`Value` copies (constants allowed), `Variable` writes back (a variable is required), `Const` is a
read-only reference. `Call` / `func` start a new `[L]` scope; `Gosub` shares it (`language-basics.md`).

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

See also: `common-patterns-v12.md`, `database.md`, `entry-points.md`, `code-review-checklist.md`.

## Sources
- https://online-help.sagex3.com/erp/12/en-us/Content/V7DEV/4gl_adxlog.html
- https://online-help.sagex3.com/erp/12/en-us/Content/V7DEV/4gl_trbegin.html
- https://online-help.sagex3.com/erp/12/en-us/Content/V7DEV/4gl_file.html
- https://online-help.sagex3.com/erp/12/en-us/Content/V7DEV/4gl_update.html
- https://online-help.sagex3.com/erp/12/en-us/Content/V7DEV/4gl_uniqid.html
- https://online-help.sagex3.com/erp/12/en-us/Content/V7DEV/4gl_onerrgo.html
- https://online-help.sagex3.com/erp/12/en-us/Content/MODEL/VERIF_CRE.htm
- https://online-help.sagex3.com/erp/12/en-us/Content/OBJ/ADC_SUBITM.htm
- https://online-help.sagex3.com/erp/12/en-us/Content/FCT/GES_AOE1.htm (CLOSE_LOC)

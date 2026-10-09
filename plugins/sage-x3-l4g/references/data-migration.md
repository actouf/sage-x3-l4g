# Data migration

A repeatable playbook for loading legacy data into Sage X3 V12: staging tables, validation with a
status per row, an idempotent loader that commits row by row, reconciliation queries, and a cutover
checklist. Read this before any initial load, mass correction or system switch. File formats and
templates are in `imports-exports.md`; transaction rules in `database.md`; scheduling in
`batch-scheduling.md`.

## Contents
- [The five-phase playbook](#the-five-phase-playbook)
- [Staging tables](#staging-tables)
- [Phase 1 - extract and stage](#phase-1---extract-and-stage)
- [Phase 2 - validate](#phase-2---validate)
- [Phase 3 - load](#phase-3---load)
- [Phase 4 - reconcile](#phase-4---reconcile)
- [Phase 5 - cutover](#phase-5---cutover)
- [Moving setup between folders](#moving-setup-between-folders)
- [Gotchas](#gotchas)
- [Sources](#sources)

## The five-phase playbook

| Phase | Goal | X3 tools | Exit criterion |
|---|---|---|---|
| 1. Extract and stage | Source rows copied as-is into Y staging tables | Import template without object, or a parser | Staged count = source count |
| 2. Validate | Every row marked valid or rejected with a reason | L4G over staging | No unexplained reject |
| 3. Load | Valid rows written to X3, safely re-runnable | Object import templates, or per-row writes for Y tables | Every valid row loaded or flagged |
| 4. Reconcile | Counts and amounts agree | `For` loops, `For (...) Sql` | Signed off by the business |
| 5. Cutover | Switch with a frozen source and a known rollback | Checklist below | Go / no-go decision |

Run the whole chain on a copy of production at least twice; time it, because the timing decides the
cutover window.

## Staging tables

One custom table per target entity (Tables dictionary GESATB, Y code, protected by your activity
code). Keep source values as text so nothing is lost before validation.

| Column | Type | Purpose |
|---|---|---|
| BATCH_ID | Char(20) | One value per extract run, never reused |
| LINENO | Integer | Line number in the source |
| Source columns | Char | Raw values (`CODE`, `DES`, `AMOUNT`, `BPCNUM` in the examples) |
| STAT | Shortint | 0 new, 1 valid, 2 loaded, 8 rejected, 9 load error (house convention) |
| MSG | Char(250) | Last reason |

Examples below use `YSTGREF [YSR]` (index `YSR0` = BATCH_ID + LINENO, unique) feeding the custom
table `YREFDATA [YRD]` (index `YRD0` = CODE). Only STAT and MSG are ever updated in staging.

## Phase 1 - extract and stage

- Flat files: an import template with an **empty Object** on the staging table runs only data-type
  checks — ideal for raw staging. Put BATCH_ID and LINENO in the extract file. Run it with
  `IMPORTSIL` or the IMPORT batch task (`imports-exports.md`).
- Formats a template cannot describe: parse with the sequential-file API (`sequential-files.md`) and
  `Write` into staging, one short transaction per row or per chunk.
- Ask the source owner for control totals (row count, amount totals) with every extract.

## Phase 2 - validate

```l4g
# Validate batch YBATCH: STAT 0 -> 1 (valid) or 8 (rejected, reason in MSG). Returns rejects.
Funprog YMIG_VALIDATE(YBATCH)
Value Char YBATCH()
Local File YSTGREF [YSR]
Local File YSTGREF [YSU]                      : # second cursor: never update through the loop's one
Local File BPCUSTOMER [BPC]
Local Shortint YSTA, TRANS_OPEN
Local Char     YMSG(250)
Local Integer  YREJ
  For [YSR]YSR0 Where BATCH_ID = [L]YBATCH and STAT = 0
    [L]YSTA = 1 : [L]YMSG = ""
    If [F:YSR]CODE = ""
      [L]YSTA = 8 : [L]YMSG = "Code missing"       : # literal for brevity — use mess() in real code
    Else
      Read [BPC]BPC0 = [F:YSR]BPCNUM
      If fstat
        [L]YSTA = 8 : [L]YMSG = "Unknown customer " + [F:YSR]BPCNUM : # literal for brevity — use mess() in real code
      Endif
    Endif
    If [L]YSTA = 8 : [L]YREJ += 1 : Endif
    [L]TRANS_OPEN = adxlog
    If [L]TRANS_OPEN = 0 : Trbegin [YSU] : Endif
    Update [YSU] Where BATCH_ID = [L]YBATCH and LINENO = [F:YSR]LINENO With STAT = [L]YSTA, MSG = [L]YMSG
    If fstat or adxuprec <> 1
      # Update fstat 1/3 already rolled back: Rollback without a transaction is error 48
      If [L]TRANS_OPEN = 0 and adxlog = 1 : Rollback : Endif
    Else
      If [L]TRANS_OPEN = 0 : Commit : Endif
    Endif
  Next
End [L]YREJ
```

Typical checks: mandatory values, references that must exist in X3 (read them, as above), code
lengths against the target dictionary, duplicates inside the batch, local menu values (the import
template expects ranks or labels depending on its Local menu format).

## Phase 3 - load

| Target | Route |
|---|---|
| Standard object (customers, products, orders…) | Its import template: Sage supplies an editable standard template for each importable object in the reference folder. The import emulates entry, so the object's controls and side effects run. Generate the file from rows with STAT = 1, import, then mark rows loaded by reading the created records |
| Custom Y table | Per-row `Write`, staging status updated in the **same** transaction (below) |

Never write standard tables directly: you would bypass the object's controls and its related
tables. For V12 classes, see `v12-classes.md`.

```l4g
# Load valid rows (STAT 1) of batch YBATCH into YREFDATA; call outside any transaction; re-runnable
Funprog YMIG_LOAD(YBATCH)
Value Char YBATCH()
Local File YSTGREF [YSR]
Local File YSTGREF [YSU]
Local File YREFDATA [YRD]
Local Shortint TRANS_OPEN, YERR
Local Integer  YKO
  For [YSR]YSR0 Where BATCH_ID = [L]YBATCH and STAT = 1
    [L]YERR = 0
    [L]TRANS_OPEN = adxlog
    If [L]TRANS_OPEN = 0 : Trbegin [YRD], [YSU] : Endif
    Read [YRD]YRD0 = [F:YSR]CODE
    # Not there yet (a rerun finds it and skips the write)
    If fstat
      Raz [F:YRD]
      [F:YRD]CODE   = [F:YSR]CODE
      [F:YRD]DES    = [F:YSR]DES
      [F:YRD]AMOUNT = val([F:YSR]AMOUNT)
      [F:YRD]BPCNUM = [F:YSR]BPCNUM
      Write [YRD]
      If fstat : [L]YERR = 1 : Endif
    Endif
    If [L]YERR = 0
      Update [YSU] Where BATCH_ID = [L]YBATCH and LINENO = [F:YSR]LINENO With STAT = 2, MSG = ""
      If fstat or adxuprec <> 1 : [L]YERR = 1 : Endif
    Endif
    If [L]YERR = 0
      If [L]TRANS_OPEN = 0 : Commit : Endif
    Else
      [L]YKO += 1
      If [L]TRANS_OPEN = 0
        If adxlog = 1 : Rollback : Endif      : # a failed Update may already have rolled back
        Trbegin [YSU]                         : # record the failure in its own transaction
        # "Load failed": literal for brevity — use mess() in real code
        Update [YSU] Where BATCH_ID = [L]YBATCH and LINENO = [F:YSR]LINENO
        & With STAT = 9, MSG = "Load failed"
        If fstat or adxuprec <> 1
          If adxlog = 1 : Rollback : Endif
        Else
          Commit
        Endif
      Endif
    Endif
  Next
End [L]YKO
```

Why it is safe to rerun: loaded rows have STAT = 2 and are no longer selected; the target write and
the STAT update share one transaction, so a crash leaves both or neither; a target row that already
exists (created by hand, say) is marked loaded without being rewritten. Run large loads as a batch
task (`batch-scheduling.md`) so they do not depend on a user session.

## Phase 4 - reconcile

Three-way check: source control totals = staged rows = loaded + rejected + load errors; amounts
likewise. A `For` loop is enough for staging:

```l4g
Local File YSTGREF [YSR]
Local Integer YNB
Local Decimal YTOT
  For [YSR]YSR0 Where BATCH_ID = [L]YBATCH and STAT = 2
    [L]YNB += 1 : [L]YTOT += val([F:YSR]AMOUNT)
  Next
```

On large volumes let the database aggregate with the `Sql` form of `For` (columns carry the `_0`
suffix in SQL; `Execsql` only runs DDL/DML and reports affected rows in `adxsqlrec`):

```l4g
Local Integer YDBTYPE
Local Char    YDB(1), YREQ(250)(1..3)
  [L]YDBTYPE = fmet GACTX.APARAM.AGETVALNUM([V]CST_ALEVFOLD, "", "TYPDBA")
  [L]YDB = string$([L]YDBTYPE = 1, "O") + string$([L]YDBTYPE = 2, "S")
  [L]YREQ(1) = "select count(*), coalesce(sum(R.AMOUNT_0), 0) from YREFDATA R"
  [L]YREQ(2) = " join YSTGREF S on S.CODE_0 = R.CODE_0"
  [L]YREQ(3) = " where S.BATCH_ID_0 = '" + [L]YBATCH + "' and S.STAT_0 = 2"
  # The caller has opened the trace (OUVRE_TRACE From LECFIC, see debugging-traces.md)
  For (Integer NB, Decimal TOT) From [L]YDB Sql [L]YREQ(1..3) As [YRC]
    Call ECR_TRACE("Loaded rows " + num$([F:YRC]NB) + ", total " + num$([F:YRC]TOT), 0) From GESECRAN
  Next
```

Never concatenate values coming from outside into SQL text; here YBATCH is generated internally.
`ECR_TRACE` is community-reported (`debugging-traces.md`).

## Phase 5 - cutover

- [ ] Rehearsal timings known; window and go / no-go criteria agreed; rollback plan written.
- [ ] Backup taken before the first load (and after sign-off).
- [ ] Source frozen; final delta extracted with its control totals.
- [ ] Recurring tasks that touch the migrated data deactivated (GESABA Active box) or the batch
      controller stopped (Stop waits for running requests).
- [ ] Workflow mails silenced: the template's Workflow box (ENAWRK) cleared, or rules deactivated.
- [ ] Sequence number counters checked against migrated keys.
- [ ] Load, reconcile, business sign-off recorded.
- [ ] Tasks and rules reactivated, users reopened, staging purged after the retention period
      (`audit-compliance.md`).

## Moving setup between folders

Several dictionary/setup functions have a **Copy** button that copies a record to another folder or
to all folders: import/export templates (GESAOE), workflow rules (GESAWA — press Validation in the
target folder), reports (GESARP), destinations (GESAIM). Development objects travel as patches
(`personalisation-activity.md`). No supported folder merge/consolidation procedure is documented
here.

## Gotchas
- Imports fire workflow rules per record unless ENAWRK is cleared — mass mail on day one.
- Fields that cannot be entered on the object's screens are not imported by a template.
- Two-digit years pivot on the DCS parameter; decimal separator and date format are per template.
- Dry run for free: import a file into the temporary storage space (GESAOW) only — format checks,
  no real import; rejects of a real run land there too when AOWSTA is checked.
- One transaction over a whole table can fail with error 43 (too many locks): commit per row/chunk.
- Declare `Local File` once before the loop, never inside it.
- Update the iterated table through a second abbreviation (`[YSU]` above).
- A rerun must never duplicate: test the target key and the staging STAT before writing.
- In batch there is no user: no `Errbox`/`Infbox`; write a log.

See also: `imports-exports.md`, `database.md`, `batch-scheduling.md`, `sequential-files.md`,
`audit-compliance.md`, `performance.md`.

## Sources
- https://online-help.sagex3.com/erp/12/en-us/Content/FCT/GESAOE.htm
- https://online-help.sagex3.com/erp/12/en-us/Content/FCT/GESAOW.htm
- https://online-help.sagex3.com/erp/12/en-us/Content/FCT/GES_AOE1.htm
- https://online-help.sagex3.com/erp/12/en-us/Content/FCT/GESATB.htm
- https://online-help.sagex3.com/erp/12/en-us/Content/FCT/GESABA.htm
- https://online-help.sagex3.com/erp/12/en-us/Content/FCT/GESAWA.htm
- https://online-help.sagex3.com/erp/12/en-us/Content/FCT/GESARP.htm
- https://online-help.sagex3.com/erp/12/en-us/Content/FCT/GESAIM.htm
- https://online-help.sagex3.com/erp/12/en-us/Content/V7DEV/4gl_sql.html
- https://online-help.sagex3.com/erp/12/en-us/Content/V7DEV/4gl_execsql.html
- https://online-help.sagex3.com/erp/12/en-us/Content/V7DEV/4gl_adxsqlrec.html
- https://online-help.sagex3.com/erp/12/en-us/Content/V7DEV/4gl_update.html
- https://online-help.sagex3.com/erp/12/en-us/Content/V7DEV/4gl_rollback.html
- https://online-help.sagex3.com/erp/12/en-us/Content/V7DEV/4gl_write.html
- https://online-help.sagex3.com/erp/12/en-us/Content/V7DEV/4gl_trbegin.html
- https://online-help.sagex3.com/erp/12/en-us/Content/V7DEV/4gl_raz.html
- https://online-help.sagex3.com/erp/12/en-us/Content/V7DEV/administration-reference_batch-server.html

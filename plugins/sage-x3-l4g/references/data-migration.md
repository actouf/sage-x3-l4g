# Data migration

Bulk historical loads, schema migrations, dual-write during cutover, validation passes. The "going live" surfaces that day-to-day imports (`imports-exports.md`) don't cover. Companion to `imports-exports.md` (per-row IMP/EXP templates) and `personalisation-activity.md` (how the schema you're migrating *to* is delivered).

For ongoing, recurring imports of business data (CSV from a partner, EDI feeds), use IMP/EXP templates. This file is for one-shot or short-window migrations: legacy ERP → X3, bulk consolidation, schema-changing patches.

## Migration shapes

| Shape | Typical scenario |
|-------|------------------|
| **Big-bang load** | Replacing legacy ERP. One night downtime, all data moves. |
| **Phased load** | Domain-by-domain (customers, then items, then orders). Multiple cutover windows. |
| **Dual-write** | Both systems live, X3 catches up while legacy still writes. |
| **Schema migration in place** | Custom field added to a standard table; backfill default values. |
| **Folder consolidation** | Multiple folders merged into one. Same schema, different keys. |

Pick the shape before designing the script. Big-bang is simplest; dual-write is the most expensive and the only one that survives a 1000-user cutover.

## The five-phase migration playbook

Every non-trivial migration goes through these phases. Skipping one bites in production.

### Phase 1 — extract

Pull source data into a neutral format. Don't extract directly into X3 tables; stage first.

```
legacy DB ─► extract.csv ─► staging tables in X3 (Y* prefixed) ─► standard tables
```

Staging tables (`YSTAGING_BPC`, `YSTAGING_ITM`) have the same shape as the target plus:

| Field | Use |
|-------|-----|
| `STAT` | `0` = pending, `1` = OK, `2` = warning, `3` = error |
| `MSG` | Last validation / load message |
| `LOAD_DAT` | When the row was extracted |
| `BATCH_ID` | Migration run identifier (so you can re-run) |

The staging buffer lets you validate, fix, and reload without re-extracting from the legacy system every time.

### Phase 2 — validate

Run validation passes against the staging table — never against production target. Validation rules:

```l4g
##############################################################
# YMIG_VALIDATE_BPC — validate staged customer rows
##############################################################
$MAIN
Local File YSTAGING_BPC [YBP]
Local Integer N_OK, N_KO

For [YBP] Where STAT = 0
    # Required fields
    If [F:YBP]BPCNAM = ""
        [F:YBP]STAT = 3
        [F:YBP]MSG  = "Empty BPCNAM"
        Rewrite [YBP]
        Incr N_KO
        Continue
    Endif

    # Format checks
    If [F:YBP]CRY = "FR" And [F:YBP]BPCCRN <> "" And not pat([F:YBP]BPCCRN, "#########")
        [F:YBP]STAT = 3
        [F:YBP]MSG  = "SIREN format invalid"
        Rewrite [YBP]
        Incr N_KO
        Continue
    Endif

    # Reference checks (currency, country, etc. exist in target)
    Local File TABCUR [TCU]
    Read [TCU]CUR0 = [F:YBP]CUR
    If fstat
        [F:YBP]STAT = 3
        [F:YBP]MSG  = "Unknown currency: " - [F:YBP]CUR
        Rewrite [YBP]
        Incr N_KO
        Continue
    Endif

    [F:YBP]STAT = 1
    [F:YBP]MSG  = ""
    Rewrite [YBP]
    Incr N_OK
Next

Call YLOG_BATCH("YMIG_VALIDATE_BPC", "END",
    "ok=" + num$(N_OK) + ",ko=" + num$(N_KO)) From YBATCHLOG
Return
```

Run validation, review the rejects (`STAT = 3`), fix in the source, re-extract, re-validate. Iterate until rejects are zero or acceptable.

### Phase 3 — load

Move staged-and-valid rows into the target tables. Always per-row transactions (see `performance.md`).

```l4g
##############################################################
# YMIG_LOAD_BPC — load validated rows into BPCUSTOMER
##############################################################
$MAIN
Local File YSTAGING_BPC [YBP], BPCUSTOMER [BPC]
Local Integer N_OK, N_FAIL

For [YBP] Where STAT = 1
    Trbegin [BPC]

    # Idempotency: skip if already loaded
    Read [BPC]BPCNUM0 = [F:YBP]BPCNUM
    If !fstat
        Rollback
        [F:YBP]STAT = 1                      # mark as already-loaded
        [F:YBP]MSG  = "Already in target"
        Rewrite [YBP]
        Incr N_OK
        Continue
    Endif

    # Build the target row
    Raz [F:BPC]
    [F:BPC]BPCNUM = [F:YBP]BPCNUM
    [F:BPC]BPCNAM(0) = [F:YBP]BPCNAM
    [F:BPC]CUR = [F:YBP]CUR
    [F:BPC]CRY = [F:YBP]CRY
    # … other columns …
    [F:BPC]CREDAT = [F:YBP]ORIG_CREDAT      # preserve original creation date

    Write [BPC]
    If fstat
        Rollback
        [F:YBP]STAT = 3
        [F:YBP]MSG  = "Write failed fstat=" + num$(fstat)
        Rewrite [YBP]
        Incr N_FAIL
        Continue
    Endif

    Commit
    [F:YBP]STAT = 1
    Rewrite [YBP]
    Incr N_OK
Next

Call YLOG_BATCH("YMIG_LOAD_BPC", "END",
    "ok=" + num$(N_OK) + ",fail=" + num$(N_FAIL)) From YBATCHLOG
Return
```

Idempotency is critical — a load that crashes mid-way must be re-runnable without duplicating. The `Read` check at the top of each row, plus `STAT = 1` marking, makes it safe.

### Phase 4 — reconcile

After loading, prove the migration is complete and correct. Two reconciliation passes:

#### Count reconciliation

```l4g
Local Decimal NB_LEGACY, NB_X3
Local Char QRY(500)

QRY = "SELECT COUNT(*) FROM YSTAGING_BPC WHERE STAT = 1"
Exec Sql QRY On 0 Into NB_LEGACY

QRY = "SELECT COUNT(*) FROM BPCUSTOMER WHERE BPCNUM LIKE '" - [V]LEGACY_PREFIX - "%'"
Exec Sql QRY On 0 Into NB_X3

If NB_LEGACY <> NB_X3
    Call ECRAN_TRACE("MIGRATION DELTA: legacy=" + num$(NB_LEGACY) + ", x3=" + num$(NB_X3), 2) From GESECRAN
Endif
```

#### Sum reconciliation

For numeric columns (balance, credit limit, opening stock), sum should match end-to-end:

```l4g
QRY = "SELECT SUM(CDTUNL) FROM YSTAGING_BPC WHERE STAT = 1"
Exec Sql QRY On 0 Into TOTAL_LEGACY

QRY = "SELECT SUM(CDTUNL) FROM BPCUSTOMER WHERE BPCNUM IN (SELECT BPCNUM FROM YSTAGING_BPC WHERE STAT = 1)"
Exec Sql QRY On 0 Into TOTAL_X3

If abs(TOTAL_LEGACY - TOTAL_X3) > 0.01
    Errbox "Sum reconciliation failed"
Endif
```

Discrepancies surface mismatched currency rates, rounding bugs, mid-flight writes from concurrent activity.

### Phase 5 — cutover

The actual go-live. Checklist:

1. Final extract from legacy (delta only — diff against last full extract).
2. Apply the delta to staging.
3. Load the delta.
4. Run reconciliation against the legacy system at point-in-time.
5. Switch users / integrations to X3.
6. Lock the legacy DB (read-only for safety).
7. Keep both systems available for 30+ days for emergency comparison.

## Dual-write strategy

For long cutovers (weeks, months), both systems must accept writes during the transition. Three options:

### Option A — write to legacy, sync to X3

Simplest. A daily delta-extract picks up changes from legacy and applies to X3.

- Pro: low risk, legacy stays the source of truth.
- Con: X3 is always behind by the delta cycle.

### Option B — write to X3, sync to legacy

X3 is the primary; legacy receives a feed for reporting / interim systems.

- Pro: X3 is current.
- Con: requires a working feed back to legacy.

### Option C — write to both atomically

Application code (or a middleware) writes to both at the same time. If either fails, both roll back.

- Pro: both are always in sync.
- Con: any outage in either system blocks all writes.

Option A is by far the most common. Option B is for organisations that have already partially migrated. Option C is an anti-pattern outside very controlled cutover windows — distributed transactions across two stacks fail in subtle ways.

## In-place schema migration

When the migration is "add a column to a standard / custom table and backfill", the workflow is shorter:

1. **Add the column** in `GESATB`. Set a default if appropriate.
2. **Validate the dictionary** (`GESVAL`). Schema propagates.
3. **Backfill** with a one-shot `$MAIN` script:

   ```l4g
   $MAIN
   Local File BPCUSTOMER [BPC]
   For [BPC] Where YPRIORITY = ""              # rows missing the new value
       Trbegin [BPC]
       Update BPCUSTOMER Where BPCNUM = [F:BPC]BPCNUM
           With YPRIORITY = func YDEFAULT.PRIORITY([F:BPC]BPCCAT) Top 1
       If fstat : Rollback : Continue : Endif
       Commit
   Next
   Return
   ```

4. **Verify** with a count: `SELECT COUNT(*) FROM BPCUSTOMER WHERE YPRIORITY = ''` should be 0.
5. **Make the column mandatory** in `GESATB` once backfill is complete.

Doing it in this order means the application code can refer to the new column from day 1; old rows have a sane value before any reader needs it.

## Folder consolidation

Merging multiple folders into one (e.g. after an acquisition) raises specific issues:

- **Key collisions** — `BP001` may exist in both folders with different meanings. Prefix one side, document the mapping.
- **Different activity codes** — the merged folder must enable the union; any `#Active`-gated code must compile in the target.
- **Different parameter values** (`GESADP`) — pick a canonical set; the migration script may need to remap referenced parameters.
- **Different message chapters** — if both used `1000`, renumber one to `1100`.
- **User / role merge** — out of L4G scope (Syracuse-side), but plan it.

## Performance during migration

Migrations write millions of rows. Apply `performance.md` guidance:

- **Per-row transactions**, not one big `Trbegin`.
- **Disable non-essential triggers** during load (re-enable after — and reconcile if any fired during the window).
- **Drop / recreate non-critical indexes** if the load is large; rebuild after. Caveat: re-indexing a billion-row table takes hours.
- **Batch the script** (`Sleep 1` every 100 rows on hot tables) to avoid starving online traffic if the migration runs during business hours.
- **Run in a maintenance window** if possible — the simplest performance fix is "no concurrent users."

## Common pitfalls

- **Skipping the staging table** — direct DB-to-DB pumps mean you can't re-validate after fixing issues. Always stage.
- **No idempotency** — the migration crashes at row 800,000 of 1,000,000; re-running creates duplicates of rows 1 to 800,000. Add the check.
- **Reconciliation only by count** — same row count, different sums means a column was wrong. Always reconcile by count *and* by sum on key numeric columns.
- **Migrating `CREDAT` as `date$`** — every customer "created today" instead of preserved historic dates. Map original-creation columns explicitly.
- **No batch ID** — when the migration runs more than once and creates artefacts both times, you can't tell what to clean up.
- **Cutover without a rollback plan** — if migration fails 2 hours into go-live, what's the path back? Document it before, not during.
- **Migrating users / passwords** — usually impossible for security reasons. Plan for users to re-set their password on first login.
- **Forgetting to re-enable mandatory column flag** after backfill — new rows skip validation if the column is still optional.
- **Dual-write Option C with no idempotency keys** — partner system retry triples-writes one customer. Always pass a correlation key.
- **Running the migration as the standard "ADMIN" user** — not auditable. Use a dedicated `YMIGUSER` that has migration-only permissions.

## Migration checklist

1. Source extract is reproducible (script + extract date stamped)?
2. Staging table covers every target column + STAT/MSG/BATCH_ID?
3. Validation rejects are zero or documented as accepted?
4. Load is idempotent — re-running doesn't duplicate?
5. Per-row transactions (not one giant `Trbegin`)?
6. Reconciliation by count AND by key sums?
7. Dependent reference data (currencies, countries, item categories) loaded first?
8. CREDAT and other historical timestamps preserved?
9. Audit trail — who ran it, when, with what BATCH_ID?
10. Rollback plan documented for cutover?

See also: `imports-exports.md` (recurring IMP/EXP templates for ongoing data flows), `batch-scheduling.md` (running migration scripts), `performance.md` (transaction granularity, indexes, profiling), `personalisation-activity.md` (deploying schema changes via patches), `diagnostics-postmortem.md` (when migration goes sideways), `security-permissions.md` (migration user ACL, audit logs).

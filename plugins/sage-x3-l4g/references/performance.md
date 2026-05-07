# Performance — indexes, locks, joins, profiling

How to keep custom L4G fast in production. Most performance incidents in X3 boil down to four causes: a query without a usable index, a transaction held across a long iteration, an N+1 read, and unbounded `For` over a table that grows.

This file covers the diagnostic patterns and the L4G primitives that usually fix them.

## The fast-path mental model

Three orders-of-magnitude rules to internalize:

| Operation | Typical cost | Multiplier on a 1M-row table |
|-----------|--------------|------------------------------|
| `Read` on a primary key | < 1 ms | × 1 |
| `Read` on a covering index | 1 – 5 ms | × 1 |
| `For` with `Order By Key` (covering index) | 5 – 50 ms / 1000 rows streamed | × 1 |
| `For` filter on non-indexed column | full scan, seconds | × 1000 |
| `Exec Sql` ad-hoc with a join | depends on plan | wide range |
| `Readlock` while another session holds the lock | wait, possibly indefinite | n/a |

Order of preference for any data access:

1. Primary key `Read`.
2. Secondary key `Read` (the X3 dictionary defines them in `GESATB`).
3. `For ... Order By Key <KEY>` walking a key.
4. `Link [TBL2]` to join (engine picks an index).
5. `Exec Sql` with explicit join — last resort, when the L4G primitives can't express the predicate.

## Indexes — what X3 gives you

In `GESATB` (Tables) → key tab, every table declares an ordered list of keys. The standard `BPCNUM0` on `BPCUSTOMER`, `ITMREF0` on `ITMMASTER`, `SOHNUM0` on `SORDER` are primary keys; secondary keys carry suffixes like `BPCNUM1`, `ITMREF1`.

To make a `For` use a key, name it explicitly:

```l4g
For [ITM] Where ITMSTA = 1 Order By Key ITMSTA0
    # uses the ITMSTA0 secondary key — sequential walk, no scan
Next
```

Without `Order By Key`, the engine guesses. On a small table the guess is fine; on a big one it's a coin flip and you get a scan.

### Adding a custom index

For a custom field that appears in `Where` clauses repeatedly, declare a key:

1. `GESATB` on the table → key tab → add `YKEY1` with the relevant column(s)
2. **Validate** the table — generates the SQL DDL
3. `Activity dictionary → patch` to apply on target folder
4. Replace your `For [TBL] Where YFLD = …` with `For [TBL] Where YFLD = … Order By Key YKEY1`

Index everything that filters in production paths. Indexes are cheap on read-heavy tables; storage cost is negligible compared to a scan.

## `Read` vs `Readlock` — only lock when you'll write

```l4g
Read     [SOH]SOHNUM0 = "S001"          # consult — no lock
Readlock [SOH]SOHNUM0 = "S001"          # consult AND mark for update — holds lock until tx ends
```

Pattern: read first to validate, then readlock + rewrite under transaction:

```l4g
Read [SOH]SOHNUM0 = [L]NUM
If fstat Or [F:SOH]SOHSTA = 9 : Return : Endif    # cheap reject

Trbegin [SOH]
Readlock [SOH]SOHNUM0 = [L]NUM
If fstat : Rollback : Return : Endif              # someone else got it
[F:SOH]SOHSTA = 9
Rewrite [SOH]
If fstat : Rollback : Return : Endif
Commit
```

Locking on the cheap-reject path doubles latency and serializes concurrent readers for no benefit.

## Transactions — keep them short

The deadlock formula in production X3:

```
deadlock_risk ∝ (rows touched) × (time held) × (concurrent writers)
```

Reduce any factor to reduce risk.

### Anti-pattern: long iteration inside a transaction

```l4g
Trbegin [SOH]
For [SOH] Where SOHSTA = 1
    [F:SOH]SOHSTA = 9
    Rewrite [SOH]
Next
Commit
```

On 100k orders, this holds 100k row locks for the loop's duration. Other sessions block, the engine deadlocks, the user sees timeouts.

### Pattern: per-row transaction

```l4g
For [SOH] Where SOHSTA = 1
    Trbegin [SOH]
    Readlock [SOH]SOHNUM0 = [F:SOH]SOHNUM
    If fstat : Rollback : Continue : Endif
    [F:SOH]SOHSTA = 9
    Rewrite [SOH]
    If fstat : Rollback : Continue : Endif
    Commit
Next
```

Each row holds its lock for milliseconds — much higher concurrency. Use this for batches.

### Pattern: bounded batch transaction

When per-row tx is too granular (auditing overhead, 10× slower):

```l4g
Local Integer N
N = 0
Trbegin [SOH]
For [SOH] Where SOHSTA = 1
    Rewrite [SOH] With SOHSTA = 9
    Incr N
    If mod(N, 500) = 0
        Commit
        Trbegin [SOH]
    Endif
Next
Commit
```

500 rows per commit is a starting point — tune to the table's lock density.

## N+1 reads → use `Link`

The classic N+1:

```l4g
For [SOH] Where ORDDAT = date$
    Read [BPC]BPCNUM0 = [F:SOH]BPCORD       # 1 read per order
    [L]NAME = [F:BPC]BPCNAM(0)
Next
```

With `Link`:

```l4g
For [SOH] Where ORDDAT = date$
    Link [BPC] With [F:SOH]BPCORD = [F:BPC]BPCNUM0
    [L]NAME = [F:BPC]BPCNAM(0)
Next
```

The engine emits a single SQL query with a join. On 10,000 orders, drops from ~8 seconds to ~300 ms.

`Link` works when the relation is many-to-one and the linked key exists. For optional links (`Left Join` semantics), `Link [BPC]` and check `[F:BPC]BPCNUM = ""` after the link — the engine sets it to empty when no row matches.

## `For ... Order By` — when sort matters

Sorted output without `Order By Key`:

```l4g
For [SOH] Where ORDDAT >= date$ - 30
    # rows in undefined order — could be insertion order, key order, or chunk-shuffled
Next
```

Forcing a key gives sorted output **for free** (the index is already ordered):

```l4g
For [SOH] Where ORDDAT >= date$ - 30 Order By Key SOHNUM0
    # rows in SOHNUM ascending
Next
```

Forcing an arbitrary `Order By <field>` triggers an external sort:

```l4g
For [SOH] Where ORDDAT >= date$ - 30 Order By BPCORD
    # engine fetches all rows, sorts in memory — costly on big sets
Next
```

Use a key when one matches the desired order; only use plain `Order By` when no key fits.

## `Exec Sql` — when L4G primitives aren't enough

Use cases where embedded SQL beats the primitives:

- Aggregates: `SELECT SUM(QTY) FROM …` instead of `For … Next` in L4G
- Multi-table joins beyond what `Link` chains
- Vendor-specific predicates (regex, JSON operators, window functions)

```l4g
Local Char    QRY(2000)
Local Decimal TOTAL

QRY = "SELECT SUM(QTYSTU) FROM SORDERQ WHERE SOHNUM = '" - [L]NUM - "'"
Exec Sql QRY On 0 Into TOTAL
If [S]stat1 : ... handle : Endif
```

Always check `[S]stat1` after `Exec Sql` (not `fstat` — `Exec Sql` uses `stat1`).

Beware: an `Exec Sql` query can return more rows than your variable holds — bind into an array or use `On 0 Into` for scalar results only.

### SQL plan inspection

When a query is slow, get the plan from the database side, not from L4G. The X3 trace (`SELECT` toggle in supervisor tracing) shows the SQL — paste it in `EXPLAIN` (or `SET STATISTICS` for SQL Server).

## Profiling — find the hot spot

### 1. Trace timestamps

```l4g
Local Decimal T0
T0 = time$ * 1000             # millis since midnight, decimal

# … work …

Call ECRAN_TRACE("Step 1: " - num$(time$ * 1000 - T0) - " ms", 0) From GESECRAN
T0 = time$ * 1000
```

`debugging-traces.md` for trace levels.

### 2. Supervisor tracing

**Administration → Utilities → Verifications → X3 tracing** records every supervisor call with timing. Reproduce the slow path with the trace on, then inspect the log.

### 3. SQL trace

Same place, toggle "SQL". Every query the engine emits appears with timing — you find unindexed scans by sorting on duration.

### 4. `funfat` / `stat1` for diagnostic codes

When a script returns slowly with a status, `[S]funfat` and `[S]stat1` carry detail. Log them on suspicion.

## Cache when you can

Within one script, repeated lookups should cache:

```l4g
Local Char  PARAM_VAL(50)
Local Char  LAST_KEY(20)
Local Char  LAST_VAL(50)

For [SOH] Where ORDDAT = date$
    If [F:SOH]CUR <> LAST_KEY
        LAST_VAL = func AFNC.PARAMG("CUR", [F:SOH]CUR, "SYM")
        LAST_KEY = [F:SOH]CUR
    Endif
    PARAM_VAL = LAST_VAL
    # … use PARAM_VAL …
Next
```

For cross-script caching, use a session global (`[V]Y…`) initialised once at session start.

## Pool sizing — services and batches

For SOAP / REST services under load, the AWS pool (`GESAPO`) decides how many sessions can run in parallel. See `web-services-soap.md` for sizing. Rule of thumb: `min ≥ peak concurrent callers`, `max ≤ 2 × min`.

Higher caps invite thrashing — when 50 sessions compete for the same locks, throughput drops below the 5-session case.

## Batch scheduling — spread the load

Long-running batches (`GESABA` / `GESAPL`) should not run concurrently with online traffic. Schedule:

- Heavy batches at off-hours (`02:00`–`05:00`).
- Per-row-tx batches with a small `Sleep` between rows if they touch hot tables.
- Use the `Recurrent` flag with cron-style scheduling rather than wake-loops.

## Common anti-patterns to flag

| Anti-pattern | Fix |
|--------------|-----|
| `For` filter on non-indexed column | Add an index in `GESATB`; rerun with `Order By Key` |
| `Read` inside a `For` over a related table | Use `Link` |
| `Readlock` on read-only path | Use `Read` |
| `Trbegin` outside the loop, `Commit` after | Move to per-row tx |
| `Exec Sql` for a single-row primary-key fetch | Use `Read` |
| `Order By <field>` instead of `Order By Key` | Use a key when one matches |
| `Infbox` / `Errbox` in a hot loop | Trace and aggregate |
| Repeated `func AFNC.PARAMG` in a loop | Cache the resolved value |
| Custom batch wakes every 30 s polling | Use `Recurrent` schedule, not poll |
| Chains of 5+ `Link` traversals | Replace with `Exec Sql` join — fewer round trips |

## When you actually need raw SQL

Sometimes the engine's plan is wrong (wrong index pick, missing statistics). Force a hint via `Exec Sql` with a vendor-specific directive — but document the reason and revisit on the next major patch / database upgrade. Hints rot fast.

## Profiling checklist for a slow custom screen / batch

1. Turn on supervisor tracing (`SQL` + `Subprog`) for the slow path.
2. Run once, scan the log for queries > 100 ms.
3. For each slow query, check the table key list — does a covering key exist?
4. If not, can one be added without breaking the standard schema (use a `Y` key)?
5. Check for N+1 patterns (same query issued in a loop) — refactor to `Link`.
6. Check transaction boundaries — is anything held across the loop?
7. Re-measure with traces still on; remove tracing for production once stable.

See also: `database.md` (`UPDTICK`, `Link`, `Exec Sql`), `code-review-checklist.md` (Tier 5 perf flags), `debugging-traces.md` (`stat1`/`funfat`, supervisor tracing), `web-services-soap.md` (AWS pool sizing).

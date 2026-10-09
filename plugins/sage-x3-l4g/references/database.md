# Database access

Opening tables, reading, iterating, joining, writing, locking and transactions in L4G, with the exact
`fstat` / `adxuprec` semantics. This file is the canonical home of the transaction idiom: every other
reference links here instead of repeating it.

## Contents
- [Declaring tables](#declaring-tables)
- [Status codes](#status-codes)
- [Reading one row](#reading-one-row)
- [Iterating with For](#iterating-with-for)
- [Joins with Link](#joins-with-link)
- [Transactions](#transactions)
- [Writing rows](#writing-rows)
- [Locking and UPDTICK](#locking-and-updtick)
- [Complete example: YTRANSFER](#complete-example-ytransfer)
- [Raw SQL](#raw-sql)
- [Gotchas](#gotchas)
- [Sources](#sources)

## Declaring tables

```l4g
Local File BPCUSTOMER [BPC]                       : # explicit abbreviation
Local File ITMMASTER                              : # abbreviation taken from the dictionary
Local File YACCOUNT [YACC] Where Y_BALANCE < 0    : # permanent filter for this declaration
Local File YACCOUNT [YAC2] Order By Key YBYBAL = Y_BALANCE Desc; Y_ACCNUM
Filter [BPC] Where BPCSTA = 2 Order By BPCNAM     : # replaces any previous Filter; "Filter [BPC]" cancels
Columns [BPC] (BPCNUM, BPCNAM)                    : # For loads only these; "Columns [BPC]" resets
LogicClose File [YAC2]
```

- Without `[ABV]` the abbreviation defined in the table dictionary (GESATB, 1 to 3 characters) is used;
  it is not derived from the table name. A script may pick its own abbreviation (up to 8 characters).
- Index names come from the dictionary: abbreviation + `0` for the primary key, `1` for the next...
  (`BPCUSTOMER`: `BPC0` on BPCNUM, `BPC1` on BPCNAM); custom indexes start with X, Y or Z. Check GESATB
  for any other index: `[ABV]KEY0`-style names in this skill are placeholders built on that convention.
- A dimensioned field FIELD is stored as columns `FIELD_0`, `FIELD_1`... (matters for raw SQL).
- `Order By` belongs to `Local File`, `Filter` and `Link`, never to `For`. `Order By Key NAME = A; B`
  creates a temporary key usable by `Read` / `For`.
- Plain `File` (no `Local`) closes the tables of earlier `File` statements: deprecated. Declare every
  table a routine uses with `Local File` at its start; class events get an automatic `LogicClose File`.
- `Columns` applies to `For`, `Rewrite` and `Rewritebykey` (`Extended` adds `Read` and `Readlock`).

## Status codes

`fstat` is set by every database instruction. Use the `[V]` constants rather than literals.

| Value | Constant | Meaning | Returned by |
|---|---|---|---|
| 0 | `[V]CST_AOK` | Success | all |
| 1 | `[V]CST_ALOCK` | Row or table locked | `Readlock`, `Write`, `Rewrite`, `Update`, `Delete`, `*bykey` |
| 2 | `[V]CST_AOUTSEARCH` | `<=` / `>=` found a row whose key differs from the value | `Read`, `Look`, `Readlock`, `Rewrite`, `Delete` |
| 3 | `[V]CST_ADUPKEY` | Duplicate value on a unique index | `Write`, `Rewrite`, `Update`, `Rewritebykey` |
| 4 | `[V]CST_AOUTKEYS` | Beyond the first / last key (`Prev` / `Next`) | `Read`, `Look`, `Readlock`, `Rewrite` |
| 5 | `[V]CST_ANOREC` | No row found | `Read`, `Look`, `Readlock`, `Rewrite` |
| 6 | `[V]CST_ARECTICKUPD` | Update conflict: UPDTICK changed since the read | `Rewritebykey`, `Deletebykey` |
| 7 | `[V]CST_ARECTICKDEL` | Row no longer exists with that UPDTICK | `Rewritebykey`, `Deletebykey` |

On `Update`, fstat 1 and 3 mean the **transaction has already been rolled back**. `adxuprec` /
`adxdlrec` hold the number of rows the last `Update` / `Delete` changed, and a `Delete` matching no row
returns fstat 0 with `adxdlrec` = 0: fstat alone does not prove a row was touched, so test the counter
whenever you expect a precise number of rows. Unopened table (7), unknown key (21), wrong read mode
(22) or too many locks (43) are runtime errors, not fstat values: they stop the script unless `Onerrgo` is armed.

## Reading one row

```l4g
Local File BPCUSTOMER [BPC]
Read [BPC]BPC0 = [L]CUSTNUM
If fstat = [V]CST_ANOREC
  [L]MSG = "Client inconnu"            : # literal for brevity — use mess() in real code
Elsif fstat = [V]CST_AOK
  [L]NAME = [F:BPC]BPCNAM
Endif
Look [BPC]BPC0 = "C0001"               : # existence test, [F:BPC] untouched
[L]FOUND = (fstat = 0)
```

- Modes: `First`, `Last`, `Next`, `Prev`, `Curr` (no value) and `=`, `<`, `<=`, `>`, `>=`. Segment
  values are separated by `;` (`Read [ABV]KEY1 = [L]A; [L]B`); `KEY(N)` uses the first N segments only.
- `[F:ABV]` changes only on success (0 or 2). `Read` is for one row; use `For` for many.
- `nbrecord([ABV])` counts all rows, `rowcount([ABV])` the rows matching `Where` / `Filter`.

## Iterating with For

```l4g
Local File BPCUSTOMER [BPC] Where BPCSTA = 2
For [BPC]BPC0 From "C0000" To "C9999"
  [L]NB += 1
Next
Local File YACCOUNT [YACC] Order By Key YBYBAL = Y_BALANCE Desc; Y_ACCNUM
For [YACC]YBYBAL Where Y_BALANCE > 0
  [L]RANK += 1
  Call YPRINT_ACC([F:YACC]Y_ACCNUM, [F:YACC]Y_BALANCE) From YACCLIB : # your own subprogram
  If [L]RANK >= 10 : Break : Endif     : # there is no "Top N": count and Break
Next
```

- `For [ABV]KEY(N)` loops on distinct values of the first N segments; nest it with deeper levels
  (`Where` / `From ... To` only on the outermost level). `For [ABV]reckey` sends no ORDER BY: fastest
  full scan when order does not matter.
- `With Lock` locks the rows read (discouraged by Sage); `With Stability` makes SQL Server ignore rows
  inserted during the loop; `Hint Key K` / `With Nohint` steer the optimizer (exceptional cases only).
- At the end of the cursor `fstat` is left at 4: keep the status of the work done inside the loop in a
  local variable instead of testing `fstat` after `Next`.
- `pat(COL,"A*")<>0` or `find(COL,1,3,7)<>0` in a `Where` become SQL `LIKE` / `IN`; date functions
  applied to columns are filtered by the engine after the fetch, and `func` is not allowed in a `Where`
  (see `performance.md`).

## Joins with Link

```l4g
Local File BPCUSTOMER [BPC], AUTILIS [AUS]
Link [BPC] With [AUS]CODUSR ~= [BPC]CREUSR As [YLNK]
& Where [BPC]BPCSTA = 2
For [YLNK]
  # [F:BPC] and [F:AUS] are both loaded for each joined row
  [L]NB += 1
Next
```

- `Link` declares a join cursor, read with `For` (or `Read`) on the link abbreviation.
- `[OTHER]KEY = expr` is a left outer join (missing rows give empty `[F:OTHER]` values); `~=` is an
  inner join, faster when applicable. Up to 12 tables (index `CODUSR` comes from Sage's Link example).
- No `Write` / `Rewrite` / `Update` / `Delete` on a link abbreviation: use the table abbreviations.
  `Columns [YLNK]([BPC]BPCNUM, [BPC]BPCNAM)` trims the default `select *`.

## Transactions

The engine supports **one** transaction level. `adxlog` is 1 inside a transaction, 0 outside. A
`Trbegin` while a transaction is open raises error 49; `Commit` / `Rollback` must run at the call level
that issued `Trbegin`; an `End` reached with the transaction open rolls it back. Any routine that writes
and may be called from an open transaction uses this idiom:

```l4g
Funprog YSTOCK_MOVE(LOC_A, LOC_B, QTY)
Value Char    LOC_A(), LOC_B()
Value Decimal QTY
Local Shortint TRANS_OPEN
  Local File YSTOCK [YSTO]
  [L]TRANS_OPEN = adxlog
  If [L]TRANS_OPEN = 0 : Trbegin [YSTO] : Endif
  Update [YSTO] Where Y_LOC = [L]LOC_A With Y_QTY -= [L]QTY
  If fstat or adxuprec <> 1
    # adxlog test: an Update returning 1 or 3 has already rolled back (Rollback alone = error 48)
    If [L]TRANS_OPEN = 0 and adxlog = 1 : Rollback : Endif
    End [V]CST_AERROR
  Endif
  # ... same check after the update of LOC_B and after every other write ...
  If [L]TRANS_OPEN = 0 : Commit : Endif
End [V]CST_AOK
```

- When `adxlog` was already 1 the routine never calls `Trbegin` / `Commit` / `Rollback`: it returns a
  status and the caller, which owns the transaction, rolls back.
- **Do not copy the samples of Sage's 4gl_trbegin.html, 4gl_commit.html, 4gl_rollback.html and
  4gl_delete.html: their `adxlog` test is inverted** (they open a transaction when one is already
  running). The 4gl_adxlog.html sample is correct.
- Never `Trbegin` in class event code: the supervisor owns the transaction around AINSERT / AUPDATE /
  ADELETE (`v12-classes.md`). Operations and standalone subprograms may manage their own.
- Tables opened before `Trbegin` take part in the transaction even if not listed. Keep transactions
  short (no user interaction, no waiting loop). `Openo` files are not transactional.

## Writing rows

Every write must run inside a transaction. `Write` inserts the `[F]` buffer; `Rewrite` rewrites the
current row (usually after `Readlock`); `Update` and `Delete ... Where` are set-based.

```l4g
Raz [F:YACC]
[F:YACC]Y_ACCNUM = [L]NEWACC
[F:YACC]Y_BALANCE = 0
Write [YACC]
If fstat : [L]ERR = fstat : Endif           : # 3 = account already exists

Update [YACC] Where Y_STATUS = 1 and Y_BALANCE = 0
& With Y_STATUS = 2, Y_CLOSDAT = date$
If fstat : [L]ERR = fstat : Else : [L]NB_CLOSED = adxuprec : Endif

Delete [YACC]YAC0 = [L]OLDACC                : # by key; adxdlrec = rows deleted
If fstat or adxdlrec <> 1 : [L]ERR = 1 : Endif
Delete [YACC] Where Y_STATUS = 9             : # set-based
If fstat : [L]ERR = fstat : Endif
```

- `Raz [F:ABV]` before filling a new row, or values from a previous `Read` are written.
- `Update` does not refresh `[F:ABV]`; reading a column modified in the same `Update` is unpredictable;
  a massive `Update` can raise error 43 (too many locks). `Writeb` buffers inserts (`adxwrb`, `Flush`).

## Locking and UPDTICK

**Pessimistic**: lock the row while you change it, inside a transaction opened with the idiom above.

```l4g
Readlock [YACC]YAC0 = [L]ACC With lockwait = 0
If fstat = [V]CST_AOK
  [F:YACC]Y_BALANCE += [L]AMOUNT
  Rewrite [YACC]
Endif
If fstat : [L]STA = fstat : Endif      : # 1 locked, 5 missing, 3 duplicate: roll back per the idiom
```

- `lockwait` (seconds; 0 = one attempt; negative = forever, deadlock risk) applies to `Readlock` and
  `Lock`, not to `Update` / `For ... With Lock`. Sage advises 0, then roll back, wait and retry.
- In a transaction, locks last until `Commit` / `Rollback` (`Unlock` does nothing there); outside one,
  release them with `Unlock [ABV]`.
- `Lock YSYMBOL With lockwait = 0` / `Unlock YSYMBOL` is a named mutex (fstat 1 = not obtained): lock
  symbols outside transactions, several in one `Lock` statement. Recipe (single-instance batch guard):
  `batch-scheduling.md`.

**Optimistic**: every table validated by the V7+ dictionary has an `UPDTICK` column fed by a database
trigger (1 on insert, +1 per update). **Application code never assigns it**; read it as `[ABV]Updtick`.
`Rewritebykey` / `Deletebykey` write only if the `[F]` UPDTICK still equals the database one, so no
lock is held between the read and the write:

```l4g
Read [YACC]YAC0 = [L]ACC
If fstat : End [V]CST_ANOREC : Endif
# ... long computation: no lock is held ...
[F:YACC]Y_BALANCE = [L]NEW_BALANCE
[L]TRANS_OPEN = adxlog
If [L]TRANS_OPEN = 0 : Trbegin [YACC] : Endif
Rewritebykey [YACC]YAC0 = [L]ACC
[L]STA = fstat
If [L]STA <> [V]CST_AOK
  If [L]TRANS_OPEN = 0 and adxlog = 1 : Rollback : Endif
  End [L]STA                           : # 6 = modified meanwhile: re-read and retry
Endif
If [L]TRANS_OPEN = 0 : Commit : Endif
```

## Complete example: YTRANSFER

The canonical transactional Funprog is in `SKILL.md` and, with an ALOG check, in `examples/YACCLIB.src`;
its AXUNIT suite is `examples/QLFYAC_TRANSFER.src`. `YACCOUNT` is a custom table declared in GESATB with
dictionary abbreviation `YAC` and primary index `YAC0` on `Y_ACCNUM`; the script opens it as `[YACC]`.
YTRANSFER may run inside its caller's transaction, so it declares its table at its start (see the
`Local File` gotcha below), captures `adxlog`, and tests `adxuprec` after each `Update`: a missing
account or an insufficient balance updates no row, which fstat alone would not reveal.

## Raw SQL

```l4g
Local Integer DBTYPE, NB
Local Char    DBCODE(1), QRY(250)
  [L]DBTYPE = fmet GACTX.APARAM.AGETVALNUM([V]CST_ALEVFOLD, "", "TYPDBA") : # 1 Oracle, 2 SQL Server
  [L]DBCODE = string$([L]DBTYPE = 1, "O") + string$([L]DBTYPE = 2, "S")
  [L]QRY = "select count(*) from YACCOUNT where Y_BALANCE_0 < 0"
  For (Integer CNT) From [L]DBCODE Sql [L]QRY As [YSQL]
    [L]NB = [F:YSQL]CNT
  Next
  Execsql From [L]DBCODE Sql "delete from YTMPLOAD where YSTA_0 = 9"
  [L]NB = adxsqlrec                    : # rows affected (0 after DDL)
```

- `For (TYPED_VARS) From DBTYPE Sql SELECT As [ABV]` iterates a SELECT; `Execsql From DBTYPE Sql CMD`
  runs anything else (`"O"`/`"3"` Oracle, `"S"`/`"5"` SQL Server). There is no `Exec Sql ... On 0 Into`.
  SQL errors are runtime errors (trap with `Onerrgo`). Use physical column names (`_0` suffix); the
  syntax is database-specific, so prefer L4G instructions whenever they can express the need.

## Gotchas

- The word after `[ABV]` in `Read` / `For` / `Delete` is a **key** name (dictionary index or
  `Order By Key`), not a column; an unknown key raises error 21.
- After `Update` fstat 1 or 3 the transaction is already rolled back: guard `Rollback` with
  `adxlog = 1` as the idiom does, also in the caller that owns the transaction.
- A `Filter` set by a called routine on a table it did not redeclare stays active in the caller.
- `clalev([ABV])` (1 if the table / class is open, 0 if not) was the V6 way to avoid reopening a table;
  Sage calls it deprecated in V7 except for a common subprogram that must reuse an already opened class.
- 4gl_file.html: "You can open a file with Local File within a transaction, but files opened in write
  mode by Trbegin will no longer be accessible". A routine that owns the transaction declares its tables
  before `Trbegin`; a routine called inside a caller's transaction (like YTRANSFER) declares them at its
  start — verify that case on your folder.

See also: `language-basics.md`, `performance.md`, `v12-classes.md`, `sequential-files.md`.

## Sources
- https://online-help.sagex3.com/erp/12/en-us/Content/V7DEV/4gl_fstat.html
- https://online-help.sagex3.com/erp/12/en-us/Content/V7DEV/4gl_adxlog.html
- https://online-help.sagex3.com/erp/12/en-us/Content/V7DEV/4gl_trbegin.html (inverted sample)
- https://online-help.sagex3.com/erp/12/en-us/Content/V7DEV/4gl_update.html
- https://online-help.sagex3.com/erp/12/en-us/Content/V7DEV/4gl_clalev.html
- https://online-help.sagex3.com/erp/12/en-us/Content/V7DEV/developer-guide_technical-columns-of-database.html
- https://online-help.sagex3.com/erp/12/en-us/Content/V7DEV/how-to_best-practice-for-data-transaction-handling.html
- https://online-help.sagex3.com/erp/12/en-us/Content/FCT/GESATB.htm
- Same V7DEV base, pages `4gl_<name>.html` for: file, filter, columns, order-by, where, logicclose,
  read, look, readlock, lockwait, nbrecord, rowcount, for, reckey, hint, stability, link, commit,
  rollback, funprog, write, rewrite, delete, adxuprec, adxdlrec, writeb, rewritebykey, deletebykey, updtick,
  glossary-updtick, lock, unlock, execsql, sql, adxsqlrec, func.

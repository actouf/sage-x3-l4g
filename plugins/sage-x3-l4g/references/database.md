# Database operations

Everything about reading and writing to the X3 database from L4G.

## Declaring a file (table)

Before using a table you must **open** it with `Local File` or `Default File`.

```l4g
Local File BPCUSTOMER [BPC]          # alias [BPC]
Local File ITMMASTER                 # alias defaults to ITM (3 first chars)
```

The alias inside brackets (`[BPC]`) is how you refer to fields: `[F:BPC]BPCNUM`.

`Default File` sets that table as the implicit one for bare `Read` / `Write` / etc., but using explicit `[F:...]` is safer and clearer.

## Single-row access: Read, Readlock, Rewrite, Write, Delete

### Read — no lock

```l4g
Read [BPC]BPCNUM0 = "BP001"
If fstat
    # record not found or error
    Call ECRAN_TRACE("Customer not found", 1) From GESECRAN
Else
    # [F:BPC] is now populated
    Infbox [F:BPC]BPCNAM(0)
Endif
```

`BPCNUM0` is the **index name** (must exist in the table's indexes), not the field name. After `Read`, the class `[F:BPC]` holds the record.

### Readlock — read and lock

Acquires a write lock — you must then `Rewrite`, `Commit`, or `Rollback` to release it.

```l4g
Trbegin [BPC]
Readlock [BPC]BPCNUM0 = "BP001"
If fstat
    Rollback
    End
Endif
[F:BPC]BPCNAM(0) = "NEW NAME"
Rewrite [BPC]
If fstat : Rollback : End : Endif
Commit
```

### Write — insert

```l4g
Raz [F:BPC]                          # clear the class buffer first
[F:BPC]BPCNUM = "BP999"
[F:BPC]BPCNAM(0) = "ACME Corp"
# ... fill other required fields ...
Trbegin [BPC]
Write [BPC]
If fstat
    Rollback
Else
    Commit
Endif
```

### Delete

```l4g
Trbegin [BPC]
Delete [BPC]BPCNUM0 = "BP999"
If fstat : Rollback : Else : Commit : Endif
```

### Update … Where … With — set-based update

```l4g
Trbegin [ACC]
Update ACCOUNT Where CODE = "A001" With BALANCE = BALANCE - 100
If fstat : Rollback : End : Endif
Commit
```

`[S]adxuprec` holds the number of rows modified. Useful when the `Where` might match zero rows (success with 0 rows updated is not an error).

### Delete Where — set-based delete

```l4g
Delete [LOG] Where LOGDAT < date$ - 90   # delete entries older than 90 days
```

`[S]adxdlrec` gives the count deleted.

## Iterating: `For <class>`

The **iteration form** of `For` reads rows one at a time into `[F:...]`.

```l4g
Local File SORDER [SOH]
For [SOH] Where SOHTYP = 1 And CUR = "EUR"
    # [F:SOH] is populated with each row in turn
    [L]TOTAL += [F:SOH]ORDAMT
Next
```

With an explicit index and ordering:

```l4g
For [SOH] Where SOHSTA <= 2 Order By Key SOHNUM0
    Incr [L]COUNT
Next
```

Limit results with `Top`:

```l4g
For [SOH] Top 100 Order By Key SOHNUM0 Desc
    ...
Next
```

`Exitfor` breaks out early; **do not modify the iteration table inside the loop** (delete/update rows from it) — undefined behavior.

## Transactions

### Trbegin — start

```l4g
Trbegin [BPC], [ITM]                 # lock scope = these tables
```

You can list multiple tables. Any update of a table **already opened** (even not listed) also participates in the transaction.

### Commit — validate

Releases all locks (on tables, rows, and symbols acquired during the transaction) and writes changes to disk.

### Rollback — abort

Undoes everything since `Trbegin`, releases locks.

### The `If adxlog` idiom — nested-transaction safety

The X3 engine supports only **one** transaction level. If your subprogram might be called from inside an already-running transaction, you must not issue another `Trbegin`:

```l4g
Local Integer IF_TRANS
If adxlog
    Trbegin [MYTABLE]
    IF_TRANS = 0                     # we own the transaction
Else
    IF_TRANS = 1                     # caller owns it
Endif

# ... work ...

If fstat
    If IF_TRANS = 0 : Rollback : Endif
    End [V]CST_AERROR                # let caller decide whether to roll back
Endif

If IF_TRANS = 0 : Commit : Endif
End [V]CST_AOK
```

This is the standard X3 pattern — use it every time a subprogram writes to the database.

### Avoid long transactions

The engine holds pessimistic locks until commit. Keep transactions short and **never put a user prompt, long computation, or remote call inside** `Trbegin` — deadlocks and timeouts will follow.

### `UPDTICK` — optimistic concurrency (V12)

V12 standard tables include an `UPDTICK` column, incremented automatically on every write. The UI reads it on load and passes it back on save; the engine rejects the save if the row changed since. In custom code you can use it explicitly when you don't want to hold a pessimistic lock:

```l4g
# Read (no lock), remember the tick
Read [YTBL]KEY0 = [L]KEY
[L]OLDTICK = [F:YTBL]UPDTICK

# ... long computation / user interaction ...

# Set-based update with tick check — no Readlock needed
Update YMYTABLE Where KEY = [L]KEY And UPDTICK = [L]OLDTICK
    With AMT = [L]NEW, UPDTICK = UPDTICK + 1

If [S]adxuprec = 0
    Errbox mess(504, 501, 1)         # "Record was modified, refresh and retry"
Endif
```

Use optimistic locking when the transaction would otherwise span a user action or a long computation; use `Readlock` when the critical section is short and contained. See `v12-classes-representations.md` for the REST equivalent.

## Link — reading a related row on the fly

```l4g
Local File SORDER [SOH], BPCUSTOMER [BPC]
For [SOH] Where SOHSTA <= 2
    Link [BPC] With [F:SOH]BPCORD = [F:BPC]BPCNUM0
    # [F:BPC] is now the customer for this order
    Infbox [F:SOH]SOHNUM + " - " + [F:BPC]BPCNAM(0)
Next
```

`Link` populates the second class for the current row; `fstat` tells you if the link succeeded.

## Embedded SQL

When L4G primitives can't express what you need:

```l4g
Local Char QRY(500)
QRY = "UPDATE ITMMASTER SET STATUT = 2 WHERE ITMREF LIKE 'XXX%'"
Exec Sql QRY
If fstat
    Call ECRAN_TRACE("SQL error: " + num$([S]stat1), 1) From GESECRAN
Endif
```

Avoid this unless necessary — you lose folder-awareness and bypass X3's own cache and trigger mechanism.

### Scalar SELECT via `Exec Sql ... On N Into`

To pull a single computed value without opening a class:

```l4g
Local Decimal NB
Local Char    QRY(500)

QRY = "SELECT COUNT(*) FROM ITMMASTER WHERE ITMSTA = 1 AND ITMREF LIKE 'Y%'"
Exec Sql QRY On 0 Into NB
If fstat
    Errbox "SQL error " + num$([S]stat1)
Else
    Infbox num$(NB) + " items."
Endif
```

`On 0` targets the current database connection. `Into` maps result columns left-to-right into the listed L4G variables; types must match. Multi-column returns work too:

```l4g
Local Char    NAME(60)
Local Decimal AMT
Exec Sql "SELECT BPCNAM, CURBAL FROM BPCUSTOMER WHERE BPCNUM='BP001'" On 0 Into NAME, AMT
```

For multi-row SQL, prefer a `For` with a filter expression L4G can translate, or a temp-table round trip.

## Useful system variables

| Variable | Meaning |
|----------|---------|
| `fstat` | 0 on success, error code otherwise — check after every DB op |
| `adxlog` | 1 if a transaction is in progress, 0 otherwise |
| `adxuprec` | Rows affected by last `Update` |
| `adxdlrec` | Rows affected by last `Delete Where` |
| `adxsqlrec` | Rows affected by last `Exec Sql` |
| `currind` | Currently-used index for the default table |
| `reckey` | Set to 1 to skip `Order By` optimization inside `For` |

## Common gotchas

- **Reading with wrong index name.** `Read [BPC]BPCNUM` fails silently — the correct form is `Read [BPC]BPCNUM0 = "..."` (the index, not the field).
- **Forgetting `Raz [F:...]`** before `Write` — residual values from a prior `Read` get written.
- **Using `Read` when you need `Readlock`** — another session can write between your read and your rewrite, causing lost updates.
- **`fstat` check placement** — check immediately after the operation, not after other statements that might reset it.
- **Comparing `Char` fields with trailing spaces.** Use the `-` trim-concat operator or explicit `strip$()`.
- **Cross-folder access.** Opening a table from a different folder requires `Local File ... In "<folder>"` — most code runs in the current folder `nomap`.

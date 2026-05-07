# Code review checklist

Consolidated red flags for L4G code review. Use this as a structured pass before approving a `.src` / `.trt` change. Each item lists the symptom, why it matters in the X3 runtime, and the fix.

The order is approximately blast-radius descending — a missing `fstat` ships silent corruption, a missing comment ships nothing.

## Tier 1 — correctness (block the merge)

### 1.1 Missing `fstat` check after a DB or file operation

**Symptom**

```l4g
Read [BPC]BPCNUM0 = [L]CODE
[L]NAME = [F:BPC]BPCNAM(0)            # used unconditionally
```

**Why** the X3 runtime does not raise an exception on `Read` failure — it sets `[S]fstat` and leaves `[F:...]` untouched (or with stale data from a previous record). The next line silently uses garbage.

**Fix** — check `fstat` after **every** `Read`, `Readlock`, `Write`, `Rewrite`, `Delete`, `Update`, `Openi`, `Openo`, `Readseq`, `Writeseq`. The only exception is right after a `For ... Next` start where the engine sets a "no rows" status — even there, prefer to test it.

```l4g
Read [BPC]BPCNUM0 = [L]CODE
If fstat
    [L]NAME = ""
    Return
Endif
[L]NAME = [F:BPC]BPCNAM(0)
```

### 1.2 `Write` / `Rewrite` / `Delete` without a transaction

**Symptom** a multi-row write where the second row fails and the first has already hit the table.

**Why** without `Trbegin` … `Commit` / `Rollback`, the engine auto-commits each write. A partial failure leaves orphan rows.

**Fix** wrap the writes in `Trbegin [TBL1], [TBL2]` … `Commit`, with `Rollback` on any `fstat`. Use the `If adxlog` idiom (1.4) to be safe in nested calls.

### 1.3 `Readlock` without a release path

**Symptom**

```l4g
Readlock [SOH]SOHNUM0 = [L]NUM
[F:SOH]SOHSTA = 9
Rewrite [SOH]
# no Commit, no Rollback, function returns
```

**Why** `Readlock` holds the row lock until **the transaction ends** (commit or rollback) **and** the cursor moves off the row. Returning from a subprogram does not release the lock — the next caller hangs.

**Fix** every `Readlock` must be matched with a `Commit` or `Rollback` on every code path, including error branches.

### 1.4 Missing `If adxlog` guard on a reusable subprogram

**Symptom** subprogram opens its own `Trbegin`, gets called from inside a caller's transaction. The engine sees a nested `Trbegin` and either silently merges (V12) or errors (older) — and on error, the `Commit` here partially commits the caller's outer work.

**Fix**

```l4g
Local Integer IF_TRANS
If adxlog
    Trbegin [TBL]
    IF_TRANS = 0
Else
    IF_TRANS = 1                   # caller owns the transaction
Endif
# … work …
If IF_TRANS = 0 : Commit : Endif
```

Apply this to every `Subprog` / `Funprog` / `Method` that may be called from a script that's already in a transaction.

### 1.5 Long-running loop inside `Trbegin` (deadlock risk)

**Symptom**

```l4g
Trbegin [SOH]
For [SOH] Where SOHSTA = 1            # could be 100,000 rows
    [F:SOH]SOHSTA = 9
    Rewrite [SOH]
Next
Commit
```

**Why** every `Rewrite` holds a row lock until commit. A long iteration → tens of thousands of held locks → other sessions deadlock.

**Fix** open and commit a transaction **per row** (or per small batch):

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

### 1.6 Concurrency without `UPDTICK`

**Symptom** custom `Update` … `With` that does not include `UPDTICK = UPDTICK + 1` or doesn't filter `Where UPDTICK = …`.

**Why** without the optimistic-concurrency token, two concurrent writers happily overwrite each other's changes (last-write-wins).

**Fix** see `database.md` — load `UPDTICK` with the row, include it in the `Where`, increment it in the `With`, check `[S]adxuprec` to detect "someone else changed the row".

### 1.7 `Onerrgo` without a reachable label

**Symptom** `Onerrgo HANDLER` declared but no `$HANDLER` label below, or the label lives in a different `Subprog`.

**Why** on error the engine jumps to a label that doesn't exist → undefined behavior (often a silent return at the wrong spot).

**Fix** declare the label in the same script unit, and verify with a quick search before merging.

### 1.8 `Goto` / `Gosub` across subprogram boundaries

**Symptom** `Goto LABEL` where `$LABEL` is in a different `Subprog`/`Funprog`.

**Why** legal in some legacy paths, but the runtime stack gets corrupted — local variables disappear, return addresses are lost.

**Fix** call a subprogram explicitly with `Call`. Within a subprog, `Gosub` to a local label is fine.

### 1.9 Modifying the iteration target inside a `For` loop

**Symptom**

```l4g
For [ITM] Where ITMSTA = 1
    Update ITMMASTER Where ITMREF = [F:ITM]ITMREF With ITMSTA = 9
Next
```

**Why** the cursor may revisit, skip, or repeat rows after the underlying state changes. Behavior depends on driver and patch level.

**Fix** collect IDs first, then iterate the collection and update one-by-one.

## Tier 2 — conventions (must fix unless explicit reason)

### 2.1 Custom code without `Y`/`Z` prefix

A custom symbol — table, field, screen, message chapter, action, subprogram — must start with `Y` (vertical) or `Z` (specific). Standard X3 names get overwritten on patch installs.

`conventions-and-naming.md` for the full rule.

### 2.2 Hard-coded folder name

```l4g
Call OUVRE_TRT("GESBPC", …)            # what if folder uses ZGESBPC?
```

Use `func AFNC.PARAMG` or a constant defined in a custom parameter, not a literal.

### 2.3 Hard-coded language strings

`Errbox "Erreur de saisie"` does not localize. Use:

```l4g
Errbox mess(123, 100, 1)               # message 123 in chapter 100, language flag 1
```

Define messages in `GESAML` / message chapters. See `conventions-and-naming.md`.

### 2.4 Missing prefix on bracketed access in shared code

```l4g
SOHNUM = "ABC"                         # which scope? L? M? F?
```

The engine resolves this using priority rules and the resolution may surprise you (or the next reader). Always write `[L]SOHNUM`, `[M:SOH]SOHNUM`, `[F:SOH]SOHNUM` in code that will be reviewed.

### 2.5 No traces in non-trivial logic

Any `Subprog` / `Funprog` over ~30 lines or running in an integration / batch context must log entry, key decisions, and exit through `ECRAN_TRACE` (or your project's wrapper). Without traces, support tickets are unworkable.

`debugging-traces.md` for trace levels and patterns.

### 2.6 `Infbox` / `Errbox` in service or batch context

Services, batches, and REST endpoints have no user — calling `Infbox` either hangs or surfaces the popup XML to the caller. Replace with a status return + trace.

### 2.7 No status return on a service subprogram

A SOAP / REST service that crashes or returns silently breaks the caller. Always return a status as the last out parameter (vocabulary: `OK`, `KO_<reason>`, `WARN_<detail>`).

`web-services-soap.md` for SOAP best practices, `web-services-rest.md` for REST.

## Tier 3 — V12 idioms (prefer V12 form for new code)

These are not bugs in existing Classic code, but new code should reach for the V12 form unless extending Classic.

| Old (Classic) | New (V12) | When |
|---------------|-----------|------|
| `Subprog` with module-level state | `Class` + `Method` + `this` | Anything beyond a single-step helper |
| `Mask` + `Inpbox` | Representation + page | All new UI |
| Classic SOAP service | REST service representation | New integrations |
| `Update` without concurrency token | `Update Where … And UPDTICK = …` | Custom updates |
| Hand-rolled CSV parser | IMP/EXP template (`GESAOI`) | Recurring imports |
| Scattered `ENVMAIL` calls | Workflow rule (`GESAWR`) | Event-driven notifications |

References: `v12-classes-representations.md`, `imports-exports.md`, `workflow-email.md`.

## Tier 4 — security & permissions (any code touching auth, ACL, or external data)

### 4.1 No ACL on a published service

A SOAP `GESAWE` entry or REST representation without an access code → any authenticated user can call it. Always set the access code; verify it maps to a function-profile granted only to the intended roles.

### 4.2 Trust of `callContext.codeUser` in SOAP

Legacy SOAP configs accept a body-level user override. In production this is impersonation. Disable in the AWS config.

### 4.3 SQL string built from user input without escaping

```l4g
QRY = "SELECT * FROM ITMMASTER WHERE ITMREF = '" - [L]USER_INPUT - "'"
Exec Sql QRY On 0 Into …               # SQL injection if [L]USER_INPUT contains a quote
```

Use `Exec Sql` parameter binding when available, or escape single quotes (`replace$(s, "'", "''")`) before interpolation.

### 4.4 XML interpolation without escape

`<FLD>` — `[L]VALUE` — `</FLD>` breaks if `[L]VALUE` contains `&`, `<`, or `"`. Route every interpolation through an escape helper. See `web-services-soap.md`.

### 4.5 Hardcoded credentials

API keys, passwords, tokens in `.src` files: a single deploy publishes them. Use `GESADP` / `PARAMG` parameters with encrypted storage. See `security-permissions.md`.

## Tier 5 — performance (catch early, expensive to retrofit)

### 5.1 `For` without `Order By Key` on a covering index

A `For` that filters on non-indexed fields scans the whole table. On `STOCK`, `SORDERQ`, `GACCENTRY` this is millions of rows.

`performance.md` for the index strategy and `Order By Key` syntax.

### 5.2 N+1 reads

```l4g
For [SOH] Where ORDDAT = date$
    Read [BPC]BPCNUM0 = [F:SOH]BPCORD          # extra Read per order
Next
```

Use `Link [BPC] With [F:SOH]BPCORD = [F:BPC]BPCNUM0` instead. The engine emits a join.

### 5.3 `Readlock` where `Read` would do

`Readlock` holds locks; `Read` doesn't. If you only consult, don't lock.

### 5.4 `Infbox` in a loop

Each box pauses the engine for user input. In a batch context this hangs forever. Move to a trace or a final summary.

## Tier 6 — style (nits, fix when convenient)

- Use 2-space indentation.
- Keywords in PascalCase (`If`, `For`, `Endif`, `Local`), identifiers in UPPERCASE.
- Inline comments use `:#` after the statement separator.
- Comment blocks use `#` per line, not `/* */`.
- Avoid commented-out code blocks left in place — remove before merge.
- Avoid mixed `Subprog` and `Funprog` in the same file when both serve the same function — pick one.

## Quick triage questions

For a fast first-pass read without the full checklist:

1. Does every DB op have a follow-up `If fstat`?
2. Is there a `Trbegin` / `Commit` pair around every multi-row write?
3. Is the `Readlock` released on **every** path (commit, rollback, error)?
4. Is the symbol prefixed with `Y` or `Z` if custom?
5. Does the script trace its work?
6. Is there an ACL / access code on every published service?
7. For new code, is the V12 idiom used?

If any answer is "no" without a documented reason, write the reason in the PR or fix the code.

See also: `database.md` (transactions and locks), `language-basics.md` (`Onerrgo`, parameter passing), `conventions-and-naming.md` (Y/Z rule, message chapters), `security-permissions.md` (ACL and credentials), `performance.md` (indexes and joins).

---
name: sage-x3-l4g
description: Writes, reviews, and debugs Sage X3 V12 4GL code, also called L4G, X3 script, Adonix or SAFE X3 script. Use for any Sage X3 development, configuration or customisation - .src scripts, Funprog and Subprog, Trbegin/Commit with adxlog, fstat and adxuprec checks, Read/For/Link/Update on [F:XXX] tables, Classic [M:XXX] screens and object actions, entry points (GESAPE, GPOINT), V12 classes and representations ($PROPERTIES, $EVENTS, $METHODS, fmet, NewInstance, ASETERROR), Syracuse REST and Classic SOAP web services, outgoing HTTP calls (ASYRRESTCLI), import/export templates, reports, workflow rules (GESAWA) and e-mails, batch tasks (GESABT, GESABA), activity codes and patches, messages and localisation, traces, performance, function profiles, audit and GDPR, data migration, AXUNIT unit tests, incident diagnostics, and L4G code review. Also use when pasted code shows [F:...], [M:...] or [L] prefixes or three-letter table abbreviations such as BPC, ITM, SOH. Not for Informix 4GL, OpenEdge ABL or other Sage products.
---

# Sage X3 L4G — Development Assistant (V12)

L4G ("langage de 4ème génération"), also called X3 script, 4GL, Adonix or SAFE X3 script, is the scripting language of the Sage X3 ERP. It is what you write in `.src` scripts (kept in the folder's `TRT` directory) to customise screens, control data, extend business objects, run batches and integrate X3 with other systems.

**This skill targets V12** (and V7+ generally): dictionary classes and representations, class scripts, Syracuse REST. Classic constructs (masks, object `$ACTION` scripts, `Inpbox`) are covered because they still run in V12 and most production folders contain them.

## When to use

Use this skill whenever the user:

- writes, reads, reviews or debugs a Sage X3 script, subprogram (`Subprog`, `Funprog`), class script, entry point, field action or batch treatment;
- pastes code with `[F:XXX]`, `[M:XXX]`, `[L]`, `[V]`, `[S]` prefixes, `Trbegin`, `Readlock`, `fstat`, `adxlog`, `Call … From …`, `Gosub`, `Onerrgo`, `Local File`, `fmet`, `NewInstance`, or `: #` comments — even without naming X3;
- mentions three-letter table abbreviations (`BPC`, `ITM`, `SOH`, `SOP`, `GAC`) or function codes such as GESACLA, GESAPE, GESACV, GESASU, GESAWE, GESAOE, GESAIM, GESARP, GESAWA, GESAWR, GESABT, GESABA, GESAFT, GESAFP, GESADS, TXT, APATCH;
- asks about Syracuse, representations, REST / SOAP web services, `ASYRRESTCLI`, import/export templates, reports, workflows and e-mails, batch tasks, activity codes, patches, messages, traces, performance, security, audit / GDPR, data migration, AXUNIT tests or production incidents on X3.

Do not use it for other 4GLs (Informix 4GL, OpenEdge ABL, Oracle Forms) or other Sage products (Sage 50, Sage 100, Sage 200, Sage Intacct) unless Sage X3 is explicitly involved.

## Verification discipline

L4G is poorly represented in public code, so plausible-looking but non-existent APIs are the main risk. Before writing code:

1. **Read the matching reference file** below; every reference cites the Sage online-help pages it relies on (`## Sources`).
2. **Use only keywords, functions, function codes and supervisor routines that appear in the references.** If the user needs something the references do not cover, say it must be checked in the folder (online help, the script dictionary, or the standard source) instead of guessing a name or signature.
3. **These do not exist in X3 — never write them:** `Class … Endclass` / `Public` / `Private` source syntax, `Continue`, `Exitfor`, `Incr`, `Readseq` / `Writeseq`, `replace$`, `len$`, `upper$`, `lower$`, `strip$`, `ENVMAIL`, `ECRAN_TRACE`, `AFNC.JSONGET`, `For … Order By`. The references give the real equivalents.

## Mental model

### 1. Keywords are case-insensitive; the house style is not

`For`, `FOR` and `for` are the same keyword, and identifiers are not case-sensitive either. The convention in X3 code — and in this skill — is **PascalCase keywords, UPPERCASE identifiers, 2-space indentation**.

### 2. Bracketed class prefixes tell you where a variable lives

| Prefix | Meaning | Example |
|--------|---------|---------|
| `[L]` | Local variable of the current script / subprogram | `[L]COUNT` |
| `[V]` | Global variable | `[V]CST_AOK` |
| `[S]` | System variable | `[S]fstat`, `[S]adxuprec` |
| `[F:ABV]` | Field of the table opened with abbreviation `ABV` | `[F:BPC]BPCNAM` |
| `[M:MSK]` | Field of a Classic screen (mask) | `[M:BPC0]BPCNUM` |

Prefixes are optional when unambiguous; write them anyway when the scope matters — it prevents subtle bugs in code you didn't author.

### 3. Statements, comments, continuation

`:` separates statements on one line. `#` starts a comment line; after a statement, write `: # comment`. A statement continued on the next line starts that line with `&`.

```l4g
# Full-line comment
Local Char MYTEXT(250) : # inline comment
If [S]fstat : [L]ERR = [S]fstat : Endif
Update [YACC] Where Y_ACCNUM = [L]FROM_ACC
& With Y_BALANCE -= [L]AMOUNT
```

### 4. `fstat`, `adxuprec` and `adxdlrec` are the error channel

Database instructions do not raise exceptions: they set `[S]fstat` (0 = success). `Update` also sets `[S]adxuprec` and `Delete` sets `[S]adxdlrec`, the number of rows touched — an `Update` on a missing row returns `fstat = 0` with `adxuprec = 0`. **Check `fstat` after every `Read`, `Readlock`, `Write`, `Rewrite`, `Delete`, `Update`, `Rdseq`/`Getseq`, and check `adxuprec` / `adxdlrec` when you expect a precise row count.** Opening a sequential file that fails is a runtime error, not an `fstat` value: test the path with `filinfo` or trap it with `Onerrgo`. Codes per instruction: `database.md`, `sequential-files.md`.

### 5. One transaction level, owned by whoever opened it

`adxlog` is 1 when a transaction is already open. A nested `Trbegin` is an error, so a reusable routine captures `adxlog` first and only opens / commits / rolls back when it was 0. Class events (`AINSERT_BEFORE`, `AUPDATE_AFTER`…) already run inside the supervisor's transaction: never `Trbegin` there. Details and the canonical idiom: `database.md`.

## Reference files — consult when needed

Read the file that matches the topic; don't preload them all.

### Core language

| File | When to read |
|------|--------------|
| `references/language-basics.md` | Types, declarations, parameter modes (`Value`/`Variable`/`Const`), control flow, `Break`, subprograms, `Gosub`, `Onerrgo` / `Resume` |
| `references/database.md` | `Read`, `For`, `Filter`, `Link`, `Write`/`Rewrite`/`Delete`, `Update … With`, `Readlock`, `Rewritebykey`/UPDTICK, `Execsql`, fstat / adxuprec / adxdlrec, **the transaction idiom** |
| `references/builtin-functions.md` | String, date, number and system functions: `format$`, `gdat$`, `instr`, `mid$`, `vireblc`, `ctrans`, `pat`, `filinfo`, `System` |
| `references/sequential-files.md` | `Openi`/`Openo`/`Openio`, `Rdseq`/`Wrseq`/`Getseq`/`Putseq`, `Iomode`, separators, encodings, `filpath` |
| `references/conventions-and-naming.md` | X/Y/Z prefixes, activity codes, message chapters, script and table naming |
| `references/function-codes.md` | Which GESxxx function does what (verified list) and codes that do not exist |

### Object models and UI

| File | When to read |
|------|--------------|
| `references/v12-classes-representations.md` | Router: classes vs representations vs Classic objects, Classic → V12 migration |
| `references/v12-classes.md` | Class dictionary, class scripts, `$PROPERTIES`/`$EVENTS`/`$METHODS`/`$OPERATIONS`, rules, events, instances, `fmet`, `ASETERROR` |
| `references/v12-representations.md` | Representations, facets, representation scripts and events |
| `references/classic-objects.md` | Classic objects: specific `$ACTION` scripts, creation / modification actions, `OK` / `GOK` |
| `references/entry-points.md` | Entry points (GESAPE, `GPOINT`, `GPE`) to customise standard processes without modifying them |
| `references/screens-and-masks.md` | Classic masks, `[M:...]`, field actions, `mkstat`, deprecated screen instructions |

### Integration

| File | When to read |
|------|--------------|
| `references/web-services-integration.md` | Router: REST vs SOAP vs outgoing HTTP vs files, integration log, publishing checklist |
| `references/web-services-rest.md` | Exposing X3 through Syracuse REST (`/api1/...`, representations, facets, paging, auth) |
| `references/web-services-rest-client.md` | Calling external HTTP/REST APIs from X3 (`ASYRRESTCLI.EXEC_REST_WS`), JSON with `ParseInstance` |
| `references/web-services-soap.md` | Publishing Classic SOAP web services (GESASU, GESAWE, Syracuse pools, callContext) |
| `references/web-services-soap-client.md` | Calling an external SOAP service from X3: envelope, escaping, parsing, faults |
| `references/imports-exports.md` | Import/export templates (GESAOE), running them from code, file exchange patterns |
| `references/reports-printing.md` | Reports dictionary, destinations, printing from code |
| `references/workflow-email.md` | Workflow rules (GESAWA), allocation rules, data models, sending e-mail (`ASEND_MAIL`) |

### Operations

| File | When to read |
|------|--------------|
| `references/batch-scheduling.md` | Batch tasks (GESABT), recurring tasks (GESABA), calendars, request monitoring, restart safety |
| `references/personalisation-activity.md` | Activity codes (GESACV), folder hierarchy, patches (APATCH / PATCH), personalisation |
| `references/localization.md` | Messages and `mess()`, connection language, date / number formatting |
| `references/localization-formats.md` | Currencies, countries and address formats, character sets |
| `references/data-migration.md` | Staging tables, idempotent loaders, reconciliation, cutover |
| `references/debugging-traces.md` | Log files (`ALOG` class in V7+ code, `OUVRE_TRACE`/`ECR_TRACE` in Classic), engine log, profiler, error variables, debugger |
| `references/diagnostics-postmortem.md` | Production incidents: locks, failed batches, logs, incident report template |

### Quality

| File | When to read |
|------|--------------|
| `references/performance.md` | Index-driven access, `Link` vs N+1 reads, `Columns`, transaction size, set-based SQL |
| `references/security-permissions.md` | Function profiles, access control, web-service auth, secrets, injection |
| `references/audit-compliance.md` | Audit table pattern, sequence numbers, GDPR access / erasure / portability, retention |
| `references/unit-testing-axunit.md` | AXUNIT test suites (`QLF*` scripts), assertions, running tests |
| `references/code-review-checklist.md` | Structured review pass before approving a script — red flags ranked by blast radius |
| `references/common-patterns.md` | Classic / core recipes |
| `references/common-patterns-v12.md` | V12 recipes |
| `references/version-caveats.md` | Version-dependent behaviour and what to verify on your folder before shipping |

### Examples

Ready-to-adapt scripts in `examples/` (documentation-verified, not compiled — compile in your folder first):

| File | What it shows | Explained in |
|------|---------------|--------------|
| `examples/YACCLIB.src` | Transactional YTRANSFER Funprog and ALOG negative-balance check | `database.md` |
| `examples/QLFYAC_TRANSFER.src` | AXUNIT test suite for YTRANSFER | `unit-testing-axunit.md` |
| `examples/YTRFPOST.src` | Batch posting of staging rows, per-row transactions, ALOG log | `batch-scheduling.md` |
| `examples/SPEYCU.src` | Classic object actions refusing creation or modification with OK = 0 | `classic-objects.md` |
| `examples/YSUBITM.src` | SUBITM entry point BEFWRIITF writing an audit row, GOK = 0 | `entry-points.md` |
| `examples/YCONTRACT_CSPE.src` | V12 class script: CONTROL rule, control events, ARET_VALUE method | `v12-classes.md` |
| `examples/YRESTRATE.src` | Outgoing REST call with EXEC_REST_WS, JSON parsing, integration log | `web-services-rest-client.md` |
| `examples/YIMPLAUNCH.src` | Silent import with IMPORTSIL and archiving of the imported file | `imports-exports.md` |

## How to respond to L4G requests

### When asked to write code

1. **Establish the target.** V12 entity with a class (→ class scripts) or a Classic object / screen (→ `$ACTION` script, entry point)? Standalone subprogram or batch? Ask only if it changes the answer.
2. **Respect naming.** Specific code uses the X, Y or Z prefix for scripts, tables, classes and activity codes; never modify a standard script — use an entry point or a specific class script.
3. **Transactions.** Use the idiom from `database.md`; check `fstat` (and `adxuprec` / `adxdlrec`) after each operation; keep transactions short and free of user interaction.
4. **Errors.** In class scripts report with `ASETERROR` and return a `[V]CST_A*` status; `Infbox`/`Errbox` are Classic-only.
5. **Logs.** For batches and imports, write a log file — the `ALOG` class in V7+ code (`debugging-traces.md`) — rather than screen messages.
6. **Show complete, runnable code** in house style rather than prose.

### When the user pastes code to review

Run the pass in `references/code-review-checklist.md`. Surface these first:

1. Missing `fstat` check after a database or file operation; missing `adxuprec` check after `Update` / `adxdlrec` after `Delete`
2. Transaction guard missing or inverted (`If adxlog : Trbegin`), `Trbegin` inside a class event, `Commit` without a `Rollback` path
3. Multi-table writes outside a transaction, or long loops / user interaction inside one
4. `Readlock` without a release path
5. `Onerrgo` handler that ignores `errn` / never `Resume`s or `End`s
6. Keywords or APIs that do not exist in X3 (see Verification discipline)
7. Custom symbols without X/Y/Z prefix, or standard scripts modified in place
8. Hard-coded user-facing texts instead of `mess()`
9. `Char` declared longer than 255 (use `Clbfile`)

Give the line, the reason, and the fix. Pull extra checks from `security-permissions.md` and `performance.md`.

### V12 default idioms (prefer over Classic)

- **Dictionary classes + specific class scripts** for business rules on V12 entities — `v12-classes.md`
- **Representations** for UI and REST exposure instead of new masks — `v12-representations.md`, `web-services-rest.md`
- **Entry points or class events** instead of modifying standard code — `entry-points.md`
- **`ASETERROR` + status constants** instead of `Infbox`/`Errbox`/`GESECRAN` for errors
- **`Rewritebykey` with UPDTICK** for optimistic concurrency — `database.md`
- **Import/export templates** (GESAOE) instead of hand-rolled parsers — `imports-exports.md`
- **Workflow rules** (GESAWA) or `ASEND_MAIL` for notifications — `workflow-email.md`
- **AXUNIT** tests for reusable Funprogs — `unit-testing-axunit.md`

Classic masks, object `$ACTION` scripts, SOAP and `Call … From …` are all still supported and common in existing folders: read them fluently, but don't start new developments with them when a V12 mechanism exists.

## A quick canonical example

A reusable transactional subprogram, written to be called inside or outside an existing transaction (see the `Local File` caveat in `database.md`):

```l4g
##############################################################
# YTRANSFER - Move AMOUNT from account FROM_ACC to TO_ACC
# Custom table YACCOUNT, opened as [YACC], fields Y_ACCNUM / Y_BALANCE
# Returns [V]CST_AOK on success, [V]CST_AERROR on failure.
##############################################################
Funprog YTRANSFER(FROM_ACC, TO_ACC, AMOUNT)
Value Char    FROM_ACC(), TO_ACC()
Value Decimal AMOUNT
Local Shortint TRANS_OPEN
  Local File YACCOUNT [YACC]
  If [L]AMOUNT <= 0 or [L]FROM_ACC = [L]TO_ACC : End [V]CST_AERROR : Endif
  # Open a transaction only if the caller has not already opened one
  [L]TRANS_OPEN = adxlog
  If [L]TRANS_OPEN = 0 : Trbegin [YACC] : Endif
  # Missing account or insufficient balance: fstat 0 with adxuprec 0
  Update [YACC] Where Y_ACCNUM = [L]FROM_ACC and Y_BALANCE >= [L]AMOUNT
  & With Y_BALANCE -= [L]AMOUNT
  If fstat or adxuprec <> 1
    Gosub YTRANSFER_ABORT
    End [V]CST_AERROR
  Endif
  Update [YACC] Where Y_ACCNUM = [L]TO_ACC With Y_BALANCE += [L]AMOUNT
  If fstat or adxuprec <> 1
    Gosub YTRANSFER_ABORT
    End [V]CST_AERROR
  Endif
  If [L]TRANS_OPEN = 0 : Commit : Endif
End [V]CST_AOK

$YTRANSFER_ABORT
  # fstat 1/3 on Update means the engine already rolled back; Rollback with no transaction is an error
  If [L]TRANS_OPEN = 0 and adxlog = 1 : Rollback : Endif
Return
```

Y prefix → specific code (custom fields start with `Y_`); `TRANS_OPEN = adxlog` → the caller keeps ownership of its transaction and rolls back on `CST_AERROR`; `adxuprec` → a missing account is detected instead of silently creating money. Full explanation in `database.md`; the AXUNIT test for this Funprog is in `unit-testing-axunit.md`.

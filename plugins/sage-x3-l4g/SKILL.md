---
name: sage-x3-l4g
description: Write, read, debug, and review Sage X3 V12 4GL code — also called L4G, X3 script, Adonix, or SAFE X3 scripting. Triggers on any mention of Sage X3 development, files with extensions .src, .trt, .adx, .adp, or L4G-specific syntax like [M:...], [F:...], Trbegin, Readlock, Funprog, Subprog, Class, Method, Public, Private, this, Call...From, Onerrgo, Default File, Mask, Inpbox, Infbox, Errbox, Gosub, fstat, adxlog, UPDTICK, or three-letter uppercase table abbreviations (BPC, ITM, SOH, GACC, etc.). Use this skill whenever the user asks about Sage X3 customization, specific scripts, processes, classes, representations, Syracuse, REST endpoints, actions on fields ("actions champs"), entry transactions, workflows, emails (ENVMAIL), reports (IMPRIM), imports/exports (LECFIC), web services (AWS/SOAP), debugging traces, performance / index / Order By Key tuning, security and authorisations (GESAUT, GACTION, GESAFP, function profiles, ACL), batch processing and scheduling (GESABA, GESAPL), personalisation and activity codes (GESAPE, GESACV, patches), localisation (mess, GESAML, multi-currency, multi-language), data migration / cutover / staging tables, post-mortem and incident diagnostics (adxlog.log, stuck locks, hung pools), audit trail / GDPR / compliance / retention, or code review of L4G. Also use proactively when the user pastes L4G code even without naming it — the bracketed-class syntax, French/English mixed keywords, and `:#` comments are diagnostic.
---

# Sage X3 L4G — Development Assistant (V12)

L4G (langage de 4ème génération), also called "X3 script", "4GL", "Adonix", or "SAFE X3 script", is the proprietary scripting language of the Sage X3 / Sage Enterprise Management ERP. It's what you write in `.src` (source / subprograms) and `.trt` (treatment / processing) files to customize screens, validate data, orchestrate transactions, call reports, and extend business logic on top of the X3 standard.

**This skill targets V12** (and by extension V7+), covering the modern stack: Classes, Representations, Pages, Syracuse, REST endpoints. Legacy Classic syntax (Masks, `Inpbox`) is still included because it runs unchanged in V12 and a lot of production code uses it.

This skill gives you enough context to **read, write, review, and debug** L4G correctly — avoiding the common traps that bite anyone coming from mainstream languages (C/Java/Python).

## When to use this skill

Trigger whenever the user:

- Asks to write or review a Sage X3 script, subprogram, process, or "action champ"
- Pastes code with `[M:...]`, `[F:...]`, `[V]`, `[L]`, `[S]` prefixes, `Trbegin`, `Readlock`, `Funprog`, `Subprog`, `Call ... From ...`, `Onerrgo`, `Local File`, `Mask`, `Inpbox`, `Gosub`
- Mentions Sage X3 customization, specific activity codes, personalization, vertical development, migrating Classic/V6 to V7/V12
- Mentions three-letter uppercase abbreviations in brackets (e.g. `[BPC]`, `[ITM]`, `[GACC]`, `[F:SOH]`, `[M:FNC]`) — these are standard X3 table/mask/class references
- Talks about "specific screens", "entry transactions", "screen customization", "supervisor", "GACTION", "GESAUT"

Don't trigger on generic 4GL discussions unrelated to Sage (e.g. Informix 4GL, OpenEdge ABL, Oracle Forms) unless Sage X3 is explicitly involved.

## Mental model — the essentials you must internalize

L4G is **not** a general-purpose language. It was designed around the X3 runtime ("engine" / `adonix`), which wraps the compiler, the screen manager, and the database driver. Four things make L4G look strange at first:

### 1. Everything is UPPERCASE and case-insensitive for symbols, but keywords are case-sensitive in form

Variable names like `FOO`, `Foo`, `fOo` all refer to the same symbol — the editor rewrites them as `FOO`. Keywords like `For`, `If`, `Endif`, `Local`, `Value`, `Return` are reserved words. The convention is **PascalCase for keywords, UPPERCASE for identifiers**.

### 2. Class prefixes in brackets tell you where a variable lives

| Prefix | Meaning | Example |
|--------|---------|---------|
| `[V]` | Global variable (session-wide) | `[V]GUSER` |
| `[L]` | Local variable in current script | `[L]COUNT` |
| `[S]` | System variable | `[S]fstat`, `[S]adxlog` |
| `[F:ABV]` | Field of database table `ABV` | `[F:BPC]BPCNUM` |
| `[M:MSK]` | Field of on-screen mask `MSK` | `[M:GESBPC]BPCNUM` |
| `[G:xxx]` | Metadata record for a table | `[G:BPC]NBIND` |

Omitting the prefix is allowed when unambiguous, but **always include it** when reading or writing code you didn't author — it makes scope explicit and prevents subtle bugs.

### 3. Comments use `:#` inline or `#` at start of line

```l4g
# This is a full-line comment
Local Integer I : # This is an inline comment after a statement separator
```

The colon `:` is the **statement separator** (not a line terminator like `;` in C). You can put multiple statements on one line:

```l4g
If [S]fstat : Rollback : End [V]CST_AERROR : Endif
```

### 4. `fstat` is the status code that nobody prints but everyone must check

Every database or sequential-file operation sets `[S]fstat`. Zero means success; anything else means an error occurred. **Always check `fstat` after `Read`, `Readlock`, `Write`, `Rewrite`, `Delete`, `Update`, `For`, `Openi`, `Openo`**, or you will ship silent bugs.

## Reference files — consult these when needed

This skill is organized by concern. Read the relevant reference file when you encounter its topic. Don't preload them all.

### Core language and conventions

| File | When to read |
|------|--------------|
| `references/language-basics.md` | Writing variables, types, control flow, subprograms, parameter passing, error handling |
| `references/database.md` | Any database operation: `Read`, `For`, `Trbegin`, `Commit`, `Rollback`, `Update`, `Readlock`, `Link`, `updtick`, SQL embedding |
| `references/builtin-functions.md` | String, date, numeric, and system functions: `pat`, `mid$`, `format$`, `num$`, `gdat`, `System`, `func` calls, file info |
| `references/conventions-and-naming.md` | Three-letter abbreviations, Y/Z specific-code prefixes, activity codes, file extensions, patch folders |
| `references/common-patterns.md` | Core / Classic recipes: transactional multi-table write, grid population, error handling, action-on-field, sub-prog params, batch |
| `references/common-patterns-v12.md` | V12 recipes: class with CRUD + `UPDTICK`, REST service, external REST consumption, import hook, scheduled batch + email |

### UI — Classic and V12

| File | When to read |
|------|--------------|
| `references/screens-and-masks.md` | Legacy (V6/Classic) masks still running in V12: `[M:...]`, `Inpbox`, standard actions, grids |
| `references/v12-classes-representations.md` | V12-native: `Class`/`Method`/`this`, representations, pages, business objects, `updtick`, REST surface |

### Integration and operations

| File | When to read |
|------|--------------|
| `references/web-services-integration.md` | Overview / router: protocol comparison, file exchange, integration logs, cross-cutting gotchas |
| `references/web-services-soap.md` | Publishing classic SOAP from X3 (`GESAWE` / `GESAPO`, parameter grid, AWS pool, debug table) |
| `references/web-services-soap-client.md` | Calling external SOAP services from L4G: envelope, WS-Security, escape, parsing, fault detection |
| `references/web-services-rest.md` | Publishing REST endpoints (Syracuse), consuming external REST APIs, JSON, OAuth, SData |
| `references/imports-exports.md` | IMP/EXP templates (`LECFIC`/`EXPFIC`), custom import hooks, delta sync patterns |
| `references/reports-printing.md` | Launching reports via `IMPRIM`, destinations (`GESADI`), Crystal / native states, Excel exports |
| `references/workflow-email.md` | Workflow rules (`GESAWR`), templates, recipients, sending emails (`ENVMAIL`), HTML bodies |
| `references/debugging-traces.md` | `ECRAN_TRACE`, `stat1`/`funfat`, supervisor tracing, integration logging |
| `references/performance.md` | Indexes, `Order By Key`, `Link` joins, `Read` vs `Readlock`, transaction granularity, profiling, anti-patterns |
| `references/security-permissions.md` | `GESAUT` / `GACTION` / `GESAFP`, ACL on services, credential storage, audit logging, SQL/XML/JSON injection |
| `references/batch-scheduling.md` | `GESABA` / `GESAPL`, recurrent vs one-shot, calendars, dependencies, batch monitoring (`GESALI`/`GESAEX`), pacing, restart safety |
| `references/personalisation-activity.md` | Activity codes (`GESACV`, `#Active`), personalisation (`GESAPE`), folder hierarchy, patch generation/import, override hygiene |
| `references/localization.md` | Messages (`mess`, `GESAML`), `[V]GLANGUE`, date / time formats, decimal separators, multi-language email templates |
| `references/localization-formats.md` | Currencies (`GESCUR`, `GDEV.DEVISE`), country addresses (`GESACO` / `FORMAT_ADDR`), RTL / CJK / UTF-8 |
| `references/data-migration.md` | One-shot loads, staging tables, validation / load / reconcile / cutover, dual-write, schema migration, folder consolidation |
| `references/diagnostics-postmortem.md` | Reading `adxlog.log`, stuck locks, hung AWS pool, batch failures, engine crashes, incident report template |
| `references/audit-compliance.md` | Audit log table pattern, GDPR access / erasure / portability, financial audit trail, retention policies, consent tracking |

### Meta

| File | When to read |
|------|--------------|
| `references/code-review-checklist.md` | Structured pass before approving a `.src` / `.trt` change — consolidated red flags ranked by blast radius |
| `references/version-caveats.md` | Before copy-pasting a snippet to production — which primitives / helpers / URLs drift across V12 patch levels and what to verify |

## How to respond to L4G requests

### When the user asks you to write code

1. **Clarify the context first.** "Is this for a V6/Classic or V7/V12 target? Standard folder or X3 custom?" — V7 syntax (`Funprog`, classes, `Method`) differs materially from V6.
2. **Always respect naming conventions.** Custom (specific) code uses `Y` or `Z` prefix for symbols, tables, screens, messages — never overwrite standard X3 names.
3. **Wrap database writes in a transaction.** `Trbegin` / `Commit` / `Rollback`, with `fstat` checks after each operation. See `references/database.md`.
4. **Use the `If adxlog` idiom** when your subprogram may be called inside or outside an existing transaction — let the caller own the transaction if it already started one.
5. **Include traces** for non-trivial logic: `Call ECRAN_TRACE("msg") From GESECRAN` or `Infbox "..."` during development, removed or gated before production.
6. **Format output like real X3 code**: PascalCase keywords, UPPERCASE identifiers, indentation with spaces, `:#` inline comments.

### When the user pastes code to review

Run the structured pass in `references/code-review-checklist.md` — it covers correctness, conventions, V12 idioms, security, performance, and style, ranked by blast radius. The headline red flags to surface first:

1. Missing `fstat` check after a database or file operation
2. `Write` / `Rewrite` / `Delete` without `Trbegin` … `Commit` / `Rollback`
3. `Readlock` without a matching release path (commit, rollback, or explicit unlock)
4. Long-running loops inside a `Trbegin` block → **deadlock risk**, the engine holds locks until commit
5. `Onerrgo` without a reachable recovery label
6. Hard-coded folder names (`GESBPC` vs `ZGESBPC`) or language-dependent strings — should use `mess(n, chapter, 1)`
7. Custom code that overwrites a standard symbol (no `Y`/`Z` prefix)
8. `Goto` across subprogram boundaries (legal but almost always a bug)
9. `Next` used on a `For` loop that was modified inside the loop body

State each issue with the exact line, explain why it's a problem, and propose the fix. Pull from `code-review-checklist.md`, `security-permissions.md`, and `performance.md` for the full set of checks.

### V12 default idioms (prefer over Classic)

When writing new code, reach for the V12 idiom unless the user is explicitly extending Classic code:

- **Classes + `this`** instead of free-floating `Subprog` globals, for anything with state or more than one step — see `references/v12-classes-representations.md`
- **Representations + pages** instead of `Mask` + `Inpbox` for any new UI
- **REST services** (class-backed service representations) instead of classic SOAP for new integrations
- **`UPDTICK`** in `Where` clauses for optimistic concurrency on custom `Update` / `Rewrite`
- **IMP/EXP templates** (dictionary-driven) instead of hand-rolled file parsers — see `references/imports-exports.md`
- **Workflow rules** (`GESAWR`) instead of scattered email-sending code — see `references/workflow-email.md`

Classic `Mask`, `Inpbox`, SOAP, and `Call … From …` are all still supported and frequently encountered in existing code. Read it fluently, but don't reach for it when starting fresh.

### When the user asks about V6 → V12 migration

Key shifts to mention:

- `Subprog` / `Funprog` remain, but classes (`Class`, `Method`, `Public`, `Private`, `this`) are the V12 idiom
- The classic `Mask` / `Inpbox` UI is superseded by Representations + Pages rendered by Syracuse, but legacy screens still run
- `Local File TBL` is replaced in V12 code by dependency-injected classes where possible — the DB primitives underneath (`Read`, `For`) are unchanged
- `UPDTICK` column and snapshot patterns are the V12 concurrency helpers
- Every published representation gets a generated REST API under `/api/x3/erp/<folder>/<object>` — SOAP web services remain for backwards compat

Full detail in `references/v12-classes-representations.md`.

## A quick canonical example

A typical transactional subprogram looks like this:

```l4g
##############################################################
# YTRANSFER - Transfer AMOUNT from ACCOUNT1 to ACCOUNT2
# Returns [V]CST_AOK on success, [V]CST_AERROR on failure.
##############################################################
Funprog YTRANSFER(ACCOUNT1, ACCOUNT2, AMOUNT)
Value Char     ACCOUNT1(), ACCOUNT2()
Value Decimal  AMOUNT
Local  Integer IF_TRANS

Local File ACCOUNT [ACC]

# Start a transaction only if none is already in progress
If adxlog
    Trbegin [ACC]
    IF_TRANS = 0
Else
    IF_TRANS = 1
Endif

# Debit
Update ACCOUNT Where CODE = ACCOUNT1 With BALANCE = BALANCE - AMOUNT
If fstat
    If IF_TRANS = 0 : Rollback : Endif
    End [V]CST_AERROR
Endif

# Credit
Update ACCOUNT Where CODE = ACCOUNT2 With BALANCE = BALANCE + AMOUNT
If fstat
    If IF_TRANS = 0 : Rollback : Endif
    End [V]CST_AERROR
Endif

If IF_TRANS = 0 : Commit : Endif
End [V]CST_AOK
```

Note: `Y` prefix → custom code; `adxlog` guard → nested-transaction safety; `fstat` check after each DB op → correct; two-space indent + PascalCase keywords → house style.

---

That's the tour. Load the relevant reference file(s) when a specific topic comes up, and always prefer to **show a complete, runnable example** over prose description — L4G is a language people learn by reading, not by theory.

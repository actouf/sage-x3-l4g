# Code review checklist

A structured review pass for L4G code, ordered by blast radius: first what corrupts or loses data,
then transactions, identifiers that do not exist, V12 idioms, security, performance and finally
style. Each item gives the symptom to look for, why it matters and the fix, with the reference that
explains it. Use it on pull requests, patches (APATCH) and pasted snippets.

## Contents
- [How to run the pass](#how-to-run-the-pass)
- [1. Correctness](#1-correctness)
- [2. Transactions and locks](#2-transactions-and-locks)
- [3. Identifiers that do not exist](#3-identifiers-that-do-not-exist)
- [4. V12 idioms and customisation hygiene](#4-v12-idioms-and-customisation-hygiene)
- [5. Security](#5-security)
- [6. Performance](#6-performance)
- [7. Style](#7-style)
- [Gotchas](#gotchas)
- [Sources](#sources)

## How to run the pass

1. Identify the context of each routine: Classic object action, entry point, class event or
   method, batch action, web service, library. The context decides who owns the transaction and
   whether a user can see a message.
2. Walk the tiers in order. Items in tiers 1-3 block the merge; tier 4-6 items need a fix or a
   written reason; tier 7 is cleanup.
3. Report each finding with its item code (C2, T4...), the line and the fix.
4. Compile the scripts and run the AXUNIT suites of the area in a test folder
   (`unit-testing-axunit.md`).

## 1. Correctness

| # | Symptom | Why it matters | Fix |
|---|---|---|---|
| C1 | `Read`, `Readlock`, `Write`, `Rewrite`, `Delete`, `Rdseq` with no `fstat` test after it | The code carries on with a stale `[F:ABV]` buffer or a row that was never written | Test `fstat` right after, against `[V]CST_*` constants (`database.md`) |
| C2 | `Update` / `Delete ... Where` meant for one row, checked with `If fstat` only | No matching row gives fstat 0 with `adxuprec` / `adxdlrec` = 0 | `If fstat or adxuprec <> 1` (`adxdlrec` for `Delete`) |
| C3 | `fstat` tested after `Next`, or after another statement than the one meant | fstat is 4 at the end of a `For`; every DB or file statement overwrites it | Copy it to a local right after the instruction (`common-patterns.md`) |
| C4 | `Write` without `Raz [F:ABV]` before filling the buffer | Values of the last `Read` are written into the new row | `Raz [F:ABV]` first |
| C5 | The word after `[ABV]` in `Read` / `For` / `Delete` is a column (`BPCNUM0`, `[BPC]BPCNUM`) | Error 21 (unknown key) at run time | Dictionary index name (`BPC0`) from GESATB (`conventions-and-naming.md`) |
| C6 | `Funprog` ending with bare `End`; constant passed to a `Variable` / `Const` parameter | Runtime errors | `End VALUE`; pass a variable or declare the parameter `Value` (`language-basics.md`) |
| C7 | `Local Integer TAB(10)` used as 1..10 | Indexes are 0..9 | `TAB(1..10)` |
| C8 | `Char` used for long text, `Char X(4000)` | `Char` stops at 255 characters and truncates silently | `Clbfile` + `Append` |
| C9 | Amounts in `Float` / `Double`, `round(...)` | Precision loss; `round` does not exist | `Decimal`, `ar2` / `arr` (`builtin-functions.md`) |
| C10 | `right$(S, N)` used for "last N characters"; `val("12,50")` | `right$` starts at position N; `val` stops at the comma | `right$(S, len(S) - N + 1)`; `ctrans(S, ",", ".")` before `val` |
| C11 | `Case` with `Default`, or a comment between `Case` and the first `When` | Not allowed by the grammar (`language-basics.md`) | `When Default` as the last branch; nothing before the first `When` |
| C12 | A `Rdseq` loop ending with `Until fstat` while the body writes to the database | fstat comes from the last write, not from the read | Save the read status in a local (`sequential-files.md`) |
| C13 | `func` called inside a `Where` clause | Not allowed in a `Where` | Compute the value into a local before the statement (`database.md`) |

## 2. Transactions and locks

| # | Symptom | Why it matters | Fix |
|---|---|---|---|
| T1 | Writes with no transaction (no `Trbegin` at any level, `adxlog` = 0) | Sage requires writes to run in a transaction | `adxlog` idiom (`database.md`) |
| T2 | `If adxlog : Trbegin`, or the samples of the trbegin / commit / rollback / delete pages copied | Inverted test: opens a transaction when one runs (error 49) and none when needed | `[L]TRANS_OPEN = adxlog` then `If [L]TRANS_OPEN = 0 : Trbegin ... : Endif` |
| T3 | Unconditional `Trbegin` in a routine that can be called from a transaction | Error 49 "transaction already in progress" | Same idiom; or refuse to run when `adxlog <> 0` (per-row batches) |
| T4 | `Rollback` after a failed `Update` without an `adxlog = 1` guard | fstat 1 / 3 on `Update` already rolled back; `Rollback` with no transaction is error 48 | `If [L]TRANS_OPEN = 0 and adxlog = 1 : Rollback : Endif` |
| T5 | A routine that did not open the transaction calls `Commit` / `Rollback` | Breaks the caller's atomicity; error 32 at the wrong call level | Return a status; the level that ran `Trbegin` closes it |
| T6 | `Trbegin` / `Commit` / `Rollback` in class events, in object actions that run inside the transaction (`INICRE`, `CREATION`, `MODIF`...), in entry points documented "transaction in progress", in workflow actions of Object rules | The supervisor or template owns the transaction | `ASETERROR` + `ASTATUS` (`v12-classes.md`), `GOK = 0` (`classic-objects.md`, `entry-points.md`) |
| T7 | One `Trbegin` around a whole batch loop | Error 43 (too many locks), all-or-nothing rerun, long locks | Commit per row or per chunk (`common-patterns.md`, `batch-scheduling.md`) |
| T8 | Dialog box, `Sleep`, HTTP call or file wait between `Trbegin` and `Commit` | Locks held for the whole wait | Do it before or after the transaction (`performance.md`) |
| T9 | Integration or error log recording a failure written inside the business transaction | The log row disappears with the `Rollback` it should explain | Write it after `Commit` / `Rollback` (`web-services-integration.md`). Audit rows describing the change itself belong inside the transaction (`audit-compliance.md`) |
| T10 | `UPDTICK` assigned in code | Maintained by the database | Never assign it; `Rewritebykey` / `Deletebykey` for optimistic locking |
| T11 | `Readlock` without `With lockwait = 0`, or with a negative one | Default wait undocumented; a negative value waits without limit | `With lockwait = 0`, roll back, wait, retry |
| T12 | Writes in `*_CONTROL_*` events or CONTROL rules | No transaction there; Sage forbids updates | Move them to `AINSERT_BEFORE` / `AUPDATE_AFTER`... |

## 3. Identifiers that do not exist

Earlier versions of this skill, and generated code in general, used names that are not X3 or are not documented. Any of
these in code is a blocker; replace it with the real equivalent.

| Invented identifier | Real equivalent | Reference |
|---|---|---|
| `Readseq`, `Writeseq`, `Close 1`, `Using 1`, `fstat = 100` at end of file | `Rdseq`, `Wrseq`; close with `Openi` / `Openo` without path; `Using [ABV]`; end of file = fstat 1 | `sequential-files.md` |
| `Continue`, `Exitfor`, `Exit`, `Incr`, `Decr`, `Onerrgo 0` | `Break` / `Break N`, wrap the rest of the body in `If`; `+= 1` / `-= 1`; `Onerrgo` alone | `language-basics.md` |
| `Class ... Endclass`, `Public`, `Private`, `Extends`, `super` | Class dictionary (GESACLA) + `<CLASS>_CSPE` script with `$EVENTS` / `$PROPERTIES` / `$METHODS` | `v12-classes.md` |
| `afterLoad`, `beforeSave` events | `AREAD_AFTER`, `AINSERT_BEFORE` / `AUPDATE_BEFORE` | `v12-classes.md` |
| `If adxlog : Trbegin` | `[L]TRANS_OPEN = adxlog` idiom | `database.md` |
| `For ... Order By`, `Top N`, `Exec Sql ... On 0 Into`, `Update TABLENAME` | `Order By` on `Local File` / `Filter` / `Link`; count and `Break`; `For (...) From DB Sql ... As [ABV]` / `Execsql`; `Update [ABV] Where ... With` | `database.md` |
| `replace$`, `len$`, `upper$`, `lower$`, `strip$`, `round`, `num$(X, FMT)`, `gdat(Y, M, D)` | `instr` loop, `len`, `toupper`, `tolower`, `vireblc`, `arr` / `ar2`, `format$(FMT, X)`, `gdat$(D, M, Y)` | `builtin-functions.md` |
| `ECRAN_TRACE`; `stat1` or `funfat` as error codes | `ECR_TRACE(MSG, FLAG) From GESECRAN` (community-reported) or the `ALOG` class; `fstat` / `errn` | `debugging-traces.md` |
| `ENVMAIL`, `ENVMAILHTML From AMAIL`, `ASYRMAILAPI` | `func ASYRMAIL.ASEND_MAIL(...)` | `workflow-email.md` |
| `IMPRIM`, `IMPRIM0 From GIMP` | `Call ETAT(...) From AIMP3` (argument list community-reported) | `reports-printing.md` |
| `LECFIC From IMPOBJ`, `EXPFIC`, `LANCEXP` | `Call IMPORTSIL(TEMPLATE, FILE) From GIMPOBJ`; `AOWSEXPORT` | `imports-exports.md` |
| `AFNC.JSONGET`, `AFNC.JSONSET`, `AFNC.XMLGET`, `ASYSTEM.ParseJson` | `ParseInstance` + `Select$` / `Contains$` | `web-services-rest-client.md` |
| `AFNC.PARAMG(...)`, `GDEV.DEVISE`, `FORMAT_ADDR` | `fmet GACTX.APARAM.AGETVALNUM(LEVEL, KEY, PARAM)` and sibling getters; currency cache | `localization-formats.md`, `database.md` |
| `NUMERO ... From GESNUM` | `func ANM_TOOL.NUMERO(ACTX, COUNTER, FCY, DAT, COMP, VAL, ERRMS)` inside a transaction; counters defined in GESANM (GESACM is the supervisor `[C]` counters) | `audit-compliance.md`, `function-codes.md` |
| `#Active ... #End`, `$ACT = ... $FIN` | Activity codes on dictionary elements (no conditional compilation) | `conventions-and-naming.md` |
| Index names `BPCNUM0`, `ITMREF0`, `SOHNUM0`; abbreviation `[GACC]` | `BPC0`, `ITM0`, `SOH0`; `[GAC]` | `conventions-and-naming.md` |
| `[V]GFOLDER`, `[V]GROLE`; `[V]GUSER` in class code | `nomap` / `GACTX.AFOLDER`; `GACTX.USER` (`GUSER` stays valid in Classic code) | `security-permissions.md` |
| Object actions `AVBAS`, `APBAS`, `ANNUL`, `DEBSAI`, `FINSAI` | `VERIF_CRE`, `INICRE`, `CREATION`, `VERIF_MOD`, `MODIF`, `VERF_ANU`... | `classic-objects.md` |
| `/api/x3/erp/...` | `/api1/x3/erp/<ENDPOINT>/<CLASS>?representation=<REP>.$<facet>` | `web-services-rest.md` |
| `CRBATCH From GESBAT`; codes GESAPL, GESAOI, GESAUT, GESAML, GESAPA, GESVAL, GESCUR, GESAWS, GESAWT | GESABT / GESABA / EXERQT; the codes in the "do not exist" table | `batch-scheduling.md`, `function-codes.md` |

## 4. V12 idioms and customisation hygiene

| # | Symptom | Why it matters | Fix |
|---|---|---|---|
| V1 | `$ACTION` / `Case ACTION` in a class or representation script | Split into four labels; announced deprecated in V12 | `$EVENTS`, `$PROPERTIES`, `$METHODS`, `$OPERATIONS` (`v12-classes.md`) |
| V2 | `Infbox`, `Errbox`, `Inpbox`, masks or `GESECRAN` errors in class code, web services or batch | Deprecated in V7 mode; no user in service or batch mode | `ASETERROR` + `ASTATUS`; `ALOG` in batch |
| V3 | `fmet this.ASETERROR(...)` whose result is not assigned to `[L]ASTATUS` | The supervisor decides on `ASTATUS`; the operation goes on | `[L]ASTATUS = fmet this.ASETERROR(...)` |
| V4 | Literal texts in errors and logs shown to users | Not translated | `mess(N, CHAPTER, 1)` (`localization.md`) |
| V5 | `NewInstance` without `FreeGroup` on every path; instance built in code without `AINIT()` | Memory leak in batches; INIT rules never run | `FreeGroup`; `fmet INST.AINIT()` (`common-patterns-v12.md`) |
| V6 | Classic globals in class code | Listed by Sage's class guide among what not to use | `this.ACTX` / `GACTX` (user, folder, language) |
| V7 | `OUVRE_TRACE` / `ECR_TRACE` in new V7+ code | Sage directs V7+ code to `ALOG` | `ALOG` (`debugging-traces.md`) |
| V8 | Edits in generated (`C_*`, `W*`, `GES<OBJ>`) or standard (`SUB<OBJ>`) scripts | Overwritten by validation or patches | `_CSPE` scripts, `SPE<OBJ>` actions, GESAPE entry points |
| V9 | A specific script carrying the name of a standard one | Shadows the standard copy: later patches are silently bypassed | Specific name + the hooks above (`personalisation-activity.md`) |
| V10 | Specific dictionary elements without an X/Y/Z activity code; codes longer than 5 characters | Treated as standard by patch tools; invalid code | Activity code on every element (`conventions-and-naming.md`) |
| V11 | Direct `Write` / `Update` on standard business tables (`STOCK`, `SORDER`, `GACCOUNT`...) | Bypasses the controls and related updates of the standard | Standard functions, import templates, web services (`common-patterns-v12.md`) |

## 5. Security

| # | Symptom | Why it matters | Fix |
|---|---|---|---|
| S1 | Passwords, API keys or tokens in scripts, `Value` defaults, URLs, logs | Readable by anyone with source or log access | Outgoing REST web service record; never log secrets (`security-permissions.md`) |
| S2 | `Execsql` / `Sql` text built from input; `evalue` or `Execsql` of partner data | SQL / code injection | L4G `Where` with variables; else whitelist identifiers and double quotes |
| S3 | JSON or XML built by plain concatenation | Broken payloads, injection | `escjson`; XML escape helper (`web-services-soap-client.md`) |
| S4 | Rights checked by comparing user codes | Bypass and maintenance burden | User function profiles (GESAFT) and their functional authorizations (GESAFP); `AGETAFCRIGHT` in V12 code |
| S5 | SOAP `codeUser` trusted; broad technical users for web services | `codeUser` is ignored; over-privileged accounts | Dedicated Syracuse user with a minimal profile (`web-services-integration.md`) |
| S6 | Personal data or full payloads in TRA logs or `YINTLOG` | Visible to every LECTRACE user; GDPR | Strip or mask before logging (`audit-compliance.md`) |
| S7 | `Dbgaff` / `dbgmode` left in delivered code | Hands sessions to the debugger | Remove; grep before building a patch |
| S8 | Hard-coded folder names, absolute paths, `System` commands built from input | Breaks on folder copy; crosses folders; shell injection | `nomap`, `filpath`, `checkpath`, `renamefile` / `delfile` |

## 6. Performance

| # | Symptom | Why it matters | Fix |
|---|---|---|---|
| P1 | `Read` of a parent row inside a `For` | One SQL round trip per row | `Link` + `Columns` (`performance.md`) |
| P2 | `pat(COL, ...)` without `<> 0`, date arithmetic or date functions on columns in `Where` | Filtered by the engine after fetching every row | `pat(...) <> 0`; pre-computed bounds |
| P3 | `For [ABV]` followed by an `If` on columns | Fetches the whole table | Put the condition in `Where` |
| P4 | Loops over wide tables loading every column | Useless I/O | `Columns [ABV](...)` |
| P5 | `Readlock` on read-only paths, `For ... With Lock`, `Readlock` / `Rewrite` loops for a uniform change | Contention, lock storms | `Read`; `Update ... Where ... With` |
| P6 | Parameter or setup reads inside a hot loop | Repeated identical queries | Read once before the loop |
| P7 | Frequent sorts on a non-indexed order; hints added "just in case" | Full sorts; frozen plans | Index in GESATB; measure before hinting |
| P8 | `openlog` or Engine trace left on; `AFLUSHLOG` after every line | Disk and CPU cost | Short diagnostic windows (`debugging-traces.md`) |

## 7. Style

- PascalCase keywords, UPPERCASE identifiers, 2-space indentation, no tabs; `: #` for inline
  comments, `&` at the start of continuation lines (`language-basics.md`).
- Explicit class prefixes in shared code: `[L]`, `[V]`, `[F:ABV]`, `[M:MASK]`.
- Y (or X/Z) prefix on every custom script, table, class, local symbol of a library, activity code
  and specific field on a standard table (`Y_`); messages in chapters 160-164 / 6000-6199, local
  menus 6200-6999 (`conventions-and-naming.md`).
- A header comment on each script and public routine: purpose, parameters, status returned.
- `Local File` at the start of each routine (plain `File` is deprecated); no `Local` declarations
  in labels reached by `Gosub`; no `Goto`.
- Library `Funprog` returning a status, error text in a `Variable` parameter.

## Gotchas

- Sage's own samples are not always right: the trbegin / commit / rollback / delete pages invert the
  `adxlog` test and several `Iomode` samples loop on `Until fstat=0` (`version-caveats.md`).
- A blocker in tier 3 often hides tier 1-2 issues around it: re-read the whole routine after the fix.
- Entry points and batch actions run inside standard programs: a `Local` in their label can clash
  with the standard's own variables.

See also: `common-patterns.md`, `common-patterns-v12.md`, `version-caveats.md`, `database.md`,
`performance.md`, `security-permissions.md`, `unit-testing-axunit.md`.

## Sources
- https://online-help.sagex3.com/erp/12/en-us/Content/V7DEV/4gl_fstat.html
- https://online-help.sagex3.com/erp/12/en-us/Content/V7DEV/4gl_adxlog.html
- https://online-help.sagex3.com/erp/12/en-us/Content/V7DEV/4gl_trbegin.html
- https://online-help.sagex3.com/erp/12/en-us/Content/V7DEV/4gl_update.html
- https://online-help.sagex3.com/erp/12/en-us/Content/V7DEV/4gl_x3script-keywords-glossary.html
- https://online-help.sagex3.com/erp/12/en-us/Content/V7DEV/4gl_glossary.html
- https://online-help.sagex3.com/erp/12/en-us/Content/V7DEV/developer-guide_classes-events.html
- https://online-help.sagex3.com/erp/12/en-us/Content/V7DEV/developer-guide_event-control.html
- https://online-help.sagex3.com/erp/12/en-us/Content/V7DEV/developer-guide_managing-log-files.html
- https://online-help.sagex3.com/erp/12/en-us/Content/V7DEV/getting-started_security-best-practices.html
- https://online-help.sagex3.com/erp/12/en-us/Content/MODEL/act_creation.htm

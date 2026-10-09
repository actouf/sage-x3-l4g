# Version caveats and documentation inconsistencies

What depends on the release, patch level or runtime of the folder, where Sage's own documentation
contradicts itself, what is not documented at all, and what to verify on your folder before shipping.
Every row cites its source; "community-reported" means a Sage Community Hub or partner source, not
the online help. When no source gives a version, none is given: there is no patch table here.

## Contents
- [Features tied to a release](#features-tied-to-a-release)
- [Documentation inconsistencies](#documentation-inconsistencies)
- [Undocumented behaviour to test](#undocumented-behaviour-to-test)
- [Upgrade hazards](#upgrade-hazards)
- [Verify on your folder before shipping](#verify-on-your-folder-before-shipping)
- [Gotchas](#gotchas)
- [Sources](#sources)

## Features tied to a release

| Feature | Available from | Status | Source |
|---|---|---|---|
| `func ASYRRESTCLI.EXEC_REST_WS` (outgoing REST) | 7.1 ("not available in version 7.0 used for early adopters") | Online help | api-guide_api-asyrrestcli |
| `EXEC_REST_WSCLB` (Clbfile headers and parameters, long bearer tokens) | V11 patch 17, V12 patch 23 (2020 R3) | Community-reported (cites Sage KB 116342); not in the online help | Community Hub thread 182920 |
| `ParseInstance`, `Select$`, `Contains$` (native JSON) | Announced in the V12.34 release notes; a reply says "available since 2023R2"; another user found them missing from a 2023 R2 runtime (96.1.206); "it also depends on the version of the X3 runtime" | Pages exist in the V12 4GL help without a version; availability community-reported | Community Hub thread 212042 |
| AXUNIT `LOG_CLASS` (dump an instance) | "From patch 6" | Online help | how-to_how-to-use-axunit |
| Hybrid development (Classic window, CRUD in a class) | X3 Update 9 | Online help | developer-guide_hybrid-development |
| Class script labels `$EVENTS` / `$PROPERTIES` / `$METHODS` / `$OPERATIONS` | Old `$PROPERTIES` / `$ACTION` dispatch "still usable in U10, but they will be deprecated in V12" | Online help | developer-guide_classes-events |
| Standard product updates through the **Updates** function | 2019 R4 and later; PATCH stays for add-ons, bespoke code and older releases (patches applied in order) | Online help | FCT/PATCH |
| Session information page (replaces three session functions) | 2021 R1 (V12 patch 25), refined in R2 / R3 | Community-reported (Sage support blog) | Support insights post on session information |
| X3 session logs of type "Batch query" | 2021 R3 | Community-reported (Sage support blog) | Support insights post on the batch server |
| HTML workflow e-mails as a standard feature | 2022 R2 (V12 patch 30) | Community-reported | Community Hub thread 200055 |
| ASYRREQMAN search / sort / filter and the "Classic function" action | 2025 R1 / V12.0.37 | Online help | FCT/ASYRREQMAN |
| Print-job load balancing over several print servers (APRSRVLST) | 2025 R1 / V12.0.37 | Online help | FCT/GESAIM |
| AREADLOG (V7-style log reading) | Not stated (the page calls it an update of LECTRACE) | Online help | administration-reference_supervisor-administration-log-file-management |

Where each feature is used: `web-services-rest-client.md`, `unit-testing-axunit.md`,
`v12-classes.md`, `classic-objects.md`, `personalisation-activity.md`, `diagnostics-postmortem.md`,
`batch-scheduling.md`, `workflow-email.md`, `reports-printing.md`, `debugging-traces.md`.

## Documentation inconsistencies

| Topic | What the help says | What this skill does |
|---|---|---|
| `adxlog` transaction test | The samples of 4gl_trbegin, 4gl_commit, 4gl_rollback and 4gl_delete open a transaction when one is already running; 4gl_adxlog and the best-practice how-to are right | Canonical idiom of `database.md` |
| Sequential-file sample loops | 4gl_iomode, 4gl_adxifs, 4gl_adxirs, 4gl_adxseek loop `Until fstat=0` (stop after one line), one sets `adxifs` where `adxirs` is meant; the 4gl_adxium loop is right | `sequential-files.md` loop |
| Method return variable | developer-guide_classes-events prose writes `ARETVALUE`; GESACLA, the error-handling guide and the samples use `ARET_VALUE` | `[L]ARET_VALUE` |
| Error deletion method | `ADELETEERROR(PROPERTY)` (classes-events, V7 tip) vs `ADELETERROR(PROPERTY)` / `ADELETERRORALL()` (developer-guide_error-handling) | Check the generated class |
| fstat 7 | 4gl_rewritebykey: "Record does not exist"; 4gl_fstat: `CST_ARECTICKDEL`, "Delete conflict: the line no longer exists with the right updtick value" | Treat 6 and 7 as concurrent changes: re-read, retry or report |
| `format$` day mask | The 4gl_format$ sample `"D:[The ]DD[th Of ]..."` renders day 5 as "5", while `DZ:DD[/]MM[/]YY` reads as a fixed-width mask | Fixed-width output uses `2D` / `2M` / `4Y` (`builtin-functions.md`) |
| Meaning of X / Y / Z | Naming guide: X add-on, Y/Z specific; GESACV field help: X partner add-on, Y vertical, Z specific; GESACV introduction: X vertical, Y/Z custom | One letter per delivery layer (`conventions-and-naming.md`) |
| Exchange-rate direction | TABCHANGE field `CURDEN` is "Destination currency" in the dictionary and "Source currency" on the FUNCURRAT screen | Check the direction on a known pair (`localization-formats.md`) |
| Rights check sample | developer-guide_access-rights sample misspells `AGETAFCRIFGRC` and omits the site argument | Follow the method table (`security-permissions.md`) |
| `Local File` inside a transaction | 4gl_file: "You can open a file with Local File within a transaction, but files opened in write mode by Trbegin will no longer be accessible" — without saying whether nested calls are concerned | Declare the caller's tables before `Trbegin`; called routines open their own; test it (checklist below) |
| Classic refusal message | MODEL/VERIF_CRE documents only `OK = 0`; the hybrid guide sets `GMESSAGE`, `GOK = 0`, `GERR = 1` and says the function returning the message "will be available soon" | `GMESSAGE` + `OK = 0`, verified on screen (`classic-objects.md`) |
| SUBITM entry points | ADC_SUBITM gives BEFWRIITF the same variables as ITMNUM ("Number": new product reference) and lists no table for CREITF; variable names are translated between language versions | Use only `[F:ITM]` and `GOK` (`entry-points.md`) |
| Function codes without a function page | GESASW (Representations) is stated on the workbench page only; the developer guide names a context dictionary "GESACTX"; neither has an `FCT/<CODE>.htm` page | GESASW as stated by the workbench page; GESACTX not cited (`function-codes.md`) |
| Closing the silent-import trace | GES_AOE1 sample: `Call CLOSE_LOC From LECFIC`; the AREADLOG page and community code: `FERME_TRACE` | Sage's sample after `IMPORTSIL` (`imports-exports.md`), `FERME_TRACE` elsewhere (`debugging-traces.md`) |
| Representation script ranks | The representation events page reserves ranks that are multiples of 100 for standard extensions; the class page says 1000 | A specific rank such as 1050 (`v12-representations.md`) |
| Parameter level at folder level | The context-parameters page defines `TYPVAL` as the folder / legislation / company / site code and lists error 4 "TYPVAL empty"; Sage's own `TYPDBA` sample passes `""` with `CST_ALEVFOLD` | Sage's sample; check the error code on your folder (`data-dictionary.md`) |
| Class script layout | Some how-to pages show `$METHODS` + `Case ACTION` for events | Four-label layout (`v12-classes.md`) |

## Undocumented behaviour to test

- The value of `adxlog` right after an `Update` that returned fstat 1 or 3 (the engine has rolled
  back): guard every `Rollback` with `adxlog = 1` (`database.md`). `examples/YTRFPOST.src` and the
  per-row recipe of `common-patterns.md` also rely on it being 0 to tell an engine rollback from a
  business refusal — test both cases on your folder.
- `Commit` / `Rollback` inside a `For` loop: 4gl_for only shows a transaction opened before the loop
  and closed after `Next`, and 4gl_commit says nothing about open cursors. The per-row transactions
  of `examples/YTRFPOST.src` and `common-patterns.md` commit inside the loop on a second abbreviation:
  test that the cursor survives on your database before relying on it.
- `EXEC_REST_WS`: no timeout is documented; a Sage-verified community answer states that it accepts
  and returns JSON only; header and parameter values are `Char` (255 characters).
- `ASEND_MAIL`: no HTML option is documented, nor whether it goes through the notification server
  when SYRMAIL = Yes (`workflow-email.md`).
- `GERRBATCH`: the scale that turns a request status into Warning is not documented
  (`batch-scheduling.md`).
- `[M:IMP2]STAT` values after `IMPORTSIL` are not listed (`imports-exports.md`).
- Community-reported only: the argument list of `Call ETAT(...) From AIMP3`, `AOWSEXPORT` and
  `EXPORTSIL` called from L4G, the `GPOINT = "..." : Gosub ENTREE From EXEFNC` call form, the
  `AM_<FIELD>` field-action prefix, the SOAP input layout of published subprograms, and the `.src` /
  `.adx` file extensions (`.trt` is not documented).

## Upgrade hazards

Community-reported cases worth a regression test after each upgrade:
- Entry point `MODTRTEXP` is no longer called in `SUBEXPOBJ` after the V12 import/export changes:
  it moved to the `AEXPPROCESS` process, so the GESAPE line must be re-declared (`entry-points.md`).
- A customised p31 copy of `SUBSOHA` left in a customer folder made sales-order entry fail after the
  upgrade to V12 p37, until the copy was removed (`personalisation-activity.md`).
- `Select$` returned nothing in a batch run on JSON containing accented characters, while the same
  script worked interactively (`web-services-rest-client.md`).

## Verify on your folder before shipping

- [ ] Record the release, patch level (GESAPT patch history) and runtime version of every target folder.
- [ ] For each supervisor API you call (`ASYRRESTCLI`, `ASYRMAIL`, `ANM_TOOL`, `GIMPOBJ`, `AIMP3`...),
      open the script and check the signature you use.
- [ ] Compile a three-line `ParseInstance` / `Select$` test before relying on the JSON parser, and
      check that `EXEC_REST_WSCLB` exists if a token exceeds 255 characters.
- [ ] For every entry point you implement, search the standard script for its `GPOINT` call.
- [ ] In each generated class you use, confirm the spelling of the error-deletion method.
- [ ] For every routine called inside a caller's transaction that declares its own `Local File`
      (YTRANSFER, entry-point helpers), check that the caller's tables stay usable after the call
      (4gl_file.html: "files opened in write mode by Trbegin will no longer be accessible").
      `examples/QLFYAC_TRANSFER.src` (case `YTC_CALLER_TRANSACTION`) is a starting point.
- [ ] Trigger each Classic refusal (`OK = 0`, `GOK = 0`) and check the message the user sees.
- [ ] Import a deliberately wrong file with each template: note `[M:IMP2]STAT` and the trace.
- [ ] Run each batch task once with a reject and check the ASYRREQMAN status and log.
- [ ] Send a test mail with SYRMAIL = Yes and = No; check sender, encoding and attachments.
- [ ] Check `format$` masks, index names and abbreviations (GESATB) on real data.
- [ ] Make sure no specific script carries the name of a standard one, and that every X/Y/Z activity
      code used is active in the folder (GESADS).

## Gotchas

- A feature present in the online help can still be missing from your runtime: pages such as the
  JSON instructions and AREADLOG do not state the release that introduced them.
- Release names and patch numbers mix: 2020 R3 = V12 patch 23, 2021 R1 = patch 25, 2022 R2 = patch 30,
  2025 R1 = V12.0.37 per the sources above; do not extrapolate other pairs.
- Community answers age: re-test any community-reported workaround after an upgrade.

See also: `code-review-checklist.md`, `personalisation-activity.md`, `function-codes.md`,
`diagnostics-postmortem.md`.

## Sources
- https://online-help.sagex3.com/erp/12/en-us/Content/V7DEV/api-guide_api-asyrrestcli.html
- https://online-help.sagex3.com/erp/12/en-us/Content/V7DEV/how-to_how-to-use-axunit.html
- https://online-help.sagex3.com/erp/12/en-us/Content/V7DEV/developer-guide_hybrid-development.html
- https://online-help.sagex3.com/erp/12/en-us/Content/V7DEV/developer-guide_classes-events.html
- https://online-help.sagex3.com/erp/12/en-us/Content/V7DEV/developer-guide_error-handling.html
- https://online-help.sagex3.com/erp/12/en-us/Content/V7DEV/developer-guide_access-rights.html
- https://online-help.sagex3.com/erp/12/en-us/Content/V7DEV/administration-reference_supervisor-administration-log-file-management.html
- https://online-help.sagex3.com/erp/12/en-us/Content/V7DEV/4gl_trbegin.html
- https://online-help.sagex3.com/erp/12/en-us/Content/V7DEV/4gl_adxlog.html
- https://online-help.sagex3.com/erp/12/en-us/Content/V7DEV/4gl_file.html
- https://online-help.sagex3.com/erp/12/en-us/Content/V7DEV/4gl_iomode.html
- https://online-help.sagex3.com/erp/12/en-us/Content/V7DEV/4gl_rewritebykey.html
- https://online-help.sagex3.com/erp/12/en-us/Content/V7DEV/4gl_fstat.html
- https://online-help.sagex3.com/erp/12/en-us/Content/V7DEV/4gl_format$.html
- https://online-help.sagex3.com/erp/12/en-us/Content/V7DEV/how-to_how-to-naming.html
- https://online-help.sagex3.com/erp/12/en-us/Content/FCT/GESACV.htm
- https://online-help.sagex3.com/erp/12/en-us/Content/FCT/FUNCURRAT.htm
- https://online-help.sagex3.com/erp/12/en-us/Content/FCT/PATCH.htm
- https://online-help.sagex3.com/erp/12/en-us/Content/FCT/ASYRREQMAN.htm
- https://online-help.sagex3.com/erp/12/en-us/Content/FCT/GESAIM.htm
- https://online-help.sagex3.com/erp/12/en-us/Content/FCT/GES_AOE1.htm
- https://online-help.sagex3.com/erp/12/en-us/Content/MODEL/VERIF_CRE.htm
- https://online-help.sagex3.com/erp/12/en-us/Content/OBJ/ADC_SUBITM.htm
- https://communityhub.sage.com/fr/sage-x3/f/technique/182920/x3v12-2021r2-appel-webservice-rest-avec-identification-oauth2-header-trop-court-via-asyrrestcli-exec_rest_ws (community)
- https://communityhub.sage.com/sage-global-solutions/sage_x3/f/general-discussion/212042/v12-34-native-json-parser (community)
- https://communityhub.sage.com/sage-global-solutions/sage_x3/f/general-discussion/200055/html-email-text-in-workflow-rules (community)
- https://communityhub.sage.com/sage-global-solutions/sage_x3/b/sage-x3-uk-support-insights/posts/improved-x3-session-information-in-latest-v12-patch-release (community, Sage support blog)
- https://communityhub.sage.com/sage-global-solutions/sage_x3/b/sage-x3-support-insights-ame/posts/understanding-and-troubleshooting-the-sage-x3-batch-server (community, Sage support blog)
- https://communityhub.sage.com/fr/sage-x3/f/technique/214506/point-d-entree-modtrtexp-et-nouvelles-releases-de-la-v12/531832 (community)
- https://communityhub.sage.com/sage-global-solutions/sage_x3/f/general-discussion/254832/v12p37-x3-trt-subsoha1-adx-1367-error-6-variable-non-existent-spjt (community)

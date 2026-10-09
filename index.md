---
title: sage-x3-l4g
description: Browse the Claude skill references for Sage X3 V12 L4G online.
---

# sage-x3-l4g — reference index

Claude skill for writing, reviewing, and debugging **Sage X3 V12 L4G** (4GL / X3 script / Adonix) code. Every reference ends with the Sage online-help pages it is based on.

This site renders the same Markdown that ships in the skill. For installation, see the **[README](README.md)** (or **[README en français](README_FR.md)**). For contribution guidelines, see **[CONTRIBUTING](https://github.com/actouf/sage-x3-l4g/blob/master/CONTRIBUTING.md)**.

> **Skill entry point** — [`SKILL.md`](plugins/sage-x3-l4g/SKILL.md): when to use, verification discipline, mental model, V12 vs Classic idioms, canonical transactional Funprog.

---

## Core language

- [`language-basics.md`](plugins/sage-x3-l4g/references/language-basics.md) — types, declarations, parameter modes, control flow, `Break`, subprograms, `Gosub`, `Onerrgo` / `Resume`
- [`database.md`](plugins/sage-x3-l4g/references/database.md) — `Read` / `For` / `Filter` / `Link`, `Update … With`, `Readlock`, `Rewritebykey` and UPDTICK, `Execsql`, fstat / adxuprec, the transaction idiom
- [`builtin-functions.md`](plugins/sage-x3-l4g/references/builtin-functions.md) — string, date, number and system functions (`format$`, `gdat$`, `instr`, `vireblc`, `ctrans`, `pat`, `filinfo`, `System`)
- [`sequential-files.md`](plugins/sage-x3-l4g/references/sequential-files.md) — `Openi` / `Openo` / `Openio`, `Rdseq` / `Wrseq` / `Getseq` / `Putseq`, `Iomode`, encodings, `filpath`
- [`conventions-and-naming.md`](plugins/sage-x3-l4g/references/conventions-and-naming.md) — X / Y / Z prefixes, activity codes, message chapters, script and table naming
- [`function-codes.md`](plugins/sage-x3-l4g/references/function-codes.md) — verified list of GESxxx functions, and codes that do not exist

## Object models and UI

- [`v12-classes-representations.md`](plugins/sage-x3-l4g/references/v12-classes-representations.md) — router: classes vs representations vs Classic objects, Classic → V12 migration
- [`v12-classes.md`](plugins/sage-x3-l4g/references/v12-classes.md) — class dictionary, class scripts (`$PROPERTIES` / `$EVENTS` / `$METHODS` / `$OPERATIONS`), rules, events, instances, `fmet`, `ASETERROR`
- [`v12-representations.md`](plugins/sage-x3-l4g/references/v12-representations.md) — representations, facets, representation scripts and events
- [`classic-objects.md`](plugins/sage-x3-l4g/references/classic-objects.md) — Classic objects: specific `$ACTION` scripts, creation / modification actions, `OK` / `GOK`
- [`entry-points.md`](plugins/sage-x3-l4g/references/entry-points.md) — entry points (GESAPE, `GPOINT`, `GPE`) to customise standard processes without modifying them
- [`screens-and-masks.md`](plugins/sage-x3-l4g/references/screens-and-masks.md) — Classic masks, `[M:...]`, field actions, `mkstat`, deprecated screen instructions

## Integration

- [`web-services-integration.md`](plugins/sage-x3-l4g/references/web-services-integration.md) — router: REST vs SOAP vs outgoing HTTP vs files, integration log, publishing checklist
- [`web-services-rest.md`](plugins/sage-x3-l4g/references/web-services-rest.md) — exposing X3 through Syracuse REST (`/api1/...`, representations, facets, paging, authentication)
- [`web-services-rest-client.md`](plugins/sage-x3-l4g/references/web-services-rest-client.md) — calling external HTTP / REST APIs (`ASYRRESTCLI.EXEC_REST_WS`), JSON with `ParseInstance`
- [`web-services-soap.md`](plugins/sage-x3-l4g/references/web-services-soap.md) — publishing Classic SOAP web services (GESASU, GESAWE, Syracuse pools, callContext)
- [`web-services-soap-client.md`](plugins/sage-x3-l4g/references/web-services-soap-client.md) — calling an external SOAP service from X3: envelope, escaping, parsing, faults
- [`imports-exports.md`](plugins/sage-x3-l4g/references/imports-exports.md) — import / export templates (GESAOE), running them from code, file exchange patterns
- [`reports-printing.md`](plugins/sage-x3-l4g/references/reports-printing.md) — reports dictionary, destinations, printing from code
- [`workflow-email.md`](plugins/sage-x3-l4g/references/workflow-email.md) — workflow rules (GESAWA), allocation rules, data models, sending e-mail (`ASEND_MAIL`)

## Operations

- [`batch-scheduling.md`](plugins/sage-x3-l4g/references/batch-scheduling.md) — batch tasks (GESABT), recurring tasks (GESABA), calendars, request monitoring, restart safety
- [`personalisation-activity.md`](plugins/sage-x3-l4g/references/personalisation-activity.md) — activity codes (GESACV), folder hierarchy, patches (APATCH / PATCH), personalisation
- [`localization.md`](plugins/sage-x3-l4g/references/localization.md) — messages and `mess()`, connection language, date and number formatting
- [`localization-formats.md`](plugins/sage-x3-l4g/references/localization-formats.md) — currencies, countries and address formats, character sets
- [`data-migration.md`](plugins/sage-x3-l4g/references/data-migration.md) — staging tables, idempotent loaders, reconciliation, cutover
- [`debugging-traces.md`](plugins/sage-x3-l4g/references/debugging-traces.md) — log files (`ALOG` class in V7+ code, `OUVRE_TRACE` / `ECR_TRACE` in Classic code), engine log, profiler, error variables, debugger
- [`diagnostics-postmortem.md`](plugins/sage-x3-l4g/references/diagnostics-postmortem.md) — production incidents: locks, failed batches, logs, incident report template

## Quality

- [`performance.md`](plugins/sage-x3-l4g/references/performance.md) — index-driven access, `Link` vs N+1 reads, `Columns`, transaction size, set-based SQL
- [`security-permissions.md`](plugins/sage-x3-l4g/references/security-permissions.md) — function profiles, access control, web-service authentication, secrets, injection
- [`audit-compliance.md`](plugins/sage-x3-l4g/references/audit-compliance.md) — audit table pattern, sequence numbers, GDPR access / erasure / portability, retention
- [`unit-testing-axunit.md`](plugins/sage-x3-l4g/references/unit-testing-axunit.md) — AXUNIT test suites (`QLF*` scripts), assertions, running tests
- [`code-review-checklist.md`](plugins/sage-x3-l4g/references/code-review-checklist.md) — structured review pass, red flags ranked by blast radius
- [`common-patterns.md`](plugins/sage-x3-l4g/references/common-patterns.md) — Classic / core recipes
- [`common-patterns-v12.md`](plugins/sage-x3-l4g/references/common-patterns-v12.md) — V12 recipes
- [`version-caveats.md`](plugins/sage-x3-l4g/references/version-caveats.md) — version-dependent behaviour and what to verify on your folder

## Examples

Shipped with the skill — see the **[examples index](plugins/sage-x3-l4g/examples/README.md)**.

| File | Topic |
|------|-------|
| [`YACCLIB.src`](plugins/sage-x3-l4g/examples/YACCLIB.src) | Transactional YTRANSFER Funprog and ALOG negative-balance check |
| [`QLFYAC_TRANSFER.src`](plugins/sage-x3-l4g/examples/QLFYAC_TRANSFER.src) | AXUNIT test suite for YTRANSFER |
| [`YTRFPOST.src`](plugins/sage-x3-l4g/examples/YTRFPOST.src) | Batch posting of staging rows, per-row transactions, ALOG log |
| [`SPEYCU.src`](plugins/sage-x3-l4g/examples/SPEYCU.src) | Classic object actions refusing creation or modification with OK = 0 |
| [`YSUBITM.src`](plugins/sage-x3-l4g/examples/YSUBITM.src) | SUBITM entry point BEFWRIITF writing an audit row, GOK = 0 |
| [`YCONTRACT_CSPE.src`](plugins/sage-x3-l4g/examples/YCONTRACT_CSPE.src) | V12 class script: CONTROL rule, control events, ARET_VALUE method |
| [`YRESTRATE.src`](plugins/sage-x3-l4g/examples/YRESTRATE.src) | Outgoing REST call with EXEC_REST_WS, JSON parsing, integration log |
| [`YIMPLAUNCH.src`](plugins/sage-x3-l4g/examples/YIMPLAUNCH.src) | Silent import with IMPORTSIL and archiving of the imported file |

---

## Other resources

- **GitHub repository** — [actouf/sage-x3-l4g](https://github.com/actouf/sage-x3-l4g)
- **Releases** — [GitHub releases](https://github.com/actouf/sage-x3-l4g/releases)
- **Changelog** — [`CHANGELOG.md`](CHANGELOG.md)
- **Issues** — [GitHub issues](https://github.com/actouf/sage-x3-l4g/issues)
- **License** — MIT

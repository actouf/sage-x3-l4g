# sage-x3-l4g

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Release](https://img.shields.io/github/v/release/actouf/sage-x3-l4g)](https://github.com/actouf/sage-x3-l4g/releases/latest)
[![Validate skill](https://github.com/actouf/sage-x3-l4g/actions/workflows/validate.yml/badge.svg)](https://github.com/actouf/sage-x3-l4g/actions/workflows/validate.yml)
[![Docs](https://img.shields.io/badge/docs-actouf.github.io-brightgreen)](https://actouf.github.io/sage-x3-l4g/)

> Claude skill for writing, reviewing, and debugging Sage X3 V12 L4G code — dictionary classes and class scripts, representations, Classic objects and entry points, transactions, Syracuse REST and SOAP, imports, workflows, batch, AXUNIT tests.

_[Version française → README_FR.md](README_FR.md)_

Gives Claude the vocabulary, idioms and conventions of Sage X3 L4G (4GL / X3 script / Adonix) so it writes code that uses real keywords and real supervisor APIs. V12-focused; Classic constructs are covered where they still run in V12.

**Every reference cites the Sage online-help pages it is based on** (a `## Sources` section at the end of each file), and the validation script rejects identifiers that do not exist in X3. The content is checked against Sage's documentation, not compiled on a live folder — see [Limits](#limits).

**[Browse the rendered references → actouf.github.io/sage-x3-l4g](https://actouf.github.io/sage-x3-l4g/)**

## What's inside

**Entry point**
- `SKILL.md` — when to use, verification discipline, mental model (prefixes, `fstat` / `adxuprec`, one transaction level), V12-vs-Classic idioms, canonical transactional Funprog

**Core language**
- `references/language-basics.md` — types, declarations, parameter modes, control flow, `Break`, subprograms, `Gosub`, `Onerrgo` / `Resume`
- `references/database.md` — `Read` / `For` / `Filter` / `Link`, `Update … With`, `Readlock`, `Rewritebykey` and UPDTICK, `Execsql`, fstat / adxuprec, the transaction idiom
- `references/builtin-functions.md` — string, date, number and system functions (`format$`, `gdat$`, `instr`, `vireblc`, `ctrans`, `pat`, `filinfo`, `System`)
- `references/sequential-files.md` — `Openi` / `Openo` / `Openio`, `Rdseq` / `Wrseq` / `Getseq` / `Putseq`, `Iomode`, encodings, `filpath`
- `references/conventions-and-naming.md` — X / Y / Z prefixes, activity codes, message chapters, script and table naming
- `references/function-codes.md` — verified list of GESxxx functions, and codes that do not exist

**Object models and UI**
- `references/v12-classes-representations.md` — router: classes vs representations vs Classic objects, Classic → V12 migration
- `references/v12-classes.md` — class dictionary, class scripts (`$PROPERTIES` / `$EVENTS` / `$METHODS` / `$OPERATIONS`), rules, events, instances, `fmet`, `ASETERROR`
- `references/v12-representations.md` — representations, facets, representation scripts and events
- `references/classic-objects.md` — Classic objects: specific `$ACTION` scripts, creation / modification actions, `OK` / `GOK`
- `references/entry-points.md` — entry points (GESAPE, `GPOINT`, `GPE`) to customise standard processes without modifying them
- `references/screens-and-masks.md` — Classic masks, `[M:...]`, field actions, `mkstat`, deprecated screen instructions

**Integration**
- `references/web-services-integration.md` — router: REST vs SOAP vs outgoing HTTP vs files, integration log, publishing checklist
- `references/web-services-rest.md` — exposing X3 through Syracuse REST (`/api1/...`, representations, facets, paging, authentication)
- `references/web-services-rest-client.md` — calling external HTTP / REST APIs (`ASYRRESTCLI.EXEC_REST_WS`), JSON with `ParseInstance`
- `references/web-services-soap.md` — publishing Classic SOAP web services (GESASU, GESAWE, Syracuse pools, callContext)
- `references/web-services-soap-client.md` — calling an external SOAP service from X3: envelope, escaping, parsing, faults
- `references/imports-exports.md` — import / export templates (GESAOE), running them from code, file exchange patterns
- `references/reports-printing.md` — reports dictionary, destinations, printing from code
- `references/workflow-email.md` — workflow rules (GESAWA), allocation rules, data models, sending e-mail (`ASEND_MAIL`)

**Operations**
- `references/batch-scheduling.md` — batch tasks (GESABT), recurring tasks (GESABA), calendars, request monitoring, restart safety
- `references/personalisation-activity.md` — activity codes (GESACV), folder hierarchy, patches (APATCH / PATCH), personalisation
- `references/localization.md` — messages and `mess()`, connection language, date and number formatting
- `references/localization-formats.md` — currencies, countries and address formats, character sets
- `references/data-migration.md` — staging tables, idempotent loaders, reconciliation, cutover
- `references/debugging-traces.md` — log files (`ALOG` class in V7+ code, `OUVRE_TRACE` / `ECR_TRACE` in Classic code), engine log, profiler, error variables, debugger
- `references/diagnostics-postmortem.md` — production incidents: locks, failed batches, logs, incident report template

**Quality**
- `references/performance.md` — index-driven access, `Link` vs N+1 reads, `Columns`, transaction size, set-based SQL
- `references/security-permissions.md` — function profiles, access control, web-service authentication, secrets, injection
- `references/audit-compliance.md` — audit table pattern, sequence numbers, GDPR access / erasure / portability, retention
- `references/unit-testing-axunit.md` — AXUNIT test suites (`QLF*` scripts), assertions, running tests
- `references/code-review-checklist.md` — structured review pass, red flags ranked by blast radius
- `references/common-patterns.md` — Classic / core recipes
- `references/common-patterns-v12.md` — V12 recipes
- `references/version-caveats.md` — version-dependent behaviour and what to verify on your folder

**Examples** (`plugins/sage-x3-l4g/examples/`, shipped with the skill)

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

## Install

### Claude Code (CLI, VS Code, JetBrains)

```bash
claude plugin marketplace add actouf/sage-x3-l4g
claude plugin install sage-x3-l4g@sage-x3-l4g
```

Or from a session: `/plugin marketplace add actouf/sage-x3-l4g`, then `/plugin install sage-x3-l4g@sage-x3-l4g`. To update later: `claude plugin update sage-x3-l4g@sage-x3-l4g` (auto-update is off by default for third-party marketplaces; you can turn it on in `/plugin`).

### Claude Desktop

**Customize → Plugins → Personal plugins → +** → add the marketplace `actouf/sage-x3-l4g`, then install `sage-x3-l4g`.

### Claude.ai (web)

1. Download `sage-x3-l4g.zip` from the [latest release](https://github.com/actouf/sage-x3-l4g/releases/latest/download/sage-x3-l4g.zip) (it contains the `sage-x3-l4g/` skill folder).
2. In Claude.ai: **Customize → Skills → + → Upload a skill**, and pick the zip.

## Using the skill

The skill triggers on its own. Ask Claude normally:

- "Écris un Funprog qui transfère un montant entre deux comptes, appelable dans ou hors transaction"
- "In my V12 class YCONTRACT, refuse creation when ENDDAT < STRDAT"
- "Ajoute un contrôle à la création d'un client sans toucher au standard"
- "Call an external REST API from X3 and read a value from the JSON response"
- "Relis ce script L4G et dis-moi ce qui cloche"
- "Write an AXUNIT test for my YTRANSFER Funprog"

## FAQ

**V12 or V7? Is V6 covered?**
V12 is the primary target; V7 shares the same class / representation model. Classic constructs (masks, `$ACTION` object scripts, SOAP) are covered because they still run in V12. Pure V6 patterns are not.

**Why check `fstat` instead of using exceptions?**
Database and file instructions don't raise exceptions: they set `[S]fstat`, and `Update` / `Delete … Where` also set `[S]adxuprec`. An `Update` on a missing row succeeds with zero rows. Skipping these checks produces silent bugs.

**Which patch level?**
References follow the V12 online help and say so when a feature is version-dependent (for example native JSON parsing). Verify on your folder before shipping; `version-caveats.md` lists what to check.

**Can examples mix French and English?**
Yes — real X3 codebases do.

**Where do I report a mistake?**
On [GitHub issues](https://github.com/actouf/sage-x3-l4g/issues), with the source or the V12 patch level that contradicts the reference.

## Limits

- No live X3 folder is involved: examples are checked against the documentation, not compiled. Compile them in your sandbox before use.
- Supervisor routines documented only by the community are marked *(community-reported)*.

## Contributing

Issues and PRs welcome — see [CONTRIBUTING.md](CONTRIBUTING.md) for sources policy, style, local testing (`claude --plugin-dir`, evals) and the release process.

## License

MIT — use, modify, and redistribute freely.

## Credits

Built from the official [Sage X3 online help](https://online-help.sagex3.com/), [L.V. Expertise X3](https://lvexpertisex3.com/), and the [Sage Community Hub](https://communityhub.sage.com/). Not affiliated with or endorsed by Sage.

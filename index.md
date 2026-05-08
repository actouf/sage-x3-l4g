---
title: sage-x3-l4g
description: Browse the Claude skill references for Sage X3 V12 L4G online.
---

# sage-x3-l4g — reference index

Claude skill for writing, reviewing, and debugging **Sage X3 V12 L4G** (4GL / X3 script / Adonix) code — classes, representations, REST, workflows, reports, batch, security, audit, and more.

This site renders the same Markdown that ships in the skill. Use it to browse the references without cloning. For installation and overview, see the **[README](README.md)** (or **[README en français](README_FR.md)**). For contribution guidelines and style, see **[CONTRIBUTING](https://github.com/actouf/sage-x3-l4g/blob/master/CONTRIBUTING.md)**.

> **Skill entry point** — [`SKILL.md`](plugins/sage-x3-l4g/SKILL.md): mental model, V12 vs Classic idioms, canonical transactional subprogram, when to use the skill, how to respond to L4G requests.

---

## Core language and conventions

- [`language-basics.md`](plugins/sage-x3-l4g/references/language-basics.md) — variables, scopes (`[L]` / `[V]` / `[S]`), types, control flow, subprograms, `Onerrgo`
- [`database.md`](plugins/sage-x3-l4g/references/database.md) — `Read` / `Readlock` / `Write` / `For`, the `If adxlog` nested-transaction pattern, `UPDTICK`, `Link`, embedded SQL
- [`builtin-functions.md`](plugins/sage-x3-l4g/references/builtin-functions.md) — strings, dates, `pat`, `System`, sequential files, `filpath` / `filinfo`
- [`conventions-and-naming.md`](plugins/sage-x3-l4g/references/conventions-and-naming.md) — Y / Z rule, three-letter aliases, message chapters, folder layout
- [`common-patterns.md`](plugins/sage-x3-l4g/references/common-patterns.md) — core / Classic recipes (transactions, grids, error handling, action-on-field, sub-prog params, batch)
- [`common-patterns-v12.md`](plugins/sage-x3-l4g/references/common-patterns-v12.md) — V12 recipes (class CRUD with `UPDTICK`, REST service, external REST consumption, import hook, scheduled batch + email)

## UI — Classic and V12

- [`screens-and-masks.md`](plugins/sage-x3-l4g/references/screens-and-masks.md) — legacy V6 / Classic masks (`[M:...]`, `Inpbox`, standard actions, grids)
- [`v12-classes-representations.md`](plugins/sage-x3-l4g/references/v12-classes-representations.md) — V12-native: `Class` / `Method` / `this`, representations, pages, business objects, REST surface

## Integration and operations

- [`web-services-integration.md`](plugins/sage-x3-l4g/references/web-services-integration.md) — overview / router: protocol comparison, file exchange, integration logs, cross-cutting gotchas
- [`web-services-soap.md`](plugins/sage-x3-l4g/references/web-services-soap.md) — publishing classic SOAP from X3 (`GESAWE` / `GESAPO`, parameter grid, AWS pool)
- [`web-services-soap-client.md`](plugins/sage-x3-l4g/references/web-services-soap-client.md) — calling external SOAP services: envelope, WS-Security, parsing, fault detection
- [`web-services-rest.md`](plugins/sage-x3-l4g/references/web-services-rest.md) — publishing REST (Syracuse), consuming external REST APIs, JSON, OAuth, SData
- [`imports-exports.md`](plugins/sage-x3-l4g/references/imports-exports.md) — IMP / EXP templates (`LECFIC` / `EXPFIC`), custom import hooks, delta sync
- [`reports-printing.md`](plugins/sage-x3-l4g/references/reports-printing.md) — launching reports via `IMPRIM`, destinations (`GESADI`), Crystal / native states, Excel exports
- [`workflow-email.md`](plugins/sage-x3-l4g/references/workflow-email.md) — workflow rules (`GESAWR`), templates, recipients, sending emails (`ENVMAIL`), HTML bodies
- [`debugging-traces.md`](plugins/sage-x3-l4g/references/debugging-traces.md) — `ECRAN_TRACE`, `stat1` / `funfat`, supervisor tracing, integration logging
- [`performance.md`](plugins/sage-x3-l4g/references/performance.md) — indexes, `Order By Key`, `Link` joins, transaction granularity, profiling, anti-patterns
- [`security-permissions.md`](plugins/sage-x3-l4g/references/security-permissions.md) — `GESAUT` / `GACTION` / `GESAFP`, ACL on services, credential storage, audit logging, injection prevention
- [`batch-scheduling.md`](plugins/sage-x3-l4g/references/batch-scheduling.md) — `GESABA` / `GESAPL`, recurrent vs one-shot, calendars, dependencies, monitoring, restart safety
- [`personalisation-activity.md`](plugins/sage-x3-l4g/references/personalisation-activity.md) — activity codes (`GESACV`, `#Active`), personalisation (`GESAPE`), folder hierarchy, patch generation / import
- [`localization.md`](plugins/sage-x3-l4g/references/localization.md) — messages (`mess`, `GESAML`), `[V]GLANGUE`, date / time formats, decimal separators, multi-language templates
- [`localization-formats.md`](plugins/sage-x3-l4g/references/localization-formats.md) — currencies (`GESCUR`, `GDEV.DEVISE`), country addresses (`GESACO` / `FORMAT_ADDR`), RTL / CJK / UTF-8
- [`data-migration.md`](plugins/sage-x3-l4g/references/data-migration.md) — staging tables, validation / load / reconcile / cutover, dual-write, schema migration, folder consolidation
- [`diagnostics-postmortem.md`](plugins/sage-x3-l4g/references/diagnostics-postmortem.md) — reading `adxlog.log`, stuck locks, hung AWS pool, batch failures, engine crashes, incident report template
- [`audit-compliance.md`](plugins/sage-x3-l4g/references/audit-compliance.md) — audit log pattern, GDPR access / erasure / portability, financial audit trail, retention, consent

## Meta

- [`code-review-checklist.md`](plugins/sage-x3-l4g/references/code-review-checklist.md) — structured review pass with red flags ranked by blast radius
- [`version-caveats.md`](plugins/sage-x3-l4g/references/version-caveats.md) — primitives / helpers / URL shapes that drift across V12 patch levels

## Examples

Compilable L4G fixtures — see the **[examples index](examples/README.md)**.

| File | Topic |
|------|-------|
| [`YCUSTLOG.src`](examples/YCUSTLOG.src) | V12 class wrapping a custom table with `UPDTICK` |
| [`YSRV_RESERVE.src`](examples/YSRV_RESERVE.src) | REST service class: stock reservation, transactional |
| [`YCTRL_FIELD.trt`](examples/YCTRL_FIELD.trt) | Field-control actions: format checks, Luhn SIREN |
| [`YIMP_HOOK.src`](examples/YIMP_HOOK.src) | Import template hooks: per-line validation + end-of-run logging |
| [`YBATCH_ORPHANS.trt`](examples/YBATCH_ORPHANS.trt) | Scheduled batch: email report of orphan orders |
| [`YBATCH_DAILY.trt`](examples/YBATCH_DAILY.trt) | Recurrent batch: drains an inbox, per-row tx, dry-run, pacing |
| [`YPERSO_GESBPC.src`](examples/YPERSO_GESBPC.src) | Personalisation hook gated by activity code, with audit trail |
| [`YMSG_MULTILANG.src`](examples/YMSG_MULTILANG.src) | Multi-language email helper, currency-aware amount, locale-aware date |

## Tests

- [`tests/triggers.md`](tests/triggers.md) — 62 prompts the skill should trigger on, plus quality-check criteria.

---

## Other resources

- **GitHub repository** — [actouf/sage-x3-l4g](https://github.com/actouf/sage-x3-l4g)
- **Changelog** — [`CHANGELOG.md`](CHANGELOG.md)
- **Issues / feature requests** — [GitHub issues](https://github.com/actouf/sage-x3-l4g/issues)
- **License** — MIT

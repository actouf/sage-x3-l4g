# Changelog

All notable changes to the `sage-x3-l4g` skill. Format based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/); versioning follows [SemVer](https://semver.org/).

## [0.3.0] — 2026-05-07

New references for code review, security, and performance, plus splitting two oversized references in line with the ~300-line guideline.

### Added
- **`references/code-review-checklist.md`** — structured pass with red flags ranked by blast radius (correctness → conventions → V12 idioms → security → performance → style), each with symptom / why / fix. Replaces the dispersed bullet list in `SKILL.md`.
- **`references/security-permissions.md`** — `GESAUT`, `GACTION`, `GESAFP`, function profiles, ACL on SOAP / REST, credential storage (`PARAMG`, encrypted parameters), audit logging, SQL / XML / JSON injection prevention, restricted-action 2FA pattern, folder isolation.
- **`references/performance.md`** — fast-path mental model, index strategy, `Read` vs `Readlock`, transaction granularity (per-row, bounded-batch), N+1 → `Link`, `For ... Order By Key`, `Exec Sql` when needed, supervisor-trace-driven profiling, AWS pool sizing, common anti-patterns table, profiling checklist.
- **`references/common-patterns-v12.md`** — split out from `common-patterns.md`. V12 recipes 1–5: class CRUD with `UPDTICK`, REST service, external REST consumption, import hook, scheduled batch with email summary.
- **`references/web-services-soap.md`** — split out from `web-services-integration.md`. Classic SOAP publication (`GESAWE`, parameter grid, 1-D / 2-D arrays), AWS pool sizing (`GESAPO`), WS-Security UsernameToken auth, debugging decision table, SOAP→REST migration guidance, SOAP client (envelope, escape helper, parsing strategies, fault detection).
- **`references/web-services-rest.md`** — split out from `web-services-integration.md`. REST publication (Syracuse representations + service classes), consuming external REST APIs (JSON parsing, build, escape, OAuth pre-flight, retry / timeout / pagination), SData migration note, REST-specific gotchas.

### Changed
- **`references/web-services-integration.md`** reduced to a slim overview / router (~90 lines) — protocol comparison, choosing SOAP vs REST, file exchange (SFTP), integration trace pattern, cross-cutting gotchas (TLS, encoding, payload size, credentials), publishing checklist.
- **`references/common-patterns.md`** trimmed to the 10 core / Classic recipes (~270 lines); V12 recipes moved to `common-patterns-v12.md`.
- **`SKILL.md`** — frontmatter `description` extended with new keywords (`UPDTICK`, performance, `Order By Key`, security, `GESAUT`, `GACTION`, `GESAFP`, ACL, code review). Reference table split into 4 sections updated for the new files. "When the user pastes code to review" section now points to `code-review-checklist.md` while keeping the headline red flags inline.
- **`README.md` and `README_FR.md`** — reference lists updated for the new files (security, performance, checklist, common-patterns-v12, web-services-soap, web-services-rest).
- **`marketplace.json`** — bumped to `0.3.0`.

## [0.2.0] — 2026-04-24

Major content expansion — V12 becomes the primary target.

### Added
- **`references/v12-classes-representations.md`** — `Class`/`Method`/`this`, inheritance, representations, pages, business objects, `UPDTICK`, REST service surface.
- **`references/web-services-integration.md`** — publishing SOAP (AWS) and REST endpoints, consuming external APIs, JSON helpers (`AFNC.JSONGET`), SData.
- **`references/reports-printing.md`** — `IMPRIM`/`IMPRIM0`, destinations (`GESADI`), Crystal vs native states, Excel exports, batch printing.
- **`references/imports-exports.md`** — IMP/EXP templates (`GESAOI`/`GESAOE`), `LECFIC`/`EXPFIC`, per-row hooks (`CTRL`/`INIT`/`FIN`), delta sync, inbox pattern.
- **`references/workflow-email.md`** — workflow rules (`GESAWR`), templates, recipients, `ENVMAIL` / `ENVMAILHTML`, SMTP config, scheduled summaries.
- **`references/debugging-traces.md`** — `ECRAN_TRACE`, `stat1`/`funfat`, supervisor tracing, integration logging, runtime introspection variables, performance profiling.
- **`references/version-caveats.md`** — consolidated list of primitives / helpers / URL shapes that drift across V12 patch levels, with actionable verification steps. Addresses the audit's "things to verify on your folder" category.
- **SOAP enrichment in `references/web-services-integration.md`** (+240 lines) — complete `GESAWE` publication walkthrough with parameter-grid table, 1-D / 2-D array parameters, AWS pool sizing (`GESAPO`) for performance, WS-Security UsernameToken auth, WSDL-invocation XML sample, SOAP debugging decision table (7 common failures), SOAP → REST migration guidance. SOAP client section expanded with WS-Security envelope, XML escape helper, 3-option parsing strategy, SOAP fault detection.
- **`examples/`** directory — 5 compilable `.src` / `.trt` fixtures illustrating V12 idioms: class with `UPDTICK`, REST service, field-control action, import hook, scheduled batch.
- **`tests/triggers.md`** — catalog of canonical prompts (FR + EN) for manual non-regression testing.
- **`CONTRIBUTING.md`** — style guide, local testing flow, PR process.
- **`CLAUDE.md`** at repo root — instructions for Claude when editing the skill itself.
- **`README_FR.md`** — French translation of the user-facing README.
- **`.github/workflows/validate.yml`** — CI to validate `marketplace.json`, frontmatter, and cross-references.
- **`scripts/validate.sh`** — local mirror of the CI checks.
- **`.gitattributes`** — enforce LF line endings across the repo.
- **FAQ section** in README covering V12/V7 differences, `fstat` vs exceptions, version compatibility.

### Changed
- **`SKILL.md`** reoriented around V12: frontmatter description expanded with new keywords (`Class`, `Method`, `this`, `Syracuse`, REST, workflows, `ENVMAIL`, `IMPRIM`, `LECFIC`, `Infbox`, `Errbox`); reference table split into 4 sections (core / UI / integration / meta); new "V12 default idioms" section guiding choice between Classic and V12 patterns.
- **`references/database.md`** — new sections: `UPDTICK` optimistic concurrency; `Exec Sql … On 0 Into` scalar SELECT.
- **`references/builtin-functions.md`** — new sections: date / locale gotchas; `filpath`, `filinfo`, `filres$` file metadata helpers.
- **`references/common-patterns.md`** — 5 new recipes (11–15): V12 class CRUD with `UPDTICK`; REST service with transaction; consume external REST API; import template custom validation hook; scheduled batch with email summary.
- **`README.md`** — reference list split into 3 sections matching the `SKILL.md` structure; install URL updated to `actouf/sage-x3-l4g`; example prompts expanded to include V12 idioms.
- **`marketplace.json`** — owner set to `actouf` (removed placeholders); description updated; bumped to `0.2.0`.

## [0.1.0] — 2026-04-24

Initial release.

### Added
- `SKILL.md` with mental model, V6/Classic-leaning guidance, canonical transactional subprogram.
- Six reference files covering language basics, database, masks, built-ins, conventions, and common patterns.
- README with install instructions for Claude.ai, Desktop, and Code.
- MIT license.

[0.3.0]: https://github.com/actouf/sage-x3-l4g/releases/tag/v0.3.0
[0.2.0]: https://github.com/actouf/sage-x3-l4g/releases/tag/v0.2.0
[0.1.0]: https://github.com/actouf/sage-x3-l4g/releases/tag/v0.1.0

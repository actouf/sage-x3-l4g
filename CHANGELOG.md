# Changelog

All notable changes to the `sage-x3-l4g` skill. Format based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/); versioning follows [SemVer](https://semver.org/).

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

[0.2.0]: https://github.com/actouf/sage-x3-l4g/releases/tag/v0.2.0
[0.1.0]: https://github.com/actouf/sage-x3-l4g/releases/tag/v0.1.0

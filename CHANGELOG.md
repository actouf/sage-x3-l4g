# Changelog

All notable changes to the `sage-x3-l4g` skill. Format based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/); versioning follows [SemVer](https://semver.org/).

## [Unreleased]

## [1.0.0] — 2026-10-09

Verified rewrite. An audit against Sage's online help showed that most of the 0.x content described APIs, keywords and function codes that do not exist in X3. Every reference has been rewritten from the documentation, now cites its sources, and the validator rejects the invented identifiers. The skill is also brought in line with the Agent Skills and Claude Code plugin specifications.

### Added
- **New references**
  - `v12-classes.md` — the real V12 class model: class dictionary (GESACLA), class scripts `_CSTD` / `_CVER` / `_CSPE`, labels `$PROPERTIES` / `$EVENTS` / `$METHODS` / `$OPERATIONS`, rules and events, instances (`NewInstance`, `fmet`, `FreeGroup`), `ASETERROR`, `ARET_VALUE`.
  - `v12-representations.md` — representations (GESASW), facets, representation scripts and events.
  - `classic-objects.md` — Classic object `$ACTION` scripts (`SPE` / `SPV` / `SUB` order), creation / modification / deletion actions, `OK` vs `GOK`.
  - `entry-points.md` — entry points (GESAPE, `GPOINT`, `GPE`).
  - `sequential-files.md` — `Openi` / `Openo` / `Openio`, `Rdseq` / `Wrseq` / `Getseq` / `Putseq`, `Iomode`.
  - `function-codes.md` — verified GESxxx function list, and codes that do not exist.
  - `web-services-rest-client.md` — outgoing calls with `ASYRRESTCLI.EXEC_REST_WS` / `ASYRWEBSER.EXEC_HTTP`, JSON with `ParseInstance` / `Select$`.
  - `unit-testing-axunit.md` — AXUNIT test suites.
- **`## Sources` section** in every reference (online-help.sagex3.com first; community-only facts marked *(community-reported)*), and **`## Contents`** in every reference over 100 lines.
- **`plugins/sage-x3-l4g/.claude-plugin/plugin.json`** — plugin manifest, now the single source of the version.
- **`plugins/sage-x3-l4g/evals/`** — `claude plugin eval` suite: 10 Sage X3 prompts (FR / EN) checking that the skill fires and uses real APIs, 6 negative prompts (Informix 4GL, OpenEdge ABL, ABAP, SQL, Python, Sage 50) checking that it stays silent.
- **`.github/workflows/release.yml`** and **`scripts/release-notes.sh`** — a pushed `vX.Y.Z` tag creates the GitHub Release with this changelog section and the claude.ai upload zip, and back-fills releases for older tagged versions.
- **Examples** shipped with the skill in `plugins/sage-x3-l4g/examples/`: `YACCLIB.src` (transactional `YTRANSFER`, ALOG check), `QLFYAC_TRANSFER.src` (AXUNIT suite), `YTRFPOST.src` (batch with per-row transactions), `SPEYCU.src` (Classic object actions), `YSUBITM.src` (entry point), `YCONTRACT_CSPE.src` (V12 class script), `YRESTRATE.src` (outgoing REST + JSON), `YIMPLAUNCH.src` (silent import).

### Changed
- **`SKILL.md`** rewritten: third-person `description` cut from 1471 to ≤ 1024 characters (Agent Skills limit, required for claude.ai upload) with correct function codes; new "When to use" and "Verification discipline" sections; corrected mental model (`fstat` + `adxuprec`, one transaction level); reference table for 35 files.
- **All 27 existing references rewritten** from the online help. `v12-classes-representations.md` becomes a short router.
- **Examples** moved from `examples/` to `plugins/sage-x3-l4g/examples/` so they ship with the skill; the eight 0.x examples (invented syntax) are replaced by the eight documentation-verified scripts listed above.
- **`scripts/validate.sh`** now checks manifests, version sync (`plugin.json` = CHANGELOG = tag), frontmatter (name, ≤ 1024-character description, portable keys), SKILL.md length, `## Contents` / `## Sources` / size of every reference, listing in SKILL.md / READMEs / `index.md`, cross-links, and L4G code blocks (deny-list of invented identifiers, 2-space indentation).
- **CI** runs `claude plugin validate --strict` on the marketplace and the plugin; `actions/checkout` pinned by SHA.
- **`marketplace.json`** — version removed (it lives in `plugin.json`), description and keywords added.
- **README / README_FR / `index.md`** — install instructions updated for current Claude Code, Desktop and claude.ai (zip from the latest release), dynamic release badge, new reference list.
- **`CLAUDE.md` / `CONTRIBUTING.md`** — sources policy, corrected house style, description rule (≤ 1024 characters), local testing with `claude --plugin-dir` and evals, release process; branch name `master`.

### Fixed
- **Transaction idiom was inverted.** `If adxlog : Trbegin` opened a transaction exactly when one was already open. Now `[L]TRANS_OPEN = adxlog` and `Trbegin` / `Commit` / `Rollback` only when it is 0, with `adxuprec` checked after `Update` (a missing row is `fstat = 0`, `adxuprec = 0`).
- **Invented V12 class syntax removed** (`Class … Endclass`, `Public`, `Private`, `Extends`, events such as `afterLoad`). Replaced by dictionary classes and class scripts.
- **Invented APIs replaced by the documented ones:** `ENVMAIL` → `ASYRMAIL.ASEND_MAIL`; `ECRAN_TRACE` → `ALOG` class (V7+) or `OUVRE_TRACE` / `ECR_TRACE` (Classic); `LECFIC From IMPOBJ` → `IMPORTSIL From GIMPOBJ`; `IMPRIM` → report printing via AIMP3; `AFNC.JSONGET` → `ParseInstance` / `Select$`; "no HTTP client" → `ASYRRESTCLI.EXEC_REST_WS`.
- **Non-existent keywords and functions removed:** `Readseq` / `Writeseq` / `Close n` (→ `Rdseq` / `Wrseq`), `Continue`, `Exitfor`, `Incr`, `replace$`, `len$`, `upper$`, `lower$`, `strip$`, `num$(x, fmt)` (→ `format$`), `gdat(y, m, d)` (→ `gdat$(d, m, y)`), `For … Order By`, `Exec Sql … Into` (→ `Execsql` / `For … Sql`), `Top N`.
- **Function codes corrected** (about 20), e.g. GESAPE is Entry points (not personalisation), GESAWA is Workflow rules, GESAIM is Destinations, GESABT / GESABA are batch tasks, GESAFT is function profiles, GESACO is Headings; codes that do not exist (GESAPL, GESAUT, GESALOCK, GESAOI…) removed.
- **Other corrections:** `fstat` tables, `mess()` third argument (message table, not language), message chapter ranges, index names (`BPC0`, not `BPCNUM0`), UPDTICK (never set by code; `Rewritebykey`), Syracuse REST URLs (`/api1/…?representation=`), Classic object actions, activity codes (5 characters), `Char` length (≤ 255, `Clbfile` beyond), the fabricated patch-drift table in `version-caveats.md`, and the claim that X3 has no unit-test framework (AXUNIT exists).

### Removed
- `tests/triggers.md` — replaced by the eval suite.
- Root `examples/` directory — moved into the plugin.

## [0.5.1] — 2026-05-08

GitHub Pages site for browsing the references without cloning.

### Added
- **`_config.yml`** at repo root — Jekyll configuration (cayman theme, GFM, pretty permalinks, exclusions for `.github/`, `scripts/`, `CONTRIBUTING.md`, `CLAUDE.md`, `LICENSE`, etc.).
- **`index.md`** at repo root — categorized landing page that links to every reference, the SKILL.md entry point, the examples, and the trigger catalogue. Mirrors the README structure.
- **Docs badge** on `README.md` and `README_FR.md` pointing to the published site.
- **Top-of-README link** to the rendered docs (English and French).

### Changed
- **`marketplace.json`** — bumped to `0.5.1`.

### Notes
- Pages must be enabled once in the GitHub repository **Settings → Pages → Source: Deploy from a branch → `master` / `(root)`**. Jekyll auto-builds on every push to `master`. URL: `https://actouf.github.io/sage-x3-l4g/`.
- No reference content changed in this release. Same skill, just easier to read.

## [0.5.0] — 2026-05-08

Audit / compliance reference, expanded triggers catalogue, Mermaid diagrams, README badges, CI branch fix.

### Added
- **`references/audit-compliance.md`** — append-only audit log table pattern with single `YAUDIT_LOG` helper, GDPR right to access (Art. 15) export skeleton, right to erasure (Art. 17) via pseudonymisation that preserves accounting links, data portability (Art. 20), financial audit trail (SOX / FCC) with reversal-entry pattern, retention policy (`YRETENTION_POLICY` table + nightly batch), consent tracking, regulator-facing reporting, anti-patterns, full checklist.
- **18 new triggers** in `tests/triggers.md` — sections for diagnostics / post-mortem (7 prompts), data migration (7 prompts), audit / compliance / retention (4 prompts). Catalog now covers 62 prompts.
- **Mermaid diagrams** in three references: folder hierarchy in `personalisation-activity.md`, transaction lifecycle in `database.md`, batch lifecycle in `batch-scheduling.md`.
- **README badges** — license, version, CI status — on both `README.md` and `README_FR.md`.

### Changed
- **`marketplace.json`** — bumped to `0.5.0`.
- **`SKILL.md`** frontmatter `description` extended with audit / GDPR / compliance / retention keywords; reference table extended.
- **`README.md` and `README_FR.md`** reference lists extended.
- **`.github/workflows/validate.yml`** — CI now triggers on `master` (the actual default branch) in addition to `main`. The badge now reflects real build status.

## [0.4.0] — 2026-05-08

Strict ~300-line discipline applied to the remaining oversized files; two new operational references; expanded patch-drift catalogue; three new examples; CONTRIBUTING.md updated.

### Added
- **`references/diagnostics-postmortem.md`** — reading `adxlog.log` (fields, fstat / stat1 / funfat cheat sheets), stuck-lock detection and clearing (`GESALOCK`), hung AWS pool diagnosis, batch failure handling, database-side post-mortem, engine crash triage, hung Syracuse, incident report template.
- **`references/data-migration.md`** — five-phase playbook (extract → validate → load → reconcile → cutover), staging table pattern with STAT/MSG/BATCH_ID, idempotent loader, count and sum reconciliation, dual-write strategies, in-place schema migration with backfill, folder consolidation, performance during migration.
- **`references/web-services-soap-client.md`** — split out from `web-services-soap.md`. SOAP client: minimal pattern, WS-Security UsernameToken, XML escape helper, three response-parsing strategies, fault detection, full client wrapper class pattern, client-specific gotchas.
- **`references/localization-formats.md`** — split out from `localization.md`. Currencies (`GESCUR`, decimals, symbols, conversion via `GDEV.DEVISE`, multi-currency reporting with rate persistence), country addresses (`GESACO` / `FORMAT_ADDR`, postcode validation), right-to-left and CJK pitfalls.
- **`examples/YBATCH_DAILY.trt`** — recurrent batch template draining an inbox table, per-row tx, dry-run mode, pacing, summary log.
- **`examples/YPERSO_GESBPC.src`** — personalisation hook on `GESBPC`, gated by activity code, with audit trail.
- **`examples/YMSG_MULTILANG.src`** — multi-language email helper using recipient language, currency-aware amount formatting, locale-aware date.

### Changed
- **`references/web-services-soap.md`** trimmed to publishing only (~225 lines); client material moved to `web-services-soap-client.md`.
- **`references/localization.md`** trimmed to messages, language, dates, numbers (~250 lines); currency / address / RTL / CJK material moved to `localization-formats.md`.
- **`references/performance.md`** condensed to under 300 lines (merged "pool sizing" + "batch scheduling" sections, tightened raw-SQL hint section).
- **`references/version-caveats.md`** expanded with: patch-level signature drifts table (12+ helpers across V12 patches 22 → 28), runtime-only divergences (`adxlog`, `fstat` after empty `For`, `[S]adxuprec`, NFC normalization, `format$` thousands separator), folder-config divergences.
- **`CONTRIBUTING.md`** — explicit ~300-line rule with up-to-340 tolerance, "what CI does NOT check" section (L4G compilation, trigger reliability, cross-version primitives), guidance for splitting an existing reference, releases / tags section.
- **`SKILL.md`** frontmatter `description` extended with data-migration and post-mortem keywords; reference table updated for the four new files.
- **`README.md` and `README_FR.md`** reference lists extended.
- **`examples/README.md`** index extended for the three new examples.
- **`marketplace.json`** — bumped to `0.4.0`.

### Notes
- L4G compilation tests, automated trigger validation, and L4G unit testing remain out of scope (no public X3 supervisor, no Anthropic API integration in CI, no widely-adopted L4G unit-test framework). Documented in `CONTRIBUTING.md`.

## [0.3.0] — 2026-05-07

Major content expansion: review / security / performance / batch / personalisation / localisation references, plus splitting two oversized files to keep each under the ~300-line guideline.

### Added
- **`references/code-review-checklist.md`** — structured pass with red flags ranked by blast radius (correctness → conventions → V12 idioms → security → performance → style), each with symptom / why / fix. Replaces the dispersed bullet list in `SKILL.md`.
- **`references/security-permissions.md`** — `GESAUT`, `GACTION`, `GESAFP`, function profiles, ACL on SOAP / REST, credential storage (`PARAMG`, encrypted parameters), audit logging, SQL / XML / JSON injection prevention, restricted-action 2FA pattern, folder isolation.
- **`references/performance.md`** — fast-path mental model, index strategy, `Read` vs `Readlock`, transaction granularity (per-row, bounded-batch), N+1 → `Link`, `For ... Order By Key`, `Exec Sql` when needed, supervisor-trace-driven profiling, AWS pool sizing, common anti-patterns table, profiling checklist.
- **`references/batch-scheduling.md`** — batch lifecycle (`GESABA` / `GESAPL` / `GESBSV`), `$MAIN` script template, parameter grid, recurrent vs one-shot, calendar-driven schedules (`GESACR`), job dependencies (script chain or `CRBATCH` enqueue), monitoring (`GESALI` / `GESAEX`), `YBATCHLOG` pattern, post-batch summaries, pacing with `Sleep`, restart safety, anti-patterns table.
- **`references/personalisation-activity.md`** — folder hierarchy (standard → parent → child), activity codes (`GESACV`, `#Active`/`#End` directives, naming rules), personalisation (`GESAPE`) for non-invasive dictionary changes, override discipline, patch generation / import workflow (`GESAPA`), versioning custom modules.
- **`references/localization.md`** — `mess()` and chapters (`GESAML`, custom range conventions), `[V]GLANGUE`, language-aware date / time (`format$`, `[V]GFORMA`), multi-currency (`GESCUR`, decimals, symbols, conversion via `GDEV.DEVISE`), country-specific addresses (`GESACO` / `FORMAT_ADDR`), email translation, UTF-8 / RTL / CJK pitfalls.
- **`references/common-patterns-v12.md`** — split out from `common-patterns.md`. V12 recipes 1–5: class CRUD with `UPDTICK`, REST service, external REST consumption, import hook, scheduled batch with email summary.
- **`references/web-services-soap.md`** — split out from `web-services-integration.md`. Classic SOAP publication (`GESAWE`, parameter grid, 1-D / 2-D arrays), AWS pool sizing (`GESAPO`), WS-Security UsernameToken auth, debugging decision table, SOAP→REST migration guidance, SOAP client (envelope, escape helper, parsing strategies, fault detection).
- **`references/web-services-rest.md`** — split out from `web-services-integration.md`. REST publication (Syracuse representations + service classes), consuming external REST APIs (JSON parsing, build, escape, OAuth pre-flight, retry / timeout / pagination), SData migration note, REST-specific gotchas.

### Changed
- **`references/web-services-integration.md`** reduced to a slim overview / router (~90 lines) — protocol comparison, choosing SOAP vs REST, file exchange (SFTP), integration trace pattern, cross-cutting gotchas (TLS, encoding, payload size, credentials), publishing checklist.
- **`references/common-patterns.md`** trimmed to the 10 core / Classic recipes (~270 lines); V12 recipes moved to `common-patterns-v12.md`.
- **`SKILL.md`** — frontmatter `description` extended with new keywords (`UPDTICK`, performance, `Order By Key`, security/`GESAUT`/`GACTION`/`GESAFP`/ACL, batch/`GESABA`/`GESAPL`, personalisation/`GESAPE`/`GESACV`/patches, localisation/`mess`/`GESAML`, code review). Reference table extended. "When the user pastes code to review" section points to `code-review-checklist.md` while keeping the headline red flags inline.
- **`README.md` and `README_FR.md`** — reference lists updated for all new files.
- **`tests/triggers.md`** expanded from 22 to 44 prompts: new sections for batch / scheduling / personalisation, localisation / security, plus more review / paste-code prompts; quality checks extended for batch/service/perf/security outputs.
- **`marketplace.json`** — bumped to `0.3.0`.

## [0.2.0] — 2026-04-24

Major content expansion — V12 becomes the primary target.

> The `v0.2.0` tag points at `2d04b5c` (initial import). Most of the changes below landed afterwards, in `698f530`…`9a1989b`; the published tag is kept as is.

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

> Never tagged: the first commit of this repository (`a9870d8`) already carries the 0.2.0 manifest.

### Added
- `SKILL.md` with mental model, V6/Classic-leaning guidance, canonical transactional subprogram.
- Six reference files covering language basics, database, masks, built-ins, conventions, and common patterns.
- README with install instructions for Claude.ai, Desktop, and Code.
- MIT license.

[Unreleased]: https://github.com/actouf/sage-x3-l4g/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/actouf/sage-x3-l4g/releases/tag/v1.0.0
[0.5.1]: https://github.com/actouf/sage-x3-l4g/releases/tag/v0.5.1
[0.5.0]: https://github.com/actouf/sage-x3-l4g/releases/tag/v0.5.0
[0.4.0]: https://github.com/actouf/sage-x3-l4g/releases/tag/v0.4.0
[0.3.0]: https://github.com/actouf/sage-x3-l4g/releases/tag/v0.3.0
[0.2.0]: https://github.com/actouf/sage-x3-l4g/releases/tag/v0.2.0
[0.1.0]: https://github.com/actouf/sage-x3-l4g/commit/a9870d8

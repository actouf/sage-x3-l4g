# Examples

Compilable L4G fixtures illustrating the idioms the skill teaches. Each file is a self-contained recipe — adapt names and tables to your project.

| File | Topic | Reference |
|------|-------|-----------|
| `YCUSTLOG.src` | V12 class wrapping a custom table with `UPDTICK` optimistic concurrency | `v12-classes-representations.md`, `database.md` |
| `YSRV_RESERVE.src` | REST service class: stock reservation with transactional safety | `web-services-rest.md`, `v12-classes-representations.md` |
| `YCTRL_FIELD.trt` | Field-control actions: format checks, Luhn SIREN, cross-field save guard | `screens-and-masks.md`, `common-patterns.md` |
| `YIMP_HOOK.src` | Import template hooks: per-line validation + end-of-run logging | `imports-exports.md` |
| `YBATCH_ORPHANS.trt` | Scheduled batch: email report of orphan orders, persistent run log | `common-patterns-v12.md`, `workflow-email.md`, `debugging-traces.md` |
| `YBATCH_DAILY.trt` | Recurrent batch template: drains an inbox table, per-row tx, dry-run mode, pacing, summary log | `batch-scheduling.md`, `performance.md` |
| `YPERSO_GESBPC.src` | Personalisation hook on `GESBPC`: gated by activity code, applies a default value, audit trail | `personalisation-activity.md`, `security-permissions.md` |
| `YMSG_MULTILANG.src` | Multi-language email helper: recipient-language `mess()`, currency-aware amount, locale-aware date | `localization.md`, `localization-formats.md`, `workflow-email.md` |

All examples follow the skill's house style: PascalCase keywords, UPPERCASE identifiers, 2-space indent, explicit bracket prefixes, `fstat` check after every DB/file op, `If adxlog` for nested-transaction safety.

## Using these

- Copy into your `<folder>/TRT/` directory.
- Rename the Y-prefixed table / script references to match your naming.
- Validate via the X3 editor (compiles to `.adx`).
- Fields referenced (e.g. `[F:YCL]UPDTICK`, `[F:YIL]ENDPOINT`) assume you've defined the matching columns in `GESATB`.

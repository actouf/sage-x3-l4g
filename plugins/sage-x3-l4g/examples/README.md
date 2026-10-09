# Example scripts

Complete L4G scripts that put the reference files together. Each file starts with a header comment
block: purpose, the dictionary elements to create first, and the reference that explains it. They
follow the skill's house style (PascalCase keywords, uppercase identifiers, 2-space indent, explicit
`[L]` / `[F:]` / `[M:]` prefixes, Y prefix on every custom symbol, `fstat` checked after every
database operation, `adxlog` transaction idiom).

| File | Topic | Reference |
|---|---|---|
| `examples/YACCLIB.src` | Transactional `YTRANSFER` Funprog (adxlog idiom) and `YCHECKBAL` ALOG log | `database.md`, `debugging-traces.md` |
| `examples/QLFYAC_TRANSFER.src` | AXUNIT test suite for `YTRANSFER` | `unit-testing-axunit.md` |
| `examples/YTRFPOST.src` | Batch process: per-row transactions over a staging table, ALOG log, Break on fatal error | `batch-scheduling.md` |
| `examples/SPEYCU.src` | Classic object actions: `VERIF_CRE` / `VERIF_MOD` refuse with `OK = 0`, `INICRE` / `INIMOD` | `classic-objects.md` |
| `examples/YSUBITM.src` | Entry point `BEFWRIITF` of `SUBITM` declared in GESAPE, `GOK = 0` | `entry-points.md` |
| `examples/YCONTRACT_CSPE.src` | V12 class script: CONTROL rule, control events with `ASETERROR`, method returning `ARET_VALUE` | `v12-classes.md` |
| `examples/YRESTRATE.src` | Outgoing REST call (`EXEC_REST_WS`), JSON parsing, integration log | `web-services-rest-client.md` |
| `examples/YIMPLAUNCH.src` | Silent import (`IMPORTSIL From GIMPOBJ`) with file archiving | `imports-exports.md` |

How they fit together: `YTRFPOST.src` posts staging rows with `YTRANSFER` from `YACCLIB.src`, which
`QLFYAC_TRANSFER.src` tests; `YIMPLAUNCH.src` can run the import template of the object whose
controls live in `SPEYCU.src`; `common-patterns.md` and `common-patterns-v12.md` show short
excerpts and point back here.

## Using these

1. **Create the prerequisites first.** Each header lists the tables (GESATB), screens (GESAMK),
   objects (GESAOB), classes (GESACLA), entry-point lines (GESAPE), messages (TXT, chapter 160),
   actions and tasks (GESACT, GESABT) and activity codes (GESACV) the script expects. Validate every
   dictionary element, and put an X/Y/Z activity code on each one so patches leave it alone
   (`conventions-and-naming.md`, `personalisation-activity.md`).
2. **Rename to your conventions.** The examples use the `Y` prefix, message chapter 160 (numbers 11,
   12, 21, 22) and local menu 6201; pick free numbers in your folder.
3. **Compile in a development folder**, never directly in production. Scripts other than class
   scripts are called with `Call ... From SCRIPT` or `func SCRIPT.NAME(...)`.
4. **Test.** Run `QLFYAC_TRANSFER` (`=>func QLFYAC_TRANSFER.TESTSUITE`) in a test folder, then check
   the points listed in `version-caveats.md` on your patch level.

These scripts are **documentation-verified, not compiled**: every keyword, supervisor API and
function code they use is documented in the online help or flagged as community-reported in the
reference they point to, but they have not been run on a live folder. Expect to adjust names, field
types and lengths to your dictionary.

See also: `common-patterns.md`, `common-patterns-v12.md`, `code-review-checklist.md`.

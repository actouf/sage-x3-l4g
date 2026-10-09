# Unit testing with AXUNIT

AXUNIT is the unit-test framework shipped with the Sage X3 supervisor (same principles as JUnit/QUnit): a test
script is a suite of test cases, each test case runs code and asserts results with `CHECK_*` calls, and results go
to a trace file and a JSON file. Read this file to write tests for specific Funprogs and class methods, run them
from the Eclipse console or in batch, and read the results. The function under test in the full example is the
`YTRANSFER` Funprog of `examples/YACCLIB.src`.

## Contents
- [Conventions](#conventions)
- [API](#api)
- [Full example: testing YTRANSFER](#full-example-testing-ytransfer)
- [Testing class methods](#testing-class-methods)
- [Running the tests](#running-the-tests)
- [Reading the results](#reading-the-results)
- [What to test](#what-to-test)
- [Gotchas](#gotchas)
- [Sources](#sources)

## Conventions

- Every unit-test file must match `QLF*_*.src`, i.e. `QLF<area>_<case>.src` (`RUN_SET("AS")` runs all
  `QLFAS_*.src` files). Sage's naming rules reserve area codes `A*` for the supervisor and give application areas
  (FIN, MFG…); **`X*` is for add-ons and `Y*`/`Z*` for vertical or specific developments** — e.g.
  `QLFYAC_TRANSFER.src` for the "YAC" (accounts) area.
- Group tests of one area under a common prefix so `func AXUNIT.RUN_SET("YAC")` runs them all.
- One script = one `Funprog TESTSUITE()` + optional `Subprog SETUP` (once, before the suite) and
  `Subprog TEARDOWN` (once, after the suite) + one `Subprog` per test case.

## API

All calls are `From AXUNIT` / `func AXUNIT.…`.

| Call | Purpose |
|---|---|
| `Call TESTSUITE_START(ID, DESCRIPTION)` | Declare the suite (Sage uses a user-story id as ID) |
| `Call ADD_TESTCASE(SUBPROG, DESCRIPTION, NB_CHECKS)` | Register a test-case sub-program and the number of checks it must execute |
| `func AXUNIT.RUN_TESTSUITE(ID, DESCRIPTION)` | Run the registered cases (SETUP before, TEARDOWN after); its result is `TESTSUITE`'s return value |
| `Call CHECK_EQUAL(GOT, EXPECT)` / `CHECK_NOTEQUAL(GOT, EXPECT)` | Assert equality / inequality |
| `Call CHECK_TRUE(GOT)` / `CHECK_FALSE(GOT)` | Assert a logical value |
| `Call LOG_LINE(TEXT)` | Write a comment line in the trace |
| `Call LOG_CLASS(INSTANCE, NAME, ERRORS)` | Dump an instance (properties, child collections, and its errors when `ERRORS` is set) |
| `func AXUNIT.RUN_ALL` | Run all unit tests (long: use batch) |
| `func AXUNIT.RUN_ALL2(EXCLUDES, NODEBUG)` | Same, excluding scripts listed as `";QLFAA_X;QLFBB_Y;"`; `NODEBUG` = 1 prevents triggering the debugger |
| `func AXUNIT.RUN_SET(PREFIX)` | Run `QLF<PREFIX>_*.src` (e.g. `"AS"` = supervisor tests) |

## Full example: testing YTRANSFER

`YTRANSFER(FROM_ACC, TO_ACC, AMOUNT)` (`examples/YACCLIB.src`: table `YACCOUNT` opened as `[YACC]`, primary index `YAC0` on
`Y_ACCNUM`, balance `Y_BALANCE`; assumed here to live in script `YACCLIB`) returns `[V]CST_AOK` or `[V]CST_AERROR`,
refuses a debit larger than the balance, opens its own transaction only when `adxlog` = 0 and checks `adxuprec`
so a missing account rolls everything back. The suite tests those behaviours.

The complete suite, with its data helpers (`YRESET_ACCOUNTS`, `YCREATE_ACCOUNT`, `YCLEAN_ACCOUNTS`,
`YBALANCE`), is `examples/QLFYAC_TRANSFER.src`. Its skeleton and two of its four cases:

```l4g
Funprog TESTSUITE()
  Call TESTSUITE_START("YAC-TRANSFER", "YTRANSFER - transfert entre comptes") From AXUNIT
  Call ADD_TESTCASE("YTC_TRANSFER_OK", "Amount moved between two accounts", 3) From AXUNIT
  Call ADD_TESTCASE("YTC_INSUFFICIENT", "Debit above balance refused, nothing changed", 3) From AXUNIT
  Call ADD_TESTCASE("YTC_UNKNOWN_ACCOUNT", "Unknown target: error and full rollback", 3) From AXUNIT
  Call ADD_TESTCASE("YTC_CALLER_TRANSACTION", "Caller transaction left open, caller rolls back", 4) From AXUNIT
End func AXUNIT.RUN_TESTSUITE("YAC-TRANSFER", "YTRANSFER - transfert entre comptes")

Subprog YTC_TRANSFER_OK
Local Integer STA
  Call YRESET_ACCOUNTS
  [L]STA = func YACCLIB.YTRANSFER("YTST1", "YTST2", 30)
  Call CHECK_EQUAL([L]STA, [V]CST_AOK) From AXUNIT
  Call CHECK_EQUAL(func YBALANCE("YTST1"), 70) From AXUNIT
  Call CHECK_EQUAL(func YBALANCE("YTST2"), 30) From AXUNIT
End

Subprog YTC_CALLER_TRANSACTION
Local File YACCOUNT [YACC]
Local Integer STA
  Call YRESET_ACCOUNTS
  # This case plays the caller that owns the transaction (the suite runs with adxlog = 0)
  Trbegin [YACC]
  [L]STA = func YACCLIB.YTRANSFER("YTST1", "YTST2", 30)
  Call CHECK_EQUAL([L]STA, [V]CST_AOK) From AXUNIT
  Call CHECK_EQUAL(adxlog, 1) From AXUNIT : # YTRANSFER must not commit our transaction
  Rollback
  Call CHECK_EQUAL(func YBALANCE("YTST1"), 100) From AXUNIT
  Call CHECK_EQUAL(func YBALANCE("YTST2"), 0) From AXUNIT
End
```

Design notes:
- SETUP/TEARDOWN run once per suite, so each test case resets its own data (`YRESET_ACCOUNTS`) — cases stay
  independent and can run in any order.
- The suite is **not** wrapped in one big transaction: X3 has a single transaction level, so the "own
  transaction" path of `YTRANSFER` would never run. Only the case that tests the caller-owned path opens (and
  rolls back) a transaction; the data helpers use the `TRANS_OPEN = adxlog` idiom like any reusable routine.
- The third argument of each `ADD_TESTCASE` equals the number of `CHECK_*` calls the case executes.

## Testing class methods

Instantiate, call methods with `fmet`, assert statuses and properties, dump on failure, free the instance
(pattern from Sage's "automatic unit test on a data class" how-to; `C_YACCOUNT` is a specific class here):

```l4g
Subprog YTC_CLASS_NEGATIVE
Local Instance YACCI Using C_YACCOUNT
Local Integer OK
  YACCI = NewInstance C_YACCOUNT AllocGroup Null
  [L]OK = fmet YACCI.AINIT()
  Call CHECK_EQUAL([L]OK, [V]CST_AOK) From AXUNIT
  YACCI.Y_ACCNUM = "YTST9"
  YACCI.Y_BALANCE = -5
  [L]OK = fmet YACCI.AINSERT()
  Call CHECK_NOTEQUAL([L]OK, [V]CST_AOK) From AXUNIT : # the control rule must refuse it
  Call LOG_CLASS(YACCI, "YACCI", 1) From AXUNIT
  FreeGroup YACCI
End
```

Read-back tests use `fmet INSTANCE.AREAD(KEY)` then `CHECK_EQUAL(INSTANCE.PROP, value)`; update tests
`AREAD` → change → `fmet INSTANCE.AUPDATE()`. Class events and rules: `v12-classes.md`.

## Running the tests

| Where | How |
|---|---|
| Eclipse console (one suite) | `=>func QLFYAC_TRANSFER.TESTSUITE` — prints the summary and the trace/JSON locations |
| One area | `func AXUNIT.RUN_SET("YAC")` |
| Everything | `func AXUNIT.RUN_ALL` or `func AXUNIT.RUN_ALL2("", 1)` — long: not from the console |
| Batch (Sage's recommended way for all tests) | A batch task (GESABT) whose process calls `func AXUNIT.RUN_ALL2("", 1)`, scheduled with GESABA — `batch-scheduling.md` |

Run suites in a test folder whose data you control, after each patch integration and before delivering a patch.

## Reading the results

Console summary (Sage's example):

```text
QLFAR_ENCODE - REQ-70693 - 4 Succeed, 0 Failed, 80ms elapsed
Trace has been written to '…/dossiers/SUPERV/TRA/QLFAR_ENCODE_ERBOU.tra'
JSON result is available at: http://…/SUPERV/TMP/QLFAR_ENCODE_ERBOU.json
```

- **Trace** `QLF<area>_<case>_<USER>.tra` in the folder's TRA directory (open it with LECTRACE/AREADLOG,
  `debugging-traces.md`): one "Start suite" line, then per case "Start test case", one line per check
  (`2.3 - check equal - OK: 'Auto Generated Book'`), `LOG_LINE` comments, and `success=N, failure=M, elapsed=Xms`.
- A line `Mismatch number of assertions: expected 8 got 7` means the case executed fewer (or more) checks than
  declared in `ADD_TESTCASE` — a skipped branch or a wrong count.
- **JSON** result in the folder's TMP directory, for CI dashboards.

## What to test

| Target | Typical cases |
|---|---|
| Pure Funprogs (calculations, parsing, formatting) | Nominal values, empty string, zero, 255-character strings, `[0/0/0]` dates |
| Transactional Funprogs | Success; each failure path returns `CST_AERROR` and leaves no partial write; caller-owned transaction (`adxlog` = 1) is neither committed nor rolled back |
| Class methods and rules | `AINIT` defaults, `AINSERT`/`AUPDATE` refused by controls (errors visible with `LOG_CLASS`), `AREAD` of what was written |
| Integration code | Parsing/mapping isolated in Funprogs fed with fixed JSON/XML strings; no live HTTP call in unit tests |
| Fixed bugs | One regression case per incident (`diagnostics-postmortem.md`, "PREVENTION") |

Leave out Classic screens (masks, `Inpbox`), real web-service calls and scheduling: they need integration tests.

## Gotchas

- Name every suite `QLF*_*.src`: that is the pattern AXUNIT documents for unit-test files and the one
  `RUN_SET("AS")` uses (`QLFAS_*.src`).
- A check inside an `If` makes the assertion count vary: keep checks unconditional.
- Tests write to the real tables of the folder: dedicated test folder, recognisable keys (`YTST*`), cleanup in
  TEARDOWN — and never run suites in production.
- A case that opens a transaction must close it itself: `Rollback` only works in the sub-program that ran
  `Trbegin` (error 32 otherwise), and `Rollback` without a transaction raises error 48.
- Debugger traps (`Dbgaff`) in code under test stop unattended runs: use `RUN_ALL2(…, 1)` in batch.

See also: `database.md`, `v12-classes.md`, `debugging-traces.md`, `batch-scheduling.md`,
`conventions-and-naming.md`, `code-review-checklist.md`.

## Sources
- https://online-help.sagex3.com/erp/12/en-us/Content/V7DEV/how-to_how-to-use-axunit.html
- https://online-help.sagex3.com/erp/12/en-us/Content/V7DEV/how-to_how-to-create-and-run-an-automatic-unit-test-on-a-data-class.html
- https://online-help.sagex3.com/erp/11/en-US/V7DEV/how-to_how-to-naming.html
- https://online-help.sagex3.com/erp/12/en-us/Content/V7DEV/developer-guide_classes-script.html
- https://online-help.sagex3.com/erp/12/en-us/Content/FCT/GESABT.htm , …/GESABA.htm
- https://online-help.sagex3.com/erp/12/en-us/Content/V7DEV/4gl_delete.html , …/4gl_adxdlrec.html , …/4gl_adxlog.html

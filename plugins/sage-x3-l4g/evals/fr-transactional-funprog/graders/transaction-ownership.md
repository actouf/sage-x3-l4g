---
type: llm
---

PASS if the Funprog (1) stores adxlog in a local variable before writing anything and runs Trbegin only when that value was 0, (2) commits only when it opened the transaction itself, (3) on failure rolls back only when it opened the transaction (otherwise it returns an error status and leaves the rollback to the caller), and (4) tests fstat after the Write and fstat plus adxuprec after the Update.
FAIL if any of the four points is missing, or if Trbegin or Commit run unconditionally.

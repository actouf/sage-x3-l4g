---
type: llm
---

PASS if the answer adds the field through the table dictionary with a specific (X, Y or Z) field name AND protects it with a specific activity code (X, Y or Z), AND says the table must then be validated.
FAIL if any of these is missing, or if it recommends altering the database table directly with SQL (ALTER TABLE) instead of the dictionary.

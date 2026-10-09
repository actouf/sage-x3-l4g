---
type: llm
---

PASS if the code uses only real Sage X3 4GL functions (for example a loop on instr with left$ / right$ / mid$ / seg$, and len() for the length) and never calls replace$, len$ or strip$ as if they existed. Saying that those functions do not exist is fine.
FAIL if the code calls replace$, len$ or strip$, or another function presented as built-in that does not exist in X3.

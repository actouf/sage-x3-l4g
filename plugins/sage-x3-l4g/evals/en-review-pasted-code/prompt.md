---
tags: [positive, review]
max_turns: 20
allowed_tools: [Skill, Read, Glob, Grep]
---

Can you review this before I deploy it?

```
Subprog YCLOSE(ORDNUM)
Value Char ORDNUM()
Local File YORDER [YORD]
If adxlog
  Trbegin [YORD]
Endif
Update [YORD] Where NUM = ORDNUM With STA = 3
Commit
End
```

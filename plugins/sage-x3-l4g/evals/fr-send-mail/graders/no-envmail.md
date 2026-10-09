---
type: regex
pattern: '(Call|func)\s+(\w+\.)?(ENVMAIL|ENVMAILHTML|ASYRMAILAPI)\b|From\s+AMAIL\b'
flags: i
match: not_contains
---

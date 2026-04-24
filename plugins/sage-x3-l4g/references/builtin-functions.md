# Built-in functions

The X3 runtime (`adonix`) exposes a large set of built-in functions. This file covers the ones you actually use day-to-day — for the complete list see the L.V. Expertise X3 reference or the Sage online help.

## String functions

| Function | Purpose | Example |
|----------|---------|---------|
| `len$(s)` | Length (trailing spaces stripped for Char) | `len$(NAME)` |
| `mid$(s, start, n)` | Substring, 1-based | `mid$("HELLO", 2, 3)` → `"ELL"` |
| `left$(s, n)` | First n chars | `left$("HELLO", 3)` → `"HEL"` |
| `right$(s, n)` | Last n chars | `right$("HELLO", 3)` → `"LLO"` |
| `upper$(s)` / `lower$(s)` | Case conversion | `upper$("abc")` → `"ABC"` |
| `strip$(s)` | Remove leading and trailing spaces | |
| `num$(i)` | Integer → string | `num$(42)` → `"42"` |
| `val(s)` | String → numeric | `val("3.14")` → `3.14` |
| `format$(fmt, v)` | Formatted conversion | `format$("N5", 42)` → `"00042"` |
| `replace$(s, old, new)` | Replace occurrences | `replace$("a,b", ",", ";")` |
| `instr(i, s, sub)` | Position of substring starting from index i | |
| `chr$(i)` | Character with ASCII code i | `chr$(9)` = tab |
| `asc(s)` | ASCII code of first char | |

### Pattern matching — `pat`

`pat(string, pattern)` returns non-zero when `string` matches `pattern`.

Wildcards:
- `*` — any number of characters (including zero)
- `?` — exactly one character
- `#` — exactly one digit
- `!` — exactly one letter
- `[abc]` — one of those characters
- `[^abc]` — any character except those

```l4g
If pat(CODE, "!###")                        # letter + 3 digits
If pat(EMAIL, "*@*.*")                      # very loose email
```

Using `pat` inside a `Where` clause translates to SQL `LIKE` when possible:

```l4g
For [BPC] Where pat(BPCNAM, "*SAGE*") <> 0  # pushed down to SQL
    ...
Next
```

**Add `<> 0`** to ensure the filter is pushed to the database — without it, the engine may filter client-side after fetching everything.

## Numeric functions

| Function | Purpose |
|----------|---------|
| `abs(n)` | Absolute value |
| `int(n)` | Integer truncation |
| `arr(n, s)` | Round n to step s (e.g., `arr(3.14159, 0.01)` → `3.14`) |
| `ar2(n)` | Round to 2 decimals (common for money) |
| `sgn(n)` | -1, 0, or 1 |
| `mod(a, b)` | Remainder of a / b |
| `min(a, b, ...)` / `max(a, b, ...)` | Variadic |

## Date functions

| Function | Purpose |
|----------|---------|
| `date$` | Current system date (Date value) |
| `time$` | Current system time as string `"HH:MM:SS"` |
| `gdat(y, m, d)` | Construct a Date from year/month/day |
| `year(d)` / `month(d)` / `day(d)` | Extract components |
| `week(d)` | ISO week number |
| `dayn(d)` | Day of week (1 = Monday … 7 = Sunday) |
| `num$(d, "J/M/A")` | Format a date |

Date arithmetic uses integer days:

```l4g
Local Date D
D = date$ + 30                              # 30 days from today
```

### Locale traps

- `num$(D, "J/M/A")` — French format. Use `"D/M/Y"` or `"YYYYMMDD"` for exchange formats.
- **`[D]` Date literals are locale-sensitive.** `[D]01/02/2024` is 1 Feb in FR, 2 Jan in US. Never hardcode — use `gdat(2024, 2, 1)`.
- **String comparison of dates** fails when formats differ. Always parse to `Date` before comparing.
- **Two-digit years** — `gdat(24, 2, 1)` gives year 24 (literally year 24 AD), not 2024. Always pass 4-digit years.
- **`dayn(d)` returns 1=Monday in FR, 1=Sunday in US** depending on locale — specify via `[S]GDATFMT` if it matters for your logic.

## System interaction

### `System` — run a shell command

```l4g
Local Char OUT(250)(1..20)                  # up to 20 output lines
System "ls -la" = OUT                       # capture stdout into array
If [S]stat1
    # error; stat1 is the exit code
Endif
```

Syntaxes:
- `System <cmd>` — run, ignore output
- `System <var> = <cmd>` — capture stdout
- `Local File X From System <cmd> As [CLS]` — stream stdout as a file

### Sequential files — `Openi`, `Openo`, `Readseq`, `Writeseq`, `Close`

```l4g
Local Char LINE(1000)
Openi "/path/to/file.txt" Using 1
If fstat : End : Endif

Repeat
    Readseq LINE Using 1
    If fstat <> 0 And fstat <> 100 : Exit : Endif   # 100 = EOF
    If fstat = 100 : Exitfor : Endif
    # process LINE
Until fstat

Close 1
```

The `Using <handle>` gives an integer channel. Always `Close`.

### File info — `filinfo`, `filpath`, `filres$`

| Function | Purpose |
|----------|---------|
| `filinfo(path, code)` | Query a file attribute — `code` 1=size, 2=mtime, 3=exists, 4=is-dir |
| `filpath(type, name, ext)` | Build a folder-aware path, e.g. `filpath("TMP", "extract", "csv")` → `<folder>/TMP/extract.csv` |
| `filres$(path)` | Resolve a path with folder placeholders (`[LAN]`, `[FCY]`, etc.) to an absolute path |
| `rmdir(path)` | Remove a directory |
| `mkdir(path)` | Create a directory |

```l4g
# Check before opening
If filinfo("TMP/incoming.csv", 3) = 0
    Errbox "File not found"
    Return
Endif

# Let the supervisor resolve folder-aware paths
Local Char P(200)
P = filpath("TMP", "extract_" - num$(date$, "YYYYMMDD"), "csv")
Openo P Using 7
```

`filpath` is portable across folders and OSes — prefer it over hand-built `nomap - "/TMP/..."` strings.

### Folder / runtime variables

| Variable | Meaning |
|----------|---------|
| `[V]GUSER` | Current logged-in user code |
| `[V]GLANGUE` | Current language (e.g., `"FRA"`, `"ENG"`) |
| `[V]GSERVEUR` | Server name |
| `nomap` | Current folder code |
| `adxdir` | Installation directory of the runtime |
| `adxmother` | Reference (root) folder name |

## Message and error utilities

```l4g
Infbox mess(<msgno>, <chapter>, 1)          # localized info popup
Errbox mess(<msgno>, <chapter>, 1)          # localized error popup
```

Arguments substitution:

```l4g
Errbox mess(12, 501, 1) - [L]ARG1 - [L]ARG2   # "-" concatenates stripped values
```

## Calling supervisor services via `func`

`func <script>.<name>(<args>)` invokes a function exposed by a `.trt` anywhere in the runtime:

```l4g
[L]CODE = func AFNC.ECHEC("MYFUNC", "Detail")
```

`func` is the way you return a value from a script-to-script call (as opposed to `Call … From …` which is procedural).

## Common gotchas

- **`mid$` is 1-based.** `mid$("HELLO", 1, 3)` → `"HEL"`. In C/Python you'd expect 0-based.
- **`num$` on a Decimal** without format uses locale-dependent separators. Use `format$("N10.2", v)` for stable output.
- **`pat` without `<> 0` inside a `Where`** — filter not pushed to SQL, major performance hit on big tables.
- **`System` blocks** the engine until completion. Don't run long-running processes inline.
- **`Openi` handle numbers** are process-global — collisions between scripts are possible. Prefer small local handles (e.g., 1, 2) and always `Close`.

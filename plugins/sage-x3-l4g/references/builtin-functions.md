# Built-in functions

String, number, formatting, date, file-information, system and encoding functions of the L4G engine,
with their exact names and argument order. Read it before calling any function you are not sure of:
many names that look plausible (`len$`, `upper$`, `replace$`, `round`, `gdat`) do not exist.
Sequential file I/O (`Openi`, `Rdseq`...) is in `sequential-files.md`.

## Contents
- [Strings](#strings)
- [Replacing a substring](#replacing-a-substring)
- [Pattern matching with pat](#pattern-matching-with-pat)
- [Numbers and rounding](#numbers-and-rounding)
- [Formatting with format$](#formatting-with-format)
- [Dates and times](#dates-and-times)
- [Files, system commands and environment](#files-system-commands-and-environment)
- [Messages, JSON, Base64 and UUID](#messages-json-base64-and-uuid)
- [Gotchas](#gotchas)
- [Sources](#sources)

## Strings

| Function | Result |
|---|---|
| `len(S)` | Length in characters (string, CLOB or BLOB) |
| `left$(S, N)` | First N characters (`""` when N = 0) |
| `right$(S, POS)` | Characters **from position POS** to the end: `right$("ABCDEF", 3)` = `"CDEF"` |
| `mid$(S, POS, N)` | Up to N characters starting at POS (1-based) |
| `seg$(S, P1, P2)` | Characters from position P1 to P2 |
| `instr(POS, S, SUB)` | Position of SUB in S, searching from POS; 0 if absent |
| `toupper(S)`, `tolower(S)` | Case conversion, accented letters included |
| `vireblc(S, OPT)` | Spaces: 0 leading, 1 trailing, 2 both, 3 first word only, 4 all, 5 runs collapsed to one |
| `ctrans(S)` | Removes accents, turns non-printable characters into spaces |
| `ctrans(S, IN, OUT)` | Replaces the Nth character of IN by the Nth of OUT; IN characters beyond `len(OUT)` are deleted |
| `string$(N, S)`, `string$(N, CODE)` | S (or `chr$(CODE)`) repeated N times; result capped at 255 characters |
| `space$(N)` | N spaces |
| `chr$(CODE)`, `ascii(S)` | UCS2 code to character; code of the first character (0 for `""`) |
| `num$(X)` | Text of any value: number, date (`DD/MM/YYYY`), UUID, datetime (`YYYY-MM-DDThh:mm:ssZ`) |
| `val(S)` | Number from text, stops at the first invalid character (`val("4A")` = 4, `val("A4")` = 0) |
| `find(X, V1, V2...)` | Rank of X in the list (arrays accepted), 0 if absent |
| `xgetchar(S, POS)` | Character at POS; faster than `mid$` on large CLOBs |
| `sum(...)` | Sum of numbers, or concatenation when the arguments are strings |

Not functions: `len$`, `upper$`, `lower$`, `strip$`, `replace$`, `asc` (an `Order By` keyword).
Use `len`, `toupper`, `tolower`, `vireblc(S, 2)`, the helper below and `ascii`.

## Replacing a substring

`ctrans` maps single characters only. To replace a substring, loop on `instr`:

```l4g
Funprog YREPLACE(TEXT, OLD, NEW)
Value Char TEXT(), OLD(), NEW()
Local Char    RESULT(255)
Local Integer POS
  If [L]OLD = "" : End [L]TEXT : Endif
  [L]POS = instr(1, [L]TEXT, [L]OLD)
  While [L]POS > 0
    [L]RESULT += left$([L]TEXT, [L]POS - 1) + [L]NEW
    [L]TEXT = right$([L]TEXT, [L]POS + len([L]OLD))
    [L]POS = instr(1, [L]TEXT, [L]OLD)
  Wend
End [L]RESULT + [L]TEXT
```

`Char` stops at 255 characters; for longer text declare `Clbfile` variables and grow them with
`Append` (`language-basics.md`).

## Pattern matching with pat

`pat(S, PATTERN)` returns 1 when S matches, else 0. Metacharacters: `*` any sequence (possibly empty),
`?` exactly one character, `#` one digit, `!` one letter. There are no character classes such as
`[abc]`.

```l4g
If pat([L]CODE, "!###")                : # one letter then three digits
  [L]OK = 1
Endif
Local File BPCUSTOMER [BPC] Where pat(BPCNAM, "*SAGE*") <> 0
```

In a `Where`, write `pat(...) <> 0` (or `= 0`): only then is it sent to the database as `LIKE` /
`NOT LIKE`; without the comparison the engine filters every fetched row. For stricter checks use
`format$`, which returns only spaces when the value does not fit: `format$("KA:3A2#", S) = space$(5)`
means S is not three uppercase letters followed by two digits.

## Numbers and rounding

| Function | Result |
|---|---|
| `abs(X)`, `sgn(X)` | Absolute value; sign |
| `int(X)` | Floor: `int(-pi)` = -4 |
| `fix(X)` | Truncation: `fix(-pi)` = -3 |
| `arr(X, STEP)` | Rounds half away from zero to a multiple of STEP: `arr(-40.5, 1)` = -41, `arr(X, 0.05)` |
| `ar2(X)` | `arr(X, 0.01)`: `ar2(40.055)` = 40.06 |
| `mod(X, Y)` | `X - Y*fix(X/Y)`; `mod(X, 0)` = X |
| `rnd(X)` | Random number in [0, X) |
| `min(...)`, `max(...)`, `sum(...)`, `avg(...)` | Aggregates over values and arrays (`sum(ARR(1..N))`) |

There is no `round`: use `arr` or `ar2`.

## Formatting with format$

`format$(FORMAT, VALUE)` returns a `Char`. FORMAT is `TYPE[options]:mask` with TYPE `N` (number),
`D` (date), `K` (string) or `LAnnn` (local menu nnn). Mask codes: `#` digit, `X` any character, `A`
uppercase (lowercase is converted), `a` lowercase, `D` / `M` / `Y` day / month / year, `h` / `m` / `s`
time; a number repeats the next code (`5#` = `#####`, `4Y` = `YYYY`); `9.2` means 9 digits, separator,
2 decimals; text between brackets is copied as is. Spaces are shown as `~` below.

| Call | Result |
|---|---|
| `format$("N0:5.2", pi)` | `"00003.14"` (option `0`: zero padding) |
| `format$("N3:8.2", 10^6*pi)` | `"~3,141,592.65"` (option `3`: digit grouping) |
| `format$("ND:5.2", -pi)` | `"~~~~3.14-"` (option `D`: sign at the end) |
| `format$("N-:5.2", pi)` | `"~~~+3.14"` (option `-`: always show the sign) |
| `format$("N:5.2", 10000*pi)` | `"*****.**"` (overflow) |
| `format$("D:4Y[-]2M[-]2D", date$)` | ISO date, as Sage builds canonical datetimes |
| `format$("D:[The ]DD[th Of ]MMMMMMMMM[, ]YYYY", [5/12/2013])` | `"The 5th Of December, 2013"` |
| `format$("DZ:DD[/]MM[/]YY", [0/0/0])` | `"~~/~~/~~"` (option `Z`: null date allowed) |
| `format$("DD2", [1/1/2013])` | `"01/01/2013"` (`DD1`..`DD5`: formats of the connection locale; DD4/DD5 add the time — the page's text names DD1-DD4, its examples DD5 too) |
| `format$("Kv2:15X", "~~ABC~DEF~~")` | `"ABC~DEF"` (option `v` + `vireblc` code) |
| `format$("K:4A", "abcd")` | `"ABCD"` |

- Decimals beyond the mask are not displayed: round with `arr` / `ar2` first.
- The decimal and grouping separators are the 4th and 3rd characters of the system variable `adxsca`.
  For files exchanged with other systems use `num$` (plain decimal text) or check `adxsca` first.
- A value that does not fit the mask gives a string of spaces, never an error.

## Dates and times

| Function | Result |
|---|---|
| `date$` | Current date, process-server time zone |
| `time$`, `time` | Current local time as `"hh:mm:ss"`; seconds since midnight |
| `datetime$` | Current `Datetime`, in GMT |
| `timestamp$` | Milliseconds since 1970-01-01 GMT, as a string (convert with `val` into a `Decimal`) |
| `gdat$(DAY, MONTH, YEAR)` | Date; out-of-range values roll over: `gdat$(0, M, Y)` = last day of month M-1 |
| `gdatetime$("2012-10-03T07:55:30Z")` | `Datetime` from the canonical GMT string |
| `day(D)`, `month(D)`, `year(D)` | Components |
| `dayn(D)` | 1 = Monday ... 7 = Sunday, whatever the locale |
| `day$(D)`, `month$(D)` | Day / month name in the connection language |
| `week(D)` | 0..53, weeks start Monday; week 0 when 1 January falls Friday to Sunday |
| `addmonth(D, N)` | Adds N months (N may be negative); clamps to month end: `addmonth([31/01/2013], 1)` = `[28/02/2013]` |
| `eomonth(D)` | Last day of the month of D |
| `nday(D)`, `nday$(N)` | Days since `[1/1/1600]`, and back |

```l4g
Local Date DUE, FIRST_DAY
Local Integer ISO_WEEK, LATE_DAYS
  [L]DUE = addmonth(date$, 2)
  [L]FIRST_DAY = gdat$(1, month(date$), year(date$))
  [L]LATE_DAYS = date$ - [L]DUE              : # date - date = number of days
  [L]ISO_WEEK = week(date$) + week(gdat$(31, 12, year(date$) - 1)) * (week(date$) = 0)
```

- Literals: `[31/12/2024]` (day/month/year), null date `[0/0/0]`. There is no `gdat(y,m,d)`.
- Two-digit years (`gdat$(1, 5, 41)`, or `"YYMMDD"` strings) use the pivot year `adxdcs`, taken from the
  connection locale. Always pass four-digit years.
- `date$` / `time$` are server-local; `datetime$` is GMT. UTC date as text: `left$(num$(datetime$), 10)`.

## Files, system commands and environment

`filinfo(PATH, CODE)` returns an integer, negative when the file is missing (-20) or not accessible
(-27):

| CODE | Property | CODE | Property |
|---|---|---|---|
| 0 | File mode (type, permissions) | 6 | Owner group id |
| 1 | Inode (Unix) | 7 | Size in bytes |
| 4 | Number of links (1 on Windows) | 8 | Last access, ms since 1970 |
| 5 | Owner user id | 9 | Last modification, ms since 1970 (Windows: last access) |

- `filpath(DIR, NAME, EXT [, FOLDER [, VOLUME [, SERVER]]])` builds `server@/root/folder/DIR/NAME.EXT`
  without checking existence; `filpath("TMP", "YEXPORT", "csv")` targets the TMP directory of the current
  folder, `filpath("", "", "")` the folder root.
- `delfile(PATH)` and `renamefile(OLD, NEW)` return 0, -20 (missing) or -27 (denied); prefer them to
  `System "rm ..."`.
- `filexist(SERVER, FOLDER, SCRIPT)` tests whether an X3 **script** exists; it is not a file test.

```l4g
Local Char    OUTPUT(250)(1..50)
Local Integer NB
  System OUTPUT = "ls -l" - filpath("TMP", "", "")
  [L]NB = stat1                              : # lines returned; negative if the command failed
  If [L]NB > dim(OUTPUT) : [L]NB = dim(OUTPUT) : Endif
```

- Forms: `System CMD` (output ignored), `System VAR = CMD` (one stdout line per array element; extra
  lines are lost but counted in `stat1`), `Local File (A, B) From System CMD As [ABV]` for long outputs.
- `CMD` runs on the process server; `"@" + CMD` on the application server, `"SERVER@" + CMD` on another
  server running an X3 engine. In cloud environments a sandbox whitelist applies (error 27).
- `getenv$("PATH")` reads the process server environment; `nomap` = current folder,
  `adxmother` / `adxmother(N)` = reference folders, `adxdir` = runtime directory.

## Messages, JSON, Base64 and UUID

- `mess(NUMBER, CHAPTER, TABLE)`: TABLE 1 = application messages, 0 = engine messages. The text comes
  back in the connection language; `errmes$(N)` equals `mess(N, 13, 0)`.
- `escjson(S)` escapes `"`, `\` and control characters for a JSON string; `unescjson(S)` reverses it.
- `LEN = b64encode(BLOB, CLOB)` returns the characters written; `LEN = b64decode(CLOB, BLOB)` returns the
  bytes written and raises error 26 on invalid input.
- `uuid$` returns a new UUID as text; `getuuid` returns an `Uuident`.
- `strencode(SRC, DEST, TYPE)` converts the engine's UCS2 text to TYPE, `strdecode(SRC, DEST, TYPE)`
  converts from TYPE to UCS2 (50 = ASCII, 122 = UCS2, 0 = UTF8); both return the length.
- `checkpath(PATH, MODE)` returns 1 when the sandbox white list allows read (0) or write (1) access.
- JSON parsing and HTTP calls: `web-services-rest-client.md`.

## Gotchas

- `right$(S, N)` starts at position N; it does not return the last N characters
  (use `right$(S, len(S) - N + 1)` for that).
- `int` and `fix` differ on negative numbers.
- A `Date` assigned to a `Char` gives `"YYYYMMDD"`, but `num$(D)` gives `"DD/MM/YYYY"`.
- `string$` and `Char` results stop at 255 characters without error.
- `format$` returns spaces instead of failing; test the result when the input is user data.
- `System` blocks the session until the command ends; avoid long commands in interactive code.

See also: `language-basics.md`, `sequential-files.md`, `localization-formats.md`, `database.md`.

## Sources
- https://online-help.sagex3.com/erp/12/en-us/Content/V7DEV/4gl_x3script-keywords-glossary.html
- https://online-help.sagex3.com/erp/12/en-us/Content/V7DEV/4gl_glossary.html
- https://online-help.sagex3.com/erp/12/en-us/Content/V7DEV/4gl_format$.html
- https://online-help.sagex3.com/erp/12/en-us/Content/V7DEV/4gl_gdat$.html
- https://online-help.sagex3.com/erp/12/en-us/Content/V7DEV/4gl_filinfo.html
- https://online-help.sagex3.com/erp/12/en-us/Content/V7DEV/4gl_system.html
- https://online-help.sagex3.com/erp/12/en-us/Content/V7DEV/4gl_pat.html
- Same V7DEV base, pages `4gl_<name>.html` for: len, left$, right$, mid$, seg$, instr, toupper,
  tolower, vireblc, ctrans, string$, chr$, ascii, num$, val, find, xgetchar, sum, abs, int, fix, arr,
  ar2, mod, rnd, date$, time$, time, datetime$, timestamp$, gdatetime$, dayn, day$, month$, week,
  addmonth, eomonth, nday, nday$, adxdcs, date, char, filpath, filexist, delfile, renamefile, stat1,
  getenv$, nomap, adxmother, adxdir, mess, errmes$, escjson, unescjson, b64encode, b64decode, uuid$,
  strencode, strdecode, checkpath, append.

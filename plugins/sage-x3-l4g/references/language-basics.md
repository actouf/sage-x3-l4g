# L4G language basics

Lexical rules, variables, data types, operators, control flow, subprograms and error trapping of the
Sage X3 4GL (L4G) engine. Read this before writing or reviewing any script. Database access lives in
`database.md`, functions in `builtin-functions.md`, file I/O in `sequential-files.md`.

## Contents
- [Lexical rules](#lexical-rules)
- [Variables, classes and arrays](#variables-classes-and-arrays)
- [Data types](#data-types)
- [Literals and operators](#literals-and-operators)
- [Control flow](#control-flow)
- [Subprograms, functions and Gosub](#subprograms-functions-and-gosub)
- [Error trapping with Onerrgo](#error-trapping-with-onerrgo)
- [Gotchas](#gotchas)
- [Sources](#sources)

## Lexical rules

- Keywords are case-insensitive **and reserved**: `For`, `FOR` and `for` are the same keyword, and no
  variable may be named after a keyword in any case (`DATE`, `FILE`, `KEY`, `VALUE`, `WHERE`... are all
  keywords). Identifiers are case-insensitive too; the editor rewrites them in uppercase.
- `:` separates statements on one line. `#` starts a comment; after a statement write `: # comment`.
- A statement continues on the next line when that next line **starts** with `&`.
- Strings are delimited by double **or** single quotes: `"it's"`, `'say "hi"'`. Sage's own samples use
  both (`filpath('TMP','rdfile1','')`).
- Labels are written `$LABEL` at the start of a line (Sage's grammar also accepts the bare name; house
  style keeps the `$`). A label needs no declaration but must be unique in its script.
- `Then` after an `If` condition is optional.

```l4g
Local Char MSG(250) : # inline comment
# full-line comment
[L]MSG = "Commande" - [L]ORDNUM - "du client" - [L]CUSTNUM
& - "bloquée"
If [L]I = 1 Then [L]J = 2 Else [L]J = 3 : Endif
```

## Variables, classes and arrays

Every variable lives in a class (namespace) that can be written as a prefix:

| Prefix | Content |
|---|---|
| `[L]` | Locals of the current `Subprog` / `Funprog` / method; shared with code reached by `Gosub` |
| `[V]` | Globals (`Global`), including Sage constants such as `[V]CST_AOK` |
| `[S]` | Engine system variables: `fstat`, `adxlog`, `adxuprec`, `nomap`... |
| `[F:ABV]` (or `[ABV]`) | Current record buffer of the table opened with abbreviation ABV |
| `[G:ABV]` | Table metadata: `nbzon`, `nbind`, `adxfname`, `currind`... |

```l4g
Local Integer  I, J
Local Decimal  AMOUNT
Local Char     CODE(20)                : # 1..255 characters
Local Char     LINES(80)(1..100)       : # 100 strings of 80 characters, indexes 1..100
Local Integer  SLOTS(10)               : # a single number N means indexes 0..N-1
Local Decimal  MATRIX(1..5, 1..12)     : # up to 4 dimensions
Local Char     NAMES(30)(1..)          : # open-ended array; highest used index = maxtab(NAMES)
Local Clbfile  BODY(2)                 : # CLOB, grows automatically
Local Instance YORD Using C_YORDER     : # V7+ class instance, see v12-classes.md
```

- `Global` creates a `[V]` variable that lives for the whole process. Sage discourages it (it prevents
  re-entrant code); keep it for constants.
- `Default Local` / `Default Global` choose where *undeclared* variables get auto-created on first
  assignment. Do not rely on auto-creation: declare everything.
- `dim(VAR)` = size of the first dimension (`-1` if the variable does not exist), `dim(VAR,0)` = number
  of dimensions, `dim(VAR,-N)` = first index of dimension N. `maxtab(ARR)` = highest used index.
- `Raz VAR, [F:ABV]` resets to null values (`""`, `0`, `[0/0/0]`, `Null`); `Kill VAR` destroys an
  `[L]` or `[V]` variable.

## Data types

| Keyword | Content |
|---|---|
| `Tinyint` | Integer 0..255. Replaces the deprecated `Libelle`; class properties of local-menu type are Tinyint |
| `Shortint` | Integer -32768..32767 |
| `Integer` | Integer -2^31..2^31-1 |
| `Decimal` | Binary-coded decimal, up to 32 digits: use it for amounts and quantities |
| `Float`, `Double` | Hardware-dependent floating point; Sage recommends `Decimal` instead |
| `Char NAME(N)` | Unicode string of 1..255 characters |
| `Schar NAME(N)` | 1-byte characters (no Unicode), 1..255; strongly discouraged |
| `Date` | `[1/1/1600]`..`[31/12/9999]`, plus the null date `[0/0/0]` |
| `Datetime` | Date and time in GMT; text form `YYYY-MM-DDThh:mm:ssZ` |
| `Clbfile NAME(N)` | CLOB. N (0..20) sizes the initial buffer (0 = 510 chars, 1 = 1022, 2 = 2046...); it auto-grows |
| `Blbfile NAME(N)` | BLOB, same sizing rule |
| `Uuident` | UUID |
| `Instance NAME Using C_X` | Pointer to a class (`C_`) or representation (`R_`) instance; `Null` until `NewInstance` |

`Mask` is **not** a data type: it is a deprecated Classic keyword declaring a screen mask (see
`screens-and-masks.md`). Never declare `Char X(4000)`: use `Clbfile`.

Implicit conversions documented by Sage:
- Decimal / Float / Double into an integer type truncates (`[L]MY_INT = 78956.23` gives 78956).
- A `Date` assigned to a `Char` gives `"YYYYMMDD"`; a `"YYYYMMDD"` or `"YYMMDD"` string assigned to a
  `Date` is converted (two-digit years use the pivot year `adxdcs`).
- `Datetime`, `Uuident` and `Instance` have no implicit conversion.

## Literals and operators

- Date literal `[31/12/2024]` (day/month/year), null date `[0/0/0]`.
- Arithmetic `+ - * /` and power `^`; compound `+=` and `-=`. Date + integer = date; date - date = number
  of days.
- Comparison `= <> < > <= >=`. For a case-insensitive comparison Sage applies `toupper()` to both sides.
- String concatenation: `+` joins as-is; `-` joins **with one space** between the operands (Sage's
  examples: `"rm"-PATH`, and `"AAAA"-[31/12/2099]` gives `"AAAA 20991231"`). `Append VAR, EXPR` appends
  efficiently to a long `Clbfile`.
- Logical: `and` (also `&`), `or` (also `|`), `xor` (also `?`), `not` (also `!`). Conditions are numbers:
  0 is false, anything else is true; logical operators return 0 or 1. `and` / `or` short-circuit from
  left to right.
- Sage's conditional-text idiom: `string$(COND, "TEXT")` returns `"TEXT"` when COND is 1, `""` when 0.

## Control flow

```l4g
If [L]QTY > 0 and [L]PRICE > 0
  [L]AMOUNT = ar2([L]QTY * [L]PRICE)
Elsif [L]QTY = 0
  [L]AMOUNT = 0
Else
  [L]AMOUNT = -1
Endif

Case [L]STATUS
  When 1, 2
    [L]TEXT = "Ouvert"
  When 3
    [L]TEXT = "Clos"
  When Default
    [L]TEXT = "Inconnu"
Endcase

For I = 1 To dim(LINES)
  Break LINES(I) = ""                  : # Break 0 does nothing, Break 1 exits the loop
  Call YPROCESS_LINE(LINES(I)) From YUTIL
Next I

For CUR = "EUR", "USD", "GBP"          : # list form
  Gosub YLOAD_RATE
Next CUR

While [L]TRIES < 5 and [L]DONE = 0
  [L]TRIES += 1
  Gosub YATTEMPT
Wend

Repeat
  Gosub YNEXT_STEP
Until [L]DONE
```

- `Case` never falls through: a `When` with no statements simply does nothing. Nothing (not even a
  comment) may sit between `Case` and the first `When`; `When Default` must be the last branch.
- `Break` leaves the innermost `For` / `While` / `Repeat`; `Break N` leaves N nested loops and `Break 0`
  does nothing, so `Break (COND)` is a conditional exit.
- There is no `Continue`, `Exit`, `Exitfor`, `Incr` or `Decr`: wrap the rest of the loop body in an `If`
  to skip an iteration, and write `+= 1` / `-= 1`.
- The numeric `For` variable and its bounds cannot be changed inside the loop; after `Next` the variable
  holds the first value past the limit. `Step` may be negative.
- `For [ABV]... Next` also iterates database cursors: see `database.md`.
- `Goto LABEL` exists but makes code unreadable; prefer `Gosub` or a loop with `Break`.

## Subprograms, functions and Gosub

```l4g
Subprog YSUM_LINES(AMOUNTS, NB, TOTAL)
Const    Decimal AMOUNTS(1..)          : # read-only reference: the caller must pass a variable
Value    Integer NB                    : # copy: the caller may pass an expression
Variable Decimal TOTAL                 : # reference: written back to the caller
Local Integer I
  [L]TOTAL = 0
  For I = 1 To [L]NB
    [L]TOTAL += [L]AMOUNTS(I)
  Next I
End

Funprog YNET_AMOUNT(GROSS, RATE)
Value Decimal GROSS, RATE
  If [L]RATE = 0 : End [L]GROSS : Endif
End ar2([L]GROSS / (1 + [L]RATE / 100))
```

```l4g
Call YSUM_LINES([L]PRICES, maxtab([L]PRICES), [L]TOTAL) From YUTIL
[L]NET = func YUTIL.YNET_AMOUNT([L]TOTAL, 20)
Gosub YWRITE_LOG                       : # label in the current script
Gosub YWRITE_LOG From YUTIL            : # label in another script
Call =[L]SUBNAME With ([L]TOTAL) From YUTIL
```

- Parameter declarations (`Value`, `Variable`, `Const`) are optional and must immediately follow the
  `Subprog` / `Funprog` line. An undeclared parameter behaves as `Const`.
- `Const` is a parameter-passing mode (read-only reference), not a constant declaration. A constant or an
  expression can only be passed to a `Value` parameter; passing one to `Variable` or `Const` fails at
  run time.
- `Funprog` must end with `End VALUE` (a bare `End` is an error there); `Subprog` ends with `End`. Both
  are "Public" keywords in Sage's glossary, i.e. they already existed in V6.
- `Call` / `func` create a new `[L]` class. Inherited: globals, system variables, opened tables, opened
  sequential files. Not inherited: the caller's locals and its `Onerrgo` label.
- `Gosub` shares everything with the caller (locals, tables, transaction, error handler) and takes no
  parameters. The label ends with `Return`; code reached by `Call` / `func` ends with `End`.
- A transaction opened with `Trbegin` must be closed at the same call level, and an `End` reached with
  the transaction still open rolls it back. Canonical idiom: `database.md`.
- A script name is resolved in the current folder first, then in the parent folders (`adxmother`).

## Error trapping with Onerrgo

```l4g
Funprog YSAFE_RATIO(NUM, DEN)
Value Decimal NUM, DEN
Local Decimal RESULT
Local Integer ERR_NUM
Local Char    ERR_TXT(250)
  Onerrgo YRATIO_ERR
  [L]RESULT = [L]NUM / [L]DEN
  Onerrgo                              : # disarm the handler
  If [L]ERR_NUM <> 0 : End 0 : Endif
End [L]RESULT

$YRATIO_ERR
  [L]ERR_NUM = errn
  [L]ERR_TXT = errmes$(errn) - "line" - num$(errl) - "script" - errp - errm
  Resume
```

- `Onerrgo LABEL` (or `Onerrgo LABEL From SCRIPT`) arms the handler; `Onerrgo` alone disarms it. There
  is no `Onerrgo 0`.
- In the handler: `errn` (error number), `errl` (line), `errp` (script), `errm` (extra detail),
  `errmes$(errn)` (message in the connection language).
- Leave the handler with `Resume` (execution continues after the failing statement; if the error occurred
  inside an `If` / `For` / `While` / `Repeat` block, it continues after the block's `Endif` / `Next` /
  `Wend` / `Until`) or with `End` (the routine ends; a transaction it opened is rolled back).
- An error raised inside the handler is not rerouted again.
- Handlers are not inherited: when a routine reached by `Call` has no handler of its own, its error
  aborts it and the caller's handler runs as if the error had occurred on the `Call` line. Arm
  `Onerrgo` in the called script when it must recover locally.
- `fstat` codes are return statuses, distinct from the runtime errors listed under "Associated errors"
  on each keyword page; only runtime errors reach `Onerrgo`. Tracing: `debugging-traces.md`.

## Gotchas

- `Local Integer TAB(10)` has indexes 0..9, not 1..10; write `TAB(1..10)` when you mean it.
- `Char` stops at 255 characters and silently truncates longer assignments.
- The default branch is `When Default`, not `Default`.
- A label reached by `Gosub` must end with `Return`; a `Return` without a `Gosub` raises error 32.
- `Float` and `Double` lose precision (`42949672951` becomes `4.29497e+10` in a Float): use `Decimal`.
- Naming a variable after a keyword (`DATE`, `KEY`, `VALUE`, `FILE`) does not compile.
- `Global` variables survive across calls for the whole process: stale values leak between runs.
- Custom symbols take the X/Y/Z prefixes described in `conventions-and-naming.md`.

See also: `database.md`, `builtin-functions.md`, `sequential-files.md`, `v12-classes.md`,
`debugging-traces.md`.

## Sources
- https://online-help.sagex3.com/erp/12/en-us/Content/V7DEV/4gl_x3script-keywords-glossary.html
- https://online-help.sagex3.com/erp/12/en-us/Content/V7DEV/4gl_glossary.html
- https://online-help.sagex3.com/erp/12/en-us/Content/V7DEV/4gl_local.html
- https://online-help.sagex3.com/erp/12/en-us/Content/V7DEV/4gl_global.html
- https://online-help.sagex3.com/erp/12/en-us/Content/V7DEV/4gl_default.html
- https://online-help.sagex3.com/erp/12/en-us/Content/V7DEV/4gl_char.html (also 4gl_tinyint, 4gl_shortint,
  4gl_integer, 4gl_decimal, 4gl_float, 4gl_double, 4gl_schar, 4gl_date, 4gl_datetime, 4gl_clbfile,
  4gl_blbfile, 4gl_uuident, 4gl_instance)
- https://online-help.sagex3.com/erp/12/en-us/Content/V7DEV/4gl_and.html (also 4gl_or, 4gl_xor, 4gl_not)
- https://online-help.sagex3.com/erp/12/en-us/Content/V7DEV/4gl_append.html
- https://online-help.sagex3.com/erp/12/en-us/Content/V7DEV/4gl_delfile.html (`-` concatenation sample)
- https://online-help.sagex3.com/erp/12/en-us/Content/V7DEV/4gl_if.html (also 4gl_then, 4gl_case,
  4gl_for, 4gl_while, 4gl_repeat, 4gl_break, 4gl_goto)
- https://online-help.sagex3.com/erp/12/en-us/Content/V7DEV/4gl_call.html (also 4gl_func, 4gl_subprog,
  4gl_funprog, 4gl_gosub, 4gl_return, 4gl_end, 4gl_value, 4gl_variable, 4gl_const)
- https://online-help.sagex3.com/erp/12/en-us/Content/V7DEV/4gl_onerrgo.html (also 4gl_resume, 4gl_errn,
  4gl_errl, 4gl_errp, 4gl_errm, 4gl_errmes$.html)
- https://online-help.sagex3.com/erp/12/en-us/Content/V7DEV/4gl_dim.html (also 4gl_maxtab, 4gl_raz,
  4gl_kill)

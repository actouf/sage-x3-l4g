# L4G Language Basics

Variables, types, control flow, subprograms, and error handling.

## Variable declaration

Syntax: `<Scope> <Type> <NAME>[(dimension)]`

```l4g
Local  Integer  I, J, K                 # Three integer locals
Local  Char     LABEL(30)               # Fixed-length string, 30 chars
Local  Char     LINES(80)(1..100)       # Array: 100 strings of 80 chars
Local  Decimal  AMOUNT
Local  Date     DAT
Global Integer  GSTATUS                 # Global: lives for the session
```

### Scopes

| Scope | Lifetime |
|-------|----------|
| `Local` | Current script only (script = `.src` / `.trt` file or `Subprog` body) |
| `Global` | Whole user session — use for cross-script state |
| `Value` | Input parameter (pass-by-value) in `Subprog`/`Funprog` header |
| `Variable` | Input/output parameter (pass-by-reference) |
| `Const` | Constant value |

### Core types

| Type | Description |
|------|-------------|
| `Integer` | 32-bit signed |
| `Shortint` | 16-bit signed |
| `Decimal` | Arbitrary-precision numeric — use for currency |
| `Char` | Fixed-length string, declare size in parentheses |
| `Date` | Date, format is locale-dependent |
| `Clbfile` | Long text (CLOB) |
| `Blbfile` | Binary large object (BLOB) |
| `Mask` | Reference to a screen mask |

Beware: `Char` without a length defaults to 1. Always give an explicit size.

### Array dimensions

Single dimension: `Local Char LINES(80)(1..100)` — 100 elements.
Starting index can be 0 or 1; convention in X3 standard code is `1..N`.

```l4g
Local Integer TAB(0..9)       # 10 elements, indices 0..9
Local Integer MAT(1..5, 1..5) # 5x5 matrix
```

## Operators

Arithmetic: `+ - * /` and `**` for power.
Comparison: `= <> < > <= >=`
Logical: `And`, `Or`, `Not`, `Xor` (not `&&` / `||`).
String concat: `+` (and `-` means "trim trailing spaces then append" for fixed-length strings).

```l4g
Local Char NAME(30)
NAME = "Jean "
LABEL = "Hello " - NAME - "!"   # "Hello Jean!" — trims trailing padding
```

## Control flow

### If / Elsif / Else / Endif

```l4g
If COND1
    ...
Elsif COND2
    ...
Else
    ...
Endif
```

### While / Wend and Repeat / Until

```l4g
While I < 10
    I += 1
Wend

Repeat
    I -= 1
Until I = 0
```

### For / Next on a range

```l4g
For I = 1 To 10 Step 2
    [L]TOTAL += I
Next I
```

Note: `For` is **also** the database iterator (see `database.md`) — the range form uses `To`/`Step`; the database form uses a class name.

### Case / When / Default

```l4g
Case STATUS
    When "A" : [L]TEXT = "Actif"
    When "I" : [L]TEXT = "Inactif"
    When "F", "C" : [L]TEXT = "Fermé ou clos"
    Default : [L]TEXT = "Inconnu"
Endcase
```

### Gosub / Return (labelled subroutines within a script)

```l4g
Gosub MY_SUB
...
$MY_SUB
    # code here
    [L]RESULT = 42
Return
```

Labels start with `$`. `Gosub` is **local to the current script**. For cross-script calls, use `Call`.

## Subprograms

`Subprog` = procedure (no return value).
`Funprog` = function (returns via `End <expr>`).

```l4g
Subprog MY_PROC(PARAM1, PARAM2)
Value    Char    PARAM1()            # Pass by value, string of any length
Variable Integer PARAM2              # Pass by reference
Local    Integer I

    # body
    PARAM2 = len(PARAM1) + I

End                                   # returns void
```

```l4g
Funprog COMPUTE(X, Y)
Value Decimal X, Y
    If Y = 0
        End 0                         # Early return
    Endif
End X / Y                             # Return value
```

### Calling across files

```l4g
Call MY_PROC(VAL1, VAL2) From YSCRIPT
```

`YSCRIPT` is the name of the `.src` or `.trt` containing `MY_PROC`. The engine finds it via the activity code / folder setup.

For functions:

```l4g
[L]RATIO = func YSCRIPT.COMPUTE(AMT, RATE)
```

## Error handling

### `Onerrgo` — jump to a label on any runtime error

```l4g
Onerrgo RECOVER

# risky code here
Openi "path" Using [L]HDL

...
Return

$RECOVER
    # cleanup, log, etc.
    Call ECRAN_TRACE("Error: " + num$([S]stat1), 1) From GESECRAN
Return
```

`Onerrgo 0` disables the handler (back to default behavior).

### Inspect `[S]fstat` and `[S]stat1`

- `fstat` — set by DB / sequential file operations. 0 = success.
- `stat1` — set by `System` calls and some engine-level errors.

### Early exits

- `End` or `End <expr>` — exits the current subprogram.
- `Return` — exits the current script or `Gosub`.
- `Exitfor` — breaks out of a `For` loop.
- `Continue` — skips to the next iteration (V7+).

## Operations that look weird coming from C/Java/Python

- `Raz <var>` — reset/zero a variable or struct. Uses type-appropriate zero.
- `Incr I` / `Decr I` — synonyms for `I += 1` / `I -= 1`.
- `:` as statement separator, not line terminator — newlines also terminate.
- No `switch/break`; Case falls through only if you list multiple values in `When`.
- String literals are double-quoted; single quotes are reserved.
- Hash (`#`) is a comment character, **not** a preprocessor directive.

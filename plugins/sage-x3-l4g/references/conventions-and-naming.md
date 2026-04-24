# Conventions and naming

Rules that aren't enforced by the compiler but that every Sage X3 project follows. Ignore them and your code will clash with the standard, break on upgrade, or be rejected by code review.

## The sacred rule: Y and Z prefixes for custom code

Standard X3 symbols use any letter **except Y and Z**. Your custom (specific) code **must start with Y or Z** — for:

- Tables — e.g., `YMYTABLE`, `ZLOGBOOK`
- Screens — e.g., `ZGESBPC` (customized copy of `GESBPC`)
- Scripts — e.g., `YTRANSFER.src`, `ZCHECK.trt`
- Activity codes — e.g., `YTRK`, `ZPER`
- Message chapters — numbers 500 and above
- Menu items, windows, reports, objects — same rule

**Why:** when Sage ships an upgrade, standard code is overwritten. Anything Y- or Z-prefixed is preserved. Conversely, modifying standard code directly means your change is lost on every patch.

Convention: **Y** = partner / vertical add-on code. **Z** = end-customer specific. In practice many teams use only one or the other.

## Three-letter table abbreviations

Every table has a **3-letter alias** used in class references `[F:...]` and mask references `[M:...]`. Standard abbreviations you'll see constantly:

| Alias | Table | Meaning |
|-------|-------|---------|
| `BPC` | BPCUSTOMER | Business Partner — Customer |
| `BPS` | BPSUPPLIER | Business Partner — Supplier |
| `BPR` | BPARTNER | Business Partner — generic |
| `ITM` | ITMMASTER | Item master |
| `ITF` | ITMFACILIT | Item-site |
| `STO` | STOCK | Stock lines |
| `SOH` | SORDER | Sales order header |
| `SOQ` | SORDERQ | Sales order line |
| `POH` | PORDER | Purchase order header |
| `MFG` | MFGHEAD | Manufacturing order header |
| `GACC` | GACCOUNT | General ledger account |
| `CPT` | CPTANALY | Analytical account |

Custom tables should use `Y` or `Z` + two letters, e.g., `YCL` for `YCUSTLOG`.

## File extensions and structure

| Extension | Purpose |
|-----------|---------|
| `.src` | Source — reusable subprograms called from elsewhere |
| `.trt` | Treatment — process / action script, often tied to a screen |
| `.adx` / `.adp` | Compiled bytecode (generated — don't edit) |
| `.adc` | Pre-compiled include |

Files live under `<folder>/TRT/` and are compiled on first use. The supervisor maintains a cache.

## Script structure

Every custom script should start with a banner:

```l4g
##############################################################
# YMY_SCRIPT  —  Short description
# Author:   initials / date
# Called by: <caller context>
# Purpose:  <what it does>
##############################################################
```

Then declarations, then `$MAIN` or a `Subprog` / `Funprog`, then `Return` / `End`.

## Indentation and formatting

- **2 spaces** for indentation (no tabs — tabs render unpredictably in the Sage editor).
- Keywords in **PascalCase**: `If`, `Then`, `Else`, `Endif`, `For`, `Next`, `Local`, `Value`, `Return`, `End`.
- Identifiers (variables, tables, fields) in **UPPERCASE**. The editor will rewrite them anyway.
- One statement per line, except for very short conditional blocks: `If X : Y : Endif`.
- Leave blank lines between logical sections.

## Comments

```l4g
# Full-line comment at start of line

Local Integer I : # Inline comment after a statement separator

######### SECTION HEADER #########
```

Use comments to document *why*, not *what* — the language is low-level enough that readers can see *what* easily.

## Activity codes

Activity codes (`AFC`) are how Sage partitions code by functional domain. Your specific code should carry an activity code starting with `Y` or `Z` so it's excluded from standard upgrades. Every record (table, field, screen, script) has an activity-code column — get it right when creating new objects.

## Labels

- Labels inside a script start with `$`: `$MAIN`, `$LIENS`, `$CTRL_CODE`.
- Standard action labels — `$LIENS`, `$AVBAS`, `$APBAS`, `$ANNUL`, `$DEBSAI`, `$FINSAI` — can be used as-is; your own labels inside a standard script should be Y/Z-prefixed: `$YCHECK_INPUT`.

## Activity-code-based conditional compilation

```l4g
$ACT=YMYCODE
    # code only compiled when YMYCODE activity is active in the folder
$FIN
```

This is how you ship code that activates only in folders where your vertical is installed.

## Message chapters

| Range | Usage |
|-------|-------|
| 0–99 | Standard system messages |
| 100–199 | Standard functional messages |
| 200–499 | Reserved by Sage |
| 500+ | Custom chapters — use these |

Refer to messages via `mess(<num>, <chapter>, 1)` — never hardcode strings.

## Where things live in a folder

- `<folder>/TRT/*.src`, `*.trt` — source files
- `<folder>/DAT/` — data files (reports, templates)
- `<folder>/PRT/` — reports
- `<folder>/TMP/` — scratch / temporary
- `<folder>/GEN/` — generated class files (`[F:...]`, `[M:...]`)

Patches are delivered as `.dat` files applied via the patch tool (AWE, AIMPPAT).

## Commit policies

- Version-control `.src` and `.trt` separately from the compiled `.adx` / `.adp` (ignore the latter).
- Each patch delivery should regenerate all `.adx` via the supervisor's recompile-all.
- Never commit dictionary data (`.dat` exports) without the corresponding script changes — they're coupled.

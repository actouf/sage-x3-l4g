# Imports and exports

X3 ships a templated import/export framework (**IMP/EXP**) — you declare a template in the dictionary and the supervisor drives the file parsing, validation, and DB write. This is almost always better than hand-rolling a file loader in L4G.

This file covers: IMP/EXP templates, how to trigger them from code, and when to fall back to manual file I/O.

## The IMP/EXP framework

### Templates live in the dictionary

- **Export templates** (`GESAOE`) — declare what rows get emitted, with what field layout
- **Import templates** (`GESAOI`) — declare how to parse an incoming file and map to tables

A template consists of:
- **Header**: code (Y/Z for custom), separator (`;`, `,`, `\t`, fixed-width), encoding, date format
- **Lines**: one line per target field, with source column, type, validation rule
- **Activation**: which object it belongs to (customer, order, article…)

### Running an import from L4G

```l4g
Local Char FILE(200), TEMPLATE(20)
FILE = "TMP/customers_today.csv"
TEMPLATE = "YIMPCUS"

Call LECFIC(TEMPLATE, FILE, "", "") From IMPOBJ

If [S]stat1
    Errbox "Import failed, see trace (stat1=" + num$([S]stat1) + ")"
Endif
```

Args to `LECFIC`:
1. Template code (from `GESAOI`).
2. Input file path (absolute or relative to `<folder>/TMP/`).
3. Trace file path (empty = default auto-generated).
4. Options string (rarely used — "SIM" for simulation mode, "REJ=<path>" for reject file).

### Running an export from L4G

```l4g
Local Char OUTFILE(200), TEMPLATE(20)
OUTFILE = "TMP/export_" - num$(date$, "YYYYMMDD") - ".csv"
TEMPLATE = "YEXPCUS"

Call OUVRE_FIC(TEMPLATE, OUTFILE, "") From EXPOBJ
Call LANCEXP From EXPOBJ
Call FERME_FIC From EXPOBJ
```

Or in one shot (newer V12 supervisors):

```l4g
Call EXPFIC(TEMPLATE, OUTFILE, "") From EXPOBJ
```

### Why use templates over raw file I/O

| Concern | Template | Raw I/O |
|---------|----------|---------|
| Validation | Built-in (dictionary types, mandatory flags, controlled values) | You write it |
| Encoding | Declarative | You handle BOM, charsets manually |
| Reject rows | Auto-written to reject file | You track yourself |
| Triggers | Object's `beforeSave` / `afterSave` run automatically | You call them manually |
| Upgrade-proof | Survives X3 patches | May break when standard object changes |
| Trace | Automatic in the X3 log | You write your own |

The only reason to bypass templates is when the source format is genuinely unstructured (nested JSON, multi-line records, custom binary) or you need non-standard business logic per row.

## Import with per-row custom logic

When you need to transform values or enrich records during import, templates support **calls** at specific steps. In `GESAOI`, for each line you can specify:

| Hook | Fires |
|------|-------|
| `CTRL` | After parse, before DB commit — return code 0 = accept, else reject |
| `INIT` | Before any read of the target object — set defaults |
| `FIN` | After commit — post-processing (trigger email, log) |

Each hook points at a `Subprog` in your custom `.src`:

```l4g
##############################################################
# YIMPCUS_CTRL — validation hook for import template YIMPCUS
# Called once per line after parsing, before the customer is written
##############################################################
Subprog YIMPCUS_CTRL()
    If [M:BPC]BPCNUM = ""
        [V]GOK = 0                       # reject this row
        Call ECRAN_TRACE("BPCNUM vide", 2) From GESECRAN
        End
    Endif
    If not pat([M:BPC]BPCCRN, "#########")
        [V]GOK = 0
        Call ECRAN_TRACE("SIREN invalide: " - [M:BPC]BPCCRN, 2) From GESECRAN
        End
    Endif
End
```

The template populates `[M:BPC]` (the object's mask class) from the file; your hook validates against it.

## Incremental / delta imports

Standard pattern for syncing from an external system:

```l4g
##############################################################
# YIMP_DELTA — pulls new orders from /inbox, processes, archives
##############################################################
$MAIN
Local Char INBOX(200), PROCESSED(200), FILES(200)(1..100)
Local Integer I, N

INBOX = "TMP/inbox/"
PROCESSED = "TMP/processed/"

System "ls " - INBOX - "*.csv" = FILES
N = 0
For I = 1 To dim(FILES)
    If FILES(I) = "" : Exitfor : Endif
    Call LECFIC("YIMPORD", INBOX - FILES(I), "", "") From IMPOBJ
    If [S]stat1
        Call ECRAN_TRACE("Fichier rejeté: " - FILES(I), 2) From GESECRAN
    Else
        System "mv " - INBOX - FILES(I) - " " - PROCESSED
        Incr N
    Endif
Next

Call ECRAN_TRACE(num$(N) + " files processed", 1) From GESECRAN
Return
```

Schedule with `GESABA`/`GESAPL`. Always move processed files out of the inbox — idempotency protects you against re-running the same file.

## Exports — common traps

### Encoding

`EXPOBJ` defaults to the folder's encoding (usually Latin-1 for legacy, UTF-8 for V12). Partners expecting UTF-8 with BOM need a destination config override or a post-processing step.

### Line endings

Windows destinations get CRLF, Unix LF — the template config controls this. If your partner fails on mixed endings, force it in the template.

### Delimiter collision

A customer name `"Dupont, Jean"` in a CSV with `,` separator breaks everything. Templates have a quoting option — enable it or switch to `;` or `\t`.

### Big extracts

For millions of rows, stream to disk rather than building a giant string in memory. Templates do this correctly; raw `Writeseq` loops do too. **Never build a multi-MB string via `CHR += ROW`** — quadratic memory.

## Manual CSV / fixed-width import when templates don't fit

```l4g
##############################################################
# YIMP_MANUAL — custom parser for a nested-format file
##############################################################
Subprog YIMP_MANUAL(FILE)
Value Char FILE()

Local Char    LINE(2000), CODE(20), VAL(100)
Local Integer HDL, LN

HDL = 1
Openi FILE Using HDL
If fstat : End : Endif

LN = 0
Repeat
    Readseq LINE Using HDL
    If fstat = 100 : Exit : Endif           # EOF
    If fstat : Exit : Endif                 # error
    Incr LN

    # Skip header line
    If LN = 1 : Continue : Endif

    CODE = strip$(mid$(LINE, 1, 20))
    VAL  = strip$(mid$(LINE, 21, 100))

    If CODE = "" : Continue : Endif

    Trbegin [YTBL]
    Read [YTBL]CODE0 = CODE
    If fstat                                # new
        Raz [F:YTBL]
        [F:YTBL]CODE = CODE
        [F:YTBL]VAL = VAL
        Write [YTBL]
    Else                                     # update
        Readlock [YTBL]CODE0 = CODE
        [F:YTBL]VAL = VAL
        Rewrite [YTBL]
    Endif
    If fstat : Rollback : Else : Commit : Endif
Until fstat

Close HDL
End
```

Note the **per-row transaction** — prevents a single bad row from blocking the whole file, and keeps locks short. See `database.md`.

## File validation before import

A common pre-check to avoid running `LECFIC` on a truncated/corrupt file:

```l4g
Subprog YPRECHECK(FILE, NBLINES)
Value    Char    FILE()
Variable Integer NBLINES

Local Char LINE(4000)
Local Integer HDL
HDL = 1
NBLINES = 0

Openi FILE Using HDL
If fstat : End : Endif
Repeat
    Readseq LINE Using HDL
    If fstat = 100 : Exit : Endif
    If fstat : Exit : Endif
    Incr NBLINES
Until fstat
Close HDL
End
```

Call before `LECFIC`; abort with a clear error if `NBLINES` is 0 or well below expected.

## Gotchas

- **Trace file always grows.** Templates append to `<folder>/TRA/` — purge these regularly or you'll eat disk.
- **Rejected rows silent by default.** Unless you pass `"REJ=<path>"` or configure a reject destination in the template, bad rows are logged to the trace only.
- **Default paths are relative.** `"TMP/file.csv"` resolves inside the current folder. Absolute paths survive folder switches; prefer them in scheduled jobs.
- **Templates run under the batch user** when scheduled — ACLs apply. A template that works interactively may fail at night with a permission error.
- **Simulation mode lies about timings.** `"SIM"` validates but skips the actual write. Useful for testing, but don't benchmark imports with it — real commits take most of the time.
- **Delete is rare in imports.** Most templates only insert/update. If a partner sends "removed items", usually you mark a flag rather than actually deleting — preserves history and avoids FK cascades.

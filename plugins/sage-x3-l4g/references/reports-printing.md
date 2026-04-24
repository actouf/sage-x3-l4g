# Reports and printing

X3 has three print engines living side by side: **Crystal Reports** (legacy SAP/BusinessObjects, still dominant), **SAP Crystal for Sage** (rebadged), and **native X3 states** (older, still used for simple reports). V12 can drive all of them from L4G the same way.

## The big picture

1. **Report definition** lives in `GESARP` (report dictionary) — name, source data, layout file, parameters.
2. **Print code** (the layout) is a `.rpt` (Crystal) or `.dict`+`.for` (native X3) stored under `<folder>/PRT/`.
3. **Report call** from L4G goes through a supervisor entry point (`IMPRIM`, `LECFIC`, etc.) which resolves the dictionary, renders, and routes to a **destination**.
4. **Destinations** (`GESADI`) describe where output goes: screen, printer, file, email, Excel.

## Launching a report from L4G

### Standard pattern

```l4g
Local Char PARAMS(500)

# Pass parameters as "NAME=VALUE;NAME=VALUE" — the supervisor parses them
PARAMS = "ITMREF=ITM001;FCY=NA011;DATDEB=" - num$(date$ - 30, "YYYYMMDD") -
         ";DATFIN=" - num$(date$, "YYYYMMDD")

Call IMPRIM("YRPT_STOCK", "", 1, PARAMS) From GIMP
```

Arguments:
1. Report code (as defined in `GESARP`) — Y/Z prefix for custom.
2. Destination code (empty = default for this report).
3. Preview flag (1 = show preview dialog; 0 = silent).
4. Parameter string.

### Silent run for batch or web service

```l4g
Call IMPRIM("YRPT_STOCK", "FILE_PDF", 0, PARAMS) From GIMP
```

`FILE_PDF` is a pre-configured destination code (see `GESADI`) that writes a PDF to a folder. Use this in scheduled jobs — never open a preview dialog from a batch.

### Calling a report with no parameter dialog

```l4g
Call IMPRIM0("YRPT_STOCK", "FILE_PDF", PARAMS) From GIMP
```

`IMPRIM0` skips the interactive "enter parameters" dialog entirely — equivalent to `IMPRIM(code, dest, 0, params)` but clearer intent.

## Destinations (`GESADI`)

A destination bundles: driver (printer / PDF / Excel / email), options, output path, and printer queue. Common ones shipped by default:

| Code | Driver | Purpose |
|------|--------|---------|
| `ECR` | Screen preview | Interactive |
| `IMP` | Physical printer | Default printer |
| `FIL` | File (PDF/RPT) | Path from destination config |
| `MAI` | Email | SMTP, uses `ENVMAIL` — see `workflow-email.md` |
| `EXC` | Excel | Direct `.xlsx` |

Create custom destinations (Y/Z prefix) when you need a specific email template, shared folder, or printer queue.

## Report parameters — conventions

Standard X3 reports expect some parameters by convention:

| Parameter | Meaning |
|-----------|---------|
| `DATDEB` / `DATFIN` | Date range, format `YYYYMMDD` |
| `FCY` | Facility code |
| `CPY` | Company code |
| `CUR` | Currency |
| `LAN` | Language (for localized reports) |

Custom reports should reuse these names where possible so scheduling and destination codes work the same way.

## Running a native X3 state (non-Crystal)

Older reports use the native X3 state engine. Call is identical from L4G:

```l4g
Call IMPRIM("LISCLI", "", 1, "BPCNUM=BP001") From GIMP
```

The supervisor looks at the dictionary — if the report's `.rpt` exists it runs Crystal; otherwise it falls back to the native engine with the `.for` layout file.

## Running a report in an asynchronous batch

Inside a `.trt` used as a batch task:

```l4g
##############################################################
# YBATCH_PRINT_DAILY — scheduled daily, prints stock report per site
##############################################################
$MAIN
Local File FACILITY [FCY]
Local Char PARAMS(500)

For [FCY] Where FCYSTA = 1
    PARAMS = "FCY=" - [F:FCY]FCY - ";DATDEB=" - num$(date$, "YYYYMMDD")
    Call IMPRIM0("YRPT_STOCK", "FILE_PDF", PARAMS) From GIMP
Next
Return
```

Silent (`IMPRIM0`), one call per site, output written to files by the `FILE_PDF` destination. Schedule via `GESABA` (batch task definition) + `GESAPL` (batch server).

## Printing from an entry transaction — after save

Typical: print a sales order confirmation after the user saves it.

```l4g
$APBAS
    If [M:SOH]SOHTYP = 1                     # only for firm orders
        Local Char PAR(200)
        PAR = "SOHNUM=" - [M:SOH]SOHNUM
        Call IMPRIM("YSOH_CONFIRM", "", 1, PAR) From GIMP
    Endif
Return
```

The user gets a print-preview after save; they can send to email / printer from there.

## Embedding report output in an email

Combine the email destination with a template:

```l4g
# Send via destination code "MAI_CLIENT" configured to email the attached PDF
Local Char PAR(500)
PAR = "SOHNUM=" - [L]NUM -
      ";EMAIL=" - [L]CUSTOMER_EMAIL -
      ";SUBJECT=Confirmation commande " - [L]NUM
Call IMPRIM0("YSOH_CONFIRM", "MAI_CLIENT", PAR) From GIMP
```

The destination's email template resolves `%SUBJECT%` / `%EMAIL%` tokens against the `PAR` string. This is cleaner than hand-rolling SMTP from L4G.

## The report workflow — `GESAWA` hook

For fully unattended report-and-send flows, wire the print into a workflow rule rather than a script — define **event → condition → action: print report X to destination Y**. Less code, easier to audit. See `workflow-email.md`.

## Generating Excel output directly

Sometimes you don't want a report at all — just a data extract to `.xlsx`. Two paths:

### Path 1 — report to Excel destination

Define the report with an Excel-oriented layout, then:

```l4g
Call IMPRIM0("YEXTRACT", "EXC_EXPORT", PARAMS) From GIMP
```

### Path 2 — bypass reports, write directly

For raw tabular data where a Crystal layout is overkill, use the sequential-file API with CSV semantics:

```l4g
Openo "TMP/extract_" - num$([S]curpos) - ".csv" Using 7
Writeseq '"ITMREF","DESC","QTY"' Using 7
For [ITM] Where ITMSTA = 1
    Writeseq '"' - [F:ITM]ITMREF - '","' -
                   [F:ITM]ITMDES1(0) - '","' +
                   num$([F:ITM]QTY) - '"' Using 7
Next
Close 7
```

Excel opens CSV natively; prefer `.csv` over `.xlsx` unless you need formulas or styling.

## Report troubleshooting

When a report fails or produces wrong output:

1. **Re-run from `GESARP`** with the same parameters — isolates whether it's your call vs the report definition.
2. **Check the trace** in **Administration → Utilities → Verifications → X3 tracing** — supervisor logs every `IMPRIM` call with resolved parameters.
3. **Destination config** — a PDF destination with a bad output path silently writes nowhere. Look at `GESADI` and test with `ECR` first.
4. **Parameter parsing** — the supervisor splits on `;`. If a parameter value contains `;` or `=`, you need to escape it (`\;`, `\=`) or use the structured variant.
5. **Localization** — reports pick the language from the current user or the `LAN` parameter. If labels come out in English when you expected French, check both.

## Gotchas

- **Report cache** — the supervisor caches the compiled `.rpt`. After modifying a Crystal template, force a recompile via **Validation** in the report editor, or the old layout keeps rendering.
- **File locks** — if a previous run left the PDF open (Acrobat, Excel), the next `IMPRIM` silently overwrites with a weird filename suffix. Always close before re-running in dev.
- **Crystal and folder context** — Crystal connects to the database using the *runtime user*, not the L4G caller. Ensure the runtime user has read ACL on every table the report joins.
- **Long parameter strings** — there's a hard limit around 1000 chars in some dest drivers. Split huge selections into multiple calls or pre-filter with a temp table.
- **Silent failures** — if `IMPRIM0` can't find the report, it may set `[S]stat1` without raising an error. Check `stat1` and the trace.

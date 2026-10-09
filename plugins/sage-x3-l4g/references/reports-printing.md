# Reports and printing

How Crystal Reports reports are declared in Sage X3 (report dictionary GESARP), where their output
goes (destinations GESAIM, print servers), how to launch one from L4G and how to hook into the print
chain with the AIMP3 entry points. Read this when a report must be printed, exported to a file or
routed automatically. Plain data extracts are usually better served by an export template
(`imports-exports.md`).

## Contents
- [The pieces](#the-pieces)
- [Report dictionary (GESARP)](#report-dictionary-gesarp)
- [Destinations (GESAIM) and print servers](#destinations-gesaim-and-print-servers)
- [Launching a report from L4G](#launching-a-report-from-l4g)
- [AIMP3 entry points](#aimp3-entry-points)
- [Gotchas](#gotchas)
- [Sources](#sources)

## The pieces

| Piece | Code | Role |
|---|---|---|
| Report dictionary | GESARP (table AREPORT) | Report code, Crystal `.rpt` file(s), parameters, scripts, default destination |
| Print launch | AIMP (Reports) | Choose report, enter parameters and destination, print; also the Print/group menus (`RPTxx` submenus, xx = group in local menu 97) |
| Destinations | GESAIM | Named output: preview, printer, message/file, printer file; print server list |
| Print server | Sage X3 Print Server (Windows service, one per profile, configured in the Console) | Runs Crystal Reports for server-side output |
| Print chain hooks | Entry points of script AIMP3 (declared in GESAPE) | Change parameters, block printer choice, post-process the file |

`GESADI` is **Miscellaneous tables**, not destinations. Native "X3 states" (`.dict`/`.for`) and
destination codes such as `ECR`/`IMP`/`FIL`/`MAI`/`EXC` are not documented — do not rely on them.

## Report dictionary (GESARP)

**General tab** (selected fields):

| Field | Meaning |
|---|---|
| Report code (RPTCOD) | The code you print — not the `.rpt` file name |
| Group (GRP) | Print group, makes the report appear under Print/group |
| Destination (PRTDEF), Mandatory (PRTOBL) | Default destination; Mandatory forbids changing it at launch |
| Type (PRTNAT) | Local menu 22 (Normal, Fax, Thermal, Color), used only when no formula or destination applies |
| Add info formula (PRTFRM) | Finds a destination by user and takes priority over Destination (e.g. a formula using a site parameter) |
| Standard script (TRTINI) / Specific script (TRTSPE) | Run **before** Crystal (initialise variables, prepare work tables) |
| Not executable (EXEFLG), Batch only (EXEBAT), Hourly constraints (HOR) | Launch restrictions |
| Crystal reports grid (CRYCOD, ORIENT, FORETA) | Up to 5 `.rpt` files printed in sequence (`file.ext`, `file_1.ext`, …) |
| Authorization site (AUZFCY), Function (FNC), Access code (ACS) | Site filtering (the `.rpt` must restrict data itself), generic `RPTxx` function |

**Parameter definitions tab**: one line per Crystal parameter — code (PARCOD, the name used inside
Crystal), type (A alphanumeric, C short integer, L long integer, DCB decimal, D date, M local menu, or
a predefined type), length, local menu, defaults (PARDEF1/PARDEF2 expressions), control formula on
`VALUE` (PARCTL), access code. For a range, enter only the start parameter whose code ends in `deb`
or `str`; the end parameter (`fin`/`end`, same root) is generated and passed to Crystal. A
**Segmentation parameter** (PARSEG) splits a huge print into several outputs by value.

**Data tab**: up to 5 data sources in other folders (`solution;folder` syntax) and up to 10 tables
(print-server limit); tables of the current folder are not listed.

Development loop: build the `.rpt` in Crystal Designer (RptDev directory), test it with "Report
developer" mode, then transfer it to the server from the Report name field's contextual menu.
Sandbox statuses (Shared, Sandbox, Commit request…) protect a report being edited. The **Form**
button prints the current report directly — the first test when a call from code misbehaves.

## Destinations (GESAIM) and print servers

| Field | Meaning |
|---|---|
| Output type (PRT) | Preview; Printer; Message and file (one format from local menu 91); Printer/file (`.prn` image of the printer stream) |
| Destination file (PRTZPL) | File name or directory (trailing `/` or `\`), literal or formula |
| Printer (PRTNAM) | Windows printer name proposed at print time |
| Export format (PRTFMT) | Crystal export format; the list depends on the Crystal Reports version |
| Type (PRTNAT) | Local menu 22; must match the report's type unless it is the first (catch-all) value |
| Access code (ACS) | Who may see and use the destination |
| Servers grid | Name, Server (host/IP), Port, Profile (`DEFAULT` = first instance), Unavailability (minutes, default 5), Deactivated |

Formats of local menu 91 include Word, several Excel versions, HTML, RTF, ASCII, CSV (GESAIM) and
PDF (AIMP). Since 2025 R1 / V12.0.37 several print servers can be listed and are load-balanced
(next available server after the last one used; an error when none is available).

In AIMP the **Message** output goes through the user's MAPI e-mail client and **File** is created in
a directory reachable from the client workstation. For unattended output, community examples use a
GESAIM destination whose output type is file with a PDF export format.

## Launching a report from L4G

The only public Sage page on the subject is the AIMP3 entry-point page; the call below is
**community-reported** (several Sage community threads and partner blogs):

```l4g
# Print purchase order YPONUM with report YPOH to destination YPDF (GESAIM: output type file, PDF)
Subprog YPRINT_PO(YPONUM)
Value Char YPONUM()
Local Char YTBPAR(30)(1..20), YTBVAL(250)(1..20)
  YTBPAR(1) = "commandedeb" : YTBVAL(1) = YPONUM : # parameter codes as defined in GESARP
  YTBPAR(2) = "commandefin" : YTBVAL(2) = YPONUM
  Call ETAT("YPOH", "YPDF", "", 0, "", YTBPAR, YTBVAL) From AIMP3
End
```

| Arg | Meaning (as reported) |
|---|---|
| 1 | Report code (GESARP), not the `.rpt` name |
| 2 | Destination code (GESAIM) |
| 3 | Language (`"FRA"`, `"ENG"`…); empty = default |
| 4 | 0/1 flag — one post: show the "print executed" message; another: write a print log |
| 5 | Character argument passed as `""` in every example (one partner passes a function code) |
| 6, 7 | Arrays of parameter codes and values (codes exactly as in the dictionary) |

- Community-reported: with wrong parameter codes nothing was produced and no error was raised —
  check the codes on the Parameter definitions tab.
- Where the file lands is driven by the destination's Destination file (PRTZPL). Community posts
  move it afterwards with `Call MOVE(SRC, DEST, STAT) From ORDSYS`; others set `FICHIER` in a report
  script, which the official AIMP3 page does not document — test it on your patch level.
- AIMP can run in batch, but no dedicated standard task is delivered; for scheduled prints wrap the
  call in your own batch process (`batch-scheduling.md`).

## AIMP3 entry points

Declare a specific script for the standard script AIMP3 in GESAPE (mechanism in `entry-points.md`).
AREPORT `[ARP]` is open in every entry point.

| Entry point | When / what |
|---|---|
| `IMPRIME` | Just before the printer is chosen; only action: `GPE` <> 0 forbids entering a printer |
| `PARAM` | Modify any report parameter before printing |
| `REPORT` | Just after the print order is sent; for print/file output, post-process the generated file |
| `REPORT_ZPL` | Same, after a ZPL report is created |
| `UPDSQLSTAT` | Just before printing; Sage's sample refreshes SQL Server statistics on AREPORTM |

Parameters are in `PARAMETRE(1..NBPAR)` as `"name=value"` strings — the name the AIMP3 page's text gives
in English and French; its sample is inconsistent (`PARAMETER` in the `GETPARAM` calls). Prefixes: `__` = X3 only, not sent (`__DESTINATION`: 0 preview, 1 print, 2 e-mail,
3 file); `_` = Crystal settings whose values are prefixed with `chr$(1)` (`_PrinterName`,
`_Orientation`, `_FormatExport`, `_ExportFile`…); `X3…` = context set by the supervisor (`X3ETA` report
code, `X3USR`, `X3LAN`…); others come from the dictionary. `GETPARAM` / `SETPARAM From ETAT` read and
write them. The print server is not a parameter: it is the local variable `SERVER` (Char 30).

```l4g
# YAIMP3 - specific script for AIMP3 entry points (GESAPE)
$ACTION
  Case ACTION
    When "IMPRIME" : Gosub YIMPRIME
    When "PARAM"   : Gosub YPARAM
  Endcase
Return

$YIMPRIME
  If [F:ARP]RPTCOD = "YPOH" : GPE = 1 : Endif : # users may not pick another printer
Return

$YPARAM
  # Gosub label: it shares AIMP3's locals (PARAMETRE, NBPAR, SERVER), which a Subprog could
  # not set; the unique Y-prefixed name keeps this Local from clashing with a standard one
  Local Char YAIMP3_VAL(250)
  Call GETPARAM("__DESTINATION", NBPAR, PARAMETRE, [L]YAIMP3_VAL) From ETAT
  If [L]YAIMP3_VAL <> "1" : Return : Endif      : # printer output only
  If [F:ARP]RPTCOD = "YPOH"
    [L]SERVER = "YPRTSRV01"                      : # dedicated print server for this report
  Endif
Return
```

Sage's PARAM sample goes further: it reads the printer's defaults with `Selimp` and stores
`_PrinterName`, `_PrinterDriver`, `_PrinterPort`, `_PrinterDescription` and `_Orientation` with
`SETPARAM`. Workflow rules can also fire when a report is launched (event type **Print**, see
`workflow-email.md`).

## Gotchas
- `IMPRIM`, `IMPRIM0` and `GIMP` print APIs are not documented anywhere; use `ETAT From AIMP3`
  (community-reported) or the AIMP function.
- Report parameters are not a `"NAME=VALUE;…"` string: they are two arrays (code, value).
- Tables read from another folder must be declared on the Data tab (at most 10, a print-server
  limit); undeclared tables are read in the current folder.
- Site authorisation in GESARP only works if the `.rpt` filters on the authorised sites.
- A printer prints one report at a time; the print server runs several requests in parallel, and
  Linked prints (IMPLIE) serialise reports sent to the same printer.
- Sub-divided prints to a printer file produce `myfile01.prn`, `myfile02.prn`…
- On SQL Server, parameters can come out wrong when AREPORTM statistics are stale — that is what
  the UPDSQLSTAT entry point is for.
- Multi-language (MULLAN) unchecked generates the report only in its original language.
- Never open a preview from batch code: use a destination of type file.

See also: `entry-points.md`, `workflow-email.md`, `batch-scheduling.md`, `imports-exports.md`.

## Sources
- https://online-help.sagex3.com/erp/12/en-us/Content/FCT/GESARP.htm
- https://online-help.sagex3.com/erp/12/en-us/Content/FCT/GESAIM.htm
- https://online-help.sagex3.com/erp/12/en-us/Content/FCT/AIMP.htm
- https://online-help.sagex3.com/erp/12/en-us/Content/OBJ/ADC_AIMP3.htm
- https://online-help.sagex3.com/erp/12/en-us/Content/FCT/GESADI.htm
- https://matteo72.wordpress.com/2012/11/17/x3-4gl-procedure-to-launch-a-report/ (ETAT arguments, community)
- https://communityhub.sage.com/us/sage_x3/f/general-discussion/187612/automatically-print-a-report-in-a-network-directory
- https://www.rklesolutions.com/blog/sage-x3-crystal-report-parameters
- https://communityhub.sage.com/sage-global-solutions/sage_x3/f/general-discussion/228097/print-files-to-an-s3-bucket

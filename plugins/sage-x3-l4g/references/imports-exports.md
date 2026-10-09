# Imports and exports

How Sage X3 moves flat/XML files in and out of the database with import/export templates (GESAOE),
how to run them interactively, in batch and silently from L4G, how to customise an import, and how
to build a delta / inbox integration. Read this before hand-writing a file loader: a template
emulates screen entry, so the object's controls run for free. Hand-written parsing lives in
`sequential-files.md`; mass loads and cutover in `data-migration.md`.

## Contents
- [Templates (GESAOE)](#templates-gesaoe)
- [Running imports and exports](#running-imports-and-exports)
- [Silent import from L4G (IMPORTSIL)](#silent-import-from-l4g-importsil)
- [Exports from L4G](#exports-from-l4g)
- [Customising an import](#customising-an-import)
- [Storage space and transcoding](#storage-space-and-transcoding)
- [Delta and inbox integrations](#delta-and-inbox-integrations)
- [Gotchas](#gotchas)
- [Sources](#sources)

## Templates (GESAOE)

There is **one** function, **GESAOE** (Import/export templates); a template is flagged for import,
export or both. `GESAOI` does not exist. A template is tied to an **object** (header + lines, same
controls as on-line entry) or, with the Object field left empty, to tables chosen in the field grid
(only data-type checks run — handy for staging tables).

| Setting (field) | What it controls |
|---|---|
| Object (OBJ), Function (FONCTION, mandatory) | Object to emulate; function used for context and access rights |
| Standard script (TRTIMP) / Specific script (SPEIMP) | `IMPxxx` standard actions; your script runs **before** the standard one |
| File type (TYPFIL) | Field separators, Record separator, Delimited, Fixed length, XML, Flat A, Header (Flat A + a title line) |
| Field separator (SEPFLD) / Record separator (SEPREC) | Non-printables as `\` + 3 decimal digits: `\010` (Unix), `\013\010` (Windows) |
| Field delimiter (FLDLIM) | Quote put around alphanumeric fields (Delimited type) |
| File format (CODDBA) / Character set (OPTCHA) | ASCII (with ISO 8859 / IBM PC / 7-bit set), UTF-8, UCS-2 |
| Decimal separator (SEPDEC), Date format (OPTDAT) | Empty separator = `.`; two-digit years pivot on the DCS parameter |
| Local menu format (OPTMNL) | 0 = rank, 1 = one-character code, n = first n characters of the label |
| Export (EXPORT), Export sequence no. (CHRNUM) | Export allowed; counter stored at the last chronological export |
| Import (IMPORT), Update allowed (OPTUPD) | Import allowed; existing records may be modified |
| Temp storage space (AOWSTA) | Rejected records also go to the storage space (GESAOW) |
| Special import (OPTSPE) | Bypass object management, use custom labels (see below) |
| Workflow (ENAWRK) | Unchecked: per-record creation/modification workflow events are not triggered |
| Data file (FILEXT), Final directory (REPFIN) | Default path (`#` = sequence number); directory imported files are moved to |

Identifiers grid (multi-level files): **Indicator** (FLGREC, up to 5 characters, used as the group
header in the file), level, table, key and link per group. Fields grid special syntaxes in the Field column:
`/` marks where the group indicator sits (mandatory once per group in a multi-group import), `"text"`
is written as-is on export, `*N` (1..99) reads/assigns the `GIMP(N)` global, `=expression` is an
export-only computed value. **Table number** (NUMTAB) links a field to a transcoding table (GESAOR).

Import logic: the primary key read from the record decides creation or modification; all fields load
first, then entry is simulated screen by screen in screen order (field order in the file does not
matter, fields that cannot be entered on screen are not imported).

## Running imports and exports

| Need | Use |
|---|---|
| Interactive import / export | Functions **GIMPOBJ** (Imports, has a **Test** button) and **GEXPOBJ** (Export) |
| Batch | Standard tasks **IMPORT** and **EXPORT** (see `batch-scheduling.md`) |
| Recurring | Recurring task (GESABA) on the IMPORT/EXPORT task |
| From L4G | `IMPORTSIL` (import), `AOWSEXPORT` (export), below |
| From outside X3 | SOAP services AOWSIMPORT / AOWSEXPORT / AOWSBATGET (api-guide_api-soap-import-export.html, in Sources) |

The template is compiled into a temporary script (`WWI…` for imports, `WWE…` for exports) — the
**Script**/**Process** button in GIMPOBJ/GEXPOBJ shows it, which is the fastest way to debug a mapping.
The **Location** field (TYPEXP) chooses Client (browser upload/download) or Server (a volume); batch
and code-driven runs need server paths.

## Silent import from L4G (IMPORTSIL)

Documented in the GESAOE technical appendix ("Silent import"). The trace is opened only when not
running on the batch server (`GSERVEUR` = 1 there; the batch server keeps one log per request):

```l4g
# Returns [V]CST_AOK or [V]CST_AERROR; YMSG receives the decoded error text
Funprog YIMP_SILENT(YTEMPLATE, YFILE, YMSG)
Value    Char YTEMPLATE(), YFILE()
Variable Char YMSG()
  YMSG = ""
  If !GSERVEUR
    Call OUVRE_TRACE("Import " + YTEMPLATE) From LECFIC
  Endif
  Call IMPORTSIL(YTEMPLATE, YFILE) From GIMPOBJ
  If !GSERVEUR
    Call CLOSE_LOC From LECFIC : # as in Sage's appendix; community code uses FERME_TRACE
  Endif
  # Failure test as used in community code (STAT values are not listed in the help)
  If [M:IMP2]STAT <> 0 or GOK < 1
    Call ERR_IMPORT([M:IMP2]STAT, YMSG) From GIMPOBJ
    End [V]CST_AERROR
  Endif
End [V]CST_AOK
```

- `YFILE` is the full server path, e.g. `filpath("TMP", "orders", "csv")` (see `builtin-functions.md`).
- The end status is in `[M:IMP2]STAT`; `ERR_IMPORT` only turns it into a sentence — the details are in
  the trace (read it with LECTRACE, see `debugging-traces.md`). The help does not list STAT values.
- Community-reported: `[V]GSILENCE = 1` before the call suppresses the log output, and one thread notes
  you then lose the import trace; another reports a file dialog appearing until a trace was opened.
- A robust check after the call is functional: read the record the file should have created.
- `ECR_TRACE` (used below to write trace lines) is community-reported; see `debugging-traces.md`.

## Exports from L4G

- **Chronological export**: GEXPOBJ "Chrono management" exports only records whose `EXPNUM` is
  greater than the counter stored in the template; the `[C]EXPORT` counter is incremented at each
  run and `#` in the file name is replaced by its value. Only tables carrying `EXPNUM` qualify.
- **AOWSEXPORT** is the documented SOAP export service (subprogram `AOWSEXPORT.EXPORT`). Calling it
  directly from L4G instead of through SOAP is community-reported; it returns the file in a Clbfile:

```l4g
Local Char    YMODEXP(20), YCHRONO(3), YEXEC(10), YRECSEP(1), YMESSA(250)
Local Char    YCRIT(250)(1..10)        : # dimension 10 per the SOAP page
Local Clbfile YDATA(0)
Local Integer YREQNUM, YSTATUS
  YMODEXP = "YBPC"
  YCHRONO = "NO"                       : # YES = chronological export
  YEXEC   = "REALTIME"                 : # BATCH returns a request number instead of data
  YRECSEP = chr$(10)
  YCRIT(1) = "[F:BPC]BPCSTA=1"         : # filters written in X3 language
  Call EXPORT(YMODEXP, YCHRONO, YCRIT, YEXEC, YRECSEP, YDATA, YREQNUM, YSTATUS, YMESSA)
  & From AOWSEXPORT
  # Web service status: 0 = OK. The caller has opened the trace (OUVRE_TRACE From LECFIC).
  If YSTATUS <> 0
    Call ECR_TRACE("Export YBPC failed: " + YMESSA, 1) From GESECRAN
  Endif
```

The index base expected for the criteria array is not documented. Write `YDATA` to disk with the
sequential-file API (`sequential-files.md`) or post it with `web-services-rest-client.md`.
`Call EXPORTSIL From GEXPOBJ` after filling the `[M:EXP2]` screen is also community-reported, by a
poster who had not tried it — prefer AOWSEXPORT or the EXPORT batch task.

## Customising an import

The template's **specific script** receives the same `IMP_*` actions as the standard `IMPxxx`
script, before it; set `GPE = 1` to inhibit the standard action. `IMP_*` actions have the context of
the matching object action (`IMP_VERIF_CRE` ↔ `VERIF_CRE`, where `OK = 0` refuses the creation).

| Action | When |
|---|---|
| `IMP_COMPILE`, `IMP_TRTSUP` | Before / after the temporary import script is written (`IMPTRT`) |
| `IMP_OUVRE` / `IMP_FERME` | Start / end of the run |
| `AP_IMPORT` | After each section is decoded (`SEPNUM` 1..8, main table abbreviation in `IMPABR`) |
| `IMP_SETBOUT`, `IMP_RAZCRE` | Options; new record initialisation |
| `IMP_VERIF_CRE`, `IMP_INICRE`, `IMP_CREATION`, `IMP_APRES_CRE` | Creation sequence |
| `IMP_VERIF_MOD`, `IMP_MODIF`, `IMP_APRES_MOD`, `IMP_DEVERROU` | Modification sequence |
| `IMP_ZONE` | Instead of a field entry: `IMPFIC`, `IMPMSK`, `IMPZON`; `OK = 1` runs the standard entry |

```l4g
# YIMPYCU - specific script of template YCU (SPEIMP); object YCU, screen YCU0
$ACTION
  Case ACTION
    When "IMP_VERIF_CRE" : Gosub YVERIF_CRE
  Endcase
Return

$YVERIF_CRE
  If [M:YCU0]YVATNUM = ""
    OK = 0 : # refuse this record, the next ones are still imported
    Call ECR_TRACE("YCU " + [M:YCU0]YCODE + ": VAT number missing", 1) From GESECRAN
  Endif
Return
```

**Special import** (OPTSPE) skips object management for speed: your process gets `$OUVRE`,
`$RAZCRE`, `$SAIMSK` (after each group, `IMPFIC` = table read) and `$VALID` (controls + database
writes, entirely yours). Sage recommends it only for proven performance problems.
`GIMP(N)` variables carry values that have no table column (standard templates use them for texts,
e.g. `*71`..`*78` in IMPITM); only plain-text texts import/export correctly, not rich text.

## Storage space and transcoding

- **Temporary storage space (GESAOW)**: with AOWSTA checked, each rejected record is stored by batch
  number with the faulty fields highlighted; users correct values, add lines and re-extract the batch
  to a file for re-import. A file can also be loaded into the storage space only (format checks, no
  real import) — a cheap dry run. An error file is produced either way.
- **Transcoding (GESAOR)**: numbered tables of local code ↔ external code, linked through NUMTAB.
  `*` on the external side is the import default, on the local side the export default; spaces are
  not significant (they cannot be entered).

## Delta and inbox integrations

Native, no code:
1. Partner drops `ORD00001.csv`, `ORD00002.csv`… in a server directory; the template's Data file is
   `<dir>/ORD#.csv` — an import processes every matching file in increasing number order.
2. **Final directory** (REPFIN) receives imported files, so a rerun never sees them again.
3. A recurring task (GESABA) runs the IMPORT task every N minutes in a time range (template and
   file entered once with its Parameters button).
4. Outbound: chronological export + EXPORT task + `#` in the output name.

Code-driven (several templates, custom routing): reuse the integration log `YINTLOG` through
`YINTLOG_WRITE` (`web-services-integration.md`) with DIRECTION `IN`, CHANNEL = template code and
CORRID = file name (or name + size); skip files whose CORRID already has an `OK` row (index `YIL1`),
call `YIMP_SILENT`, then log the result and move the file. `Call MOVE(SOURCE, TARGET, STAT) From ORDSYS` is community-reported for moving files (no
spaces in file or directory names). Always log before moving, never delete an inbound file on
failure (quarantine it), and see `batch-scheduling.md` for restart safety.

## Gotchas
- `LECFIC` is the trace script (OUVRE_TRACE, LEC_TRACE; closed with FERME_TRACE, or CLOSE_LOC as in
  Sage's GES_AOE1 sample), not an import API; `EXPOBJ`/`IMPOBJ` subprograms such as
  `LECFIC From IMPOBJ`, `EXPFIC` or `LANCEXP` are not documented.
- An inactive template cannot be used; the object itself must allow imports (Import box on its
  Miscellaneous tab, otherwise "Import not possible for this object").
- Fields that cannot be entered on the screen are silently not imported.
- Without OPTUPD an existing key cannot be modified by the import.
- Without a primary key in the file every record is a creation (needs an automatic sequence number).
- Local menu values: with OPTMNL = 0 the file must carry ranks, not labels.
- Two-digit years are pivoted by DCS; prefer four-digit dates.
- Mass imports fire workflow rules per record unless ENAWRK is unchecked.
- `#` stands for a 5-digit number on import; files must follow that numbering.
- XML templates can generate an XSD (Options / Export schema) in `X3_PUB/<folder>/GEN/ALL/WEBS`.

See also: `batch-scheduling.md`, `data-migration.md`, `sequential-files.md`, `workflow-email.md`,
`web-services-soap.md`, `web-services-integration.md`, `debugging-traces.md`.

## Sources
- https://online-help.sagex3.com/erp/12/en-us/Content/FCT/GESAOE.htm
- https://online-help.sagex3.com/erp/12/en-us/Content/FCT/GES_AOE1.htm (actions, special import, silent import)
- https://online-help.sagex3.com/erp/12/en-us/Content/FCT/GES_AOE2.htm (GIMP variables)
- https://online-help.sagex3.com/erp/12/en-us/Content/FCT/GIMPOBJ.htm
- https://online-help.sagex3.com/erp/12/en-us/Content/FCT/GEXPOBJ.htm
- https://online-help.sagex3.com/erp/12/en-us/Content/FCT/GESAOW.htm
- https://online-help.sagex3.com/erp/12/en-us/Content/FCT/GESAOR.htm
- https://online-help.sagex3.com/erp/12/en-us/Content/MODEL/VERIF_CRE.htm
- https://online-help.sagex3.com/erp/12/en-us/Content/V7DEV/api-guide_api-soap-import-export.html
- https://communityhub.sage.com/us/sage_x3/f/general-discussion/102514/importsil-creating-file-but-not-importing
- https://communityhub.sage.com/us/sage_x3/f/general-discussion/103337/import-template-through-code
- https://communityhub.sage.com/fr/sage-x3/f/technique/250171/catcher-les-erreurs-dans-un-script-d-import
- https://communityhub.sage.com/us/sage_x3/f/general-discussion/108302/function-importsil
- https://communityhub.sage.com/us/sage_x3/f/general-discussion/199927/x3v12-4gl-how-to-run-silent-export-from-an-export-template-in-4gl-only
- https://www.greytrix.com/blogs/sagex3/2014/01/10/moving-a-file-from-a-directory/

# Accounting: automatic journals (GESGAU)

Every module posts its documents (sales and purchase invoices, payments, depreciation, reversals...)
to accounting through an **automatic journal**: a GESGAU setup record that turns the current record
of a triggering table into the header and lines of a journal entry. Read this when a requirement
changes how a standard document is posted, adds specific fields to journal entries, or asks to
post a specific document. The GESAPE mechanism itself (declaration, `ACTION`, `GPE`) is in
`entry-points.md`; this file covers only what is specific to automatic journals.

## Contents
- [How posting works](#how-posting-works)
- [Journal header setup](#journal-header-setup)
- [Lines and accounting codes](#lines-and-accounting-codes)
- [Formulas and AFNC functions](#formulas-and-afnc-functions)
- [Link and journal subprograms](#link-and-journal-subprograms)
- [Accounting entry tables](#accounting-entry-tables)
- [CPTAUTO entry points](#cptauto-entry-points)
- [SUBGAU entry point CHARGE](#subgau-entry-point-charge)
- [What is not documented](#what-is-not-documented)
- [Gotchas](#gotchas)
- [Sources](#sources)

## How posting works

- GESGAU (V11 menu: Setup > Financials > Accounting interface > Automatic journals) stores the
  setup in GAUTACE [GAU] (header, index GAU0 = COD) and GAUTACED [GAD] (lines, GAD0 = COD+LINNUM).
- "This transfer is done by a standard subprogram by transferring a code for the operation. For
  example, the BPCIN code is called when validating a customer business partner invoice."
- "The application programs control the code used and the time of the call to the generation
  subprogram." The help names neither that subprogram nor its parameters: see
  [What is not documented](#what-is-not-documented).
- Before it is recorded, the generated entry sits in screens GACCENT0-2; the CPTAUTO entry points
  can change it there.

## Journal header setup

| Field | Use (GESGAU page) |
|---|---|
| `COD` | Entry code: the operation code the standard program passes |
| `MODULE`, `CODACT` | Module the posting comes from, activity code |
| `TBL`, `KEYTBL` | Triggering table and its index (first index by default); "the current record for this table is used" |
| `GRPFLG` | *1 Journal per line*: one entry per triggering record. *Grouped journal*: one entry for the records sharing the first P parts of an N-part key (page example: journal SOI on GACCDUDATE, key DUD2) |
| `REITBL`, `REIFLD` | Entry split table and field: break into several entries; all lines must then be *Linked table* lines on that table |
| `LIKTBL`, `LIKFLD` | Linked tables, and the triggering-table field giving each one's key (bill-to or paying BP...) |
| `FORCND` | Filter on the triggering table (fields of triggering and linked tables, global variables) |
| `FORCND2` | Condition, for example `AFNC.PARAM("FRAVAT",[F:SIH]CPY)="2"`; tested after the filter |
| `NEGAMT` | Negative amounts allowed; otherwise a negative credit becomes a positive debit and vice versa |
| `DATFLG` | First date: an entry in a closed period goes to the first date of the first open period; otherwise it is not created and an error is written to the log file |
| `PRGLIK`/`ACTLIK`, `PRGAFTVCR`/`ACTAFTVCR` | Hooks: see [Link and journal subprograms](#link-and-journal-subprograms) |

The **Formulas** grid (`INTIT`, `FORCLC`) gives one expression per header field of the entry, of
that field's type. Key header fields named on the page: *Journal entry type* (mandatory; the entry
number is assigned automatically if not set, and the journal defaults to the type's journal),
*Category* (1 Actual, 2 Active simulation, 3 Inactive simulation, 4 Off balance sheet, 5 Template;
default 1), *Status* (1 Temporary, 2 Final; default 1), site, dates and currency. The Traceability
tab (`TRCFLG`, `TRCTBL`, `TRCKEY`, `TRCACT`, generic action `GASACCNUM1`) links grouped entries back
to their source transactions.

## Lines and accounting codes

The **Lines** button opens the line definitions (GAUTACED):

- `LINTYP` *unique*: one line. *Repetitive*: a variable number of lines driven by an index whose
  range comes from formulas; the line conditions can use the index. *Linked table*: one line per
  record of the General table `LINTBL1` (usually the document lines), with an optional Analytical
  table `LINTBL2` joined by the expression `LIKTBL2`.
- `FORCND` conditions on the principal and general tables: if false, the line is not generated.
  Grids **Ledgers** (`LEDTYP`) and **Legislations** (`ACT`, `LEG`) restrict where it applies.
- `DEBCDT` (Netting): Yes offsets lines with opposite signs and otherwise identical
  characteristics. `FLGDUD` (Control account) is set on the first line of invoice journals, which
  generates the BP tax-included line; set it on whichever line generates that line.
- **Accounting codes** grid (`TYPACCCOD`, `ACCNUM`, `ACCKEY`, `ACCCND`): when no formula fixes the
  account, masks from the product, customer, site... accounting codes are applied in declared
  order, each filling only the positions still `x`; leftover `x` become zeros (page example:
  `7xxxxxxx` gives `723024548`). The nature is taken from the first code that defines one.
- Table GAUTACED also has line-level hook columns (`PRGBEFLIN`/`ACTBEFLIN`, `PRGAFTLIN`/`ACTAFTLIN`,
  `PRGAFTLIK`/`ACTAFTLIK`), which the GESGAU page does not describe.

## Formulas and AFNC functions

Formulas are expressions over the online tables: the triggering table, its linked tables, the
General and Analytical tables of *Linked table* lines and the tables linked on the line screen.
The page gives the call syntax `func TRT.FUNCT(arguments)` and these functions of process AFNC:

| Function | Result |
|---|---|
| `AFNC.ACTIV(COD)` | 1 if activity code COD is active in the folder, 0 if not |
| `AFNC.PARAM(PARAM, SITE)` | Value of setup parameter PARAM, alphanumeric, 30 characters max |
| `AFNC.CONSULT(ACCES)` | 1 if access code ACCES grants display rights, else 0 (1 if ACCES is empty) |
| `AFNC.MODIF(ACCES)` | Same, for modification rights |
| `ADNC.EXEC(ACCES)` | Same, for execution rights: spelled `ADNC` on the English and French pages |

Account formula from the page: `"703"+seg$([F:ITM]TSICOD,2,3)` gives 703 followed by characters 2
to 3 of the product statistical group, the link to ITM being declared by an accounting code line.
For fixed asset journals the page adds `func TRTCPTINT3.GET_LIN_DES` (label of the line, DES of
GAUTACED) and `func TRTCPTINT3.LECTEXTRA("GAUTACE","DESTRA","PIHI","")` (label of the header).

## Link and journal subprograms

"You can intervene in the posting process in some places by calling subprograms. The action name
corresponds to the label name defined in the process run when generating the automatic journal."

| Hook | Script / label fields | When (GESGAU page) |
|---|---|---|
| Link subprogram | `PRGLIK` / `ACTLIK` | After the links of the header: "to anticipate the opening of additional tables, to assign global variables, or to read information specifically linked to the triggering context" |
| Journal subprogram | `PRGAFTVCR` / `ACTAFTVCR` | After the journal creation |

Both columns are 10 characters (GAUTACE dictionary): a Y-prefixed script name and a label in it.
The page documents neither the call mechanism nor the context (transaction, variables): inspect it
in the debugger before writing anything to the database from these labels.

## Accounting entry tables

| Table | Abbreviation | Primary index | Notes |
|---|---|---|---|
| GACCENTRY (Accounting entries) | HAE | HAE0 = TYP+NUM | HAE1 = JOU+ACCDAT+TYP+NUM; HAE5 = REFINT (duplicates) |
| GACCENTRYD (Accounting entry lines) | DAE | DAE0 = TYP+NUM+LIN+LEDTYP | DAE2 = ACCNUM |
| GACCENTRYA (Analytical accounting line) | DAA | DAA0 = TYP+NUM+LIN+LEDTYP+ANALIN | |

The abbreviation does not derive from the table name: `[HAE]`, not `[GAE]`. Header columns worth
knowing: `TYP` (entry type), `NUM`, `JOU`, `ACCDAT`, `STA`, `ORIMOD` (source module), `BPRVCR`
(source document). Line keys include `LEDTYP`: give it when reading a line.

```l4g
Funprog YHAE_EXISTS(ENTTYP, ENTNUM)
Value Char ENTTYP(), ENTNUM()
Local File GACCENTRY [HAE]
  Read [HAE]HAE0 = [L]ENTTYP; [L]ENTNUM
  If fstat
    End 0
  Endif
End 1
```

## CPTAUTO entry points

Declare them in GESAPE on standard script CPTAUTO ("Process CPTAUTO: Automatic journal"). For all
five: "There is one transaction in progress" and "A log file is normally open (it can depend on the
context)". The entry being built is in screens GACCENT0 [HAE0], GACCENT1 [HAE1], GACCENT2 [HAE2]
(and VENTILE2 [VT2]); their fields can be changed "on the condition of respecting the general
validation rules for a document", and specific fields added to the accounting entry tables must be
added to these screens.

| Entry point | Called | Notable context |
|---|---|---|
| `PIECE` | Just before the recording of the journal | GAUTACE [GAU], COMPANY [CPY], FACILITY [FCY], TABCUR [TCU], plus the triggering and linked tables |
| `CLEGRP` | Before NOL (line about to be posted) is initialised | Local `CLEGRP` = grouping fields separated by `' / '`, can be completed; also GAUTACED [GAD], GACCOUNT [GAC] (account of the current line), BPARTNER [BPR] |
| `LIGNE` | On creation of each line | `NOL` = index of the line just created; same tables as CLEGRP |
| `LIN_ANA` | On creation of each analytical line | `NOL` (general line, HAE2), `VENT` (analytical line, VT2), pointers `PTV(NOL)`/`PTF(NOL)` on HAE2; not called when the line uses a prior distribution (GESDSP) |
| `OPNTAB` | After tables are opened and variables declared, before reading the journal | "used to define other tables using the same abbreviations"; masks and variables not yet initialised; only COMPANY [CPY] |

No return variable (`GPE`, `GOK`) is documented to refuse the journal. Illustrative script, not
compiled (compile and test it in your folder): it stamps each generated line with the automatic
journal code, in a specific field `Y_GAUCOD` added to GACCENTRYD and to the grid of GACCENT2.

```l4g
# YCPTAUTO - GESAPE line: standard CPTAUTO, specific YCPTAUTO, activity code YGAU
$ACTION
  Case ACTION
    When "LIGNE" : Gosub Y_LIGNE
  Endcase
Return

$Y_LIGNE
  # Transaction already open: no Trbegin / Commit / Rollback, no Infbox
  # NOL indexes the HAE2 grid, as PTV(NOL) does on the CPTAUTO page;
  # check in the debugger that [GAU] holds the journal being generated
  [M:HAE2]Y_GAUCOD(NOL) = [F:GAU]COD
Return
```

## SUBGAU entry point CHARGE

On standard script SUBGAU, CHARGE is used "to add in accounting entries additional fields, which can
be set up as standard fields". It is called when an automatic journal is loaded or created, after
the standard accounting entry fields are loaded; no transaction, no trace file. Mask GAU1 [GAU1] is
available; the variable `i` holds the number of lines already loaded and "must be incremented before
adding specific fields"; it is then assigned to the grid-bottom variable `[M]NBLIG`. Tables ATABLE,
ATABZON, ATABIND, ATYPE, ACTIV and AMSKZON are open but their content is not significant. The GAU1
column names are not documented: read the screen in GESAMK.

## What is not documented

- **Posting a specific document.** The help does not document the generation subprogram (name,
  parameters, call) nor how a specific triggering table gets posted. Do not write a `Call` to it
  from memory. Find a standard caller in your folder (search the standard sources for an operation
  code such as `"BPCIN"`), treat what you find as internal and patch-sensitive, and test it on a
  copy folder.
- **Hook context**: call mechanism and variables for `PRGLIK`/`PRGAFTVCR`, and the meaning of the
  GAUTACED line-level hooks.
- Prefer what is documented: GESGAU setup (formulas, conditions, accounting codes) and the CPTAUTO
  and SUBGAU entry points.

## Gotchas

- The first CPTAUTO entry point is `PIECE`. The V11 English page titles it "JOURNAL" (translated
  heading) but its body and the French page call it PIECE: `When "PIECE"`.
- CPTAUTO entry points fire for every automatic journal: filter on the journal code.
- A specific field on the accounting entry tables must also be on GACCENT0-2 for CPTAUTO to fill
  it; SUBGAU CHARGE is the documented way to make it settable in GESGAU like a standard field.
- `ADNC.EXEC` is how both pages spell it; `AFNC.EXEC` is not documented: check script AFNC in your
  folder. The page's own `AFNC.PARAM` example passes a company (`[F:SIH]CPY`) as SITE, and omits
  `func` although the stated syntax is `func TRT.FUNCT(...)`: test such formulas.
- GESGAU checks formula syntax on entry but not errors such as a division by zero. Errors like
  "ZZZ : Error in Field Evaluation" or "Triggering Table not Referenced" (listed on the V11 page)
  appear at generation, for example on invoice validation.
- An entry in a closed period without `DATFLG` is not created; the error goes to the log file.

See also: `entry-points.md`, `function-codes.md`, `conventions-and-naming.md`, `data-dictionary.md`,
`development-workflow.md`, `screens-and-masks.md`, `database.md`, `debugging-traces.md`.

## Sources
- https://online-help.sagex3.com/erp/12/en-us/Content/FCT/GESGAU.htm
- https://online-help.sagex3.com/erp/12/fr-fr/Content/FCT/GESGAU.htm (`ADNC.EXEC` spelling)
- https://online-help.sagex3.com/erp/11/en-US/FCT/GESGAU.htm (menu path, generation error messages)
- https://online-help.sagex3.com/erp/12/en-us/Content/OBJ/ADC_CPTAUTO.htm
- https://online-help.sagex3.com/erp/12/fr-fr/Content/OBJ/ADC_CPTAUTO.htm (PIECE)
- https://online-help.sagex3.com/erp/11/en-US/OBJ/ADC_CPTAUTO.htm ("JOURNAL" heading)
- https://online-help.sagex3.com/erp/12/en-us/Content/OBJ/ADC_SUBGAU.htm
- https://lvexpertisex3.com/x3help/ENG/OBJ/ADC_SUBGAU.htm (mirror of the same page)
- https://online-help.sagex3.com/erp/12/en-us/Content/MCD/GACCENTRY.htm
- https://online-help.sagex3.com/erp/12/en-us/Content/MCD/GACCENTRYD.htm
- https://online-help.sagex3.com/erp/12/en-us/Content/MCD/GACCENTRYA.htm
- https://online-help.sagex3.com/erp/12/en-us/Content/MCD/GAUTACE.htm
- https://online-help.sagex3.com/erp/12/en-us/Content/MCD/GAUTACED.htm
- https://online-help.sagex3.com/erp/12/en-us/Content/FCT/GESDSP.htm
- https://online-help.sagex3.com/erp/12/en-us/Content/FCT/GESAPE.htm

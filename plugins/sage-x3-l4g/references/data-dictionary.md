# Data dictionary: tables, data types, local menus, parameters

The data dictionary describes what a folder's database holds and how values are entered: tables and indexes
(GESATB), data types (GESATY), local menus (TXT), miscellaneous tables (GESADV / GESADI), SQL views (GESAVW)
and general parameters (GESADP). Read this before changing one of them or reading a miscellaneous table or a
parameter in code. Naming rules and number ranges: `conventions-and-naming.md`; labels: `localization.md`.

## Contents
- [Tables (GESATB)](#tables-gesatb)
- [Adding a field to a standard table](#adding-a-field-to-a-standard-table)
- [Indexes](#indexes)
- [Validating tables and the dictionary](#validating-tables-and-the-dictionary)
- [Data types (GESATY)](#data-types-gesaty)
- [Local menus (TXT)](#local-menus-txt)
- [Miscellaneous tables (GESADV, GESADI)](#miscellaneous-tables-gesadv-gesadi)
- [SQL views (GESAVW)](#sql-views-gesavw)
- [General parameters (GESADP)](#general-parameters-gesadp)
- [Reading a parameter in L4G](#reading-a-parameter-in-l4g)
- [Gotchas](#gotchas)
- [Sources](#sources)

## Tables (GESATB)

A table has a header (code `CODFIC`, abbreviation `ABRFIC`, description) and the General, Columns, Index
and Audit tabs. Validating the definition creates or updates the table in the database.

| Field (General tab) | What it controls |
|---|---|
| Activity code `CODACT`, Module | Table created only if the code is empty or active and the module is active. Tables with an X/Y/Z code are specific and "not affected by version changes" |
| Table type `TYPFIC` | Application (default, functional tables), Supervisor (in every folder: users, logs...), Sage X3 system (supervisor folder only, never copied), Dictionary (merged during updates), Internal (Sage only, never for external development) |
| Copy type `CRE`, Copy option `OPT` | What folder creation copies from the reference folder: nothing, everything, or groups picked from local menu 26 |
| Open access `SECURE` | Selected: every folder of the solution reads and writes. Cleared: access follows the calling folder's rights (GESADS, Links tab). Not updated by patches |

| Columns grid | Meaning |
|---|---|
| `CODZONE` | Field name, read as `[F:ABV]FIELD`; a dimensioned field gives the database columns `FIELD_0`, `FIELD_1`... |
| `CODTYP` | Data type: `A`, `C` (short integer), `L` (long integer), `DCB` (decimal), `D`, `M` / `MM` (local menu), `ACB` (CLOB), `ABB` (BLOB), or any GESATY type |
| `NOLIB`, `LONG`, `DIME`, `CODACT` | Local menu number; length for `A` and `DCB`; dimension; activity code (optional element, X/Y/Z = specific, grid sizing) |
| `LIEN`, `EXPLIEN`, `ANNUL` | Linked table and link expression, `comp1;comp2` for a multi-part key (a field controlled by miscellaneous table 43: linked table ATABDIV, expression `43;MYFIELD`; globals need `[V]`); on deletion of the linked record: Block, Delete, RTZ or Other |

- Columns filled by object management when they exist: `CREDAT`/`UPDDAT`, `CRETIM`/`UPDTIM`,
  `CREUSR`/`UPDUSR`, `EXPNUM` (export timestamp), `ENAFLG` (active flag, filtered by the selection window).
- Entry refuses an alphanumeric length above 250, a decimal over 32 digits and a dimensioned field in an
  index. From 2026 R1 / V12.0.39 the API columns are read-only here and edited in Table properties (GESATBP).

## Adding a field to a standard table

1. Name it `X_...`, `Y_...` or `Z_...` (GESATB rule) and give the line an X/Y/Z activity code: the patch
   tools treat an element without one as standard (`conventions-and-naming.md`).
2. Never add fields or specific characteristics to **system or dictionary tables**: GESATB states they are
   not preserved during folder validation or migration.
3. Add it **at the end** of the grid. When a patch integrates a table, a field added at the end keeps the
   database statistics; one inserted between two others makes the table be deleted and re-created, losing
   the statistics of the whole table (PATCH).
4. Validate the table, filling existing rows with the Processing button if needed. Code reads the field like
   any column (`[F:BPC]Y_SEGMENT`). The GESATB page does not say that validation generates or updates a
   screen, class or representation: those are separate elements (`screens-and-masks.md`, `v12-classes.md`).

## Indexes

| Field | Rule |
|---|---|
| Index code `CODIND` | Abbreviation + `0` for the primary key, `1` for the next...; specific indexes start with X, Y or Z |
| Descriptor `DESCRIPT`, Duplicates `HOMONYM` | Fields joined by `+` (`LEGCPY+FCY` on FACILITY); `-` before a field sorts it descending (never the first one); HOMONYM = duplicate values allowed |
| Specific clustered index `ORDIND` | Only one per table; never modified by patches (the Sage default `DEFORDIND` can be) |
| Activity `CODACT` | Empty = always present; inactive code = index not generated; X/Y/Z = specific key on a standard table |

The **Configuration file** block (`FICCFG`) is saved as `<table>.cfg` in FIL and used by `valfil`; with Open
access selected, validation adds a `$SECURITY` section. Index names are the key names of `Read` (`database.md`).

## Validating tables and the dictionary

**Validation** (GESATB): a missing table is created empty; an existing one gets its structure updated
with its records preserved (fields added, removed or recopied). If nothing changed, only the indexes are
rebuilt. **Forced** validation revalidates data and indexes completely.

- Validating or restoring a table clears the SQL views based on it: after a forced validation, revalidate
  those views in the current folder and every other folder that uses the table (GESAVW).
- Audit tab settings are applied at validation: triggers come from the `SUBTRIGGER` processing; specific
  developments customise the trigger description in `SPETRIGGER` (`audit-compliance.md`).
- **Processing** creates a temporary script `WWINI<abbreviation>`, run after validating an existing table
  to set values in its rows: `$OUVRE` (before the update transaction; opens at least that table),
  `$DEFAULT` (transaction started; needs a `Default File` on it), `$INIZON` (once per row before rewrite:
  the assignments, such as `MYFIELD = OTHFIELD + 1`). It runs after the structure change, so renaming a field
  takes three steps: keep both, assign `NEWFIELD = OLDFIELD` in `$INIZON`, delete the old one afterwards.

**VALDICO** (Validation; V11 menu: Development > Utilities > Dictionary > Validations > Dictionary) is a
selective folder validation: element types (tables, screens, objects, windows, queries) and ranges, filtered
by data type, activity code, action code or module, optionally in one language. Its forced validation
regenerates tables by temporary copy; **Test mode** only lists elements in the log; batch task VALDICO.

In a patch these elements travel as `ATB` (definition, no data), `ATY`, `AML` (local menu), `AVW`, `ADI`
(miscellaneous table contents) and `ADP` (parameter and general-level value): `personalisation-activity.md`.

## Data types (GESATY)

A data type gives every field using it an internal type, length, format, options, linked object, default
value and actions; characteristics left empty are entered on each field.

| Element | Content |
|---|---|
| Internal type `TYPTYP`, Length `LNGTYP` | Alphanumeric, Local menu, Short integer (-32768..32767), Long integer, Decimal (`N.M`, up to 32 significant digits), Date (1600-9999, null date `[0/0/0]`), Blob, Clob; length 0 = entered on each field |
| Adonix format `FORTYP` | Right part of a format (`10X`); `=` for a variable format (`=[F:DEV]FM92`; MD1 uses `=GDEVFMT`) |
| Linked object `OBJLIEN` (Convergence tab) | Brings the existence control, selection windows and tunnel |
| Default value `VALDEF` | Formula (type CRY proposes `GPAYS`); a screen field's own default wins |
| Class tab | Content type, class `CODCLA`, default representations (`DEFREPDES`, `DEFREPMOB`, `DEFREPTAB`), Rules grid (type, script, sub-program, sequence, activity code) |

`AX1` / `AX2` / `AX3` (translated text, length 12 / 20 / 30) are not created in the database: the text is
in ATEXTRA. `ADI` holds a code of the miscellaneous table whose number is in the link expression.

**Actions grid** (Convergence tab, actions dictionary codes, run for every field of the type). Types
`ACTTYP`: Before-field, Init_button, Init, Before_entry, Control, After-field, After-modif, Selection (F12),
Button 1 (F9, tunnels), Button 2 to 20, Before_line, After_line, Click. Execution `EXEACT`: Interactive,
Import / Web service (once all fields are loaded), Always. When the type and the screen field define the
same action type, the type's runs first, then the field's; for Selection and Button only the field's runs.

**Validation** compiles `WWGLOBLON`: one shortint global `GLON<type>` per alphanumeric data type, holding
its length. Declare work variables with it so that a length change follows:

```l4g
Local Char YITEM(GLONITM)            : # length of data type ITM
  [L]YITEM = [F:ITM]ITMREF
```

In Sage X3 SaaS, and on-premises from 2025 R2, the Length, Adonix format and Options of a Sage-supplied
type are changed in **GESATYC** (Data type personalization), then applied with VALDICO; other properties
in GESATY with an X/Y/Z activity code. Folder validation does not update types with an X/Y/Z activity code.

## Local menus (TXT)

There is no GESAML function: local menus and message chapters are maintained in **TXT** (table APLSTD).

| Field | Meaning |
|---|---|
| Chapter `LANCHP`, `TITCHP`, Local menu `MENLOCAL` | Number (ranges: `conventions-and-naming.md`), title; checked = local menu, cleared = message chapter |
| Activity code `CODACT`, Module | X/Y/Z protects a specific chapter |
| Changeable `AUZMOD` | Users may edit it in setup; it is then not updated by folder revalidation, version installation or patches (TXT_TRA) |
| `NONTRA`, `LONG`, `MINI`, `MAXI` | Do not translate (new lines not created in other languages); label width; minimum and maximum number of choices |
| Grid `LANNUM`, `CODE`, `LANMES` | Rank, one-character code, label |

- A field of type `M` / `MM` stores the **rank** (local menu 1: 1 = No, 2 = Yes): add values at the end,
  never insert; at most 123 choices. Leaving TXT after a change updates the cache files of each language.
- Changeable menus are edited by users in **COMBOS** (V11 menu: Setup > General parameters > Local menus):
  on End, answer Yes to "Update of local menus". Radio-button menus can need screens revalidated (VALDICO).
- **GENMENULOC** (V11 menu: Development > Utilities > Dictionary > Local menu update) regenerates the
  `menus` / `menuXXX` files Crystal Reports uses on client workstations: run it after answering No or after
  mass changes; clients get them at their next connection.

## Miscellaneous tables (GESADV, GESADI)

- **GESADV** (definition, table ATABTAB): number `NUMTAB`, descriptions, module, activity code (X/Y/Z =
  specific), access code, Changeable `UPDFLG`, company / legislation filters, code length `LNG` (at most
  folder parameter `MAXADI`), dependency `DEPNUM` on another miscellaneous table, up to 15 alphanumeric
  (length 40) and 15 numeric columns. Posting revalidates screens with an `ADI` field on the table.
- **GESADI** (data): code, descriptions, additional values, dependency, active flag, default value. Tables
  900 to 999 are delivered as standard: a record added there needs a code starting with X, Y or Z, or the
  next folder validation deletes it.

Table ATABDIV `[ADI]`, key `CODE` = NUMTAB+CODE (no duplicates): `A1`-`A15` (alphanumeric, 40), `N1`-`N15`
(decimal 11.6), `DEPCOD`, `ENAFLG` (local menu 1), `LNGDES` / `SHODES` (types AX3 / AX1, text in ATEXTRA).
The GESADI page still speaks of "1 to 4" additional values: check in GESADV which column holds which value.

```l4g
# YADI_A1 - first alphanumeric column of code YCOD in specific miscellaneous table 6001
Funprog YADI_A1(YCOD)
Value Char YCOD()
Local File ATABDIV [ADI]
  Read [ADI]CODE = 6001; [L]YCOD
  If fstat : End "" : Endif                : # code not found
  If [F:ADI]ENAFLG <> 2 : End "" : Endif   : # inactive (local menu 1: 2 = Yes)
End [F:ADI]A1
```

The description sits in ATEXTRA under `ATABDIV` / `LNGDES` / language / table number / code. The help gives
`AFNC.TEXTRA(table_code, field_code, key_value_1, key_value_2)` in calculator syntax only, without the number
format: test `func AFNC.TEXTRA("ATABDIV", "LNGDES", num$(6001), [L]YCOD)` on your folder first.

## SQL views (GESAVW)

- Code 1-12 characters, never a table's name; abbreviation 1-8; Active `ENAFLG`; X/Y/Z activity code =
  specific view, not impacted by version changes. Used tables / views grid: type `ATB` or `AVW`, optional.
- Query in `TEX1` (Oracle) and `TEX2` (SQL Server), at least for the folder's database; `%formula%` parts
  become constants at validation. Do not hard-code a folder: folder validation validates views from the X3
  folder, so avoid `func`, `nomap` and `adxmother` in formulas or revalidate the view in its folder after.
- Fields tab must match the query (number, order, type); specific fields start with `X_`, `Y_` or `Z_`;
  AX1-AX3 types are refused. Sort keys: abbreviation + `0`, `1`... (X/Y/Z for specific ones), for
  `Order By`; **no index is created**; Duplicates defaults to Yes (No only to support `Read` Next / Prev).
- Validation checks the query, runs `create view` and writes in FIL `.srf` (fields, `#V` on line 3),
  `.fde` (`valfil -n`), `.viw` (query) and, with configuration text or secured access, `.cfg`.
- A view is read-only: `Local File`, `Close Local File`, `Filter`, `For ... Next`, `Read`, `Columns`, `Link`.

```l4g
# YVSALES: specific view, abbreviation YVS, sort key YVS0 on BPCNUM
Local File YVSALES [YVS]
Local Decimal YTOTAL
  For [YVS]YVS0 Where BPCNUM = "C0001"
    [L]YTOTAL += [F:YVS]Y_AMOUNT
  Next
```

## General parameters (GESADP)

| Field | Meaning |
|---|---|
| Chapter `CHAPITRE`, Group `GRPPAR` | Miscellaneous tables 901 and 903; a specific chapter is an X/Y/Z code added to table 901 |
| Parameter `PARAM` | 10 alphanumeric characters; specific ones start with X, Y or Z and carry an X/Y/Z activity code to survive version changes and revalidation |
| Definition level `NIVDEF` (local menu 987) | Folder, Legislation, Company, Site or User: the finest level that can hold a value |
| Value type `TYPVAL`, `NOLIB`, Object `OBJET` | Internal type, local menu number; an object brings its controls and selection |
| Control processing `TRAIT` | Script with `Subprog VERF_PARAM(PARAM,VALEUR,OK)`; `OK = 0` plus `GMESSAGE` refuses the value |
| Global variable `CODVAR` | `[V]` variable loaded at connection: `G*` standard, X/Y/Z specific |
| Changeable `MODIF` | Cleared: only a program changes the value (TYPDBA) |

- A global variable generates WWAGLOBVAR (folder to site levels) or WWAGLOBUSR (user). It keeps its value
  when the site or company changes: re-read it (`Call GLOBVAR(SITE) From WWGLOBXXX`, one per module).
- Values are entered in **Parameter values** (V11 menu: Setup > General parameters > Parameter values):
  a chapter, then a legislation, company, site or nothing (folder); a group can take a predefined set of
  values. User-level values go in the user record (GESAUS, Parameter tab). Its help page is FCT/ADPVAL.htm;
  the supervisor parameters page names it ADOVAL, a code with no help page (404 in V11 and V12).
- Inheritance: site, then its company, its legislation, the folder. A user-level search starts from the
  user's default site for the parameter's module.

## Reading a parameter in L4G

V7+ code reads the APARAM cache of the context: `this.ACTX` in class code, `GACTX` outside a class.

| Need | Call |
|---|---|
| Folder, legislation, company or site value | `fmet GACTX.APARAM.AGETVALCHAR(LEVCOD, TYPVAL, PARAM)`; `AGETVALNUM` (integer or local menu); `AGETVALDATE` |
| `LEVCOD` / `TYPVAL` | `[V]CST_ALEVFOLD`, `[V]CST_ALEVLEG`, `[V]CST_ALEVCPY`, `[V]CST_ALEVFCY` / the code of that level |
| Parameter defined at User level | `AGETUSERVALCHAR(PARAM)`, `AGETUSERVALNUM`, `AGETUSERVALDATE` |
| Classic code | `Call PARAM(SITE,PARAM,VALEUR) From ADOVAL`; `Call PARAMUTIL(PARAM,VALEUR,USER,"") From SUBAUS` |
| Formula (automatic journals...) | `func AFNC.PARAM(PARAM, SITE)`: alphanumeric value, at most 30 characters |

- The six getters apply the inheritance above and return an empty value on error (for example an unknown
  company code). The Classic calls always return a string: assign dates directly, use `val()` for numbers.
- `AFNC.PARAMG` has no page in the Sage help: never use it.

```l4g
# YCTL_ACTIVE - is the specific control enabled for site FCY?
# YCTLACT: specific parameter (GESADP), level Site, local menu 1 (2 = Yes), activity code YCTL
Funprog YCTL_ACTIVE(FCY)
Value Char FCY()
Local Integer YVAL
  [L]YVAL = fmet GACTX.APARAM.AGETVALNUM([V]CST_ALEVFCY, [L]FCY, "YCTLACT")
  If [L]YVAL = 2 : End [V]CST_ATRUE : Endif
End [V]CST_AFALSE
```

```l4g
# Classic form of the same read: the value comes back as a string
Local Char    YVALUE(250)
Local Integer YVAL
  Call PARAM([L]FCY, "YCTLACT", [L]YVALUE) From ADOVAL
  [L]YVAL = val([L]YVALUE)
```

## Gotchas
- GESAML does not exist: local menus are TXT (`AML` is only the APATCH element type).
- A field inserted in the middle of a table loses its statistics at patch time; a value inserted in the
  middle of a local menu silently changes the meaning of stored ranks.
- After a forced table validation, views built on the table must be revalidated in every folder.
- The context-parameters page defines `TYPVAL` as the level's code and lists error 4 "TYPVAL empty", with no
  folder-level example; other references of this skill pass `""` with `[V]CST_ALEVFOLD`. Check on your folder.
- `AFNC.PARAM` returns a string: compare it with a string (GESGAU: `AFNC.PARAM("FRAVAT",[F:SIH]CPY)="2"`).

See also: `conventions-and-naming.md`, `localization.md`, `function-codes.md`, `database.md`,
`personalisation-activity.md`, `audit-compliance.md`, `v12-classes.md`, `screens-and-masks.md`,
`accounting-automatic-journals.md`.

## Sources
- https://online-help.sagex3.com/erp/12/en-us/Content/FCT/GESATB.htm , FCT/GESATBP.htm , FCT/GESAVW.htm
- https://online-help.sagex3.com/erp/12/en-us/Content/FCT/PATCH.htm , FCT/APATCH.htm , FCT/VALDICO.htm
- https://online-help.sagex3.com/erp/12/en-us/Content/FCT/GESATY.htm , FCT/GESATYC.htm
- https://online-help.sagex3.com/erp/12/en-us/Content/FCT/TXT.htm , FCT/TXT_TRA.htm , FCT/COMBOS.htm , FCT/GENMENULOC.htm
- https://online-help.sagex3.com/erp/12/en-us/Content/FCT/GESADV.htm , FCT/GESADI.htm , MCD/ATABDIV.htm , MCD/ATEXTRA.htm
- https://online-help.sagex3.com/erp/12/en-us/Content/FCT/GESADP.htm , FCT/ADPVAL.htm , FCT/GESGAU.htm (AFNC.PARAM)
- https://online-help.sagex3.com/erp/12/en-us/Content/V7DEV/administration-reference_supervisor-parameters.html
- https://online-help.sagex3.com/erp/12/en-us/Content/V7DEV/developer-guide_context-parameters.html , V7DEV/developer-guide_context.html
- https://online-help.sagex3.com/erp/11/en-US/FCT/VALDICO.htm , FCT/COMBOS.htm , FCT/GENMENULOC.htm , FCT/ADPVAL.htm (V11 menu paths)
- https://online-help.sagex3.com/erp/12/en-us/Content/FCT/ADOVAL.htm , FCT/GESAML.htm (both 404, checked)

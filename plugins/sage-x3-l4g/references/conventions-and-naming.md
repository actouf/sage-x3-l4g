# Conventions and naming

Naming rules for anything you create in a Sage X3 folder: the first letter of dictionary codes, table,
field and index names, class and representation names, script names, activity codes, message chapters and
local menu numbers. The rules are what lets standard patches and folder revalidation leave specific code
alone; read this before creating any dictionary element or script.

## Contents
- [First letter of dictionary codes](#first-letter-of-dictionary-codes)
- [Tables, fields and indexes](#tables-fields-and-indexes)
- [Standard table abbreviations](#standard-table-abbreviations)
- [Classes, representations and methods](#classes-representations-and-methods)
- [Script names](#script-names)
- [Script files and folders](#script-files-and-folders)
- [Activity codes](#activity-codes)
- [Message chapters, local menus and miscellaneous tables](#message-chapters-local-menus-and-miscellaneous-tables)
- [Library functions](#library-functions)
- [Gotchas](#gotchas)
- [Sources](#sources)

## First letter of dictionary codes

Sage's naming guide (classed "strict") applies to tables and abbreviations, views, classes, collections,
constants, methods and operations, representations, data types, activity codes, context variables,
parameters, scripts, and Classic screens, windows, objects and inquiries.

| Pattern | Meaning |
|---|---|
| `A*` | Supervisor elements |
| `B*` to `T*`, `V*` | Standard application elements |
| `U*` | Usually reserved for temporary tables used during updates; do not use for tables or classes |
| `W*` | Generated elements; never create or edit them by hand |
| `X*` | Add-ons developed outside Sage |
| `Y*`, `Z*` | Specific elements developed outside Sage |
| `QLF<area>_<case>` | AXUNIT test scripts (area `X*` add-ons, `Y*`/`Z*` vertical or specific) |

How X, Y and Z are split between layers is not stated consistently in the help: the naming guide says
X = add-on, Y/Z = specific; the GESACV field help says X = partner add-on (with a Sage-issued ID),
Y = vertical, Z = specific; the GESACV introduction says X = vertical, Y/Z = custom. What every page agrees
on is that **X, Y and Z mark non-standard elements, which standard patches do not touch**. Pick one letter
per delivery layer and keep it everywhere. This skill uses `Y` in its examples.

## Tables, fields and indexes

| Element | Rule (GESATB unless noted) |
|---|---|
| Table code | 1-10 alphanumeric characters, starting with a letter; custom tables start with X, Y or Z |
| Abbreviation | 1-3 alphanumeric characters, starting with a letter, unique in the folder |
| Custom field added to a standard table | Name starts with `X_`, `Y_` or `Z_` (same rule for screen fields in GESAMK) |
| Dimensioned field | One database column per occurrence: `FIELD_0`, `FIELD_1`, ... |
| Index name | Abbreviation + `0` for the primary key, `1` for the next, and so on (`BPC0`) |
| Custom index on a standard table | Name starts with X, Y or Z |
| Classic object code | 1-3 alphanumeric characters (GESAOB) |
| Activity code | Up to 5 alphanumeric characters (GESACV) |

Table limits from GESATB: 15 indexes per table, 16 fields and 250 characters per index, 255 fields and
1,000 columns (fields x dimensions) per table, 32 KB per record.

Do not add specific fields or characteristics to **system or dictionary tables**: GESATB warns that they
are not preserved during folder validation or migration.

## Standard table abbreviations

Declare a table with its dictionary abbreviation and use the index names from the table dictionary.
Checked on the table-dictionary pages (`MCD/<TABLE>.htm`):

| Table | Abbreviation | Primary index (segments) |
|---|---|---|
| BPARTNER | BPR | BPR0 (BPRNUM) |
| BPCUSTOMER | BPC | BPC0 (BPCNUM) |
| BPSUPPLIER | BPS | BPS0 (BPSNUM) |
| BPADDRESS | BPA | BPA0 (BPATYP+BPANUM+BPAADD) |
| ITMMASTER | ITM | ITM0 (ITMREF) |
| ITMFACILIT | ITF | ITF0 (ITMREF+STOFCY) |
| STOCK | STO | STO0 (STOFCY+STOCOU) |
| SORDER / SORDERQ / SORDERP | SOH / SOQ / SOP | SOH0 (SOHNUM) / SOQ0 / SOP0 (SOHNUM+SOPLIN+seq) |
| PORDER / PORDERQ | POH / POQ | POH0 (POHNUM) / POQ0 (POHNUM+POPLIN+POQSEQ) |
| SINVOICE | SIH | SIH0 (NUM) |
| MFGHEAD | MFG | MFG0 (MFGNUM) |
| GACCOUNT | GAC | GAC0 (COA+ACC) |
| FACILITY / COMPANY | FCY / CPY | FCY0 (FCY) / CPY0 (CPY) |
| AUTILIS | AUS | CODUSR (USR) |
| TABCUR / TABCOUNTRY / TABLAN | TCU / TCY / TLA | TCU0 (CUR) / TCY0 (CRY) / TLA0 (LAN) |
| APLSTD | AST | CLE (LANCHP+LANNUM+LAN) |

```l4g
Local File BPCUSTOMER [BPC]
Local Char CUSTOMER(15), CUSTNAME(80)
  [L]CUSTOMER = "C0001"
  Read [BPC]BPC0 = [L]CUSTOMER
  If fstat = 0
    [L]CUSTNAME = [F:BPC]BPCNAM
  Endif
```

For any other table, open its definition in GESATB (or the `MCD/<TABLE>.htm` help page) instead of
guessing the abbreviation or the index name.

## Classes, representations and methods

Rules from the naming guide for persistent classes (illustrated with a specific table `YTICKET`):

| Object | Name |
|---|---|
| Main class managing the table | Same as the table: `YTICKET` |
| Cache class of the table | The table abbreviation |
| Desktop / mobile / tablet representation | `YTICKET` / `YTICKETM` / `YTICKETT` |
| Additional representation | Table name + purpose suffix: `YTICKETAD1` |
| Variant class | Table name + variant suffix |

- A class must not reuse the name or abbreviation of an existing table it is not linked to.
- Collections are properties: avoid `C_` / `R_` prefixes (too close to the generated class and
  representation names) and give them explicit names.
- Methods: `A*` public supervisor, `_A*` private supervisor (never call them), `B*`..`V*` standard,
  `X*`/`Y*`/`Z*` non-standard public, `_X*`/`_Y*`/`_Z*` non-standard private.
- Generated class code is named `C_<CLASS>`; see `v12-classes.md`.

## Script names

| Script | Naming | Source |
|---|---|---|
| Class script | `<CLASS>[segment]_C<STD/VER/SPE>`, for example `BPCUSTOMER_CSPE` | GESACLA, naming guide |
| Representation script | `<REP>[segment]_R<STD/VER/SPE>` | naming guide |
| Split sub-scripts | Main name + `_EVT`, `_PRO`, `_MPU`, `_MPR`, `_TYP`, `_GAT` | naming guide |
| Classic specific actions of object XXX | `SPEXXX` (vertical: `SPVXXX`) | GESAMK, GESAOB |
| Classic standard scripts | `SUBXXX` for object XXX, `CNS*` for inquiries, `IMP*` for imports | GESADC, APATCH |
| Library of functions | Ordinary dictionary rules: `Y*` | naming guide |
| Unit tests | `QLF<area>_<case>` | naming guide; see `unit-testing-axunit.md` |

The optional segment lets a partner tag its own scripts: the naming guide's example is a vertical
partner using prefix `XVE` on standard class BPCUSTOMER, giving `BPCUSTOMERXVE_CVER` and
`BPCUSTOMERXVE_RVER`. The class "Scripts" grid lists each script with a type (standard, vertical,
specific), a running order and an activity code; sub-scripts called by a router script are not declared
there.

When a patch is integrated into a folder flagged **Specific folder** (GESADS), the scripts treated as
specific are those whose name starts with X, Y or Z, starts with `SPE`, or starts with `CNS` and ends
with `SPE`. Name entry-point scripts and SPE scripts accordingly; see `entry-points.md` and
`classic-objects.md`.

## Script files and folders

- Each folder has a `TRT` sub-directory (GESADS uses its presence to recognise a real folder). The
  community describes `.src` files as the readable source and `.adx` files as the compiled form in that
  directory (community-reported). The online help does not document a `.trt` file extension: `TRT` is the
  directory and a patch element type.
- In a patch, element type `TRT` delivers a script source that is compiled on integration; type `ADX`
  delivers the compiled file only (APATCH).
- Version-control the source only; compiled files are regenerated.
- Log files produced by long-running functions are `F<n>.tra` files in the folder's `TRA` sub-directory,
  read with LECTRACE (see `debugging-traces.md`).

## Activity codes

An activity code (GESACV, up to 5 alphanumeric characters) is attached to dictionary elements, not to
lines of code. It does three things:

1. **Optional elements**: when the code is inactive in the folder, the element (table, field, index,
   screen, block, class property, method, class script, local menu...) is not generated; for a class
   script the call is skipped (GESACLA).
2. **Protection**: an element carrying a code that starts with X, Y or Z is considered non-standard and is
   not affected by a standard patch or a version change (GESACV, GESATB, GESAMK, GESACLA).
3. **Sizing**: "Sizing" codes set the dimension of grids and multi-occurrence fields.

Other facts worth knowing:
- Types are Functional, Sizing and Localization; localisation codes start with K (one 3-character code
  per country). Dependencies can be None, Reverse, Sizing or Formula.
- Codes are switched on in the folder record (GESADS, "Specific" tab for X/Y/Z codes); any change
  requires revalidating the folder.
- A code such as `YHEALTH` (7 characters) is invalid; use 5 characters or fewer (`YHLTH`, `YEDI`).
- There is no conditional-compilation directive tied to activity codes (`#Active`, `$ACT` do not exist).

Patch delivery and folder layering are in `personalisation-activity.md`.

## Message chapters, local menus and miscellaneous tables

Message chapters and local menus share table APLSTD and the TXT function. Reserved ranges (TXT page and
naming guide):

| Range | Use |
|---|---|
| 160-164 | Messages for specific developments |
| 165-169 | Messages for vertical developments |
| 1000-1999 | Local menus for vertical developments |
| 4000-4999 | Add-ons |
| 5100-5199 | Messages or local menus for vertical developments |
| 5200-5999 | Local menus for vertical developments |
| 6000-6199 | Messages for specific developments |
| 6200-6999 | Local menus for specific developments |
| 8000-8999 | Localizations |
| 13000-13999, 18000-29999 | Add-ons |

Miscellaneous tables (GESADV): 1000-1999 vertical, 4000-4999 add-ons, 6000-6999 specific, 8000-8999
localizations, 13000-13999 and 18000-29999 add-ons.

- Read a message with `mess(NUM, CHAPTER, 1)`; the text comes back in the connection language
  (`localization.md`).
- A local menu stores the **rank** of the choice: add values at the end, never insert (local menu 1 is
  No = 1, Yes = 2). A local menu is limited to 123 choices.
- Dictionary texts (ATEXTE) above 100,000 are specific; their numbers are assigned automatically and may
  be renumbered when a patch is integrated.

## Library functions

The naming guide recommends `Funprog` over `Subprog` in libraries, returning `[V]CST_ATRUE` on success
or `[V]CST_AFALSE` on error, plus a character parameter of at most 250 characters (data type AMSG) that
receives the error message.

```l4g
# Script YLIBCTL - shared controls (Y prefix: specific library)
Funprog YCTL_CODE(CODE, ERRMSG)
Value    Char CODE()
Variable Char ERRMSG()
  [L]ERRMSG = ""
  If len([L]CODE) = 0
    [L]ERRMSG = mess(1, 6000, 1) : # chapter 6000-6199 = specific messages
    End [V]CST_AFALSE
  Endif
End [V]CST_ATRUE
```

Layout conventions (PascalCase keywords, uppercase identifiers, 2-space indentation, `: #` comments,
`&` continuation lines) are described in `language-basics.md`.

## Gotchas
- `GACCOUNT` is `[GAC]`, not `[GACC]` (abbreviations are at most 3 characters).
- `W*` names belong to generated code: a `W` class or script you create can be overwritten.
- A specific field on a standard table without an X/Y/Z activity code is a standard element for the patch
  tools: give every specific element its activity code.
- Inserting a value in the middle of a local menu silently changes the meaning of stored data.
- An index name is not the field name: `BPC0`, never `BPCNUM0`.
- Class names that collide with an unrelated table name or abbreviation are rejected by the naming rules.

See also: `function-codes.md`, `personalisation-activity.md`, `v12-classes.md`, `localization.md`,
`database.md`.

## Sources
- https://online-help.sagex3.com/erp/12/en-us/Content/V7DEV/how-to_how-to-naming.html
- https://online-help.sagex3.com/erp/12/en-us/Content/V7DEV/developer-guide_classes-script.html
- https://online-help.sagex3.com/erp/12/en-us/Content/FCT/GESACV.htm
- https://online-help.sagex3.com/erp/12/en-us/Content/FCT/GESATB.htm
- https://online-help.sagex3.com/erp/12/en-us/Content/FCT/GESAMK.htm
- https://online-help.sagex3.com/erp/12/en-us/Content/FCT/GESAOB.htm
- https://online-help.sagex3.com/erp/12/en-us/Content/FCT/GESACLA.htm
- https://online-help.sagex3.com/erp/12/en-us/Content/FCT/GESADC.htm
- https://online-help.sagex3.com/erp/12/en-us/Content/FCT/GESADS.htm
- https://online-help.sagex3.com/erp/12/en-us/Content/FCT/TXT.htm
- https://online-help.sagex3.com/erp/12/en-us/Content/FCT/TXT_TRA.htm
- https://online-help.sagex3.com/erp/12/en-us/Content/FCT/APATCH.htm
- https://online-help.sagex3.com/erp/12/en-us/Content/FCT/LECTRACE.htm
- https://online-help.sagex3.com/erp/12/en-us/Content/MCD/BPCUSTOMER.htm (and the other `MCD/<TABLE>.htm` pages)
- https://communityhub.sage.com/us/sage_x3/f/general-discussion/199401/about-adx-binary-files-in-trt-folder (community: `.src` / `.adx`)

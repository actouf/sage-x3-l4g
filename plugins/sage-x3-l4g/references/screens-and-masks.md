# Screens, masks and field actions (Classic)

Classic screens (masks) still run every Classic page of V12: object windows, inquiries, entry
transactions. This file covers the screen dictionary (GESAMK), the `[M:ABV]` classes, field actions
and their `C_` / `AM_` labels, `mkstat` / `GMESSAGE`, the display instructions (`Affzo`, `Actzo`,
`Grizo`, `Diszo`, `Effzo`), message boxes and grids. Sage flags all of these instructions as
"usable only in Classic pages related code and deprecated for code running in version 7 mode": use
them only when customising a Classic page. New UI is built with representations
(`v12-representations.md`). Object-level actions (`LIENS`, `VERIF_CRE`...) are in `classic-objects.md`.

## Contents
- [Screen dictionary (GESAMK)](#screen-dictionary-gesamk)
- [Masks in code](#masks-in-code)
- [Field actions](#field-actions)
- [mkstat, GMESSAGE and field context](#mkstat-gmessage-and-field-context)
- [Display instructions](#display-instructions)
- [Message boxes and messages](#message-boxes-and-messages)
- [Grids](#grids)
- [Gotchas](#gotchas)
- [Sources](#sources)

## Screen dictionary (GESAMK)

- **Screen code** (`CODMSK`) 1 to 10 characters; **abbreviation** (`ABRMSK`) 1 to 4 characters. Two
  screens with the same abbreviation must never be open together. For an object `XXX` the header
  screen is named `XXX0` and the tabs `XXX1`...`XXXn` (recommended, not mandatory). `GESBPC` is the
  customer **function** (object `BPC`), not a screen.
- **Scripts**: Standard (`TRTSTD`, normally `SUBXXX`), Vertical (`TRTSPV`, `SPVXXX`), Specific
  (`TRTSPE`, `SPEXXX`). Validation creates or updates the script when an action of that level is
  added to a field.
- **Blocks**: type Table (scrolling grid), List, Text, Hidden, Browser, Office...; for a Table block,
  *Line* (`NBLIGT`) = maximum lines, *Options* = allowed grid functions (`A` delete line, `*` insert,
  `R` add at end, `S`/`B`/`C` cut/copy/paste...), *Parameter* (`BASPAG`) = the **grid-bottom
  variable** (data type ABS) holding the number of lines entered.
- **Fields**: field code (`CODZON`) 1 to 10 characters, accessed as `[M:ABV1]FIELDNAME`; specific
  fields must start with `X_`, `Y_` or `Z_`. *Input* Enter / Displayed / Hidden, *Mandatory*, *Entry
  condition* (`CONSAI`, e.g. `[M]ZONEPREC=2`), *Default value* (`VALDEF`, prefix `*` to force it),
  *Access code*.
- **Validation** builds the `.msk` file and the generated scripts `W0<screen>` (import) and
  `W1<screen>` (interactive). Never edit generated scripts.

## Masks in code

```l4g
Subprog YLOAD_VIEW(BPC)
Value Char BPC()
Local File BPCUSTOMER [BPC]
Local Mask YBPCVIEW [YBV]          : # screen YBPCVIEW declared with abbreviation YBV
  Read [BPC]BPC0 = [L]BPC
  If fstat = 0
    [M:YBV] = [F:BPC]              : # copies the fields that have the same name
  Endif
End
```

- `Mask` closes all previously opened masks; inside subprograms use `Local Mask`, which restores the
  caller's mask list on return. `Mask NAME [ABV]` can reopen a screen under another abbreviation.
- `[M:ABV] = [F:ABV]` and `[F:ABV] = [M:ABV]` copy same-named fields; for grid lines, `nolign`
  selects which array element is copied (see the `nolign` page).
- Inside object actions and field actions the screens of the window are already open: do not
  redeclare them.

## Field actions

Defined per field in the *Actions* grid of GESAMK:

| Type | When |
|---|---|
| Before field | Before any entry or display of the field (e.g. set its format) |
| Init button | Define the contextual-menu button names |
| Initialization | Initialise the field |
| Before entry | Before each entry (e.g. set `mkstat` to prevent entry) |
| Control | Validate the value |
| After field | After a successful control (assign or display other fields) |
| After change | Like After field, only if the value changed |
| Selection | F12 selection |
| Button 1 / Buttons 2 to 20 | Tunnel (F9) / contextual menu entries |
| Before line / After line | Scrolling grids: entering a line in modification / after each line |
| Click | Icon fields |

- **Action** code: a catalogued action (GESACT) or `STD`, `SPE`, `SPV` = a label written in the
  standard, specific or vertical script. **Execution**: Interactive, Import/batch, Always.
  **Deactivation** (`DISACT`): an `SPE` action can deactivate the `SPV` or `STD` action of the same
  type. Classic dev rules: to remove a standard field action, add an `SPX` action instead of deleting.
- **Label names**: screen validation adds the subprogram skeleton to the specific script. Sage's own
  sample names the Control label `Subprog C_<FIELD>(VALEUR)`; After change uses `AM_<FIELD>(VALEUR)`
  (community-reported: `VALEUR` holds the new value while `[M:...]FIELD` still holds the old one).
  For other action types, open the generated section of the script for the exact name.
- Catalogued actions placed on a contextual button can have before/after labels in `$ACTION`: label
  `A` or `B` + button code + `_` + field, e.g. `AB2_CHP` / `BB2_CHP` for button 2 of field `CHP`.

## mkstat, GMESSAGE and field context

```l4g
# In SPEXXX (control action, type Control / SPE, on grid field QTY)
Subprog C_QTY(VALEUR)
Variable Decimal VALEUR
  If [L]VALEUR = 0 and nolign = 1
    GMESSAGE = mess(3, 160, 1) : # "Quantity cannot be 0 on the first line"
    mkstat = 1                 : # reject the value (Sage sample)
  Endif
End
```

- `mkstat` (deprecated keyword) rejects the entry in a control, prevents entry when set in Before
  entry, and stops linked actions of a catalogued action. `GMESSAGE` carries the text shown.
- `zoncou` = name of the field being controlled; `zonsui = zoncou` keeps the cursor on it without a
  beep (`zoncou + "(" + num$(index) + ")"` in a grid). `nolign` = current grid line, starting at 1.
- Object action `APRES_MODIF` runs after the field's After change action for **any** field
  (`COUZON`, `COUIND`); use it when one rule reacts to several fields.

## Display instructions

| Instruction | Effect |
|---|---|
| `Affzo` | Display fields |
| `Actzo` | Re-activate fields previously grayed (by `Grizo`/`Diszo`) |
| `Grizo` | Gray out enterable fields |
| `Diszo` | Gray out, stating the fields are meaningful in the context |
| `Effzo` | Reset the variables (empty, null date, 0) and display blanks |
| `Chgstl ... With STYLE` | Apply a style (`With ""` = default style) |

Syntax (same for all): `Affzo [ABV]` (whole mask), `Affzo [ABV]FIELD1, FIELD2`, ranks `Affzo [ABV]20-30`,
ranges `FIELD1-FIELD9`, array element `FIELD(I+1)`, computed `=expression`. On grids: `Affzo [M]NBLIG`
(grid-bottom variable), `Affzo [M]FIELD` (column), `Affzo [M]FIELD(nolign-1)` (cell).

```l4g
# In SPEYBC1 (After change / SPE on flag Y_FLG): enable the note only when the flag is Yes
Subprog AM_Y_FLG(VALEUR)
Variable Integer VALEUR
  If [L]VALEUR = 2
    Actzo [M:YBC1]Y_NOTE
  Else
    Effzo [M:YBC1]Y_NOTE
    Grizo [M:YBC1]Y_NOTE
  Endif
End
```

`Effzo` does not work on a mask that is not displayed: use `Raz` there. `Actzo`, `Grizo`, `Diszo`
and `Affzo` on a whole class mark the screen valid (field checks are skipped).

## Message boxes and messages

| Instruction | Syntax |
|---|---|
| `Infbox` / `Errbox` / `Wrnbox` | `Errbox MESSAGE_LIST [Titled TITLE] [Sleep SECONDS]` |
| `Qstbox` | `Qstbox MESSAGE_LIST [Titled TITLE] Using ANSWER [Sleep SECONDS]`: 1 = Yes, 2 = No (also on time-out) |

`MESSAGE_LIST` is a comma-separated list of strings, one line each. All are Classic-only and
deprecated in V7 mode. The keyword glossary has no `Question` instruction: use `Qstbox`.

Texts come from the message dictionary: `mess(NUMBER, CHAPTER, 1)` returns the text in the connection
language; the third argument is the message **table** (1 = application, 0 = engine), not a language.
Specific messages go in the chapters reserved for customisation (`conventions-and-naming.md`).

## Grids

A Table block is a set of array fields plus the grid-bottom variable declared in *Parameter*. In a
simple object with a grid tab, load that variable in the `LIENS` action; gray cells there too, before
the supervisor's `Affzo` (it is too late afterwards).

```l4g
$Y_LIENS
  # Grid tab YBC1 (columns Y_NOTE, bottom variable Y_NBLIG) loaded from YBPCNOTE
  Call Y_LOADNOTES
Return

# A Subprog has its own locals; a Gosub label shares the template's (see entry-points.md)
Subprog Y_LOADNOTES
Local File YBPCNOTE [YBN]
Local Integer I
  [L]I = 0
  For [YBN] Where BPCNUM = [F:BPC]BPCNUM
    If [L]I >= dim([M:YBC1]Y_NOTE)
      Break
    Endif
    [M:YBC1]Y_NOTE([L]I) = [F:YBN]YNOTE
    [L]I += 1
  Next
  [M:YBC1]Y_NBLIG = [L]I
End
```

Grid columns are arrays indexed from 0 while `nolign` starts at 1: line `nolign` is element
`nolign-1`. `LIENS0` / `LIENS2` are for grid and combined objects (reading groups of records), not for
loading a grid tab.

## Gotchas

- Field actions use `mkstat`; object actions use `OK` / `GOK` (`classic-objects.md`).
- Sage's hybrid guide warns that field-action code is lost when representations replace Classic
  windows: put business rules in classes or object actions.
- Writing `[F:...]` in a field action changes nothing on screen; the user sees `[M:...]`.
- Do not `Commit` or `Rollback` in actions: the object template owns the transaction.
- `Local Mask GESBPC`-style declarations are wrong: GESBPC is a function code.

See also: `classic-objects.md`, `entry-points.md`, `localization.md`, `v12-classes-representations.md`,
`language-basics.md`.

## Sources
- https://online-help.sagex3.com/erp/12/en-us/Content/FCT/GESAMK.htm
- https://online-help.sagex3.com/erp/12/en-us/Content/FCT/GESACT.htm
- https://online-help.sagex3.com/erp/12/en-us/Content/V7DEV/4gl_x3script-keywords-glossary.html
- https://online-help.sagex3.com/erp/12/en-us/Content/V7DEV/4gl_Mask.html
- https://online-help.sagex3.com/erp/12/en-us/Content/V7DEV/4gl_Affzo.html (and 4gl_Actzo, 4gl_Grizo,
  4gl_Diszo, 4gl_Effzo, 4gl_Chgstl, 4gl_Errbox, 4gl_Infbox, 4gl_Qstbox)
- https://online-help.sagex3.com/erp/12/en-us/Content/V7DEV/4gl_Nolign.html
- https://online-help.sagex3.com/erp/12/en-us/Content/V7DEV/4gl_Zoncou.html
- https://online-help.sagex3.com/erp/12/en-us/Content/V7DEV/4gl_mess.html
- https://online-help.sagex3.com/erp/12/en-us/Content/V7DEV/4gl_dim.html
- https://online-help.sagex3.com/erp/12/en-us/Content/MODEL/LIENS.htm
- https://online-help.sagex3.com/erp/12/en-us/Content/MODEL/APRES_MODIF.htm
- https://online-help.sagex3.com/erp/11/en-US/MODEL/RULES_DEV.htm
- https://online-help.sagex3.com/erp/12/en-us/Content/V7DEV/developer-guide_hybrid-development.html
- https://www.greytrix.com/blogs/sagex3/2012/02/18/difference-between-x3-actions-apres-modif-vs-am-xxx/
  (community-reported)
- https://communityhub.sage.com/sage-global-solutions/sage_x3/f/general-discussion/247389/management-of-custom-fields
  (community-reported)

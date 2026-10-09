# Classes, representations and Classic objects: router

V12 runs two development models side by side: V7+ **classes** and **representations** (Syracuse
pages, REST) and the **Classic** model (objects, screens/masks, field actions, entry points). This
short file says which is which, where each one's code lives, and which reference to open. There is no
`Class ... Endclass` source syntax in X3: classes and representations are dictionary entries plus
event scripts.

## The models at a glance

| Model | Dictionary | Code lives in | Dispatch | Read |
|---|---|---|---|---|
| Class | GESACLA | `<CLASS>_CSTD`, `_CVER...`, `_CSPE...` scripts | `$EVENTS`, `$PROPERTIES`, `$METHODS`, `$OPERATIONS` | `v12-classes.md` |
| Representation | GESASW (Representations) | `<REP>_RSTD`, `_RSPE...` scripts | Same labels, no `$OPERATIONS` | `v12-representations.md` |
| Classic object | GESAOB | `SUB<OBJ>` / `SPV<OBJ>` / `SPE<OBJ>` | `$ACTION` + `Case ACTION` | `classic-objects.md` |
| Classic screen | GESAMK | `SUBXXX` / `SPEXXX` field-action subprograms | `C_<FIELD>`; `AM_<FIELD>` (community-reported) | `screens-and-masks.md` |
| Entry point | GESAPE | Specific script declared on a standard script | `$ACTION` + `Case ACTION` | `entry-points.md` |

- V7 introduced classes (usually mapped to tables) and representations (the UI view of a class);
  V6 worked with tables (`[F:]` classes) and masks (`[M:]` classes). Classic pages keep running in
  V12 through the Classic mode.
- A representation always wraps one class: the class instance is a child of the representation
  instance (`MYREP.CUST.NAME`).
- Business rules belong in the class: every caller (pages, REST, imports, other scripts) goes through
  it. Representation scripts hold UI-only logic.

## Which file for which question

- Rules, CRUD events, transactions in events, `ASETERROR`, `fmet`, instances: `v12-classes.md`.
- Facets, links, query events, representation scripts: `v12-representations.md`.
- Calling a class through REST: `web-services-rest.md`.
- `VERIF_CRE`, `LIENS`, `GOK`, `SPE<OBJ>`: `classic-objects.md`.
- `[M:]`, field actions, `mkstat`, `Affzo`, grids, message boxes: `screens-and-masks.md`.
- `GPOINT`, `GPE`, GESAPE: `entry-points.md`.
- Activity codes, patch protection: `personalisation-activity.md`.

## Classic to V12 migration notes

Closest documented equivalent of each Classic hook, matched by when it runs:

| Classic | V12 class / representation |
|---|---|
| `VERIF_CRE` / `VERIF_MOD` (`OK = 0`) | `AINSERT_CONTROL_*` / `AUPDATE_CONTROL_*` + `ASETERROR` (no transaction) |
| `INICRE` / `CREATION` (`GOK = 0`) | `AINSERT_BEFORE` / `AINSERT_AFTER` (transaction; error = rollback) |
| `AB_CREATION` / `AB_MODIF` | `AINSERT_ROLLBACK` / `AUPDATE_ROLLBACK` |
| `LIENS` (after read) | `AREAD_AFTER` |
| Field Control action `C_<FIELD>` + `mkstat` | `CONTROL` rule + `ASETERROR` |
| Field After change action `AM_<FIELD>` (prefix community-reported) | `PROPAGATE` rule |
| `GMESSAGE`, `Errbox`, `GESECRAN` routines | `[L]ASTATUS = fmet this.ASETERROR(...)` |
| Mask fields `[M:ABV]FIELD` | Representation properties, `ASETATTRIBUTE` for hidden/disabled |

- **Hybrid development** (from Update 9): keep a Classic window but delegate CUD to a class
  (`ANOWRITE = 1` in `OUVRE`, `AINSERT`/`AUPDATE` from `CREATION`/`MODIF`). Sage warns this code
  will need rewriting later and does not support combined objects. Details in `classic-objects.md`.

## Gotchas

- Field-action code is lost when representations replace Classic windows: move rules into the class.
- `Infbox`, `Errbox`, `Qstbox`, `Mask`, `Affzo`, `Actzo`, `Grizo`, `Diszo`, `Effzo`, `mkstat` are
  deprecated for code running in V7 mode; keep them in Classic page code only.
- The `$ACTION` label of class scripts (pre-V11) is announced as deprecated in V12; some Sage how-to
  pages show `$METHODS` + `Case ACTION` for events. Use the split labels.
- Never create codes starting with W (generated) and never edit generated scripts.

See also: `v12-classes.md`, `v12-representations.md`, `classic-objects.md`, `screens-and-masks.md`,
`entry-points.md`, `common-patterns-v12.md`, `version-caveats.md`.

## Sources
- https://online-help.sagex3.com/erp/12/en-us/Content/V7DEV/developer-guide_representations.html
- https://online-help.sagex3.com/erp/12/en-us/Content/V7DEV/developer-guide_classes-events.html
- https://online-help.sagex3.com/erp/12/en-us/Content/V7DEV/developer-guide_classes-script.html
- https://online-help.sagex3.com/erp/12/en-us/Content/V7DEV/workbench-reference_representation-management.html
- https://online-help.sagex3.com/erp/12/en-us/Content/V7DEV/developer-guide_hybrid-development.html
- https://online-help.sagex3.com/erp/12/en-us/Content/V7DEV/4gl_x3script-keywords-glossary.html
- https://online-help.sagex3.com/erp/12/en-us/Content/FCT/GESACLA.htm
- https://online-help.sagex3.com/erp/12/en-us/Content/FCT/GESAOB.htm
- https://online-help.sagex3.com/erp/12/en-us/Content/FCT/GESAMK.htm
- https://online-help.sagex3.com/erp/12/en-us/Content/FCT/GESAPE.htm
- https://online-help.sagex3.com/erp/12/en-us/Content/MODEL/act_objet.htm
- https://www.greytrix.com/blogs/sagex3/2012/02/18/difference-between-x3-actions-apres-modif-vs-am-xxx/ (AM_ prefix, community-reported)

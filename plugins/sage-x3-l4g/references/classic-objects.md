# Classic objects: SPE scripts and object actions

The Classic (V6-style) object template still drives most standard functions in V12 (customers,
orders, invoices run as Classic pages). This file covers the object dictionary (GESAOB), the
`SPE<OBJ>` specific script with its `$ACTION` label, the documented actions per phase (creation,
modification, deletion, code change, entry transactions), how to refuse or abort with `OK` / `GOK`,
and hybrid objects that delegate CRUD to a V12 class. Field-level actions (`C_`, `AM_` labels) are in
`screens-and-masks.md`; entry points of standard processes are in `entry-points.md`.

## Contents
- [Object dictionary (GESAOB)](#object-dictionary-gesaob)
- [Scripts and call order](#scripts-and-call-order)
- [Action reference](#action-reference)
- [Refusing or aborting: OK, OKANU, GOK](#refusing-or-aborting-ok-okanu-gok)
- [Variables available in actions](#variables-available-in-actions)
- [Complete example: SPEBPC](#complete-example-spebpc)
- [Hybrid objects](#hybrid-objects)
- [Gotchas](#gotchas)
- [Sources](#sources)

## Object dictionary (GESAOB)

| Field | Notes |
|---|---|
| Object code (`ABREV`) | 1 to 3 alphanumeric characters (customers: `BPC`, function `GESBPC`) |
| Linked table (`NOMFIC`) | Main table managed by the object |
| Management type (`TYPGES`) | Simple (one record, left list), In grid (whole small table in one grid), Combined (N-1 fixed key parts, last part in a grid), Browser (extra left list) |
| Standard / Vertical / Specific script (`TRTSTD`, `CTLSPV`, `TRTSPE`) | Scripts holding the object's actions |
| Activity code (`CODACT`) | Makes the object optional |
| Selection options | Filters identified by a letter: upper case standard, **lower case specific** |
| Tables to open (`TABFIC`) | Extra tables opened and closed automatically with the object |

## Scripts and call order

The supervisor process `GOBJET` implements the template and calls these scripts:

| Script | Owner | Notes |
|---|---|---|
| `GES<OBJ>` | Generated at object validation | Never edit (rewritten) |
| `WO<OBJ>`, `WGO<OBJ>` | Generated at window validation | Never edit |
| `SUB<OBJ>` | Sage standard | Contains `$ACTION`; never modify |
| `SPV<OBJ>` | Vertical layer | Not delivered; must contain `$ACTION` |
| `SPE<OBJ>` | Specific / customer | Not delivered; must contain `$ACTION` |

For every action the call order is `SPE<OBJ>`, then `SPV<OBJ>` (skipped if `GPV = 1`), then
`SUB<OBJ>` (skipped if `GPE = 1`). So a specific action runs **before** the standard one:

- to replace the standard action, set `GPE = 1`;
- to run after the standard action, call it yourself, then set `GPE = 1`:

```l4g
$Y_AFTER_STANDARD
  Gosub ACTION From SUBXXX : # standard action first (SUBXXX = standard script of the object)
  # ... specific code here ...
  GPE = 1                  : # the supervisor must not call SUBXXX again
Return
```

Community-reported: the specific script field is not editable in object management and the object
actions are always looked up in `SPE` + object code (`SPEBPC` for customers); create that script
rather than renaming it.

Every specific object script contains the `$ACTION` label, which tests the `ACTION` variable:

```l4g
$ACTION
  Case ACTION
    When "VERIF_CRE" : Gosub Y_VERIF_CRE
    When "CREATION"  : Gosub Y_CREATION
  Endcase
Return
```

Actions are called by `Gosub ACTION From SPE<OBJ>`, so they share the local variables of the object
process: declare extra resources once in `OUVRE`.

## Action reference

Transaction = whether the update transaction is open when the action runs (per the action pages).

| Phase | Action | Transaction | When / use |
|---|---|---|---|
| Life cycle | `OUVRE` | No | Once, tables and screens open: declare `Local`/`Global` resources |
| | `FERME` | No | Leaving the object; no display instructions in Web mode |
| Display | `LIENS` | No | After reading a record: read extra tables, load fields and grid-bottom variables |
| | `STYLE` | No | After display: `Chgstl` styles |
| Creation | `RAZCRE` | No | New record started: default mask values (refresh with `Affzo`) |
| | `VERIF_CRE` | No | Before `Trbegin`: `OK = 0` refuses |
| | `INICRE` | Yes | `[F]` loaded from screens (+ CREUSR...), just before `Write`: last values, `GOK = 0` aborts |
| | `CREATION` | Yes | After a successful `Write`: extra updates, `GOK` |
| | `APRES_CRE` | No | After `Commit`: non-transactional updates, prints, workflow globals |
| | `AB_CREATION` | No | After `Rollback`: unlock symbols, reset globals |
| Modification | `AVANT_MOD` | No | First field changed, record locked: `OK = 0` refuses |
| | `VERIF_MOD` | No | Before `Trbegin`: `OK = 0` refuses |
| | `AVANT_MODFIC` | Yes | `Trbegin` done, record locked |
| | `INIMOD` | Yes | `[F]` loaded (+ UPDUSR...), just before `Rewrite`: `GOK = 0` aborts |
| | `MODIF` | Yes | After a successful `Rewrite`: extra updates, `GOK = 0` aborts |
| | `APRES_MOD` | No | After `Commit` |
| | `FIN_MOD` | No | After `Commit` and unlock (simple objects) |
| | `AB_MODIF` | No | After `Rollback` |
| Deletion | `AV_VERF_ANU` | No | Before dictionary link checks |
| | `AP_VERF_ANU` | No | After link checks: `OKANU = 0` refuses |
| | `VERF_ANU` | No | Before the transaction: `OK = 0` refuses; `CODE` = key |
| | `AV_ANNULE` | Yes | Transaction start: extra updates, `GOK = 0` aborts |
| | `ANNULE` | Yes | Per deleted record: table `NOMFIC` open as `[ANUL]`, criterion `CRITERE`, `GOK` |
| | `AP_ANNULE` | No | After `Commit` |
| Code change | `VERF_CHG` | No | `OK = 0` refuses; `OCODE` / `NCODE` old and new key |
| | `CHANGE` | Yes | Table open as `[CHGT]`, key name in `CLEPRIM`, `GOK` |
| | `AP_CHANGE` | No | After `Commit` |
| Entry transactions | `DEFTRANS` | No | Start of window analysis: `OK = 0` stops, message in `GMESSAGE` |
| | `VARIANTE` | No | Per window: `OK = 0` hides that variant |
| | `SETTRANS` | No | After the window is chosen: read the entry transaction setup |
| Other | `RAZDUP` | No | Duplication detected: default values |
| | `ABANDON` | No | Creation, duplication or modification aborted |
| | `APRES_MODIF` | No | After **any field** modification (`COUZON`, `COUIND`); not the end of modification |

`LIENS0` / `LIENS2` (before/after reading a group of records) belong to grid and combined objects.
The full alphabetical list is on the "Actions (OBJect)" page in the sources.

## Refusing or aborting: OK, OKANU, GOK

- **Before the transaction** (`VERIF_CRE`, `VERIF_MOD`, `AVANT_MOD`, `VERF_ANU`, `VERF_CHG`,
  `DEFTRANS`, `VARIANTE`): set `OK = 0`. `AP_VERF_ANU` uses `OKANU = 0`.
- **Inside the transaction** (`INICRE`, `CREATION`, `AVANT_MODFIC`, `INIMOD`, `MODIF`, `AV_ANNULE`,
  `ANNULE`, `CHANGE`): set `GOK = 0`; the supervisor rolls back and calls `AB_CREATION` / `AB_MODIF`.
  A negative `GOK` means "locked by another user": rollback and retry, up to `GROLLBACK` attempts,
  then the user is asked whether to continue.
- Never `Trbegin`, `Commit` or `Rollback` in these actions: the template owns the transaction. Code
  shared with batch callers uses the `adxlog` idiom of `database.md`.
- Message to the user: the `DEFTRANS` page pairs `OK = 0` with `GMESSAGE`; Sage's hybrid guide sets
  `GMESSAGE`, `GOK = 0` and `GERR = 1` "to retrieve the error in the Classic UI".

## Variables available in actions

| Variable | Meaning |
|---|---|
| `ACTION` | Code of the action being called |
| `OK`, `OKANU`, `GOK` | Refuse / abort flags (above) |
| `GPE`, `GPV` | Skip the standard / vertical action |
| `GCONSULT` | Set before calling the object: 0 rights apply, 1 no modification, 2 no modification, no record change, no left list |
| `GMESSAGE`, `GERR` | Message and error flag returned to the Classic UI |
| `CODE`, `SUPP` | Key being deleted; first key element when the key has several parts (`ANNULE`) |
| `COUZON`, `COUIND` | Current field name and grid index (`APRES_MODIF`) |
| `GUSER` | Current X3 user code (global variable, documented on ADC_GESUSER.htm) |
| `[F:<abv>]`, `[M:<mask>]` | Main table buffer (filled from screens before `INICRE`/`INIMOD`) and screen classes |

## Complete example: SPEBPC

Customer object `BPC` (table `BPCUSTOMER [BPC]`). Custom tables: `YBPCLOG [YBL]` (audit) and
`YCONTRACT [YCT]` with index `YCT1` on `BPCNUM`. Messages 1 and 2 of specific chapter 160.

```l4g
# SPEBPC - specific actions of the Classic customer object
$ACTION
  Case ACTION
    When "OUVRE"    : Gosub Y_OUVRE
    When "VERF_ANU" : Gosub Y_VERF_ANU
    When "CREATION" : Gosub Y_LOG
    When "MODIF"    : Gosub Y_LOG
  Endcase
Return

$Y_OUVRE
  # Called once; object tables already open. Extra tables live as long as the object.
  Local File YBPCLOG [YBL], YCONTRACT [YCT]
Return

$Y_VERF_ANU
  # No transaction yet. CODE holds the key of the customer being deleted.
  Read [YCT]YCT1 = CODE
  If fstat = 0
    GMESSAGE = mess(2, 160, 1) : # "Customer still has contracts"
    OK = 0                     : # refuse the deletion
  Endif
Return

$Y_LOG
  # Inside the supervisor transaction; [F:BPC] holds the record just written
  Raz [F:YBL]
  [F:YBL]BPCNUM  = [F:BPC]BPCNUM
  [F:YBL]YACTION = ACTION
  [F:YBL]YUSR    = GUSER
  [F:YBL]YDAT    = date$
  Write [YBL]
  If fstat
    GMESSAGE = mess(1, 160, 1)
    GOK = 0 : GERR = 1         : # supervisor rolls back the customer update
  Endif
Return
```

## Hybrid objects

Hybrid development (available from Update 9) keeps a Classic window but delegates create, update and
delete to a V12 class (`v12-classes.md`):

- `OUVRE`: `ANOWRITE = 1` disables the Classic writes; declare `Global Instance ... Using C_<CLASS>`
  (global because deletion runs in a subprogram).
- `LIENS`: the supervisor still reads the screens; instantiate and `fmet INST.AREAD(key)`.
- `RAZCRE`: `NewInstance`, `fmet INST.AINIT()`, `SetInstance [M:<mask>] With INST`, `Affzo`.
- `CREATION` / `MODIF`: `SetInstance INST With [F:<abv>]`, then `fmet INST.AINSERT()` /
  `AUPDATE()`; on `>= [V]CST_AERROR` set `GMESSAGE`, `GOK = 0 : GERR = 1`.
- `FERME`: `FreeGroup` the instance, then `Kill` it.

Sage warns that hybrid code will have to be rewritten for future servers, that field actions are lost
when representations replace Classic windows, and that combined objects are not supported.

## Gotchas

- `APRES_MODIF` fires after each field change, not after saving; the end of a modification is
  `APRES_MOD` (after commit) or `FIN_MOD` (after unlock).
- `OK` before the transaction, `GOK` inside it: use the flag documented for the action you hook.
- Without `GPE = 1`, the standard action still runs after yours: decide explicitly.
- The screens-to-`[F:<abv>]` transfer is documented at `INICRE` / `INIMOD`; before that, test the
  entered values in `[M:...]`.
- Do not modify `SUB<OBJ>` scripts: patches overwrite them. Protect specific dictionary changes with
  X/Y/Z activity codes (`personalisation-activity.md`).

See also: `screens-and-masks.md`, `entry-points.md`, `v12-classes-representations.md`,
`database.md`, `conventions-and-naming.md`.

## Sources
- https://online-help.sagex3.com/erp/12/en-us/Content/FCT/GESAOB.htm
- https://online-help.sagex3.com/erp/12/en-us/Content/MODEL/fon_objet.htm
- https://online-help.sagex3.com/erp/12/en-us/Content/MODEL/act_objet.htm
- https://online-help.sagex3.com/erp/12/en-us/Content/MODEL/act_creation.htm
- https://online-help.sagex3.com/erp/12/en-us/Content/MODEL/act_modif.htm
- https://online-help.sagex3.com/erp/12/en-us/Content/MODEL/act_suppression.htm
- https://online-help.sagex3.com/erp/12/en-us/Content/MODEL/act_changement.htm
- https://online-help.sagex3.com/erp/12/en-us/Content/MODEL/act_transac.htm
- https://online-help.sagex3.com/erp/12/en-us/Content/MODEL/VERIF_CRE.htm (and the INICRE, CREATION,
  VERIF_MOD, INIMOD, MODIF, LIENS, VERF_ANU, AP_VERF_ANU, ANNULE, CHANGE, DEFTRANS, OUVRE, FERME pages
  in the same folder)
- https://online-help.sagex3.com/erp/12/en-us/Content/V7DEV/developer-guide_hybrid-development.html
- https://online-help.sagex3.com/erp/12/en-us/Content/OBJ/ADC_GESUSER.htm (GUSER)
- https://communityhub.sage.com/sage-global-solutions/sage_x3/f/general-discussion/247389/management-of-custom-fields
  (community-reported: SPE + object code)

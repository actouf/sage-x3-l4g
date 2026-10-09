# V12 representations: dictionary, facets, scripts, events

A representation is the user-interface (and REST) view of a class: which properties are shown in
which facet, how the page is organised, which links are offered, and which extra UI-only properties,
methods and scripts exist. Read this when you create or customise a representation, write a
representation script, or need the query events. Class-level code (rules, CRUD events, `ASETERROR`)
is in `v12-classes.md`; REST URLs are in `web-services-rest.md`.

## Contents
- [Representation, class and facets](#representation-class-and-facets)
- [Representation dictionary (GESASW)](#representation-dictionary-gesasw)
- [Representation scripts](#representation-scripts)
- [Representation events](#representation-events)
- [Query events](#query-events)
- [Links](#links)
- [Example: specific representation script](#example-specific-representation-script)
- [Exposure in REST](#exposure-in-rest)
- [Gotchas](#gotchas)
- [Sources](#sources)

## Representation, class and facets

- A representation is always associated with one class. At run time the class instance is a **child**
  of the representation instance, under the name given in the *Instance* field: if representation
  `CUSTOMER` has class `CUSTOMER` with instance `CUST`, then `MYREP.CUST.NAME` is a class property and
  `MYREP.DISPLAYED_BALANCE` a representation-only (UI) property.
- A **facet** is a use case of the representation, i.e. a restricted view:

| Facet | URL suffix | Use |
|---|---|---|
| Query | `$query` | List with sorting, filtering, paging; entry point of an activity |
| Details | `$details` | Display of one record |
| Edit | `$edit` | Creation or modification (works on a working copy) |
| Lookup | `$lookup` | Selection pop-up when a reference must be chosen |
| Summary | `$summary` | Summarised view of a record |

Other technical facets exist but do not appear in the dictionary. A request selects the facet with
`representation=<REP>.$<facet>`.

## Representation dictionary (GESASW)

The workbench reference gives function code GESASW for *Representations* (there is no
`FCT/GESASW.htm` page in the online help). Sections: Header, General, Properties, Methods,
Organization, Displayed properties, Links, Menus.

| Field / grid | Notes |
|---|---|
| Class code, Instance | Mandatory class; Instance names the class child instance |
| Activity code | X/Y/Z protects a specific representation during patches |
| Authorization (function) | Checked against the user's function profile. **Empty = available to every user who can reach the endpoint** |
| Sage X3 function | Classic function opened when a record is modified from `$details` and no `$edit` facet exists |
| Type | Desktop or Mobile |
| Facets, Behaviors | Facets supported; built-in behaviours (create, update, delete, duplicate, Excel/Word/PDF, mail merge) |
| Collections | Redeclare a class collection only to change it; Insertion/Deletion/Sort/Addition can be cleared but not enabled beyond the class |
| Scripts | Ordered list of scripts (see below) |
| Properties / Methods | Representation-only properties and methods. Only stateful methods: operations exist only on classes. *Return* is the type of `ARET_VALUE` |
| Organization | Page, sections, blocks (codes up to 12 upper-case letters/digits); Filters grid (Mandatory, Default, Option condition, Error message); Sort order (index of the main table, or a descriptor such as `-FIELD1+FIELD2`) |
| Displayed properties | Alias (up to 30 chars, upper case, digits, underscore; first char a letter), dot path (`SORDER.LINE.ITEMCODE`), collection, block, order, *Filter P*, *Entry P*, and per facet: present, initial state Visible/Invisible, and *Input* for Edit |

*Validation* generates the representation into `R_<repr>.stc` plus the UI/CRUD glue scripts; never
edit them. *Option > Global validation* also validates the class and its child classes. A
representation is not usable until validated.

## Representation scripts

- Naming (workbench reference): `<repr>_Ryyyy`, yyyy = `STD` for the first standard script, starting
  with `VER` for vertical and `SPE` for specific scripts; the default standard script is
  `<REP>_RSTD` with rank 1000. The representation events page says ranks that are multiples of 100
  are reserved for standard extensions (the class page says 1000) and that specific/vertical script
  names should start with X, Y or Z. Use e.g. `YCUSTLOG_RSPE` with a rank such as 1050.
- Labels and dispatch variables are those of class scripts (V11 split): `$EVENTS` (`CURPTH`,
  `AEVENT`), `$PROPERTIES` (`CURPRO`, `ARULE`), `$METHODS` (`AMETHOD`, result in `[L]ARET_VALUE`).
  No `$OPERATIONS`: representations have no operations. Older Sage pages still show `$METHODS` with
  `Case ACTION`; do not copy that layout.
- In a representation script paths include the class instance: `CURPTH` is `""` for the
  representation itself, `"YCL"` for the class, `"YCL.LINES"` for a child; `CURPRO` is
  `"YCL.YAMOUNT"`. In a rule, `this` is the instance holding the property (the class instance for
  `"YCL.YAMOUNT"`), and the representation is reachable through `this.APARENT`.
- There is no mask: no `[M:...]`, no `Affzo`/`Infbox`. UI state changes go through
  `ASETATTRIBUTE` and the link methods below.

## Representation events

- Every class event of `v12-classes.md` is also called in representation scripts (CRUD events only if
  the class is Persistent or Interface), plus the constructor events `C_<CLASS>` and `R_<REP>`.
- Nesting adds one level: for a "before" event the representation scripts run (`CURPTH` empty), then
  the class scripts, then the representation scripts again with `CURPTH = "DOC"`, and so on down the
  lines; "after" events are nested in reverse. For INIT and CONTROL, representation scripts run first,
  then the main class, then the child classes.
- Put UI-only logic (recomputing a displayed total on every change) in the representation script:
  Sage notes that the same code in the class would run repeatedly in service mode.

## Query events

Query events run when the `$query` facet is requested. There is no working copy (`this` is not
available) except in `AQUERY_TRANS_AFTER`. `PQRY` is an instance of class `AQUERY` holding the query;
`PQRY.QWHERE` is the filter in SData syntax. The cursor uses the abbreviation `[LNK_]`.

| Event | Typical use |
|---|---|
| `AQUERY_DECODE_CRITERIA_AFTER` | Add filterable columns (`NBPRO`, `TBPRO`, `TBPTH`, `TBFIL`, `TBTYP` arrays) |
| `AQUERY_PRIMARYKEYS_AFTER` | Set the order keys in `ASTDKEY` (`;`-separated); mandatory for interface classes |
| `AQUERY_OPEN_AFTER` | Open extra tables; for an interface class open everything yourself |
| `AQUERY_CRITERIA_AFTER` | Add conditions to `PQRY.QWHERE` |
| `AQUERY_JOIN_AFTER` | Replace or (interface class) declare the `Link ... As [LNK_]` cursor |
| `AQUERY_TRANS_AFTER` | Per returned line: fill computed properties of `this.<INSTANCE>`; set `[L]ASTATUS = [V]CST_AERROR` to drop the line |
| `AQUERY_CLOSE_AFTER` | Query closed |

## Links

- Levels: page (right panel), record (right panel on details/edit, every line on query), property,
  collection line, collection.
- Automatic links come from data types and from the CRUD behaviours; they can be deactivated or
  replaced, not edited. Manual link types: Representation (with an action such as Display details or
  Display list; not callable from an edit facet), Method (edit facet only), Operation (optionally
  *Asynchronous*), Sage X3 Classic function, URL, Crystal Report (report code from GESARP).
- Standard link codes: fields `ADETAILS`, `ALOOKUP`, `AQUERY`; record `ADETAILS`, `AEDIT`, `ADELETE`;
  page `ASAVE`, `AABORT`, `ACREATE`, `AQUERY`.
- After a patch removes properties, some links are flagged *Invalid*: fix and revalidate.
- At run time, `fmet this.ASETLINKDISABLE(CODE, [V]CST_AFFLNKREC)` / `ASETLINKENABLE` (or
  `CST_AFFLNKPAG` for page links) toggle links; they work in the Details facet only.
- `fmet this.ASETATTRIBUTE(PROPERTY, "$isHidden" | "$isDisabled" | "$isMandatory", VALUE)` changes
  property state; only properties enterable in Edit can be enabled/disabled, and *Technical* fields
  never appear.

## Example: specific representation script

Representation `YCUSTLOG` on class `YCUSTLOG` (instance `YCL`), with a representation-only property
`YBIG` (local menu 1, No/Yes) and script line Specific / `YCUSTLOG_RSPE` / rank 1050.

```l4g
# YCUSTLOG_RSPE - specific script of representation YCUSTLOG
$EVENTS
  Case [L]CURPTH
    When ""
      Case [L]AEVENT
        When "AQUERY_CRITERIA_AFTER" : Gosub Y_QRY_CRITERIA
        When "AREAD_AFTER"           : Gosub Y_READ_AFTER
      Endcase
  Endcase
Return

$PROPERTIES
  Case [L]CURPRO
    When "YCL.YAMOUNT" : Gosub Y_PROP_AMOUNT
  Endcase
Return

$Y_QRY_CRITERIA
  # Query facet shows only open logs (YSTATUS = 1); no instance here
  If PQRY.QWHERE <> ""
    PQRY.QWHERE = "(" + PQRY.QWHERE + ") and YSTATUS eq 1"
  Else
    PQRY.QWHERE = "YSTATUS eq 1"
  Endif
Return

$Y_READ_AFTER
  # this = representation instance, this.YCL = class instance (Details facet)
  If this.YCL.YSTATUS = 2
    [L]ASTATUS = fmet this.ASETLINKDISABLE("AEDIT", [V]CST_AFFLNKREC)
    [L]ASTATUS = fmet this.ASETLINKDISABLE("ADELETE", [V]CST_AFFLNKREC)
  Endif
Return

$Y_PROP_AMOUNT
  Case [L]ARULE
    When "PROPAGATE"
      # this = class instance YCL; this.APARENT = representation instance
      this.APARENT.YBIG = 1 + (this.YAMOUNT >= 10000)
  Endcase
Return
```

## Exposure in REST

Syracuse serves classes through their representations and facets: the same dictionary definition
drives the browser pages and the REST/JSON requests (`representation=<REP>.$<facet>`). Request URLs, paging and authentication are in `web-services-rest.md`; integration choices in
`web-services-integration.md`.

## Gotchas

- An empty *Authorization* field exposes the representation to every user of the endpoint.
- Business rules belong in the class, not in the representation: REST and import callers that use
  the class without this representation would bypass them.
- Representation properties are not persisted: compute them in `AREAD_AFTER`, `PROPAGATE` or
  `AQUERY_TRANS_AFTER`.
- `ASETLINKDISABLE` has no effect in the Edit facet.
- Query events have no `this` (except `AQUERY_TRANS_AFTER`): work on `PQRY` and the `[LNK_]` cursor.
- Revalidate the representation (or run a global validation) after changing its class.

See also: `v12-classes.md`, `v12-classes-representations.md`, `web-services-rest.md`,
`security-permissions.md`.

## Sources
- https://online-help.sagex3.com/erp/12/en-us/Content/V7DEV/developer-guide_representations.html
- https://online-help.sagex3.com/erp/12/en-us/Content/V7DEV/developer-guide_representations-events.html
- https://online-help.sagex3.com/erp/12/en-us/Content/V7DEV/workbench-reference_representation-management.html
- https://online-help.sagex3.com/erp/12/en-us/Content/V7DEV/developer-guide_classes-events.html
- https://online-help.sagex3.com/erp/12/en-us/Content/V7DEV/developer-guide_event-aquery_open_after.html
- https://online-help.sagex3.com/erp/12/en-us/Content/V7DEV/developer-guide_event-aquery_criteria_after.html
- https://online-help.sagex3.com/erp/12/en-us/Content/V7DEV/developer-guide_event-aquery_join_after.html
- https://online-help.sagex3.com/erp/12/en-us/Content/V7DEV/developer-guide_event-aquery_primarykeys_after.html
- https://online-help.sagex3.com/erp/12/en-us/Content/V7DEV/developer-guide_event-aquery_decode_criteria_after.html
- https://online-help.sagex3.com/erp/12/en-us/Content/V7DEV/developer-guide_event-aquery_trans_after.html
- https://online-help.sagex3.com/erp/12/en-us/Content/V7DEV/how-to_how-to-crud-3-levels.html
- https://online-help.sagex3.com/erp/12/en-us/Content/V7DEV/4gl_instance.html

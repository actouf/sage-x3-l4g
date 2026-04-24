# Screens, Masks, and Field Actions

Screen logic is what most X3 customization actually is. This covers the Classic (V6) mask model — V7 Representations reuse the same scripts under the hood.

## Masks — the screen data structure

A **mask** is the on-screen form; its underlying data class is `[M:MSKNAM]`. You declare it with `Mask`, then interact with it like a record:

```l4g
Local Mask GESBPC [M:BPC]            # open the customer screen mask
[M:BPC]BPCNUM = "BP001"               # assign a field value programmatically
```

The mask class holds whatever the user has typed (or what you've pushed programmatically) — **not yet committed to the database**.

## The transfer idiom: [F] ↔ [M]

A common pattern: copy an entire database record into the mask for display, or pull the mask values into the record before writing.

```l4g
[F:BPC] = [M:BPC]                    # mask → record (before a write)
[M:BPC] = [F:BPC]                    # record → mask (after a read)
```

This works because the field names are aligned by convention. If they diverge, you have to copy field by field.

## Entry transactions and action calls

X3 screens have **standard action points** — named hooks the engine invokes at specific moments. You attach your code by naming the action in the screen's script:

| Action | When it fires |
|--------|---------------|
| `LIENS` | Opening the screen, after the mask is built |
| `AVBAS` | Just before `Save` — validate before write |
| `APBAS` | Just after `Save` — post-write processing |
| `ANNUL` | On `Cancel` — cleanup or undo |
| `DEBSAI` | Before the screen starts accepting input |
| `FINSAI` | After input ends, before control returns |

Custom action names can be added; look for them in the entry transaction definition (GESAUT / Object management).

### Example — validating a field on save

```l4g
$AVBAS
    If [M:BPC]BPCCRN = ""
        Call ECRAN_TRACE("SIREN obligatoire", 2) From GESECRAN
        Gosub ECR_CHAMP_ERR                 # flag the field in error
        GOK = 0                             # block the save
    Endif
Return
```

`GOK = 0` tells the supervisor the operation failed; the screen stays open.

## Actions on fields ("actions champs")

Fields have three main hooks: **Entry**, **Exit (control)**, **After update**.

- **Entry (E)** — runs when the cursor enters the field. Typical use: pre-fill a default, enable/disable related fields.
- **Control (Sortie champ / C)** — runs when the cursor leaves. Typical use: validate the value, set a message.
- **Button / Click** — tied to a specific UI element.

You define which script to call in the field dictionary (GESAFE). The action label lives in a `.trt` or `.src` file:

```l4g
##############################################################
# ZBPC_CTRL_CRN — control action on customer SIREN field
##############################################################
$CTRL_CRN
    If [M:BPC]BPCCRN <> ""
        If len([M:BPC]BPCCRN - "") <> 9
            Call ECRAN_TRACE("SIREN doit faire 9 chiffres", 2) From GESECRAN
            GOK = 0
        Endif
    Endif
Return
```

## Table-type screens (grids)

When a mask contains a grid (`En tableau` object), X3 calls `LIENS2` (or a custom action) to populate it. The convention:

```l4g
$LIENS2
    Raz [M:ZTK0]                    # clear grid rows
    Local Integer I
    I = 0
    For [YSRC] Order By Key KEYIDX
        Incr I
        [M:ZTK0]COL1(I) = [F:YSRC]NAME
        [M:ZTK0]COL2(I) = [F:YSRC]QTY
        If I >= maxtab([M:ZTK0])     # don't overflow the grid's max rows
            Exitfor
        Endif
    Next
    [M:ZTK0]NBLIG = I                # tell the UI how many rows to display
Return
```

`[M:ZTK0]` is the grid's class; `NBLIG` is the row count the renderer reads.

## User-facing messages

### Infbox, Errbox, Question

```l4g
Infbox "Opération terminée."                         # informational popup
Errbox "Erreur de lecture."                          # error popup (red)
Question "Confirmer la suppression ?", [L]REPONSE     # [L]REPONSE = 1 if yes, 0 if no
```

### Traces and logs

```l4g
Call ECR_TRACE("Message", 1) From GESECRAN           # adds a line to the current trace
Call ECRAN_TRACE("Message", 2) From GESECRAN         # bolder / level-2 trace
```

### Localized messages via `mess()`

Never hardcode user-facing strings — use the message dictionary:

```l4g
Infbox mess(17, 107, 1)              # message #17, chapter 107, language index 1
```

Standard X3 messages live in chapters 0–199 (reserved); custom messages should live in chapter `5xx` and above.

## Opening another screen (`Call` pattern for screens)

```l4g
Call OUVRE_MASK("GESBPC", [L]HDL) From MASKOUV       # open by name
Call LANCE("Z_MY_FUNC") From LANCE                   # launch a function
```

## `maxtab`, `rowcount`, and sizing grids

- `maxtab([M:CLASSNAME])` — maximum number of rows the grid class allows
- `nbzon([F:BPC])` — number of fields in a table/class
- `size([F:BPC]BPCNAM)` — size of a single field

## Common gotchas

- **Forgetting `Raz [M:...]`** before repopulating a grid leaves ghost rows in display.
- **Writing to `[F:...]` instead of `[M:...]`** in an entry action — nothing shows on screen because the user-facing buffer wasn't touched.
- **Setting `GOK = 0` without a user message** — the save fails silently with no explanation.
- **Calling `Commit` from an action script** — actions run inside the supervisor's transaction; commit there and you break transactional integrity across the rest of the save path. Let the supervisor commit.
- **Overwriting `NBLIG`** to a value larger than filled rows — grid shows garbage after the last real row.

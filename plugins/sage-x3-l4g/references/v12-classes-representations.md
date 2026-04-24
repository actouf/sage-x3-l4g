# V12 — Classes, Representations, and Pages

V12 (and V7+) introduced a modern layer on top of the Classic engine: **classes** for reusable code and **representations** + **pages** for UI. Classic `Subprog`/`Funprog` and `Mask`/`Inpbox` still run — you just have better options now.

This file is the V12 idiom. **Everything here applies to V7+ as well** — class syntax, representations, and Syracuse semantics were introduced in V7 and are unchanged in V12 at the L4G level. REST endpoint auto-generation is the V12-specific addition. For legacy screens still shipping in V12, see `screens-and-masks.md`.

## The V12 layer cake

| Layer | Classic (V6) | V12 / Syracuse |
|-------|--------------|----------------|
| UI | Masks (`Mask`, `Inpbox`) | Representations + Pages (HTML5, Syracuse) |
| Business code | `Subprog`, `Funprog`, `.src` / `.trt` | Classes + Methods (still `.src`) |
| API surface | Internal `Call … From …` | REST (`/api/x3/erp/...`) + classic scripts |
| Data access | `[F:ABV]`, `Read`, `For` | Same — classes wrap `[F:...]` but primitives are unchanged |

You'll still write `Read [BPC]BPCNUM0 = …` in a V12 class. What changes is how that logic is **organized** and **exposed**.

## Classes

A class groups fields, methods, and state in a single `.src` file. File = class.

```l4g
##############################################################
# YCUSTOMER — class wrapping customer-related business logic
##############################################################
Class YCUSTOMER

    Public Char    CUSID(20)
    Public Char    CUSNAM(60)
    Public Decimal CREDIT
    Private Integer LOADED

    Public Method Init(ID)
    Value Char ID()
        this.CUSID = ID
        this.LOADED = 0
    End

    Public Method Load()
        Local File BPCUSTOMER [BPC]
        Read [BPC]BPCNUM0 = this.CUSID
        If fstat
            End 1                        # error
        Endif
        this.CUSNAM = [F:BPC]BPCNAM(0)
        this.CREDIT = [F:BPC]CDTUNL
        this.LOADED = 1
    End 0

    Public Funprog IsLoaded()
    End this.LOADED

Endclass
```

### Accessing the class

```l4g
Local YCUSTOMER C
C.Init("BP001")
If C.Load() = 0
    Infbox C.CUSNAM - " limit=" + num$(C.CREDIT)
Endif
```

### Visibility modifiers

| Keyword | Meaning |
|---------|---------|
| `Public` | Accessible from outside the class |
| `Private` | Only this class |
| `Protected` | This class and subclasses |

`this` inside a method refers to the current instance. Omit it and bare `CUSID` means a local — prefer `this.CUSID` when touching an instance field.

### Inheritance

```l4g
Class YVIPCUSTOMER Extends YCUSTOMER
    Public Decimal BONUS

    Public Method Init(ID)
    Value Char ID()
        # Call parent
        super.Init(ID)
        this.BONUS = 0
    End
Endclass
```

### Constructor / destructor

V12 runs `Init` only if you call it explicitly (there's no implicit auto-ctor). Pattern: expose a public `Init` method and call it right after instantiation. For teardown, provide an explicit `Dispose` method and call it before the variable goes out of scope.

## Representations

A **representation** is the V12 equivalent of a Classic mask, but metadata-driven and rendered by Syracuse (HTML5 client). You define it via **Administration → Usage → Screens → Representations** (`GESAOT`).

A representation groups:
- **Pages** — what the user sees (form, list, detail)
- **Properties** — fields (typed, validated, translated)
- **Actions** — buttons / server-side entry points
- **Collections** — child grids, expandable sections

### Calling a class method as an action

In the representation editor, each action points to a script method:

```
action name:   validate
script:        YMYSCRIPT.YValidate
```

Maps to:

```l4g
Funprog YValidate()
    If [M:...]FIELD = ""
        End 1          # failure — blocks save
    Endif
End 0
```

The HTTP status / UI feedback comes from the return value (0 = OK).

### Representation script (`.src`) structure

```l4g
##############################################################
# YMY_REPR — script backing representation YMYREPR
##############################################################

$ACTION_VALIDATE
    # runs when the "Validate" button is pressed in the UI
    If [M:YREPR]AMT < 0
        Call ECRAN_TRACE("Montant négatif", 2) From GESECRAN
        GOK = 0
        Return
    Endif
Return

$ACTION_SUBMIT
    # publish to an external system
    Call YPUBLISH([M:YREPR]ORDERID) From YWEBSERVICES
Return
```

You still use `[M:REPNAME]` for the UI-bound buffer — the representation generates the same mask class under the hood.

## Pages

Pages describe layout and user flow inside a representation. They come in types:

| Page type | Purpose |
|-----------|---------|
| `List` | Grid view, usually the landing page for a business object |
| `Detail` | Single-record form |
| `Wizard` | Step-by-step sequence |
| `Summary` | Read-only dashboard |
| `Picker` | Modal for selection in another page |

Pages are declared as metadata, not code. Your L4G code only reacts to their events (entry, exit, action).

## Business objects

A **business object** ties it all together: a main table, one or more representations, classes that drive behavior, and REST endpoints auto-generated for CRUD. V12 ships standard objects like `BPC`, `ITM`, `SOH` — custom objects are declared in `GESAOB` with Y/Z prefix.

Standard lifecycle events you can hook:

| Event | Fires |
|-------|-------|
| `afterLoad` | After the record is loaded into the representation |
| `beforeSave` | Before commit |
| `afterSave` | After commit |
| `onInit` | When a new record is started |
| `onValidate` | On explicit validate action |

All map to named `$` labels in the representation's script.

## Dependency injection via classes

Instead of `Call … From YSCRIPT`, instantiate a class directly:

```l4g
Local YCUSTOMER CUS
CUS.Init("BP001")
If CUS.Load() = 0
    [M:YMYREPR]CUSNAM = CUS.CUSNAM
Endif
```

This is the V12-preferred style when the logic has state or needs multiple calls — it localizes the state in the object rather than in globals.

## updtick — optimistic concurrency

V12 standard tables have an `UPDTICK` column (incremented on every write). The UI reads it on load and passes it back on save; the engine rejects the save if the row changed meanwhile.

In custom code, when you do your own `Readlock` / `Rewrite` you can either:
- Rely on the built-in lock (pessimistic, short transaction), or
- Use `UPDTICK` in the `Where` clause of `Update`:

```l4g
Update YMYTABLE Where KEY = [L]KEY And UPDTICK = [L]TICK With VALUE = [L]NEWVAL, UPDTICK = UPDTICK + 1
If [S]adxuprec = 0
    Errbox mess(504, 501, 1)             # "Record changed by another user"
Endif
```

## REST API surface

Every V12 business object gets a generated REST API under `/api/x3/erp/<folder>/<object>`. Custom objects get it too, provided the representation is published.

| HTTP verb | Effect |
|-----------|--------|
| `GET /api/x3/erp/SEED/YMYOBJ` | List |
| `GET /api/x3/erp/SEED/YMYOBJ('KEY')` | Read |
| `POST /api/x3/erp/SEED/YMYOBJ` | Create |
| `PATCH /api/x3/erp/SEED/YMYOBJ('KEY')` | Update |
| `DELETE /api/x3/erp/SEED/YMYOBJ('KEY')` | Delete |

Authentication via Syracuse token. See `web-services-integration.md` for calling patterns.

## Syracuse service script

For logic exposed only as an API (no UI), a **service** representation gives you an endpoint backed by a class method:

```l4g
##############################################################
# YTRANSFER service — POST /api/x3/erp/SEED/YTRANSFER
##############################################################
Class YTRANSFER

    Public Char    FROM_ACC(20)
    Public Char    TO_ACC(20)
    Public Decimal AMOUNT
    Public Char    RESULT(20)            # returned to caller

    Public Method Execute()
        Local Integer IF_TRANS
        If adxlog
            Trbegin [ACC]
            IF_TRANS = 0
        Else
            IF_TRANS = 1
        Endif

        Update ACCOUNT Where CODE = this.FROM_ACC With BALANCE = BALANCE - this.AMOUNT
        If fstat
            If IF_TRANS = 0 : Rollback : Endif
            this.RESULT = "ERROR_DEBIT"
            End 1
        Endif

        Update ACCOUNT Where CODE = this.TO_ACC With BALANCE = BALANCE + this.AMOUNT
        If fstat
            If IF_TRANS = 0 : Rollback : Endif
            this.RESULT = "ERROR_CREDIT"
            End 1
        Endif

        If IF_TRANS = 0 : Commit : Endif
        this.RESULT = "OK"
    End 0

Endclass
```

The caller POSTs JSON `{ "FROM_ACC":"A1", "TO_ACC":"A2", "AMOUNT":100 }`, Syracuse deserializes it into the class, calls `Execute()`, serializes the instance back as JSON.

## Migration checklist — Classic → V12

When lifting a legacy feature to V12:

1. Wrap the logic in a class; keep database access primitives (`Read`, `For`) unchanged.
2. Replace the `Mask` + `Inpbox` screen with a representation + page, keeping the same backing class.
3. Move `$LIENS`, `$AVBAS`, `$APBAS` labels into named actions on the representation.
4. Publish a REST endpoint if the feature needs programmatic access.
5. Add `UPDTICK` handling if you do custom `Readlock`/`Rewrite`.
6. Stop using Classic `Infbox` / `Errbox` for server logic — use method return codes and let the UI surface the error via the representation's toast layer.

## Gotchas

- **Class methods don't auto-open tables.** Declare `Local File … [XXX]` inside the method body just like a `Subprog`.
- **`this` is sometimes implicit**, but being explicit prevents shadowing by locals — always write `this.FIELD` when touching instance state.
- **Circular class refs** (A has YB, B has YA) compile but instantiation order matters — initialize lazily.
- **Representations cache aggressively.** After a script change, force a "Validate representation" in the editor or the runtime keeps the old version.
- **REST endpoint 401** usually means the Syracuse user lacks ACL on the representation — check user role first, not the code.
- **`Infbox` inside a service method** appears nowhere for REST callers; use the return value or a response field.
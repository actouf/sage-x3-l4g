# REST endpoints — publishing and consuming, SData

The V12-native integration surface. Every published representation gets a generated REST API; consuming external REST APIs uses HTTP helpers and JSON parsing.

For SOAP / AWS publishing and SOAP client patterns, see `web-services-soap.md`. For cross-cutting concerns (file exchange, TLS, integration logs, the protocol comparison), see `web-services-integration.md`.

## Publishing a REST endpoint (V12)

The V12 way. Every published **representation** (see `v12-classes-representations.md`) gets a generated REST API under:

```
GET/POST/PATCH/DELETE  /api/x3/erp/<folder>/<object>
```

### Service (non-persistent) endpoint

For operations that aren't CRUD on a table — a computation, a transaction, a validation:

```l4g
##############################################################
# YSRV_CHECK_STOCK — REST service class
# Exposed at POST /api/x3/erp/SEED/YSRV_CHECK_STOCK
##############################################################
Class YSRV_CHECK_STOCK

    Public Char    ITMREF(30)
    Public Decimal QTY                   # out
    Public Char    STATUS(20)            # out

    Public Method Execute()
        Local File ITMMASTER [ITM], STOCK [STO]

        Read [ITM]ITMREF0 = this.ITMREF
        If fstat
            this.STATUS = "KO_UNKNOWN_ITEM"
            this.QTY = 0
            End 0
        Endif

        this.QTY = 0
        For [STO] Where ITMREF = this.ITMREF
            this.QTY += [F:STO]QTYSTU
        Next
        this.STATUS = "OK"
    End 0

Endclass
```

The class is wrapped in a service representation (no UI). Syracuse serializes the public fields to/from JSON.

### CRUD endpoint on a business object

Any V12 business-object representation is automatically exposed as REST. For example, a custom `YORDER` object → `GET/POST/PATCH/DELETE /api/x3/erp/SEED/YORDER`. Filtering, paging, and selection are handled via Syracuse query parameters.

`v12-classes-representations.md` covers the class → representation → page wiring.

### Calling a REST endpoint

```
POST /api/x3/erp/SEED/YSRV_CHECK_STOCK HTTP/1.1
Authorization: Bearer <syracuse-token>
Content-Type: application/json

{ "ITMREF": "ITM001" }
```

Response:

```json
{
  "ITMREF": "ITM001",
  "QTY": 42.5,
  "STATUS": "OK"
}
```

### Authentication

- **Basic auth** — user + password; fine for internal, avoid for the internet.
- **OAuth2 / Syracuse token** — standard for external integrations.
- Endpoint ACLs are set per role in Syracuse — check **Administration → Security → Roles → ACL** when a 403 shows up.

See `security-permissions.md` for the role / function-profile layer that backs Syracuse ACLs.

### Best practices for REST services

- **Return a status field** in the response (`OK`, `KO_<reason>`) — partners parse that more reliably than HTTP codes alone.
- **Validate every input field** before touching the database — services bypass entry-transaction checks.
- **Wrap DB writes in `If adxlog`** transactional idiom (`database.md`).
- **Don't call `Infbox` / `Errbox`** — there's no user; the popup XML may surface to the partner and crash their parser.
- **Log every invocation** to a dedicated integration table.
- **Version explicitly** — a `_V2` service rather than a breaking signature change. Run both during the deprecation window.
- **Idempotency keys** — accept a partner-supplied correlation id, check it before acting, return the prior result on retry.

## Consuming an external REST API from X3

The standard way in V12: the `WEBSER` / `HTTP` helper subprograms shipped with the supervisor. Exact script name depends on version; on recent V12 it's `func HTTPREST.*` or a dedicated class.

### Generic pattern

**Note on script names below:** the X3 supervisor does not expose a single fixed HTTP helper — different V12 patch levels ship `WEBSER`, `HTTPREQ`, or nothing at all (you write a thin wrapper over `System curl` or over the JVM bridge). The examples below call `HTTPPOST` / `HTTPGET` from a **user-defined** `YHTTP` script — substitute with whatever wrapper exists in your folder. The pattern (args, status handling) is what matters, not the exact script name.

```l4g
Local Char URL(500), BODY(2000), RESP(10000)
Local Integer HTTPCODE

URL = "https://api.partner.example/inventory/ITM001"
BODY = '{"apikey":"ABC","quantity":10}'

Call HTTPPOST(URL, BODY, "application/json", RESP, HTTPCODE) From YHTTP

If HTTPCODE = 200
    # parse RESP as JSON — see below
Else
    Call ECRAN_TRACE("HTTP " + num$(HTTPCODE) + ": " + RESP, 2) From GESECRAN
Endif
```

### Parsing JSON

Two common approaches in V12:

**1. Standard `func AFNC.JSON*` helpers** (present in most V12 installs):

```l4g
Local Char RESP(10000), VAL(200)
# RESP contains: {"status":"OK","qty":42}
VAL = func AFNC.JSONGET(RESP, "status")     # "OK"
Local Integer QTY
QTY = val(func AFNC.JSONGET(RESP, "qty"))   # 42
```

**2. Full DOM via the Syracuse class `ASYSTEM.ParseJson`** (newer V12 patch levels).

If neither is available or your folder is locked to an older supervisor, write a minimal parser in L4G using `instr`, `mid$`, and `pat`. Keep it to a small helper class, don't inline it.

### Building JSON

```l4g
Local Char BODY(2000)
BODY = '{"itmref":"' - [L]ITMREF - '","qty":' + num$([L]QTY) + '}'
```

Escape any user-supplied value (`"`, backslash, newlines) or your caller will send unparseable bodies. A minimal helper:

```l4g
Funprog YJSON_ESC(S)
Value Char S()
    S = replace$(S, "\", "\\")
    S = replace$(S, chr$(34), "\" + chr$(34))
    S = replace$(S, chr$(13), "\r")
    S = replace$(S, chr$(10), "\n")
    S = replace$(S, chr$(9), "\t")
End S
```

Route every interpolation through `YJSON_ESC` for any field that could contain user-entered text.

### Authenticating outbound REST calls

| Mode | How |
|------|-----|
| API key in header | Add an `Authorization: Bearer <key>` (or vendor-specific) HTTP header. Build a wrapper `YHTTPAUTH` that pulls the key from `GESADP`. |
| OAuth2 client credentials | Pre-flight `POST /token` with `client_id` + `client_secret`, cache the access token until expiry, refresh on 401. |
| Basic auth | `Authorization: Basic <base64(u:p)>`; rarely used for internet APIs but common in B2B. |

Pull credentials from encrypted parameters; never inline. See `security-permissions.md`.

### Pagination, retry, timeout

- **Pagination** — most APIs return a `next` cursor or a `Link: <…>; rel="next"` header. Loop until exhausted; cap loop iterations to prevent infinite-page bugs.
- **Retry** — on 5xx or transient network failure, retry with exponential backoff (1s, 2s, 4s, 8s, then give up). On 4xx, do not retry.
- **Timeout** — HTTP wrappers default to 30s. Configurable per call where supported. Long partner APIs need explicit overrides.

### Partner API — full pattern

```l4g
##############################################################
# YFETCH_INVENTORY — pull inventory from partner API
##############################################################
Funprog YFETCH_INVENTORY(SKU)
Value Char SKU()

Local Char    URL(500), RESP(10000), TOKEN(500)
Local Integer HTTPCODE, TRY

# Get cached or refresh token
TOKEN = func YOAUTH.GET_TOKEN()

URL = func AFNC.PARAMG("YINT", "PARTNER", "URL") - "/inventory/" - SKU

For TRY = 1 To 4
    Call HTTPGET_AUTH(URL, TOKEN, RESP, HTTPCODE) From YHTTPAUTH
    If HTTPCODE = 200 : Exitfor : Endif
    If HTTPCODE = 401              # token expired; refresh once
        TOKEN = func YOAUTH.REFRESH()
        Continue
    Endif
    If HTTPCODE >= 500
        Sleep 2 ** TRY              # exponential backoff
        Continue
    Endif
    # 4xx other than 401 — fail fast
    End ""
Next

If HTTPCODE <> 200
    Call ECRAN_TRACE("Partner API " + num$(HTTPCODE) + ": " + RESP, 2) From GESECRAN
    End ""
Endif

End RESP
```

## SData

V7/V12 carries SData endpoints forward for backwards compatibility:

```
GET /sdata/x3/erp/SEED/BPCUSTOMER('BP001')
```

Returns an Atom XML feed. New code should prefer the REST API — SData is retained for apps built against V7 and earlier integrations. A `GET` against an SData URL on V12 still works, but for new clients reach for `/api/x3/erp/...` instead.

## REST-specific gotchas

- **Self-signed certs** — the runtime rejects them by default; configure the trust store via Syracuse rather than disabling TLS verification.
- **Folder context in REST** — the URL contains the folder (`SEED`). Make sure the Syracuse user is bound to that folder, or you'll get a cryptic 500.
- **Encoding** — REST default is UTF-8. Older partner APIs may serve ISO-8859-1 — check `Content-Type` before parsing.
- **Payload size** — the REST layer buffers the whole body in memory; don't pass megabytes through a single call, chunk or use file exchange (see `web-services-integration.md`).
- **OAuth token expiry** — cache, but always handle 401 by refreshing once and retrying. Don't retry on every call (rate-limited APIs ban you).
- **HTTP headers case sensitivity** — most partner servers treat headers case-insensitively, but a few enforce case (e.g. `X-API-Key` vs `x-api-key`). Match what the docs show literally.
- **JSON field nesting** — `func AFNC.JSONGET(RESP, "rates.USD")` works on most patches with dotted paths, but check on yours; older shipping versions only support flat keys.

See also: `web-services-integration.md` (overview, file exchange, TLS, integration logging), `web-services-soap.md` (SOAP server and SOAP client), `v12-classes-representations.md` (representation → REST endpoint wiring), `security-permissions.md` (auth, ACL, OAuth credential storage), `version-caveats.md` (`HTTPPOST` / `AFNC.JSON*` availability).

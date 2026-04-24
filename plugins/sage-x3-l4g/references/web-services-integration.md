# Web services and integration

How to expose L4G logic as a service, and how to consume external APIs from X3. V12-centric.

## The three integration surfaces in V12

| Surface | Protocol | Use case |
|---------|----------|----------|
| **REST API** (Syracuse) | HTTP/JSON | Modern — default for V12 integrations |
| **Classic SOAP web services** (AWS / GESAWS) | SOAP/XML | Legacy but still fully supported, same in V6/V7/V12 |
| **SData** | OData-like XML | Older middle-tier integrations, less common in new builds |

Publishing *outbound* calls (X3 calls someone else) uses a separate set of primitives — see **Consuming external APIs** below.

## Publishing a SOAP web service (classic)

SOAP/AWS remains the most common integration surface in production V12 shops — it's metadata-driven, stable across versions, supports complex parameter types better than REST, and partners that have already built SOAP clients rarely want to switch.

The lifecycle is: write the subprogram → declare it in `GESAWE` → let the engine generate the WSDL → callers invoke via the SOAP endpoint, routed through the AWS pool.

### 1. Create the subprogram

```l4g
##############################################################
# YWS_CHECK_STOCK — returns stock for an item code
##############################################################
Subprog YWS_CHECK_STOCK(ITMREF, QTY, STATUS)
Value    Char    ITMREF()
Variable Decimal QTY                     # out
Variable Char    STATUS()                # out — "OK" / "KO_<reason>"

    Local File ITMMASTER [ITM], STOCK [STO]

    # Always validate first — services bypass entry-transaction checks
    If ITMREF = ""
        STATUS = "KO_EMPTY_ITMREF"
        QTY = 0
        End
    Endif

    Read [ITM]ITMREF0 = ITMREF
    If fstat
        STATUS = "KO_UNKNOWN_ITEM"
        QTY = 0
        End
    Endif

    QTY = 0
    For [STO] Where ITMREF = [F:ITM]ITMREF
        QTY += [F:STO]QTYSTU
    Next
    STATUS = "OK"
End
```

### 2. Publish it in `GESAWE` (web service exposition)

Go to **Administration → Web services → Classic SOAP web services**. Create a publication with:

| Field | Value |
|-------|-------|
| Code | `YWS_CHECK_STOCK` (the service name clients will use) |
| Description | Human-readable; appears in the WSDL |
| Type | `GOSUB` (subprogram) |
| Module | Activity code governing the service (e.g. `YINT`) |
| Access code | ACL on who can invoke |
| Script | The `.src` filename containing the subprogram |
| Subprogram | The actual `Subprog` name |

Then for each parameter, declare a line in the detail grid:

| Column | Meaning |
|--------|---------|
| Rank | Position in the signature (1, 2, 3…) — **must match the L4G order** |
| Name | XML element name in the SOAP body |
| Dimension | `0` = scalar, `1` = 1-D array, `2` = 2-D |
| Type | `CHAR`, `DECIMAL`, `INTEGER`, `DATE`, `CLBFILE` |
| Length | For `CHAR` only |
| I/O | `0` = in, `1` = out, `2` = in/out |
| Description | Appears as XML comment in the WSDL |

**Save → Validate** — the engine generates the WSDL. If validation fails, the error usually points to a mismatch between the `GESAWE` parameter list and the `Subprog` signature (count, order, or type).

### 3. Invoke

The SOAP endpoint is:

```
http://<host>:8124/soap-generic/syracuse/collaboration/soap-generic-x3:CAdxWebServiceXmlCC?wsdl
```

The port and path depend on your Syracuse install. The WSDL exposes a `run` operation — clients package the call like this:

```xml
<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
  <soap:Body>
    <run xmlns="http://www.adonix.com/WSS">
      <callContext>
        <codeLang>FRA</codeLang>
        <poolAlias>WSPOOL</poolAlias>
      </callContext>
      <publicName>YWS_CHECK_STOCK</publicName>
      <inputXml>
        <![CDATA[<PARAM>
          <FLD NAME="ITMREF">ITM001</FLD>
        </PARAM>]]>
      </inputXml>
    </run>
  </soap:Body>
</soap:Envelope>
```

Output parameters come back serialized in the response `resultXml`.

### Complex parameter types — 1-D and 2-D arrays

SOAP in X3 handles structured data via **table-type parameters** (dimension 1 = vector, dimension 2 = matrix). Declare in `GESAWE` with `Dimension = 1` or `2`, then on the L4G side:

```l4g
##############################################################
# YWS_BATCH_RESERVE — reserves stock for a list of items
# ITMREFS and QTYS are 1-D arrays, RESULTS is out
##############################################################
Subprog YWS_BATCH_RESERVE(ITMREFS, QTYS, RESULTS, STATUS)
Value    Char    ITMREFS()(1..100)          # 1-D array, up to 100 items
Value    Decimal QTYS(1..100)
Variable Char    RESULTS()(1..100)           # parallel out array
Variable Char    STATUS()

Local Integer I
For I = 1 To 100
    If ITMREFS(I) = "" : Exitfor : Endif
    # per-item logic — populate RESULTS(I) with "OK" or "KO_<reason>"
    ...
Next
STATUS = "OK"
End
```

Clients pass the array as repeated `<FLD>` elements under a named `<TAB>`:

```xml
<TAB DIM="100" NAME="ITMREFS" SIZE="30">
  <LIN><FLD>ITM001</FLD></LIN>
  <LIN><FLD>ITM002</FLD></LIN>
</TAB>
```

Declare the max dimension honestly — if you write `1..100` in L4G but the partner sends 200 entries, only the first 100 reach you and the rest are silently dropped.

### AWS pool configuration (`GESAPO`) — performance

Every SOAP call needs a pre-initialized X3 session. The engine keeps these in a **pool** declared in `GESAPO` (Administration → Web services → Pools):

| Setting | Effect |
|---------|--------|
| Alias | Pool name (callers reference it in `callContext.poolAlias`) |
| Min/Max size | Pre-allocated and cap — sets concurrency ceiling |
| User | X3 user the service runs as (ACL scope) |
| Folder | Which folder the session is bound to |
| Activity | The activity code chain active in the session |

**Sizing rule of thumb:** min ≥ peak-concurrent-callers, max ≤ 2 × min (higher caps invite thrashing). Short-lived services (<500ms) tolerate a smaller pool than long ones.

A cold pool start takes seconds — callers that hit a freshly-restarted Syracuse see timeouts until the pool fills. **Always set min ≥ 1** in production.

Restart the pool after changing activity codes / user ACL — cached sessions keep the old context otherwise.

### Authentication

SOAP services accept two auth modes:

| Mode | Setup | Use |
|------|-------|-----|
| **Basic auth** | HTTP `Authorization: Basic <base64(user:pass)>` — the user must have ACL on the published service in `GESAWE` | Internal integrations, trusted networks |
| **WS-Security UsernameToken** | SOAP header `<wsse:Security>` with UsernameToken — same user lookup | When Basic is blocked by the web layer |

The `callContext.codeUser` field inside the SOAP body can override the auth user in some legacy configs — **disable this in production**, it's a well-known impersonation footgun.

### Best practices for classic SOAP

- **Return a status code as the last parameter** — never crash on validation failures, let the caller handle them. Use a vocabulary: `OK`, `KO_<reason>`, `WARN_<detail>`.
- **Validate each input explicitly** — services bypass the entry transaction's natural checks.
- **Wrap any DB writes in the `If adxlog` transactional idiom** (`database.md`).
- **Don't call `Infbox` / `Errbox`** in a service subprogram — the user doesn't see a screen, and some clients crash parsing an unexpected popup response.
- **Log every invocation** to a dedicated integration table (see `debugging-traces.md`) — support tickets are unworkable otherwise.
- **Don't change signatures in place.** Adding an in/out parameter renumbers ranks and breaks every deployed client. Publish a `_V2` service instead and deprecate the old one.
- **Idempotency.** A partner retrying after a network blip shouldn't double-insert. Accept an external correlation key and check it before acting.

### Debugging SOAP

When a SOAP call fails, the error surfaces in layers:

| Symptom | Likely cause | Where to look |
|---------|--------------|---------------|
| `Method not found` or empty WSDL | `GESAWE` record exists but not validated, or activity code inactive | Re-validate the publication; check activity code is on |
| `No such pool: <ALIAS>` | Pool in `GESAPO` missing or wrong folder | Verify alias, restart the pool |
| 401 / 403 | ACL denies the authenticated user | User's role → ACL on the service code |
| Parameter deserialization error | Rank / type mismatch between `GESAWE` grid and `Subprog` signature | Compare column-by-column; re-generate WSDL |
| Timeout, pool exhausted | All sessions busy, caller waits beyond timeout | Increase pool size, optimize the service |
| Silent empty response | Subprog threw before writing out params | Add `ECRAN_TRACE` entries; X3 tracing ON |
| WSDL namespace mismatch | Client pinned to an older WSDL with different namespace | Re-download the WSDL; regenerate client stubs |

**Turn on X3 tracing** (Administration → Utilities → Verifications → X3 tracing) before reproducing — you see every supervisor call the service makes and where it returns.

### Migrating SOAP → REST — when and how

Don't migrate unless there's a reason. Keep SOAP for:

- Services with **complex array parameters** — REST service classes flatten badly to JSON
- **Long-deployed external clients** — you can't force them to rebuild
- Services that are already **working, tested, audited**

Migrate to REST for:

- **New integrations** where the partner chooses — REST is simpler to adopt
- Services that naturally CRUD a business object — the representation gives you the REST API for free
- Services that need **streaming** or large payloads — REST with HTTP chunking beats SOAP
- **Mobile or browser clients** — no SOAP tooling anymore

Migration pattern: wrap the existing SOAP `Subprog` in a V12 class, expose the class as a REST service (see next section), and run both in parallel for a deprecation window. Clients migrate at their own pace.

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

- **Basic auth** — user + password; fine for internal, avoid for the internet
- **OAuth2 / Syracuse token** — standard for external integrations
- Endpoint ACLs are set per role in Syracuse — check **Administration → Security → Roles → ACL** when a 403 shows up

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

Escape any user-supplied value (`"`, backslash, newlines) or your caller will send unparseable bodies.

## SOAP client — calling an external SOAP service

When an external partner only exposes SOAP, build the envelope, POST it, parse the response.

### Minimal pattern

```l4g
Local Char ENVELOPE(4000), RESP(10000)
Local Integer HTTPCODE

ENVELOPE = '<?xml version="1.0" encoding="UTF-8"?>' +
           '<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">' +
           '  <soap:Body>' +
           '    <GetStock xmlns="http://partner.example/">' +
           '      <ITM>' - [L]ITMREF - '</ITM>' +
           '    </GetStock>' +
           '  </soap:Body>' +
           '</soap:Envelope>'

Call HTTPPOST("https://partner/soap", ENVELOPE, "text/xml; charset=utf-8", RESP, HTTPCODE) From YHTTP
```

Mandatory HTTP headers the partner usually expects:

- `Content-Type: text/xml; charset=utf-8`
- `SOAPAction: "<namespace>/<operation>"` — some servers reject the call without it

### With WS-Security UsernameToken

When the partner requires authenticated SOAP:

```l4g
Local Char SEC(1000)
SEC = '<soap:Header>' +
      '  <wsse:Security xmlns:wsse="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd">' +
      '    <wsse:UsernameToken>' +
      '      <wsse:Username>' - [L]USR - '</wsse:Username>' +
      '      <wsse:Password Type="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-username-token-profile-1.0#PasswordText">' -
              [L]PWD - '</wsse:Password>' +
      '    </wsse:UsernameToken>' +
      '  </wsse:Security>' +
      '</soap:Header>'

ENVELOPE = '<?xml version="1.0" encoding="UTF-8"?>' +
           '<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">' +
           SEC +
           '  <soap:Body>...</soap:Body>' +
           '</soap:Envelope>'
```

Never hardcode credentials — pull from `GESADP` parameters or an encrypted config.

### Escaping XML payload

Values interpolated into XML must be escaped — `&` → `&amp;`, `<` → `&lt;`, `>` → `&gt;`, `"` → `&quot;`, `'` → `&apos;`. Helper:

```l4g
Funprog YXML_ESC(S)
Value Char S()
    S = replace$(S, "&", "&amp;")
    S = replace$(S, "<", "&lt;")
    S = replace$(S, ">", "&gt;")
    S = replace$(S, chr$(34), "&quot;")
    S = replace$(S, chr$(39), "&apos;")
End S
```

Forget this once and a customer name with `&` breaks the whole envelope. Every `<FLD>` interpolation goes through `YXML_ESC` — not optional.

### Parsing the response

**Option 1 — pattern extraction** for small payloads:

```l4g
Local Integer P1, P2
Local Char    QTY_STR(20)

P1 = instr(1, RESP, "<Quantity>")
P2 = instr(1, RESP, "</Quantity>")
If P1 > 0 And P2 > P1
    QTY_STR = mid$(RESP, P1 + len$("<Quantity>"), P2 - P1 - len$("<Quantity>"))
    [L]QTY = val(QTY_STR)
Endif
```

Brittle but simple — acceptable when the response has 2-3 fields you need.

**Option 2 — XML helper** when available:

```l4g
Local Char VAL(100)
VAL = func AFNC.XMLGET(RESP, "//Quantity")
[L]QTY = val(VAL)
```

`AFNC.XML*` presence depends on the patch level — see `version-caveats.md`.

**Option 3 — dedicated class** when parsing is non-trivial. Build a `YXMLPARSER` class once, reuse across services.

### SOAP fault handling

Server-side errors come back as `<soap:Fault>`. Detect and surface:

```l4g
If instr(1, RESP, "<soap:Fault>") > 0 Or instr(1, RESP, "<SOAP-ENV:Fault>") > 0
    Local Char REASON(500)
    REASON = mid$(RESP, instr(1, RESP, "<faultstring>") + len$("<faultstring>"),
                        instr(1, RESP, "</faultstring>") - instr(1, RESP, "<faultstring>") - len$("<faultstring>"))
    Call ECRAN_TRACE("SOAP fault: " - REASON, 2) From GESECRAN
    End 1
Endif
```

Don't confuse an HTTP 200 carrying a `<soap:Fault>` with success — SOAP faults travel in 200 or 500 responses depending on the stack.

## SData

V7/V12 carries SData endpoints forward for backwards compatibility:

```
GET /sdata/x3/erp/SEED/BPCUSTOMER('BP001')
```

Returns an Atom XML feed. New code should prefer the REST API — SData is retained for apps built against V7.

## File exchange — when HTTP isn't an option

Some partners still want files over SFTP. Pattern:

1. Write the file to `TMP/` via `Openo` + `Writeseq` (see `builtin-functions.md`).
2. Trigger the transfer via `System` calling a shell helper (`lftp`, `scp`, `curl`).
3. Log the response into a tracking table (`YINTEGRATIONLOG`).
4. Schedule the job with the X3 batch scheduler (`GESAPL`) or externally.

Avoid keeping credentials in the L4G source — use `PARAMG` parameter values stored encrypted or environment-level config.

## Integration traces

Every integration script should log to a dedicated table:

```l4g
Raz [F:YINTLOG]
[F:YINTLOG]INTDAT = date$
[F:YINTLOG]INTTIM = time$
[F:YINTLOG]ENDPOINT = URL
[F:YINTLOG]HTTPCODE = CODE
[F:YINTLOG]RESP = left$(RESP, 2000)
Write [YINTLOG]
```

When production goes sideways you'll thank yourself — `adxlog.log` is not enough to debug an integration after the fact.

## Gotchas

- **Self-signed certs** — the runtime rejects them by default; configure the trust store via Syracuse rather than disabling TLS verification.
- **Timeouts** — HTTP helpers have a default (often 30s); long-running partner APIs need an explicit override.
- **Folder context in REST** — the URL contains the folder (`SEED`). Make sure the Syracuse user is bound to that folder, or you'll get a cryptic 500.
- **SOAP and transactions** — a SOAP subprogram runs in its own session with no pre-existing transaction; don't assume `adxlog` semantics from a batch context.
- **Payload size** — classic SOAP and the X3 REST layer buffer the whole body in memory; don't pass megabytes through a single call, chunk or use file exchange.
- **Encoding** — default is UTF-8 for REST, often ISO-8859-1 in older SOAP — check `Content-Type` before parsing.
- **SOAP parameter order** — ranks in `GESAWE` must match the `Subprog` signature exactly. A swap compiles fine but deserializes garbage.
- **SOAP pool restart** — changing activity codes, user ACL, or the underlying subprogram requires a pool restart. Cached sessions keep stale context otherwise.
- **WSDL caching on the client side** — clients that cache the WSDL at build time don't pick up your changes until rebuilt. Version the service (`_V2`) before changing signatures.
- **XML unescaped interpolation** — a single `&` or `<` in a customer name breaks the envelope. Route every interpolation through an escape helper.
- **SOAP fault vs HTTP 200** — a fault can travel in a 200 response body. Check for `<soap:Fault>` explicitly, don't rely on the HTTP code alone.
- **`callContext.codeUser` impersonation** — legacy configs accept a user code in the body that overrides auth. Disable in production.
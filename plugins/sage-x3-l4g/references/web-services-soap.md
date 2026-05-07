# SOAP web services — publishing and consuming

Classic SOAP / AWS (`GESAWS`) is still fully supported in V12 and remains the most common integration surface in production X3 shops — metadata-driven, stable across versions, supports complex parameter types better than REST, and partners with deployed SOAP clients rarely want to switch.

For the REST side, REST → JSON consumption, and the protocol comparison, see `web-services-rest.md`. For cross-cutting integration concerns (file exchange, TLS, integration logging), see `web-services-integration.md`.

## Publishing a SOAP web service (classic)

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

The `callContext.codeUser` field inside the SOAP body can override the auth user in some legacy configs — **disable this in production**, it's a well-known impersonation footgun. See `security-permissions.md`.

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

Migration pattern: wrap the existing SOAP `Subprog` in a V12 class, expose the class as a REST service (see `web-services-rest.md`), and run both in parallel for a deprecation window. Clients migrate at their own pace.

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

Never hardcode credentials — pull from `GESADP` parameters or an encrypted config (`security-permissions.md`).

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

## SOAP-specific gotchas

- **SOAP parameter order** — ranks in `GESAWE` must match the `Subprog` signature exactly. A swap compiles fine but deserializes garbage.
- **SOAP pool restart** — changing activity codes, user ACL, or the underlying subprogram requires a pool restart. Cached sessions keep stale context otherwise.
- **WSDL caching on the client side** — clients that cache the WSDL at build time don't pick up your changes until rebuilt. Version the service (`_V2`) before changing signatures.
- **XML unescaped interpolation** — a single `&` or `<` in a customer name breaks the envelope. Route every interpolation through an escape helper.
- **SOAP fault vs HTTP 200** — a fault can travel in a 200 response body. Check for `<soap:Fault>` explicitly, don't rely on the HTTP code alone.
- **`callContext.codeUser` impersonation** — legacy configs accept a user code in the body that overrides auth. Disable in production.
- **SOAP and transactions** — a SOAP subprogram runs in its own session with no pre-existing transaction; don't assume `adxlog` semantics from a batch context.

See also: `web-services-integration.md` (overview, file exchange, TLS), `web-services-rest.md` (REST publishing and SOAP→REST migration target), `security-permissions.md` (ACL, credential storage), `debugging-traces.md` (integration logging), `version-caveats.md` (`HTTPPOST` / `AFNC.XML*` availability).

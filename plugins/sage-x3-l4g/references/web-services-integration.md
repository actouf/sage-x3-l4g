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

Still widely used — entirely driven by metadata + a `Subprog`.

### 1. Create the subprogram

```l4g
##############################################################
# YWS_CHECK_STOCK — returns stock for an item code
##############################################################
Subprog YWS_CHECK_STOCK(ITMREF, QTY, STATUS)
Value    Char    ITMREF()
Variable Decimal QTY                     # out
Variable Char    STATUS()                # out — "OK" / "KO"

    Local File ITMMASTER [ITM], STOCK [STO]

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

- Go to **Administration → Web services → Classic SOAP web services**
- Create a subprogram publication (`GOSUB` type) pointing to `YWS_CHECK_STOCK` in its `.src`
- Declare each parameter: name, type, in/out, length
- Generate the WSDL

### 3. Invoke

Callers hit `http://<host>/soap-generic/syracuse/collaboration/soap-generic-x3:CAdxWebServiceXmlCC?wsdl` with the subprogram and folder context.

### Best practices for classic SOAP

- Return a **status code** as the last parameter — never crash on validation failures, let the caller handle them.
- Validate each input explicitly; web services bypass the entry transaction's natural checks.
- Wrap any DB writes in the `If adxlog` transactional idiom (`database.md`).
- Don't call `Infbox` / `Errbox` in a service subprogram — the user doesn't see a screen.

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

Less frequent, but when an external partner only exposes SOAP:

```l4g
Local Char ENVELOPE(4000), RESP(10000)
ENVELOPE = '<?xml version="1.0"?>' +
           '<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">' +
           '  <soap:Body>' +
           '    <GetStock xmlns="http://partner.example/"><ITM>ITM001</ITM></GetStock>' +
           '  </soap:Body>' +
           '</soap:Envelope>'

Call HTTPPOST("https://partner/soap", ENVELOPE, "text/xml; charset=utf-8", RESP, [L]CODE) From YHTTP
```

Extract values with `pat` / `instr` or the supervisor's XML helpers (`func AFNC.XML*` when available).

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
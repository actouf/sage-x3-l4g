# SOAP client — calling an external SOAP service from L4G

When an external partner exposes only SOAP, X3 builds the envelope, POSTs it via an HTTP wrapper, and parses the response. This file covers the client side; for *publishing* a SOAP service from X3, see `web-services-soap.md`.

## Minimal pattern

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

Note: `HTTPPOST` is illustrative; the X3 supervisor doesn't ship a single fixed HTTP helper. See `version-caveats.md` and `web-services-rest.md` for the wrapper pattern.

## With WS-Security UsernameToken

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

## Escaping XML payload

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

Forget this once and a customer name with `&` breaks the whole envelope. Every interpolation goes through `YXML_ESC` — not optional.

## Parsing the response

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

## SOAP fault handling

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

## Pattern: full client wrapper

A reusable client class for one external SOAP partner:

```l4g
##############################################################
# YPARTNERSOAP — client wrapper for partner.example SOAP API
##############################################################
Class YPARTNERSOAP

    Public Char URL(500)
    Public Char USR(50)
    Public Char PWD(100)            # populated from encrypted parameter at construct time

    Public Method GetStock(ITMREF, QTY)
    Value    Char    ITMREF()
    Variable Decimal QTY
        Local Char    ENVELOPE(4000), RESP(10000), ITM_ESC(60)
        Local Integer HTTPCODE

        ITM_ESC = func YXML_ESC(ITMREF)

        ENVELOPE = '<?xml version="1.0" encoding="UTF-8"?>' +
                   '<soap:Envelope xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">' +
                   func YPARTNERSOAP_SEC(this.USR, this.PWD) +
                   '  <soap:Body>' +
                   '    <GetStock xmlns="http://partner.example/">' +
                   '      <ITM>' - ITM_ESC - '</ITM>' +
                   '    </GetStock>' +
                   '  </soap:Body>' +
                   '</soap:Envelope>'

        Call HTTPPOST(this.URL, ENVELOPE, "text/xml; charset=utf-8", RESP, HTTPCODE) From YHTTP

        If HTTPCODE <> 200
            Call ECRAN_TRACE("Partner HTTP " + num$(HTTPCODE), 2) From GESECRAN
            End 1
        Endif

        If instr(1, RESP, "<soap:Fault>") > 0
            Call ECRAN_TRACE("SOAP fault from partner", 2) From GESECRAN
            End 1
        Endif

        # Extract <Quantity>…</Quantity>
        Local Integer P1, P2
        P1 = instr(1, RESP, "<Quantity>")
        P2 = instr(1, RESP, "</Quantity>")
        If P1 > 0 And P2 > P1
            QTY = val(mid$(RESP, P1 + len$("<Quantity>"), P2 - P1 - len$("<Quantity>")))
            End 0
        Endif

        End 1                       # response did not parse
    End

Endclass
```

Wrapping each partner SOAP API in its own class avoids spreading XML literals across business code.

## SOAP client — gotchas

- **XML unescaped interpolation** — a single `&` or `<` in a customer name breaks the envelope. Route every interpolation through an escape helper.
- **SOAP fault vs HTTP 200** — a fault can travel in a 200 response body. Check for `<soap:Fault>` explicitly, don't rely on the HTTP code alone.
- **WSDL caching on the client side** — when calling a partner whose WSDL changed, regenerate stubs / re-read the WSDL. Stale cached schemas serialize to the old format and break.
- **HTTPS trust store** — self-signed certs from the partner side are rejected unless added to the Syracuse trust store. Don't disable TLS verification.
- **SOAPAction header** — easy to forget; some servers reject silently with a 200 + empty body or a 405.
- **Encoding** — older partner servers default to ISO-8859-1. Force `charset=utf-8` in the request header and check the response `Content-Type` before parsing.
- **Timeout** — partner APIs that summarize a large dataset can take 30+ seconds. Set the wrapper timeout explicitly per call.
- **Credentials in source** — pull `USR` / `PWD` from encrypted `GESADP` parameters at object construction; never hardcode.

See also: `web-services-soap.md` (publishing SOAP from X3), `web-services-integration.md` (overview, file exchange, TLS, integration logs), `security-permissions.md` (credential storage), `version-caveats.md` (`HTTPPOST` / `AFNC.XML*` availability), `code-review-checklist.md` (XML interpolation flag).

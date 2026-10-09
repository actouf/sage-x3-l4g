# SOAP client — calling an external SOAP service from L4G

How X3 code calls a partner's SOAP/XML service: which supervisor API can carry a raw XML envelope,
how to build the envelope safely in a CLOB, post it, detect faults and extract values. For publishing
SOAP services from X3 see `web-services-soap.md`; for JSON/REST partners see
`web-services-rest-client.md`.

## Contents
- [What Sage provides](#what-sage-provides)
- [EXEC_HTTP signature](#exec_http-signature)
- [Escaping values into XML](#escaping-values-into-xml)
- [Reading values and faults from the response](#reading-values-and-faults-from-the-response)
- [Full example](#full-example)
- [Timeouts and retries](#timeouts-and-retries)
- [Gotchas](#gotchas)
- [Sources](#sources)

## What Sage provides

Sage's online help documents **no dedicated SOAP client** (no WSDL import, no stub generation).

| Option | Status | Use |
|---|---|---|
| `func ASYRWEBSER.EXEC_HTTP` | Documented (ASYRWEBSER API page); its sample calls a SOAP service's `?wsdl` URL | Default: post a hand-built envelope |
| `func ASYRRESTCLI.EXEC_REST_WS` | Documented, but "the data sent to the web service must be in JSON format"; a Sage-verified community answer confirms it only accepts and returns JSON | Not for SOAP envelopes |
| `func ASYRWEBSER.EXEC_JS` + custom node.js bundle | Documented mechanism | When you need full control (signing, namespaces) |
| External program via `System` | Generic | Last resort; needs an executable on the application server |

Community users report `EXEC_HTTP` calling a third-party SOAP service and receiving its answer, and
others getting HTTP 400 on unusual APIs: validate the exact request in SoapUI or Postman first
(community-reported).

## EXEC_HTTP signature

```l4g
Funprog EXEC_HTTP(HEADERCOD, HEADERVAL, DATA, RESHEAD, RESBODY) : # library ASYRWEBSER
Value    Char    HEADERCOD()(1..)  : # header keys
Value    Char    HEADERVAL()(1..)  : # header values
Value    Clbfile DATA()            : # body, for POST and PUT only
Variable Clbfile RESHEAD()         : # response header
Variable Clbfile RESBODY()         : # response body
# Returns the HTTP status (Integer)
```

Sage's sample passes the target as the pseudo-headers `url` and `method` in the first two array
entries (values as plain strings, not JSON constants) and sends `'{}'` as body on a GET. Header values
are `Char`, so a URL or header longer than 255 characters cannot be passed.

## Escaping values into XML

`ctrans` substitutes single characters only and there is no string-replace function, so escape with a
character loop. Appending straight into the envelope CLOB avoids any `Char` length limit.

```l4g
# Script YXMLLIB - XML helpers for SOAP clients
# Appends TXT to DEST with the five XML special characters escaped
Subprog YXML_APPEND(DEST, TXT)
Variable Clbfile DEST()
Value    Char    TXT()
Local Integer I
Local Char    C(1)
  For [L]I = 1 To len([L]TXT)
    [L]C = mid$([L]TXT, [L]I, 1)
    Case [L]C
      When "&"      : Append [L]DEST, "&amp;"
      When "<"      : Append [L]DEST, "&lt;"
      When ">"      : Append [L]DEST, "&gt;"
      When chr$(34) : Append [L]DEST, "&quot;"
      When "'"      : Append [L]DEST, "&apos;"
      When Default  : Append [L]DEST, [L]C
    Endcase
  Next I
End
```

## Reading values and faults from the response

There is no XML parser API in the documented 4GL function set; the Sage-verified community answer is
"CLOB manipulation" with `instr` and `seg$`/`mid$`, which accept CLOBs. Values come back XML-escaped
(`&amp;`) and the result of `mid$` is `Char`, so extract leaf values, not subtrees.

```l4g
# Script YXMLLIB (continued)
# Returns the text between <TAG> and </TAG> (first occurrence), or "" if absent
# TAG must include the namespace prefix exactly as the partner sends it (e.g. "a:Status")
Funprog YXML_TAG(XML, TAG)
Variable Clbfile XML()
Value    Char    TAG()
Local Integer P1, P2
Local Char    OPENTAG(100), CLOSETAG(100), RESULT(255)
  [L]OPENTAG  = "<" + [L]TAG + ">"
  [L]CLOSETAG = "</" + [L]TAG + ">"
  [L]P1 = instr(1, [L]XML, [L]OPENTAG)
  If [L]P1 = 0
    End ""
  Endif
  [L]P1 += len([L]OPENTAG)
  [L]P2 = instr([L]P1, [L]XML, [L]CLOSETAG)
  If [L]P2 = 0
    End ""
  Endif
  [L]RESULT = mid$([L]XML, [L]P1, [L]P2 - [L]P1)
End [L]RESULT
```

A SOAP 1.1 fault is a `<prefix:Fault>` element carrying an unqualified `<faultstring>`; the prefix
varies (`soap:`, `s:`, `SOAP-ENV:`), so search for `:Fault>`. Faults can arrive with HTTP 500 or 200:
test the body, not only the status. SOAP 1.2 uses `Reason`/`Text` instead of `faultstring`.

## Full example

```l4g
# Script YSOAPSHIP - asks a carrier's SOAP service for a tracking number
# The partner contract (namespace, SOAPAction, tags) comes from its WSDL
Funprog YSOAP_TRACKNUM(ORDREF, ERRMSG)
Value    Char ORDREF()
Variable Char ERRMSG()
Local Char    HCOD(64)(4), HVAL(255)(4), TRACKNUM(50), STA(10)
Local Clbfile ENV(1), RESHEAD(0), RESBODY(0)
Local Integer HTTPSTA
  Raz [L]ERRMSG
  [L]ENV = '<?xml version="1.0" encoding="UTF-8"?>'
  Append [L]ENV, '<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/"'
  Append [L]ENV, ' xmlns:car="http://carrier.example/ws"><soapenv:Body><car:GetTracking>'
  Append [L]ENV, '<car:Reference>'
  Call YXML_APPEND([L]ENV, [L]ORDREF) From YXMLLIB
  Append [L]ENV, '</car:Reference></car:GetTracking></soapenv:Body></soapenv:Envelope>'

  [L]HCOD(0) = "url"          : [L]HVAL(0) = "https://carrier.example/ws/tracking.svc"
  [L]HCOD(1) = "method"       : [L]HVAL(1) = "POST"
  [L]HCOD(2) = "Content-Type" : [L]HVAL(2) = "text/xml; charset=utf-8"
  [L]HCOD(3) = "SOAPAction"   : [L]HVAL(3) = '"http://carrier.example/ws/GetTracking"'
  [L]HTTPSTA = func ASYRWEBSER.EXEC_HTTP([L]HCOD, [L]HVAL, [L]ENV, [L]RESHEAD, [L]RESBODY)

  [L]STA = "KO"
  If instr(1, [L]RESBODY, ":Fault>") > 0
    [L]ERRMSG = func YXMLLIB.YXML_TAG([L]RESBODY, "faultstring")
  Elsif [L]HTTPSTA = 200
    [L]TRACKNUM = func YXMLLIB.YXML_TAG([L]RESBODY, "a:TrackingNumber")
    If [L]TRACKNUM <> ""
      [L]STA = "OK"
    Endif
  Else
    [L]ERRMSG = "HTTP status " + num$([L]HTTPSTA)
  Endif
  Call YINTLOG_WRITE("OUT", "CARRIER", "GetTracking", [L]ORDREF, [L]HTTPSTA, [L]STA, [L]ENV, [L]RESBODY) From YINTLOGLIB
End [L]TRACKNUM
```

`HCOD(64)(4)` declares indexes 0 to 3 for the four pseudo-headers used here. Sage's sample declares
`HEADERCOD(64)(3)` and fills only indexes 0-1 (`url`, `method`): size the arrays to the headers you send,
starting at index 0 as the sample does. `YXML_APPEND` and `YXML_TAG` both live in
script `YXMLLIB`. Keep the URL in a parameter or table rather than in source
(`security-permissions.md`); the log row is defined in `web-services-integration.md`.

## Timeouts and retries

- No timeout argument is documented for `EXEC_HTTP`; a hung partner blocks the session. Prefer calling
  slow partners from batch tasks (`batch-scheduling.md`) rather than from interactive screens.
- Retry only idempotent operations (queries) or operations the partner de-duplicates by a reference you
  send. Never retry on a fault returned by the partner's business logic.
- Back off between attempts with `Sleep SECONDS`, doubling the wait each time, and cap the attempts
  (pattern in `web-services-rest-client.md`).

## Gotchas

- An unescaped `&` or `<` in a customer name breaks the envelope: route every value through
  `YXML_APPEND`.
- `SOAPAction` must match the WSDL exactly, including the quotes most SOAP 1.1 servers expect.
- Tag search is literal: namespace prefixes can change between partner releases. Re-check after any
  partner upgrade, or search the local name after the prefix.
- For XML (not SOAP) REST APIs the community-reported answer is the same: `EXEC_REST_WS` cannot send
  raw XML; use `EXEC_HTTP` or a node.js bundle through `EXEC_JS`.
- Accented characters: declare `charset=utf-8` and test with real data (community reports encoding
  issues in batch with the JSON parser; the same care applies to XML).

See also: `web-services-integration.md`, `web-services-rest-client.md`, `builtin-functions.md`.

## Sources
- https://online-help.sagex3.com/erp/12/en-us/Content/V7DEV/api-guide_api-asyrwebser.html
- https://online-help.sagex3.com/erp/12/en-us/Content/V7DEV/api-guide_api-asyrrestcli.html
- https://online-help.sagex3.com/erp/12/en-us/Content/V7DEV/4gl_instr.html
- https://online-help.sagex3.com/erp/12/en-us/Content/V7DEV/4gl_mid$.html
- https://online-help.sagex3.com/erp/12/en-us/Content/V7DEV/4gl_seg$.html
- https://online-help.sagex3.com/erp/12/en-us/Content/V7DEV/4gl_ctrans.html
- https://online-help.sagex3.com/erp/12/en-us/Content/V7DEV/4gl_append.html
- https://online-help.sagex3.com/erp/12/en-us/Content/V7DEV/4gl_case.html
- https://online-help.sagex3.com/erp/12/en-us/Content/V7DEV/4gl_clbfile.html
- https://communityhub.sage.com/sage-global-solutions/sage_x3/f/general-discussion/220325/connecting-to-an-external-rest-with-an-xml-header (community)
- https://communityhub.sage.com/sage-global-solutions/sage_x3/f/general-discussion/186961/3rd-party-webservice-soap-response (community)
- https://communityhub.sage.com/sage-global-solutions/sage_x3/f/general-discussion/120743/consuming-external-webservice-soap (community)

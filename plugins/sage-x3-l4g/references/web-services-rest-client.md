# REST client — calling external HTTP/JSON APIs from L4G

How X3 code consumes an external REST API: the Syracuse "Outgoing REST web services" record, the
`ASYRRESTCLI.EXEC_REST_WS` call (and `EXEC_REST_WSCLB` for long headers), building JSON with `escjson`,
parsing it with `ParseInstance` / `Select$` / `Contains$`, retries, pagination and logging. For XML or
SOAP partners see `web-services-soap-client.md`; for exposing X3 itself see `web-services-rest.md`.

## Contents
- [Configure the outgoing REST web service](#configure-the-outgoing-rest-web-service)
- [EXEC_REST_WS](#exec_rest_ws)
- [EXEC_REST_WSCLB for long headers](#exec_rest_wsclb-for-long-headers)
- [Building JSON bodies](#building-json-bodies)
- [Parsing JSON responses](#parsing-json-responses)
- [Retry, backoff, timeouts](#retry-backoff-timeouts)
- [Full example: YREST_GET_RATE](#full-example-yrest_get_rate)
- [Pagination](#pagination)
- [Authentication patterns](#authentication-patterns)
- [Debugging](#debugging)
- [Gotchas](#gotchas)
- [Sources](#sources)

## Configure the outgoing REST web service

One record per partner, in Syracuse (administration page `restWebService`; menu Administration >
Administration > Web Services > Rest web services per a Sage partner deck, community-hosted).

| Field | Meaning (Sage) |
|---|---|
| Name | Mandatory, unique; the `NAME` argument of the call |
| Base Url | Prefix of every call; the call adds a sub-URL |
| Content type | XML or JSON |
| Authentication | None or Basic |
| Parameters | Default key/value URL parameters, overridable per call |
| Headers | Default HTTP headers (accept, accept-language...), overridable per call |
| CA certificates, Certificates | Certificates of the site, required for a secure (TLS) connection |

The **Test GET** action calls the service and shows the HTTP status. A Sage-verified community answer
states that `ASYRRESTCLI` only accepts and returns JSON whatever the Content type: for XML APIs use
`web-services-soap-client.md`.

## EXEC_REST_WS

`HTTPSTATUS = func ASYRRESTCLI.EXEC_REST_WS(NAME, HTTPMETHOD, SUBURL, PARAM_COD, PARAM_VAL, HEADER_COD,
HEADER_VAL, DATA, FUTURE, RETURNS, RESHEAD, RESBODY)` — available from 7.1, works in Classic and
native V7+ code, returns the HTTP status.

| Argument | Declared as | Content |
|---|---|---|
| `NAME` | Value Char | Outgoing REST web service name |
| `HTTPMETHOD` | Value Clbfile | `GET`, `PUT`, `POST` or `DELETE` |
| `SUBURL` | Value Char | Appended to the Base Url |
| `PARAM_COD`, `PARAM_VAL` | Value Char arrays | Extra URL parameter names / values |
| `HEADER_COD`, `HEADER_VAL` | Value Char arrays | Extra header names / values |
| `DATA` | Value Clbfile | JSON body for POST/PUT (Sage passes `"{}"` on GET) |
| `FUTURE` | Value Integer | 1 = 'future' mode, 0 = 'wait' mode |
| `RETURNS` | Value Char | Empty = whole JSON in `RESBODY`; a property name = only its value |
| `RESHEAD`, `RESBODY` | Variable Clbfile | Response header and body |

- Values in `PARAM_VAL` / `HEADER_VAL` are **JSON constants**: `'"application/json"'` for a string,
  `"true"` for a boolean, `"3.1415926"` for a number, `'"2014-07-14"'` for a date. Call-time entries
  replace same-named defaults of the record and add the others.
- Keep `FUTURE` = 0. Future mode needs a later retrieval call that the online help does not document.
- Community-reported: one user could not get `PARAM_COD`/`PARAM_VAL` accepted on a GET and appended
  `?search=r2` to `SUBURL` instead; `RETURNS` failed on a property name containing hyphens.

## EXEC_REST_WSCLB for long headers

Header and parameter values above are `Char` (255 characters max), too short for long OAuth2 bearer
tokens (community report: an 800-character token). A Sage team member on Community Hub and a Sage
partner deck describe
`EXEC_REST_WSCLB`, added in V11 patch 17 and V12 patch 23 (2020 R3), not yet in the online help:

`HTTPSTATUS = func ASYRRESTCLI.EXEC_REST_WSCLB(NAME, HTTPMETHOD, SUBURL, PARAMS, HEADERS, DATA, FUTURE,
RETURNS, RESHEAD, RESBODY)` where `PARAMS` and `HEADERS` are Clbfile JSON objects
`{"code1":"val1","code2":"val2"}` (`"{}"` when empty).

```l4g
# Script YRESTORD - posts an order to a partner API protected by a bearer token
Funprog YREST_POST_ORDER(TOKEN, ORDNUM, CUSTNAME, AMOUNT, ORDDAT)
Value Clbfile TOKEN()
Value Char    ORDNUM(), CUSTNAME()
Value Decimal AMOUNT
Value Date    ORDDAT
Local Clbfile PARAMS(0), HEADERS(1), BODY(1), RESHEAD(0), RESBODY(0)
Local Integer HTTPSTA
Local Char    STA(10)
  PARAMS  = "{}"
  HEADERS = '{"Accept":"application/json","Content-Type":"application/json",'
  Append HEADERS, '"Authorization":"Bearer ' + TOKEN + '"}'
  BODY = '{"orderNumber":"' + escjson(ORDNUM) + '",'
  Append BODY, '"customer":"' + escjson(CUSTNAME) + '",'
  Append BODY, '"amount":' + num$(AMOUNT) + ','
  Append BODY, '"orderDate":"' + format$("D:4Y[-]2M[-]2D", ORDDAT) + '"}'
  HTTPSTA = func ASYRRESTCLI.EXEC_REST_WSCLB(
& "YPARTNER", "POST", "/orders", PARAMS, HEADERS, BODY, 0, "", RESHEAD, RESBODY)
  STA = "KO"
  If HTTPSTA = 200 or HTTPSTA = 201
    STA = "OK"
  Endif
  Call YINTLOG_WRITE("OUT", "YPARTNER", "POST /orders", ORDNUM, HTTPSTA, STA, BODY, RESBODY) From YINTLOGLIB
End HTTPSTA
```

`HEADERS` is not logged: it carries the token.

## Building JSON bodies

- Strings: `escjson(VALUE)` escapes quotes, backslashes and control characters (ECMA-404); wrap the
  result in double quotes yourself. `unescjson` reverses it.
- Numbers: `num$(VALUE)` (plain decimal, no spaces). Dates: `format$("D:4Y[-]2M[-]2D", DATE)`.
- Build in a `Clbfile` with `Append`: no 255-character limit and fast on long strings.
- `DATA` may be the object (`'{"age":25}'`) or the stringified object (`'"{\"age\":25}"'`).

## Parsing JSON responses

- **One flat property**: `RETURNS = "price"` puts only that value in `RESBODY` (Sage's example, then
  `val(RESBODY)`).
- **Native parser** (4GL pages in the V12 online help):

| Instruction | Syntax | Path dialect | Result |
|---|---|---|---|
| `ParseInstance` | `ParseInstance OBJ With JSON` after `Local Instance OBJ Using OBJECT` | — | Documented codes 0, -6, -10, -26 |
| `Select$` | `TXT = OBJ.Select$("$.rates.USD")` | JSONPath (`$.a.b`, `$.list[0].x`) | String |
| `Contains$` | `R = OBJ.Contains$("/rates/USD")` | JSON pointer (`/a/b`, `/list/0`) | Integer: **0 = present**, -6 = absent |
| `Get$` | `R = OBJ.Get$("/bar", DEST)` | JSON pointer | Value copied into `DEST` |

Release with `FreeGroup OBJ`. The pages list status codes without saying how an instruction exposes
them: test `Contains$` before `Select$`. Community-reported: announced in the V12.34 release notes,
said by a Sage reply to be available since 2023 R2, and dependent on the runtime version; JSON payload
size is limited (limit not published); property names with `$` need `OBJ.Select$("$.['$uuid']")`; one
user saw `Select$` return nothing in batch with accented characters. Without the parser, fall back to
`instr`/`mid$` as in `web-services-soap-client.md`.

## Retry, backoff, timeouts

Neither `EXEC_REST_WS` nor the outgoing record documents a timeout. Retry only transient answers (429,
5xx) and idempotent calls, double the `Sleep` between attempts, cap the attempts, and run slow partners
in batch (`batch-scheduling.md`) because `Sleep` blocks the session.

## Full example: YREST_GET_RATE

```l4g
# Script YRESTRATE - one exchange rate from an external JSON API
# Outgoing REST web service "YFXRATES": Base Url https://api.rates.example/v1, JSON, no auth
# Expected answer: {"base":"EUR","rates":{"USD":1.0832}}
Funprog YREST_GET_RATE(BASECUR, TARGETCUR)
Value Char BASECUR(), TARGETCUR()
Local Char     PCOD(100)(1..10), PVAL(255)(1..10), HCOD(100)(1..10), HVAL(255)(1..10)
Local Char     SUBURL(255), TXT(50), STA(10)
Local Clbfile  RESHEAD(0), RESBODY(0)
Local Integer  HTTPSTA, TRY, WAIT
Local Decimal  RATE
Local Instance OBJ Using OBJECT
  SUBURL = "/latest?base=" + BASECUR + "&symbols=" + TARGETCUR
  HCOD(1) = "Accept" : HVAL(1) = '"application/json"'
  WAIT = 2
  For TRY = 1 To 3
    HTTPSTA = func ASYRRESTCLI.EXEC_REST_WS(
& "YFXRATES", "GET", SUBURL, PCOD, PVAL, HCOD, HVAL, "{}", 0, "", RESHEAD, RESBODY)
    If HTTPSTA <> 429 and HTTPSTA < 500
      Break
    Endif
    If TRY < 3
      Sleep WAIT
      WAIT = WAIT * 2
    Endif
  Next TRY
  RATE = 0
  STA = "KO"
  If HTTPSTA = 200
    ParseInstance OBJ With RESBODY
    If OBJ.Contains$("/rates/" + TARGETCUR) = 0
      TXT  = OBJ.Select$("$.rates." + TARGETCUR)
      RATE = val(TXT)
      STA  = "OK"
    Endif
    FreeGroup OBJ
  Endif
  Call YINTLOG_WRITE("OUT", "YFXRATES", "GET " + SUBURL, "", HTTPSTA, STA, "", RESBODY) From YINTLOGLIB
End RATE
```

Currency codes are safe in a URL; encode any free text placed in `SUBURL` yourself.

## Pagination

Follow the partner's cursor or `next` link, cap the number of pages, and log each page. Walk JSON arrays
by index until `Contains$` reports the element absent:

```l4g
# Inside a page loop; OBJ parsed from {"items":[{"id":"A1"},{"id":"A2"}],"next":"c2"}
  I = 0
  While OBJ.Contains$("/items/" + num$(I)) = 0
    ITEMID = OBJ.Select$("$.items[" + num$(I) + "].id")
    # process ITEMID
    I += 1
  Wend
  NEXTCURSOR = OBJ.Select$("$.next")
  FreeGroup OBJ
  OBJ = null
```

## Authentication patterns

| Partner expects | Do |
|---|---|
| Basic | Set Authentication = Basic on the outgoing record; no credentials in source |
| API key header | Default header on the record, or `HEADER_COD`/`HEADER_VAL` (JSON-quoted value) |
| OAuth2 bearer | Get the token with a first call (community example: `RETURNS` = `"access_token"` into a Clbfile), then `EXEC_REST_WSCLB` with `"Authorization":"Bearer ..."`; cache it until expiry |
| JWT signed for a connected application | `GET_TOKEN(CLIENTID, PARAMS, RESHEAD, RESBODY)` from library `ASYRCONNAPP` (V11 page: "Func", sample uses `Call ... From ASYRCONNAPP`; PARAMS is YAML) |

Community-reported: token endpoints that require `application/x-www-form-urlencoded` or form-data
bodies could not be called through `ASYRRESTCLI` (raw JSON only).

## Debugging

- Use **Test GET** on the record, then Postman with the same URL and headers.
- `RESHEAD` is a JSON string (the ASYRWEBSER page shows `statusCode`, `message`, `content-type`,
  `content-length`); read it when the status alone does not explain a failure.
- Community-reported: set the Syracuse global settings log levels *REST*, *HTTP out* and *HTTP in* to
  "Silly" to see the exact request Syracuse sends.
- Every call goes to `YINTLOG` (`web-services-integration.md`).

## Gotchas

- Unquoted header values (`HVAL(1) = "application/json"`) are not JSON constants: quote them.
- 255-character limit on `EXEC_REST_WS` parameter and header values: use `EXEC_REST_WSCLB`.
- Community-reported: `EXEC_REST_WS` hung on responses around 420 kB on one development server; page
  large results.
- `Contains$` returns 0 when the path **exists** — the opposite of a boolean test.
- `Select$` uses JSONPath (`$.a.b`), `Contains$`/`Get$` use JSON pointer (`/a/b`).
- No documented timeout: a dead partner blocks the session.

See also: `web-services-integration.md`, `web-services-soap-client.md`, `builtin-functions.md`,
`security-permissions.md`.

## Sources
- https://online-help.sagex3.com/erp/12/en-us/Content/V7DEV/api-guide_api-asyrrestcli.html
- https://online-help.sagex3.com/erp/11/en-US/V7DEV/api-guide_api-asyrrestcli.html
- https://online-help.sagex3.com/erp/12/en-us/Content/V7DEV/administration-reference_outgoing-rest-web-services.html
- https://online-help.sagex3.com/erp/12/en-us/Content/V7DEV/4gl_parse-instance.html
- https://online-help.sagex3.com/erp/12/en-us/Content/V7DEV/4gl_select.html
- https://online-help.sagex3.com/erp/12/en-us/Content/V7DEV/4gl_contains.html
- https://online-help.sagex3.com/erp/12/en-us/Content/V7DEV/4gl_get$.html
- https://online-help.sagex3.com/erp/12/en-us/Content/V7DEV/4gl_escjson.html
- https://online-help.sagex3.com/erp/12/en-us/Content/V7DEV/4gl_freegroup.html
- https://online-help.sagex3.com/erp/12/en-us/Content/V7DEV/4gl_sleep.html
- https://online-help.sagex3.com/erp/12/en-us/Content/V7DEV/4gl_append.html
- https://online-help.sagex3.com/erp/11/en-US/V7DEV/api-guide_api-asyrconnapp.html
- https://online-help.sagex3.com/erp/12/en-us/Content/V7DEV/api-guide_api-asyrwebser.html
- https://communityhub.sage.com/fr/sage-x3/f/technique/182920/x3v12-2021r2-appel-webservice-rest-avec-identification-oauth2-header-trop-court-via-asyrrestcli-exec_rest_ws (community)
- https://communityhub.sage.com/fr/sage-x3/f/technique/217700/exec_rest_ws-et-format-json (community)
- https://communityhub.sage.com/us/sage_x3/f/general-discussion/212042/v12-34-native-json-parser (community)
- https://communityhub.sage.com/us/sage_x3/f/general-discussion/220325/connecting-to-an-external-rest-with-an-xml-header (community)
- https://communityhub.sage.com/us/sage_x3/f/general-discussion/178221/exec_rest_ws-stops-responding-rest-web-service-gets-stuck (community)
- https://www.greytrix.com/blogs/sagex3/?p=25177 (community)
- https://communityhub.sage.com/cfs-file/__key/communityserver-discussions-components-files/40/7848.04-_2D00_-REST-Web-Services.pdf (Sage BP-day deck, community-hosted)

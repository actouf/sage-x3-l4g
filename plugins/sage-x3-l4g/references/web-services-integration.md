# Web services and integration — router

Start here for any integration question: pick the surface, then open the protocol file. This file also
owns the single integration-log table (`YINTLOG`) that every inbound and outbound call writes to, the
cross-cutting gotchas, and the go-live checklist.

## Contents
- [Pick the surface](#pick-the-surface)
- [The integration log table](#the-integration-log-table)
- [Gotchas](#gotchas)
- [Go-live checklist](#go-live-checklist)
- [Sources](#sources)

## Pick the surface

| Direction | Need | Mechanism | Read |
|---|---|---|---|
| In | Read any entity; create/update entities built on classes and representations | Syracuse Web API, JSON: `/api1/x3/erp/<ENDPOINT>/<CLASS>?representation=<REP>.$<facet>` | `web-services-rest.md` |
| In | Call a Classic object or a 4GL subprogram | Classic SOAP (`CAdxWebServiceXmlCC`, RPC/encoded) through a Syracuse Classic SOAP pool | `web-services-soap.md` |
| Out | Call an external JSON/REST API | `func ASYRRESTCLI.EXEC_REST_WS` / `EXEC_REST_WSCLB` + Syracuse "Outgoing REST web services" record | `web-services-rest-client.md` |
| Out | Call an external SOAP/XML service | `func ASYRWEBSER.EXEC_HTTP` with a hand-built envelope (no dedicated SOAP client is documented) | `web-services-soap-client.md` |
| Both | Batch files | Import/export templates, sequential files (on-premise only) | `imports-exports.md`, `sequential-files.md` |
| In | GraphQL API of Sage X3 Services | Nodes and packages declared in the dictionary; custom code in TypeScript, not 4GL | Below |

Sage's own rule (Web services overview): the Web API can read data from all modules; updates go through
the Web API for modules rebuilt on classes/representations; SOAP serves modules still on the Classic
interface and supports read and update. Sage X3 Online accepts only OAuth2 for web services and does
not allow file-based integration.

**Sage X3 Services (GraphQL).** A separate component (Sage X3 2021 R2 or later, Windows Server 2019 or
2022 only, required by Mobile Automation) that serves a GraphQL schema built from API nodes. Packages
(GESAPACK) "structure the nodes dictionary and the GraphQL schema"; node bindings (GESANODEB) map nodes to
X3 data models, scripts, imports, windows or views, and a node whose binding is not published "is hidden
in the GraphQL schema". Specific activity codes (X, Y, Z) must be linked to a package. Computed properties
take TypeScript written in the Sage X3 Services development environment: this skill covers 4GL only.

## The integration log table

One custom table, created in the table dictionary (GESATB), shared by every integration. Abbreviation
`YIL`; index `YIL0` = `LOGID` (unique), `YIL1` = `CORRID` (not unique, for idempotency look-ups).

| Column | GESATB type | Content |
|---|---|---|
| `LOGID` | L (long integer) | `uniqid([F:YIL])` |
| `LOGDATTIM` | ADATIM (datetime) | `datetime$` (GMT) |
| `USR` | AUS (user code) | `GACTX.USER` |
| `DIRECTION` | A, 3 | `IN` / `OUT` |
| `CHANNEL` | A, 30 | Outgoing service name, SOAP publication, or class/representation |
| `OPERATION` | A, 80 | HTTP method + sub-URL, SOAP operation, or facet |
| `CORRID` | A, 50 | Partner correlation / idempotency key |
| `HTTPSTA` | C (short integer) | HTTP status (0 when none) |
| `STA` | A, 10 | `OK` / `KO` / `RETRY` |
| `REQBODY`, `RESBODY` | ACB (CLOB) | Payloads with secrets removed |

```l4g
# Script YINTLOGLIB - one row per call. Call it AFTER the business Commit/Rollback:
# inside an open transaction the row joins it and disappears on Rollback.
Subprog YINTLOG_WRITE(DIRECTION, CHANNEL, OPERATION, CORRID, HTTPSTA, STA, REQBODY, RESBODY)
Value Char    DIRECTION(), CHANNEL(), OPERATION(), CORRID(), STA()
Value Integer HTTPSTA
Value Clbfile REQBODY(), RESBODY()
Local File YINTLOG [YIL]
Local Shortint TRANS_OPEN
  Raz [F:YIL]
  [F:YIL]LOGID     = uniqid([F:YIL])
  [F:YIL]LOGDATTIM = datetime$
  [F:YIL]USR       = GACTX.USER
  # Parameters share the column names: [L] makes the parameter explicit (4gl_default.html)
  [F:YIL]DIRECTION = left$([L]DIRECTION, 3)
  [F:YIL]CHANNEL   = left$([L]CHANNEL, 30)
  [F:YIL]OPERATION = left$([L]OPERATION, 80)
  [F:YIL]CORRID    = left$([L]CORRID, 50)
  [F:YIL]HTTPSTA   = [L]HTTPSTA
  [F:YIL]STA       = left$([L]STA, 10)
  [F:YIL]REQBODY   = [L]REQBODY
  [F:YIL]RESBODY   = [L]RESBODY
  [L]TRANS_OPEN = adxlog
  If [L]TRANS_OPEN = 0 : Trbegin [YIL] : Endif
  Write [YIL]
  If fstat
    If [L]TRANS_OPEN = 0 and adxlog = 1 : Rollback : Endif
    End
  Endif
  If [L]TRANS_OPEN = 0 : Commit : Endif
End
```

`Write` must run inside a transaction (4gl_write.html), hence the `adxlog` idiom from `database.md`.
The default search order for a variable without class is `[S], [L], [V], [M], [F]` (4gl_default.html), so
the unprefixed names would already resolve to the parameters; the `[L]` prefix states the intent.
Purge old rows with a scheduled task (`batch-scheduling.md`); retention rules live in `audit-compliance.md`.

## Gotchas

- **TLS** — Basic authentication sends a base64 (not encrypted) password: Sage requires the Syracuse
  server in HTTPS for production. For outbound calls, add the partner's CA certificates / certificates
  to the Outgoing REST web service record.
- **Encoding** — escape every interpolated value: `escjson` for JSON, a character loop for XML
  (`web-services-soap-client.md`). SOAP `codeLang` takes an X3 code (FRA, ENG); the `Accept-Language`
  header takes ISO codes (fr-FR).
- **Payload size** — inbound SOAP volume is metered by the licence (`WSSIZELIMIT` per `WSPERIOD`, then
  `WSGRACELIMIT` slow-down, then stop). Outbound limits are community-reported only (see
  `web-services-rest-client.md`): page through large data instead of pulling it in one call.
- **Credentials** — inbound calls run as a Syracuse user mapped to an X3 user: give it a dedicated,
  minimal profile (`security-permissions.md`). Outbound Basic credentials live in the Outgoing REST web
  service record, not in source. SOAP `codeUser` is ignored.
- **Header length** — `EXEC_REST_WS` header values are `Char` (255 max): long bearer tokens need
  `EXEC_REST_WSCLB`.
- **Timeouts** — no timeout parameter is documented on `EXEC_REST_WS`, `EXEC_HTTP`, or the outgoing
  service record. Inbound SOAP has pool queue / unused / life timeouts (`web-services-soap.md`).

## Go-live checklist

1. Surface chosen from the table above; signature frozen (publish a new name rather than change one).
2. Inbound REST: class + representation validated, endpoint mapped to the folder. Inbound SOAP: GESASU
   "Web services" flag, GESAWE publication, pool started, host web-service child processes > 0.
3. Technical user with a minimal function profile; HTTPS; auth mode enabled in Syracuse.
4. Every input validated in code; business errors returned as data (SOAP status/messages, REST
   `$diagnoses`), never as UI boxes.
5. Database writes follow the transaction idiom in `database.md`.
6. Every call logged through `YINTLOG_WRITE`; partner correlation key stored in `CORRID` and checked
   before acting (idempotency).
7. Tested outside X3 first (Postman / SoapUI), then from X3.

See also: `debugging-traces.md`, `security-permissions.md`, `database.md`, `development-workflow.md`.

## Sources
- https://online-help.sagex3.com/erp/12/en-us/Content/V7DEV/integration-guide_ws-overview.html
- https://online-help.sagex3.com/erp/12/en-us/Content/V7DEV/integration-guide_index.html
- https://online-help.sagex3.com/erp/12/en-us/Content/V7DEV/integration-guide_file-integration.html
- https://online-help.sagex3.com/erp/12/en-us/Content/V7DEV/integration-guide_ws-basic-authentication.html
- https://online-help.sagex3.com/erp/12/en-us/Content/V7DEV/administration-reference_outgoing-rest-web-services.html
- https://online-help.sagex3.com/erp/12/en-us/Content/V7DEV/api-guide_soap-web-services.html
- https://online-help.sagex3.com/erp/12/en-us/Content/FCT/GESATB.htm
- https://online-help.sagex3.com/erp/12/en-us/Content/V7DEV/developer-guide_technical-columns-of-database.html
- https://online-help.sagex3.com/erp/12/en-us/Content/V7DEV/4gl_write.html
- https://online-help.sagex3.com/erp/12/en-us/Content/V7DEV/4gl_default.html
- https://online-help.sagex3.com/erp/12/en-us/Content/V7DEV/4gl_uniqid.html
- https://online-help.sagex3.com/erp/12/en-us/Content/V7DEV/4gl_datetime$.html
- https://online-help.sagex3.com/erp/11/en-US/V7DEV/how-to_how-to-get-information-relating-to-the-current-context.html
- https://online-help.sagex3.com/erp/12/en-us/Content/V7DEV/getting-started_Sage-X3-Services-installation.html
- https://online-help.sagex3.com/erp/12/en-us/Content/FCT/GESAPACK.htm
- https://online-help.sagex3.com/erp/12/en-us/Content/FCT/GESANODEB.htm

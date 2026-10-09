# Classic SOAP web services — publishing X3 subprograms and objects

How to expose a 4GL subprogram or a Classic object as a SOAP web service in V12: declaration (GESASU),
publication (GESAWE), the Syracuse side (host, Classic SOAP pool), the generic `CAdxWebServiceXmlCC`
endpoint, call context, XML parameters, authentication, responses and debugging. For calling an
external SOAP service from X3 see `web-services-soap-client.md`; for choosing SOAP vs REST see
`web-services-integration.md`.

## Contents
- [When SOAP is the right surface](#when-soap-is-the-right-surface)
- [1. Write the subprogram](#1-write-the-subprogram)
- [2. Declare it in GESASU](#2-declare-it-in-gesasu)
- [3. Publish it in GESAWE](#3-publish-it-in-gesawe)
- [4. Syracuse side: host and Classic SOAP pool](#4-syracuse-side-host-and-classic-soap-pool)
- [Calling the service](#calling-the-service)
- [Authentication](#authentication)
- [Response: status and messages](#response-status-and-messages)
- [Debugging](#debugging)
- [Gotchas](#gotchas)
- [Sources](#sources)

## When SOAP is the right surface

Sage positions SOAP for modules still on the Classic interface (objects, masks, subprograms); entities
rebuilt on classes and representations are exposed through the REST Web API (`web-services-rest.md`).
SOAP services are RPC/encoded, use the same format as V6, and run in dedicated Classic sessions held by
a Syracuse pool. A web service is either a **subprogram** (its parameters become the service fields) or
an **object** + transaction (its screen fields become the service fields).

## 1. Write the subprogram

No user is in front of a web-service session: return errors through output parameters instead of
`Infbox` / `Errbox` (deprecated Classic UI instructions).

```l4g
# Script YWSBPC - published as web service YWSBPC
Subprog YWS_BPCINFO(CUSTCODE, CUSTNAME, RETSTA, RETMSG)
Value    Char    CUSTCODE()
Variable Char    CUSTNAME()
Variable Integer RETSTA        : # 1 = OK, 0 = error
Variable Char    RETMSG()
Local File BPCUSTOMER [BPC]
  Raz [L]CUSTNAME, [L]RETMSG
  [L]RETSTA = 0
  If [L]CUSTCODE = ""
    [L]RETMSG = "CUSTCODE is mandatory"           : # literal for brevity — use mess() in real code
    End
  Endif
  Read [BPC]BPC0 = [L]CUSTCODE
  If fstat
    [L]RETMSG = "Unknown customer " + [L]CUSTCODE : # literal for brevity — use mess() in real code
    End
  Endif
  [L]CUSTNAME = [F:BPC]BPCNAM
  [L]RETSTA = 1
End
```

Writes follow the transaction idiom in `database.md`; log the call with `YINTLOG_WRITE`
(`web-services-integration.md`).

## 2. Declare it in GESASU

The Subprograms dictionary (GESASU) is what makes a subprogram eligible for web-service generation.

| Field | Use |
|---|---|
| File (PRG) / Subprograms (SUBPRG) | Script and subprogram name |
| Activity code (CODACT) | X/Y/Z activity code for custom elements |
| Web services (WEBS) | Check box: the subprogram can be generated as a web service |
| Function (FONCTION) | Ticked for a `Funprog` (called by `func`), cleared for a `Subprog` |
| Parameters grid | Code (10 chars), Type (Char, Integer, Decimal, Date, Local menu, Clob, Blob), Dim., Argument type (by address = `Variable`, by value = `Value`) |

The **Parameter Definitions** action analyses the subprogram and fills code, type and argument type;
you complete titles and dimensions. **Option / Verification** checks grid vs source. The
**Publication** button (active when "Web services" is ticked) publishes the subprogram directly.

## 3. Publish it in GESAWE

| Field | Use |
|---|---|
| Publication name (PUBLI) | The `publicName` callers send |
| Type (TYPOBJ) | Object or sub-program |
| Object (OBJET) / Transaction (VARIANTE) / Invisible fields | Object publications |
| Script (PRG) / Subprograms (SUBPRG) | Sub-program publications |
| Mapping tab | Groups, fields, type, length, dimension, mandatory flag, min/max, pattern; select/unselect and rename groups |

The **Publication** button generates the wrapper program (`WJ` + publication name) and the XML/XSD
descriptions (**XML view**, **XSD view**). **Publication / Global publication** republishes in bulk.
Republish after any signature change.

## 4. Syracuse side: host and Classic SOAP pool

- **Host** — the host record's *Number of web services child processes* defaults to 0; until it is
  set, every call fails with HTTP 500 `No web services accepted`. Each pool is duplicated per web
  services child process.
- **Classic SOAP pool** (administration page `soapClassicPool`; tester and pool lists are under
  Administration > Administration > Web Services, community-reported path):

| Field | Meaning (Sage) |
|---|---|
| Alias | Pool name, sent as `poolAlias` in every call context |
| Auto start / Stopped manually | Start with Syracuse and restart after failure / stop only manually |
| Endpoint | X3 endpoint (folder) used for every request |
| X3 runtime tags | Restrict the runtimes the pool can connect to |
| Locale / User | Language and user for channel initialisation; the call context can change them |
| Maximum size | Max clients per node.js process; a new client starts only when all are busy |
| Initialization size | Clients created at start per process; above 8, start/stop may time out |
| Unused timeout (mn) | Default 20: idle channels stop, down to the initialization size |
| Life timeout (mn) | Default 720: channels are recycled after this lifetime |
| Queue timeout (mn) | Requests queued longer are rejected with an error |

**Start/Update** applies size, endpoint, locale or user changes to existing channels; it fails if the
host is not set up with dedicated web sessions. Pools can be driven by REST (Basic or bearer auth):
`POST /api1/syracuse/collaboration/syracuse/soapClassicPools(alias eq 'AWS')/$service/start` (also
`/$service/stop`, `.../soapClassicPools/$service/startAll` and `stopAll`). The licence does not cap
channel count; it meters exchanged volume (`WSSIZELIMIT`, `WSPERIOD`, `WSGRACELIMIT`,
`WSGRACESLOWDOWN`).

## Calling the service

- Endpoint: `http://<server>:<port>/soap-generic/syracuse/collaboration/syracuse/CAdxWebServiceXmlCC`
- WSDL: `http://<server>:<port>/soap-wsdl/syracuse/collaboration/syracuse/CAdxWebServiceXmlCC?wsdl`
  (namespace `http://www.adonix.com/WSS`). It describes the generic operations only; per-service
  layouts come from `getDescription`.
- Operations: `run` (subprogram), `query` (object left list, `listSize`), `read`, `save` (create),
  `modify`, `delete`, `getDescription` — the tester lists twelve operations (community-reported).

| `callContext` element | Use |
|---|---|
| `codeLang` | X3 language code (FRA, ENG); optional if the `Accept-Language` header (ISO) is sent |
| `poolAlias` | Mandatory: pool Alias |
| `poolId` | Optional: force one client, e.g. to debug with breakpoints on that process |
| `requestConfig` | `&`-separated: `adxwss.trace.on=on`, `adxwss.optreturn=JSON` (default XML), `adxwss.beautify=true` |
| `codeUser`, `password` | Deprecated, no longer used |

```xml
<soapenv:Envelope xmlns:soapenv="http://schemas.xmlsoap.org/soap/envelope/"
    xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema"
    xmlns:wss="http://www.adonix.com/WSS">
  <soapenv:Header/>
  <soapenv:Body>
    <wss:run soapenv:encodingStyle="http://schemas.xmlsoap.org/soap/encoding/">
      <callContext xsi:type="wss:CAdxCallContext">
        <codeLang xsi:type="xsd:string">ENG</codeLang>
        <poolAlias xsi:type="xsd:string">YWSPOOL</poolAlias>
        <poolId xsi:type="xsd:string"></poolId>
        <requestConfig xsi:type="xsd:string">adxwss.optreturn=XML</requestConfig>
      </callContext>
      <publicName xsi:type="xsd:string">YWSBPC</publicName>
      <inputXml xsi:type="xsd:string"><![CDATA[<PARAM>
        <GRP ID="GRP1"><FLD NAME="CUSTCODE">C0001</FLD></GRP>
      </PARAM>]]></inputXml>
    </wss:run>
  </soapenv:Body>
</soapenv:Envelope>
```

Parameter XML: scalar fields are `<FLD NAME="...">` inside a `<GRP ID="...">`; array parameters become
`<TAB ID="..." SIZE="n">` with one `<LIN NUM="i">` per row (community-reported for subprograms; Sage's
`save` example uses the same `TAB`/`LIN NUM`/`FLD NAME` shape). Group IDs come from the GESAWE Mapping
tab — copy them from `getDescription` or the tester. Dates travel as `YYYYMMDD` (Sage's `save`
example: `20330127`).

## Authentication

The X3 user is resolved from the Syracuse user's endpoint login map, not from the call context. Send an
`Authorization` header: `Basic <base64(login:password)>` or a bearer token (Sage's examples show both).
Authentication modes are enabled in Syracuse (`web-services-rest.md`, Authentication); Sage X3 Online
accepts OAuth2 only.

## Response: status and messages

HTTP 200 only means the request was authenticated and well-formed. Read the body: `status` = 1 (ran
without error) or 0 (errors occurred), `messages` (array of `type` + `message`), `resultXml` (output
parameters, XML or JSON per `adxwss.optreturn`), `technicalInfos` (durations, pool entry,
`traceRequest` when tracing is on). HTTP 401 = authentication failed.

## Debugging

| Symptom | Cause (documented) | Fix |
|---|---|---|
| HTTP 500 `No web services accepted` | Host web services child processes = 0 | Set it on the host record |
| Pool start fails, host setup message | Host lacks dedicated web sessions | Fix the host, then Start/Update |
| HTTP 200, `status` 0, `No classic web service pool match to 'X'` | Wrong `poolAlias` or pool stopped | Check Alias, start the pool |
| HTTP 401 `Authentication failed...` / `Error 30: Invalid token` | Bad Basic credentials / bad bearer token | Fix credentials or token |
| Request rejected after waiting | All channels busy beyond Queue timeout | Raise Maximum size or shorten the service |
| Timeout while starting/stopping the pool | Initialization size above 8 | Lower it or raise the request timeout |
| Input XML refused / deserialization error | Arrays sent as scalars, wrong group IDs (community-reported) | Rebuild from `getDescription` |
| Need detail of the server-side run | — | `requestConfig` `adxwss.trace.on=on`; `poolId` + debugger |

## Gotchas

- `codeUser` in old clients is silently ignored — the authenticated Syracuse user decides.
- Changing a subprogram signature requires GESASU update + GESAWE republication, and breaks deployed
  clients: publish a new name instead.
- Pool settings changes (size, endpoint, locale, user) need **Start/Update** to reach running channels.
- An HTTP 200 with `status` 0 is a failure; always test the body status and `messages`.

See also: `web-services-integration.md`, `web-services-soap-client.md`, `web-services-rest.md`,
`security-permissions.md`, `function-codes.md`.

## Sources
- https://online-help.sagex3.com/erp/12/en-us/Content/V7DEV/api-guide_soap-web-services.html
- https://lvexpertisex3.com/x3help/ENG/V7DEV/api-guide_soap-web-services.html
- https://online-help.sagex3.com/erp/12/en-us/Content/V7DEV/administration-reference_soapClassicPool.html
- https://online-help.sagex3.com/erp/12/en-us/Content/V7DEV/administration-reference_host.html
- https://online-help.sagex3.com/erp/12/en-us/Content/FCT/GESASU.htm
- https://online-help.sagex3.com/erp/12/en-us/Content/FCT/GESAWE.htm
- https://online-help.sagex3.com/erp/12/en-us/Content/V7DEV/integration-guide_ws-overview.html
- https://communityhub.sage.com/sage-global-solutions/sage_x3/f/general-discussion/76797/multi-dimensional-parameters-in-subprogram-called-as-a-web-service (community)
- https://www.rklesolutions.com/blog/5-days-sage-x3-web-services-v12-day-3 (community)

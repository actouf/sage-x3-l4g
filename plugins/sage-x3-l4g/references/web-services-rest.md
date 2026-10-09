# Syracuse REST Web API — exposing X3 classes and representations

How external systems read and update X3 through the Syracuse Web API (`/api1/`): URL anatomy, facets,
query/filter/paging, read, create, update, delete, operations and links, authentication, responses and
errors, and the SData legacy. The 4GL side lives in classes and representations (`v12-classes.md`,
`v12-representations.md`); calling external APIs from X3 is in `web-services-rest-client.md`.

## Contents
- [What is exposed](#what-is-exposed)
- [URL anatomy](#url-anatomy)
- [Query: list, filter, sort, page](#query-list-filter-sort-page)
- [Read one resource](#read-one-resource)
- [Create, update, delete](#create-update-delete)
- [Operations and links](#operations-and-links)
- [Authentication](#authentication)
- [Errors and status codes](#errors-and-status-codes)
- [SData and legacy URLs](#sdata-and-legacy-urls)
- [Gotchas](#gotchas)
- [Sources](#sources)

## What is exposed

The Web API is available on every representation configured in the dictionaries: there is no separate
publication step. Sage ships read-only representations on all resources, so any module can be read;
create/update/delete need a class and a representation whose facets allow them. A custom integration
therefore means: custom table → class (GESACLA) → representation with the facets the partner needs →
validation. Business rules defined in the class and representation run before saving, so the payload
returned can differ from the one submitted.

## URL anatomy

```
https://<server>:<port>/api1/x3/erp/<ENDPOINT>/<CLASS>?representation=<REP>.$<facet>&<options>
https://<server>:<port>/api1/x3/erp/<ENDPOINT>/<CLASS>('<KEY>')?representation=<REP>.$<facet>
```

| Part | Meaning |
|---|---|
| `api1` | Web API version; stateless web-service mode |
| `x3/erp` | Application / contract for X3 entities (`syracuse/collaboration/syracuse` for platform entities such as SOAP pools or endpoints) |
| `<ENDPOINT>` | Syracuse endpoint = one X3 folder |
| `<CLASS>` | Class code (standard such as `BPCUSTOMER`, or custom) |
| `('<KEY>')` | Primary key; composite key parts joined with `~` |
| `representation=<REP>.$<facet>` | Mandatory in api1; `<REP>` must be a representation of `<CLASS>` or the call fails |

Facets: `$query` (list), `$details` (one record), `$edit` (update/delete), `$create` (creation),
`$lookup` (selection), `$summary` (summary view).

## Query: list, filter, sort, page

```
GET /api1/x3/erp/SEED/BPCUSTOMER?representation=BPCUSTOMER.$query&count=50
    &where=left(BPCNAM,4) eq 'Test'&orderBy=BPCNAM desc,BPCNUM asc
```

| Option | Effect |
|---|---|
| `count=N` | Page size (default 20); the server may cap it — read `$itemsPerPage` |
| `where=<predicate>` | Filter in api1 syntax: `eq`, functions such as `left(...)`, quoted strings |
| `orderBy=<prop> asc\|desc,...` | Only properties present on the query facet |
| `key=gt.<value>` | Keys greater than a value; used by paging links |

The response is an envelope: `$itemsPerPage`, `$resources` (the rows), `$links` (`$first`, `$prev`,
`$next`, `$last`, plus representation links). Page by following `$links.$next.$url` until `$next` is
absent — never rebuild the URL yourself. URL-encode spaces and quotes in `where` / `orderBy`.

## Read one resource

```
GET /api1/x3/erp/SEED/BPCUSTOMER('C0001')?representation=BPCUSTOMER.$details
```

The payload carries `$uuid`, `$etag`, the properties, child collections as embedded arrays (each line
with its own `$uuid`), and references as two fields: the key (`CUR`) and a `_REF` object (`CUR_REF`
with `$title`, ...). Other `$` properties are internal: ignore them.

## Create, update, delete

| Action | Request | Success |
|---|---|---|
| Template | `GET .../<CLASS>/$template?representation=<REP>.$create` | Defaults from the dictionaries |
| Metadata | `GET .../$prototypes('<REP>.$edit')` | `$properties` with types, lengths, mandatory flags |
| Create | `POST .../<CLASS>?representation=<REP>.$create` + JSON body | 201, `Location` header = new resource URL |
| Update | `PUT .../<CLASS>('<KEY>')?representation=<REP>.$edit` + partial JSON body | 200, new state returned |
| Delete | `DELETE .../<CLASS>('<KEY>')?representation=<REP>.$edit` | 200 |

The template step is optional; remove its `$` keys before posting. An update body may contain only the
changed properties; to touch existing lines, send their `$uuid` (read with `$edit` first). Sage's
API-requests page also shows creation as a POST on `.$edit`. ETag-based concurrency control from SData
2.0 is not available in this Web API.

```
POST /api1/x3/erp/SEED/YSOT?representation=YSOT.$create
Authorization: Basic <base64(login:password)>
Content-Type: application/json

{"SOHNUM":"SO0001","COURIER":"DHL","STATUS":"PICKED"}
```

## Operations and links

Operations declared on the class (dictionary "Methods and Operations") are placed on the
representation as record links; the query feed may return representation-specific links next to the
paging links. The integration guide does not publish a URL pattern for operations: read the link
`$url` from `$links` (or from `$prototypes`) instead of hard-coding one. Operation code goes in the
class script (`v12-classes.md`).

## Authentication

| Mode | Where | Notes |
|---|---|---|
| Basic | On-premise only | `Authorization: Basic base64(user:password)`; HTTPS mandatory in production; the Syracuse user must use basic authentication and be mapped to an X3 user with a suitable profile |
| Client certificate | On-premise only, HTTPS only | No header; the login is the certificate subject's common name; the certificate is declared on the host |
| OAuth2 | Online (only mode) and on-premise | Bearer token; Syracuse needs `auth: ["oauth2","bearer"]` |

Modes are enabled in the `session.auth` array of Syracuse's `nodelocal.js` (for example
`auth: ["basic", "oauth2"]`). With `/api1/`, every call carries the `Authorization` header, no session
cookie is used, and sessions come from a dedicated short-timeout pool. Connected applications (client
ID + secret used to sign JWT tokens; Administration > Administration > Settings > Authentication >
Connected applications per a Sage partner deck) are not mentioned by the api1 integration pages: check
your patch level before relying on them for api1. See `security-permissions.md` for profiles.

## Errors and status codes

- 4xx / 5xx: class, representation or syntax problem (or authentication).
- 200 on a read does **not** prove the record exists: test for `$diagnoses`, for example
  `{"$diagnoses":[{"$severity":"error","$message":"721 : Record does not exist"}]}`.
- 201 on a create only proves the class, representation and body were accepted: success is a payload
  without an error `$diagnoses` entry (Sage's sample ends with a `$links.$save` section).
- Raise business errors from class code with `ASETERROR` (`v12-classes.md`); never with `Infbox`.

## SData and legacy URLs

The Web API is based on SData 2.0 with differences: URLs start with `/api1/` instead of `/sdata/`, and
the representation parameter is mandatory. Sage states that `/sdata/` "must no longer be used in
webservice mode" — it is meant for interactive sessions and consumes a token, even if it seems to work.
Migrate old clients to `/api1/`.

## Gotchas

- Representation not belonging to the class → error; api1 requires both names.
- `count` is a request, not a guarantee: loop on `$links.$next` instead of assuming page sizes.
- Composite keys use `~`, not commas.
- Updating lines without their `$uuid` creates or mismatches lines.
- Online deployments: OAuth2 only, no Basic, no certificates.
- Test interactively: a browser redirects to the login page first; Postman needs an `Authorization`
  header.
- Log inbound calls you handle in custom code through `YINTLOG_WRITE`
  (`web-services-integration.md`).

See also: `web-services-integration.md`, `web-services-soap.md`, `v12-classes.md`,
`v12-representations.md`, `security-permissions.md`.

## Sources
- https://online-help.sagex3.com/erp/12/en-us/Content/V7DEV/integration-guide_ws-overview.html
- https://online-help.sagex3.com/erp/12/en-us/Content/V7DEV/integration-guide_ws-query.html
- https://online-help.sagex3.com/erp/12/en-us/Content/V7DEV/integration-guide_ws-read-details.html
- https://online-help.sagex3.com/erp/12/en-us/Content/V7DEV/integration-guide_ws-create.html
- https://online-help.sagex3.com/erp/12/en-us/Content/V7DEV/integration-guide_ws-update.html
- https://online-help.sagex3.com/erp/12/en-us/Content/V7DEV/integration-guide_ws-delete.html
- https://online-help.sagex3.com/erp/12/en-us/Content/V7DEV/integration-guide_ws-basic-authentication.html
- https://online-help.sagex3.com/erp/12/en-us/Content/V7DEV/integration-guide_ws-certificates-authentication.html
- https://online-help.sagex3.com/erp/12/en-us/Content/V7DEV/integration-guide_ws-oauth2-authentication.html
- https://online-help.sagex3.com/erp/12/en-us/Content/V7DEV/integration-guide_ws-sdata-differences.html
- https://online-help.sagex3.com/erp/12/en-us/Content/V7DEV/api-guide_api-requests.html
- https://online-help.sagex3.com/erp/12/en-us/Content/V7DEV/developer-guide_representations.html
- https://online-help.sagex3.com/erp/12/en-us/Content/V7DEV/developer-guide_classes-dictionaries.html
- https://online-help.sagex3.com/erp/12/en-us/Content/V7DEV/administration-reference_connected-applications.html
- https://communityhub.sage.com/cfs-file/__key/communityserver-discussions-components-files/40/7848.04-_2D00_-REST-Web-Services.pdf (Sage BP-day deck, community-hosted: facet/verb table, `$lookup`, `$summary`, connected-applications menu path)

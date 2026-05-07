# Security and permissions

How access control works in Sage X3 V12, what to check on a custom screen / class / service, and how to avoid the standard footguns. Covers user roles, function profiles (`GESAFP`), function authorisations (`GESAUT`), action authorisations (`GACTION`), folder-level filters, and credential storage.

## The X3 access-control stack

Before getting to L4G specifics, the model itself:

```
User  ──┐
        ├──> Role(s)  ──┐
        ├──> Folder      ├──> Function profile (GESAFP)  ──> Function (GESAFC) ──> ACL on screen / object / service
        └──> Group(s)   ──┘                                                           ↑
                                                                                       └── filtered by GACTION (action-level rights) and Roles (Syracuse)
```

Three layers gate everything:

1. **Authentication** — user identity (Syracuse session token, Basic auth, WS-Security).
2. **Authorisation** — function profile assigned to the user controls which functions (screens, batches, reports, services) are reachable.
3. **Action filter** — even inside an allowed function, the actions visible (`Save`, `Delete`, `Validate`) are filtered by `GACTION`.

REST endpoints inherit the same model — Syracuse maps a role to a set of functions and propagates ACL down to the published representation.

## Function profiles (`GESAFP`)

Assign each user / role a function profile. The profile lists allowed functions (`GESAFC`):

| Function code | Type | Example |
|---------------|------|---------|
| `GESBPC` | Screen | Customer entry |
| `IMP_CUSTOMER` | Import template | Customer import |
| `YWS_CHECK_STOCK` | Web service | Custom service |
| `YIMP_HOOK` | Subprogram | Custom hook |

Custom (`Y`/`Z`) functions must be declared in `GESAFC` — without an entry, no profile can grant access. **Always declare a custom function with the same prefix as its file.**

## Function authorisations (`GESAUT`)

The `GESAUT` table stores the cross-product user × function. For a given user/group, it shows what's authorized. Useful for audits — but day-to-day, edit `GESAFP` (the profile) and let it propagate.

In L4G, check authorisation explicitly when needed:

```l4g
Local Integer ALLOWED
Call ATTRIB([V]GUSER, "YWS_CHECK_STOCK", ALLOWED) From GESAUT
If !ALLOWED
    Errbox mess(45, 100, 1)        # "Not authorised"
    Return
Endif
```

`ATTRIB` is the supervisor signature — verify presence on your patch level (`version-caveats.md`).

## Action authorisations (`GACTION`)

Even when a function is allowed, individual actions inside it are filtered. The standard pattern at the top of an action handler:

```l4g
##############################################################
# $YACTION — custom action on the BPC entry
##############################################################
$YACTION
Local Integer OK
Call CTRACT("BPC", "YACTION", OK) From GACTION
If !OK
    Errbox mess(45, 100, 1)
    Return
Endif
# … action body …
Return
```

Register the action code (`YACTION`) in `GESACT` (Action codes) and grant it via the role's action profile. Without registration, `CTRACT` returns `0` (deny) for everyone.

## ACL on a published service

### Classic SOAP (`GESAWE`)

Every record in `GESAWE` has an **Access code** field. The user authenticated for the SOAP call must have that access code in their function profile, otherwise the call fails 403. Default: leave the field empty during development → **non-default before production**.

Don't reuse a generic access code across unrelated services — granularity matters. A `YWS_DEBUG` code accidentally bound to a sensitive service grants debug-tier users full access.

### REST representation (Syracuse)

Each representation gets a function code. In Syracuse: **Administration → Roles**, link the role to the function with `Read`, `Update`, `Create`, `Delete` flags as appropriate.

Service representations (non-CRUD) get a single execute permission — grant per role, never per user.

## Credential storage — never hardcode

API keys, passwords, OAuth client secrets, partner SOAP credentials must not appear in `.src` files. Options, ranked by preference:

### 1. Generic parameters (`PARAMG`) — preferred for non-secret config

```l4g
Local Char URL(500)
URL = func AFNC.PARAMG("YINT", "EXTAPI", "URL")
```

Defined in `GESADP` per folder, surface-level access controlled.

### 2. Encrypted parameters

For real secrets, use the parameter type "encrypted" (chapter parameter with `cypher = 1`) or store in a custom table with `crypt$()` / `decrypt$()` calls. Encryption key lives in folder-level config, not in code.

### 3. External secret manager

For multi-environment deploys, Syracuse can read environment variables passed at boot. Reference them via a single supervisor wrapper. Don't shell out to `env` from L4G — leaks via traces.

### Anti-patterns to flag in review

- A literal API key in a string assignment
- A password as a default value of a `Subprog` parameter
- Credentials passed via the URL query string (logged everywhere)
- A "temporary" hardcoded token with a comment saying "TODO replace before deploy"

## Login and session context

Useful system variables for security-sensitive code:

| Variable | Meaning |
|----------|---------|
| `[V]GUSER` | Current X3 user code |
| `[V]GFOLDER` | Active folder |
| `[V]GLANGUE` | Session language |
| `[S]adxlog` | Set when inside a transaction (also relevant for atomicity, see `code-review-checklist.md`) |
| `[V]GROLE` (V12) | Active Syracuse role |

Always log `[V]GUSER` + `date$` + `time$` into integration log tables — non-negotiable for audits.

## Restricted-access actions

For high-risk operations (mass delete, financial close, custom batches), require a second factor: prompt for the user's password again, or require the user to belong to a specific group.

```l4g
Local Char    PWD(20)
Local Integer OK
Inpbox PWD Mask 0001                    # password mask, hidden input
Call CHECK_PWD([V]GUSER, PWD, OK) From AUTHUTI
If !OK
    Errbox "Wrong password."
    Return
Endif
# proceed with high-risk action
```

`AUTHUTI.CHECK_PWD` exists on most patch levels — confirm before relying.

## Folder-level isolation

When code reads or writes data across folders, enforce isolation:

```l4g
If [V]GFOLDER <> "PROD"
    Errbox "Cette opération n'est autorisée qu'en PROD."
    Return
Endif
```

The folder is set at session start and immutable for the session — safe to gate on.

**Common bug:** custom scripts assuming the standard "SEED" / "X3" folder name. Always read `[V]GFOLDER` at runtime, never hardcode.

## SQL injection — prevent at the boundary

`Exec Sql` with concatenated user input is the standard L4G injection vector:

```l4g
# vulnerable
QRY = "SELECT * FROM ITMMASTER WHERE ITMREF = '" - [L]USER_IN - "'"
Exec Sql QRY On 0 Into …

# safer — escape single quotes
[L]USER_IN = replace$([L]USER_IN, "'", "''")
QRY = "SELECT * FROM ITMMASTER WHERE ITMREF = '" - [L]USER_IN - "'"
```

Better still: use the L4G primitive form (`Read [ITM]ITMREF0 = [L]USER_IN`) — the engine binds the parameter, no string concat.

Reserve `Exec Sql` for queries that genuinely need it (cross-table aggregates, advanced predicates) and apply the escape guard explicitly.

## XML / JSON injection in services

Outbound payloads built by string concatenation break with `&`, `<`, `"`. See `web-services-soap.md` for `YXML_ESC` and `web-services-rest.md` for the JSON build pattern.

Inbound: never `Exec` or `eval` content from a partner. Treat every external input as untrusted — validate format before storing.

## Audit trail — what to log

Every security-relevant operation logs:

| Field | Source |
|-------|--------|
| User | `[V]GUSER` |
| Date | `date$` |
| Time | `time$` |
| Folder | `[V]GFOLDER` |
| Action code | `"YDELETE"`, `"YEXPORT"`, `"YIMPORT"`… |
| Target ID | `[L]CODE`, `[F:SOH]SOHNUM`… |
| Result | `"OK"`, `"DENIED"`, `"ERROR"` |
| Context | source IP if a service, batch id if a batch |

Write to a dedicated `YAUDITLOG` (or `YINTEGRATIONLOG`) table — never `adxlog.log` only, that file rolls.

## Standard pitfalls (production-tested)

- **Service deployed without ACL** — anyone authenticated calls it. Set the access code in `GESAWE` before opening the firewall.
- **`callContext.codeUser` impersonation** — legacy SOAP option that overrides auth from the body. Disable.
- **"Test" user with admin rights left in production** — quarterly audit `GESAFP` for orphan profiles.
- **Custom action without `CTRACT`** — bypasses `GACTION`. Every custom action handler starts with the `CTRACT` check.
- **Error messages leaking schema** — `Errbox "ERROR: SELECT failed on YTABLE"` exposes table names. Use `mess()` codes in production.
- **Hardcoded encryption keys** — same key in dev / preprod / prod, committed in a `.src` file. Move to folder parameter.
- **Trace files in a public path** — `Openo "/var/www/html/trace.log"`. Always write to `TMP/` or a folder-private path.

## Review checklist for security-sensitive changes

1. ACL set on every new screen / function / service?
2. Custom action code registered in `GESACT` and added to a profile?
3. `CTRACT` check at the top of every custom action handler?
4. Credentials read from `PARAMG` / encrypted store, never literals?
5. SQL queries use parameter binding or escape user input?
6. XML/JSON outbound payloads run through escape helpers?
7. User + date + folder + result logged to an audit table?
8. Error messages use `mess()` codes (no schema leakage)?

See also: `code-review-checklist.md` (overall review pass), `web-services-soap.md` (SOAP auth), `web-services-rest.md` (REST auth and OAuth), `conventions-and-naming.md` (message chapters and Y/Z rule), `version-caveats.md` (which `ATTRIB` / `CTRACT` / `CHECK_PWD` signatures are stable).

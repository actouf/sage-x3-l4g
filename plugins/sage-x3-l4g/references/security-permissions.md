# Security and permissions

How access control works in Sage X3 V12 (Syracuse platform + X3 folder), how specific code checks rights with the
documented context methods, and the coding rules that keep custom developments safe: secrets, injection, folder
isolation, hardening. Read it before publishing a service, adding a custom function, or building SQL/JSON/XML from
user input. Audit trails and GDPR are in `audit-compliance.md`.

## Contents
- [Two layers of access control](#two-layers-of-access-control)
- [Syracuse: users, groups, roles, security profiles](#syracuse-users-groups-roles-security-profiles)
- [X3 folder: users, function profiles, access codes](#x3-folder-users-function-profiles-access-codes)
- [Checking rights in code](#checking-rights-in-code)
- [Web-service authentication](#web-service-authentication)
- [Secrets](#secrets)
- [Injection](#injection)
- [Hardening development and runtime](#hardening-development-and-runtime)
- [Folder isolation](#folder-isolation)
- [Gotchas](#gotchas)
- [Sources](#sources)

## Two layers of access control

| Layer | Managed in | Controls |
|---|---|---|
| Platform (Syracuse) | Administration pages: Users, Groups, Roles, Security profiles, Endpoints | Authentication, which endpoints (folders) a user reaches, which role he connects with, platform administration rights, license badges |
| Folder (X3) | GESAUS (users), GESAFT (function profile codes), GESAFP (functional authorizations), GESACS (access codes) | Which functions, per company/site, with which rights and options; which records/fields an access code protects |

A request is allowed only if both layers agree: the user's group grants the endpoint, and the X3 user behind that
endpoint holds the function in his function profile.

## Syracuse: users, groups, roles, security profiles

- **User**: login, active flag, authentication policy (Standard = global setting, DB, LDAP, OAuth2, SAML2), and
  per-endpoint X3 user code ("Endpoints login" grid; by default the X3 user code equals the login).
- **Group**: a set of users; grants the list of **endpoints** and is associated with one **role**.
- **Role**: what the user connects as; carries the license **badges** and one **security profile**.
- **Security profile**: platform administration rights (CRUD + Execute per code such as `users`, `myProfile`,
  `technicalSettings`, development) and a level 0-99 (0 most powerful). A role without security profile has no
  restriction on administration — always assign one.

Sage's security guide: least privilege per role, never share accounts, grant `technicalSettings` to a single admin
role, and give each user only the endpoints he needs.

## X3 folder: users, function profiles, access codes

- **GESAUS (Users)**: menu profile (navigation only, not rights), **function profile** (rights), access-code grid
  (Inquiry / Modification / Execution per code, or "All access codes"), user parameters.
- **GESAFT (User function profiles)**: the profile code; "All authorized functions" for administrator profiles only.
- **GESAFP (Functional profile)**: function-by-function authorizations, optionally per site or site group, plus
  options. For object functions the rights are creation / modification / deletion (GESAFC "access type object").
- **GESAFC (Functions)**: a specific function must exist here (Y/Z code) to be granted in GESAFP. Each function can
  carry up to 20 option letters; **lower-case letters are reserved for specific developments**, and at execution the
  supervisor loads the authorized options in the global `GUSRAUZ(n)` (n = site breakdown index).
- **GESACS (Access codes)**: codes up to 10 characters acting as locks on records, fields, reports or functions;
  users get read / write / execute on each code in GESAUS.
- The main administrator code comes from parameter `ADMUSR` (ADMIN by default); Sage recommends the restricted
  `ADMCA` user for routine administration.

## Checking rights in code

V12 exposes the rights through the context (`this.ACTX` in class code). Every method takes the current instance
as first argument; with `AFLGERR = [V]CST_ATRUE` the refusal is also written in the instance's error list,
with `[V]CST_AFALSE` only `[V]CST_AERROR` is returned.

| Method | Arguments | Answers |
|---|---|---|
| `AGETAFCRIGHT` | `(this, FUNCTION, AFLGERR)` | Function allowed on at least one site/company |
| `AGETAFCRIGHTFCY` / `AGETAFCRIGHTCPY` | `(this, FUNCTION, SITE or COMPANY, AFLGERR)` | Function allowed for that site / company |
| `AGETAFCRIGHTC` / `R` / `U` / `D` / `N` | `(this, FUNCTION, SITE, AFLGERR)` | Object function: create / read / update / delete / change the enable flag |
| `AGETACSRIGHTC` / `M` / `E` | `(this, ACCESS_CODE, AFLGERR)` | Access code: creation / modification / execution right |

```l4g
# Fragment of a class script operation: refuse a closing if the user lacks the specific function YACCCLO
$YCLOSE_ACCOUNT
  [L]ASTATUS = fmet this.ACTX.AGETAFCRIGHT(this, "YACCCLO", [V]CST_ATRUE)
  If [L]ASTATUS = [V]CST_AERROR
    Return : # the error is already attached to this
  Endif
  # ... business logic, see v12-classes.md
Return
```

Sage's own sample on that page misspells the method (`AGETAFCRIFGRC`) and omits the site argument — follow the
table. For Classic functions, the function launch itself is filtered by GESAFP; no other Classic check API is
documented. Never re-implement rights by testing user codes in code.

## Web-service authentication

- SOAP and REST calls authenticate a Syracuse user; that user's groups, role and X3 function profile apply as for a
  person. Create dedicated technical users with only the needed functions; the Users page offers "Password never
  expires" precisely for such flows. The SOAP `codeUser` field of the call context is deprecated and ignored.
- Sage's security guide: prefer Sage ID, OAuth2, SAML2 or LDAPS; basic authentication is intended for demos.
- Details per protocol: `web-services-soap.md`, `web-services-rest.md`; outgoing calls: `web-services-rest-client.md`.

## Secrets

- Never write passwords, API keys or tokens in scripts, in `Value` defaults, in URLs or in traces/log tables.
- Outgoing REST services are declared in Syracuse (*Outgoing REST web services*: base URL, content type,
  authentication None/Basic, CA certificates); code refers to the service **name** — `web-services-rest-client.md`.
  Keep credentials there, managed by administrators, not in L4G.
- Folder or user parameters (GESADP) are configuration, readable by anyone allowed on the setup functions and
  copied with the folder: do not treat them as a vault. There is no documented "encrypted parameter" type, and no
  `crypt$`/`decrypt$` function in the glossary.
- Separate credentials per environment; never copy production secrets into a test folder.

## Injection

**SQL.** Sage's guidance: `Execsql` and `Sql` take an evaluated string, so every piece of data used to build it
must be escaped. First choice: use `Read`/`For`/`Update … Where` with variables (no SQL text built in your code).
If raw SQL is unavoidable, whitelist identifiers and double single quotes in values:

```l4g
##############################################################
# YSQL_QUOTE - return a quoted SQL literal ('O''Neil')
##############################################################
Funprog YSQL_QUOTE(TXT)
Value Char TXT()
Local Char RES(255)
Local Integer I
  For [L]I = 1 To len([L]TXT)
    If mid$([L]TXT, [L]I, 1) = "'"
      [L]RES += "''"
    Else
      [L]RES += mid$([L]TXT, [L]I, 1)
    Endif
  Next I
End "'" + [L]RES + "'"
```

**JSON.** Build values with `escjson` (escapes `"`, `\` and control characters U+0000-U+001F):

```l4g
Local Char YNAME(80), YJSON(250)
[L]YNAME = 'Dupont "Le Grand"'
[L]YJSON = '{"name":"' + escjson([L]YNAME) + '"}'
```

**XML.** Escape `&` first, then `<`, `>`, `"`, `'` — helper and SOAP envelopes in `web-services-soap-client.md`.

**Inbound data.** Never `evalue` or `Execsql` text received from a partner; validate format and length before storing.

## Hardening development and runtime

From Sage's security best practices:
- Development is for dedicated environments: disable the development privilege in every role's security profile in
  production and remove function **ADOTRT** (the script editor, community-reported) from X3 function profiles.
- Configure the runtime **sandbox**: it restricts `System` commands and the file locations the engine can touch.
- `nodelocal.js`: `adminUserRestrict = true` (ADMIN code only for the admin login) and a restrictive
  `upload.allowedTypes`.
- Only HTTPS (443) is user-facing; the Node debug proxy (9514) is for development environments only; MongoDB,
  Elasticsearch, AdxAdmin (localhost only) and the database are never exposed.
- Audit options to switch on after go-live: parameter `TABTRA` (operation audit trail), activity code AUDIT with
  table triggers (AUDITH/AUDITL), V12 audit collection on administrative data in MongoDB — `audit-compliance.md`.

## Folder isolation

- The current folder is `nomap` (or `GACTX.AFOLDER`); the user code is `GACTX.USER`. Classic code and workflow
  formulas use `GUSER` (ADC_GESUSER.htm, GESAWA.htm); V7+ code uses `GACTX.USER`. Do not hard-code folder names
  or compare them to decide behaviour: use a folder-level parameter instead.

```l4g
# YALLOWPURGE: specific integer parameter declared in GESADP at folder level, 1 = allowed
Local Integer YALLOW
[L]YALLOW = fmet GACTX.APARAM.AGETVALNUM([V]CST_ALEVFOLD, "", "YALLOWPURGE")
If [L]YALLOW <> 1
  End
Endif
```

- File paths: build them with `filpath` (current folder by default) — never absolute paths to another folder.
- Which folders a user reaches is decided by Syracuse groups → endpoints, not by code.

## Gotchas

- The menu profile only shapes the menu ("it does in no case define the authorizations", GESAUS help): hiding a
  function from a menu is not a security control. Rights live in GESAFP.
- A custom function not declared in GESAFC cannot be granted — and every profile with "All authorized functions"
  (GESAFT) reaches it anyway.
- Access codes protect only what references them (record field, report, function); an empty code protects nothing.
- `RES` in `YSQL_QUOTE` is limited to 255 characters (`Char` maximum): longer values need a `Clbfile`.
- Error messages returned to web-service callers should not reveal table names or SQL; log details server-side.

See also: `audit-compliance.md`, `web-services-soap.md`, `web-services-rest.md`, `web-services-rest-client.md`,
`web-services-soap-client.md`, `v12-classes.md`, `function-codes.md`, `code-review-checklist.md`.

## Sources
- https://online-help.sagex3.com/erp/12/en-us/Content/V7DEV/developer-guide_access-rights.html
- https://online-help.sagex3.com/erp/12/en-us/Content/V7DEV/getting-started_security-best-practices.html
- https://online-help.sagex3.com/erp/12/en-us/Content/V7DEV/administration-reference_users.html
- https://online-help.sagex3.com/erp/12/en-us/Content/V7DEV/administration-reference_groups.html
- https://online-help.sagex3.com/erp/12/en-us/Content/V7DEV/administration-reference_roles.html
- https://online-help.sagex3.com/erp/12/en-us/Content/V7DEV/administration-reference_security-profiles.html
- https://online-help.sagex3.com/erp/12/en-us/Content/FCT/GESAUS.htm , …/GESAFT.htm , …/GESAFP.htm , …/GESAFC.htm , …/GESACS.htm
- https://online-help.sagex3.com/erp/12/en-us/Content/V7DEV/developer-guide_context-parameters.html
- https://online-help.sagex3.com/erp/12/en-us/Content/V7DEV/how-to_how-to-get-information-relating-to-the-current-context.html
- https://online-help.sagex3.com/erp/12/en-us/Content/V7DEV/4gl_escjson.html , …/4gl_execsql.html , …/4gl_nomap.html , …/4gl_filpath.html
- https://online-help.sagex3.com/erp/12/en-us/Content/V7DEV/administration-reference_outgoing-rest-web-services.html
- https://online-help.sagex3.com/erp/12/en-us/Content/OBJ/ADC_GESUSER.htm , https://online-help.sagex3.com/erp/12/en-us/Content/FCT/GESAWA.htm (GUSER)

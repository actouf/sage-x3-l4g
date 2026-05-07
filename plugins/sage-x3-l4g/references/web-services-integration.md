# Web services and integration — overview

Cross-cutting integration concerns and a router into the protocol-specific files. Read this first when you need to choose between SOAP and REST, or when the question is about file exchange, TLS, or where to log.

For the protocol mechanics, follow the link:

| Topic | File |
|-------|------|
| Publishing a SOAP / AWS service, calling an external SOAP service | `web-services-soap.md` |
| Publishing a REST endpoint, consuming an external REST API, SData | `web-services-rest.md` |

## The three integration surfaces in V12

| Surface | Protocol | Use case |
|---------|----------|----------|
| **REST API** (Syracuse) | HTTP/JSON | Modern — default for V12 integrations |
| **Classic SOAP web services** (AWS / GESAWS) | SOAP/XML | Legacy but still fully supported, same in V6/V7/V12 |
| **SData** | OData-like XML | Older middle-tier integrations, less common in new builds |

Publishing *outbound* calls (X3 calls someone else) uses a separate set of primitives — see the consumer sections in `web-services-rest.md` (REST/JSON) and `web-services-soap.md` (SOAP envelope + client).

## Choosing between SOAP and REST

| Driver | Pick |
|--------|------|
| New partner, new integration | REST (`web-services-rest.md`) |
| Existing partner with deployed SOAP client | SOAP (`web-services-soap.md`) |
| Complex array / matrix parameters | SOAP — REST flattens awkwardly |
| Mobile / browser client | REST — no SOAP tooling left |
| Internal X3 ↔ X3 between folders | Either; REST is simpler |
| Streaming or large payloads | REST with HTTP chunking |
| Metadata-heavy parameter contracts | SOAP — WSDL is well-understood by partner tooling |

When in doubt: REST for new code, SOAP only when an existing constraint demands it.

## File exchange — when HTTP isn't an option

Some partners still want files over SFTP. Pattern:

1. Write the file to `TMP/` via `Openo` + `Writeseq` (see `builtin-functions.md`).
2. Trigger the transfer via `System` calling a shell helper (`lftp`, `scp`, `curl`).
3. Log the response into a tracking table (`YINTEGRATIONLOG`).
4. Schedule the job with the X3 batch scheduler (`GESAPL`) or externally.

Avoid keeping credentials in the L4G source — use `PARAMG` parameter values stored encrypted or environment-level config (`security-permissions.md`).

## Integration traces — log every call

Every integration script (inbound or outbound, REST or SOAP or file-based) logs to a dedicated table:

```l4g
Raz [F:YINTLOG]
[F:YINTLOG]INTDAT = date$
[F:YINTLOG]INTTIM = time$
[F:YINTLOG]INTUSER = [V]GUSER
[F:YINTLOG]ENDPOINT = URL
[F:YINTLOG]HTTPCODE = CODE
[F:YINTLOG]RESP = left$(RESP, 2000)
Write [YINTLOG]
```

When production goes sideways you'll thank yourself — `adxlog.log` is not enough to debug an integration after the fact. See `debugging-traces.md` for the retention and rotation patterns.

## Cross-cutting gotchas

These apply to both SOAP and REST. Protocol-specific gotchas live in the respective files.

- **Self-signed certs** — the runtime rejects them by default; configure the trust store via Syracuse rather than disabling TLS verification.
- **Timeouts** — HTTP helpers have a default (often 30s); long-running partner APIs need an explicit override.
- **Encoding** — default is UTF-8 for REST, often ISO-8859-1 in older SOAP — check `Content-Type` before parsing.
- **Payload size** — both protocol layers buffer the whole body in memory; don't pass megabytes through a single call, chunk or use file exchange.
- **Credential storage** — never hardcode API keys, passwords, or OAuth secrets in `.src` files. Use `GESADP` parameters with encrypted storage. See `security-permissions.md`.
- **Audit trail** — every integration logs `[V]GUSER`, `date$`, `time$`, endpoint, status, and a truncated response body. Required for support and audit.
- **Idempotency** — every inbound service should accept a partner correlation key and refuse to double-process; every outbound retry uses the same correlation key.
- **Versioning** — never change a published service signature in place. Publish `_V2` and run both during deprecation.

## The publishing checklist (any new service)

Before opening the firewall to a new integration:

1. Function declared in `GESAFC` with `Y`/`Z` prefix.
2. Access code set in `GESAWE` (SOAP) or representation linked to a Syracuse role (REST).
3. Pool in `GESAPO` sized for expected concurrency (SOAP — see `web-services-soap.md`).
4. Validation of every input parameter — services bypass entry-transaction checks.
5. Status code returned (`OK`, `KO_<reason>`); never crash on bad input.
6. DB writes wrapped in `If adxlog` transactional idiom (`database.md`).
7. Trace + integration log on every invocation.
8. Idempotency key honored.
9. Documented (signature, semantics, error codes) — partners don't read source.

See also: `web-services-soap.md` (SOAP server and client), `web-services-rest.md` (REST server, REST client, SData), `security-permissions.md` (auth, ACL, credentials), `debugging-traces.md` (integration logging), `code-review-checklist.md` (overall review pass), `version-caveats.md` (which HTTP / JSON / XML helpers are stable).

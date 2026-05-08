# Version-specific caveats

Things that work on **most** V12 installs but drift between patch levels, verticals, or folder configurations. Read this file before copy-pasting a snippet into production — the skill's examples are correct patterns, not guaranteed literal signatures.

## Host scripts whose name varies

The `Call <NAME> From <SCRIPT>` pattern is stable; the `<SCRIPT>` name isn't.

| Primitive | Examples use | Also seen as | Check where |
|-----------|--------------|--------------|-------------|
| `ENVMAIL` (send email) | `From AMAIL` | `GESAML`, `GESAMS`, custom | `workflow-email.md` |
| `ECRAN_TRACE` (add trace line) | `From GESECRAN` | universal on standard folders | `debugging-traces.md` |
| `NUMERO` (next sequence value) | `From GESNUM` | universal | `common-patterns.md` |
| `OUVRE_TRT` (open an entry) | `From GESAUT` | universal | `common-patterns.md` |
| `LECFIC` / `EXPFIC` (import/export) | `From IMPOBJ` / `EXPOBJ` | universal on standard folders | `imports-exports.md` |
| `IMPRIM` (launch a report) | `From GIMP` | universal | `reports-printing.md` |

**Action:** `grep -r "Subprog ENVMAIL"` in your folder's `TRT/` before wiring. Adjust the `From` part to match.

## Helper libraries that may not exist

| Helper | Examples use | Availability |
|--------|--------------|--------------|
| `func AFNC.JSONGET(body, key)` | `web-services-rest.md`, `common-patterns-v12.md` | Present on most V12 ≥ 2023 patches; may be missing on older patches or stripped installs |
| `func AFNC.PARAMG(chap, code, symb)` | `examples/YBATCH_ORPHANS.trt` | Universal, but parameter order has small variants |
| `func AFNC.XML*` (XML parse) | `web-services-soap.md` | Less common; test before relying on it |
| HTTP client (`HTTPPOST`, `HTTPGET`) | `web-services-rest.md`, `web-services-soap.md`, `common-patterns-v12.md` | **No shipped standard** — examples use a user-defined `YHTTP` wrapper. Build yours over `System curl`, the JVM bridge, or a published supervisor helper in your version |

**Action:** stub any missing helper with a minimal L4G wrapper that has the same signature — keeps your business code portable.

## Index names on standard tables

The skill's DB examples use the `<FIELD>0` naming convention for primary indexes (e.g. `Read [BPC]BPCNUM0 = "BP001"`). This is correct on most standard tables but not universal — some tables use shorter alias names (`BPC0`, `ITM0`) as the index key.

**Action:** check `GESATB` for your table — the indexes tab lists the actual index names.

## `Method` vs `Funprog` inside a class

The V12 class idiom in `v12-classes-representations.md` uses:

- `Public Method X()` — returns void via `End`
- `Public Funprog X()` — returns a value via `End <expr>`

Both compile on V12. Older V7 patches accept only `Public Funprog` / `Public Subprog` — there's no `Method` keyword. **V12 patch ≥ 24** is where `Method` became reliable.

**Action:** if your target is V7 or an old V12, use `Funprog`/`Subprog` inside classes instead of `Method`.

## REST endpoint URL shape

Examples write `/api/x3/erp/<folder>/<object>`. Exact shape depends on your Syracuse version:

- Some installs use `/api1/<collection>/<folder>/<object>`
- Legacy SData endpoints mount under `/sdata/x3/erp/...`
- Custom virtual hosts can add a prefix (e.g., `/erp-prod/api/...`)

**Action:** confirm by hitting `GET /api/x3/erp/<folder>/$metadata` in a browser with your Syracuse token — if you get the OData metadata doc, the base path is correct.

## `UPDTICK` column

Standard V12 tables include `UPDTICK`. Custom Y/Z tables **don't** — you have to add the column explicitly in `GESATB` (type `Integer`, mandatory) and set it in your `Write` / `Rewrite` code.

**Action:** before relying on `UPDTICK` on a custom table, confirm the column exists. See `database.md`.

## Mail attachment paths

`ENVMAIL(...)` with a file attachment requires the runtime user to have **read access** to the path. Batch contexts often run as a different OS user than interactive sessions — an attachment generated in interactive mode with restrictive permissions won't send at night.

**Action:** generate attachments in `<folder>/TMP/` and let the runtime handle cleanup, or `chmod 644` after writing.

## Activity-code-based conditional compilation

```l4g
$ACT=YMYCODE
    ...
$FIN
```

Conditional compilation runs at **compile time** based on the folder's active activity codes. If you change activity codes after deployment, you must recompile the affected scripts — the cached `.adx` keeps the old behavior otherwise.

**Action:** after toggling an activity code, `force recompile all` from the supervisor, or delete `<folder>/ADX/` contents and let the engine re-cache.

## Patch-level signature drifts (known)

The following signature changes are commonly encountered when moving between patch levels. None are universal — verify by reading the standard `Subprog` declaration on your folder.

| Helper | Patch range | Drift |
|--------|-------------|-------|
| `ENVMAIL` | V12 ≤ 22 vs ≥ 24 | Older patches: 6 args (recipient, cc, bcc, subject, body, attach). Newer: 7th arg `replyto` added. Calling the older signature with 7 args fails compile; calling new with 6 fails at runtime. |
| `ENVMAILHTML` | V12 ≥ 26 only | Not present on patches < 26. Build the HTML body yourself and pass `Content-Type: text/html` via the standard hook on older patches. |
| `func AFNC.JSONGET` | V12 ≥ 24 | Dotted-path keys (`"rates.USD"`) work on ≥ 26; flat keys only on 24-25. |
| `func AFNC.JSONSET` | V12 ≥ 26 | Not on earlier patches. Build the JSON string by concatenation if absent. |
| `Class … Method` | V12 ≥ 24 | Earlier V12 (and V7) accept `Class … Funprog/Subprog` only — no `Method` keyword. |
| `Public Const` inside a class | V12 ≥ 26 | Earlier patches: declare constants as global variables instead. |
| `UPDTICK` standard fill | V12 ≥ 22 | The supervisor auto-increments `UPDTICK` on `Write`/`Rewrite` of standard tables on ≥ 22. On older patches, set it explicitly: `[F:TBL]UPDTICK = [F:TBL]UPDTICK + 1`. |
| `Top N` in `Update Where` | V12 ≥ 24 | The `Top 1` qualifier on `Update` is supported on ≥ 24. On older, work around with explicit `Read` + `Rewrite`. |
| `func ASYSTEM.ParseJson` | V12 ≥ 28 | Newer DOM-style helper; absent earlier. |
| `Sleep$ "0.1"` | V12 ≥ 26 | Sub-second sleep. Earlier: only integer seconds (`Sleep 1`); use `System "sleep 0.1"` if needed. |
| `mess(n, ch, "ENG")` | V12 ≥ 26 | Three-letter language code as `lang` arg. Earlier patches accept only numeric (1 = current, 2 = next, …) or implicit. |
| `Exec Sql … On 0 Into` | universal V12 | Stable, but the variable types on the `Into` clause are validated more strictly on ≥ 28 — implicit conversions that worked on 22 may fail. |
| `For [TBL] Where … Top N` | V12 ≥ 24 | `Top` clause on `For`. Earlier: count manually with `If N >= LIMIT : Exitfor : Endif`. |
| Syracuse REST URL shape | drifts continually | `/api/x3/erp/<folder>` on most ≥ 24; some installs `/api1/<col>/<folder>`. Always verify with `$metadata`. |

**Action:** when copy-pasting a snippet that uses any of these, check the patch level of the target folder. The minor changes that are silent on the development folder become production crashes elsewhere.

## Common runtime-only divergences

These compile cleanly across patches but behave differently:

- **`adxlog` value across `Trbegin` / `Commit`** — on most V12 the system flag is non-zero inside a transaction; some early V12 patches set it only after the first DB op inside the transaction. The `If adxlog` idiom from `database.md` is robust to both.
- **`fstat` after a `For` with no rows** — older patches set `fstat = 0` after entering an empty `For`, newer patches set a non-zero "no rows" status. Don't infer "rows existed" from `fstat` alone.
- **`[S]adxuprec` on `Update`** — populated reliably on ≥ 22; on earlier folders, count via the rowcount of a follow-up `Read`.
- **Unicode normalization on `Read` by key** — newer patches normalize NFC before comparing; older don't. A French customer name with NFD-encoded accents matches the index on new and misses on old.
- **`format$` thousands separator** — on locales that use `'` as thousands separator (Swiss French), `format$` adds it on ≥ 26 and not before. Documents shipped on patch upgrade may suddenly format differently.

## Folder-config divergences (not patch-related)

Even on the same patch, folder configuration can change behaviour:

- **Activity codes** — a snippet using `Y`-prefixed tables compiles only when the activity is on. See `personalisation-activity.md`.
- **Module dependencies** — `Call` to a script in a module not installed on the target folder fails at runtime, not at compile.
- **Supervisor user ACL** — batch user without ACL on a touched table silently writes nothing on some configs; throws on others.
- **Trace destination** — `ECRAN_TRACE` writes to screen in interactive sessions, to `adxlog.log` in batch. A trace test that works in dev may "vanish" in prod batch.

## How to use this file when reviewing code

If you're code-reviewing someone's L4G and they've copied a snippet from this skill:

1. Confirm each `Call … From X` — does `X` exist in this folder?
2. Confirm each `func <helper>.<name>()` — does the helper library ship in this install?
3. Confirm index names in `Read [TBL]<INDEX>` — match what `GESATB` declares?
4. Confirm `UPDTICK` handling on custom tables — does the column exist?
5. Confirm class syntax (`Method` vs `Funprog` inside `Class`) — does the target V12 patch accept it?

Five minutes of verification here saves hours of "it compiled fine but does nothing in prod."

## When to open an issue against this skill

If you hit a divergence that's **not** covered above (a signature mismatch, a primitive not found, a URL shape that differs), open an issue at [github.com/actouf/sage-x3-l4g/issues](https://github.com/actouf/sage-x3-l4g/issues) with:

- Your Sage X3 version + patch level
- The folder type (seed / vertical / custom)
- The exact snippet from the skill that failed
- The actual signature you found in your standard library

The fix goes in the relevant reference and, if broadly applicable, into this caveats file.

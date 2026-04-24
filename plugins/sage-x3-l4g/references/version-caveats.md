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
| `func AFNC.JSONGET(body, key)` | `web-services-integration.md`, `common-patterns.md` | Present on most V12 ≥ 2023 patches; may be missing on older patches or stripped installs |
| `func AFNC.PARAMG(chap, code, symb)` | `examples/YBATCH_ORPHANS.trt` | Universal, but parameter order has small variants |
| `func AFNC.XML*` (XML parse) | `web-services-integration.md` | Less common; test before relying on it |
| HTTP client (`HTTPPOST`, `HTTPGET`) | `web-services-integration.md`, `common-patterns.md` | **No shipped standard** — examples use a user-defined `YHTTP` wrapper. Build yours over `System curl`, the JVM bridge, or a published supervisor helper in your version |

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

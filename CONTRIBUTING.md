# Contributing to sage-x3-l4g

Thanks for considering a contribution. This skill teaches Claude how to write and debug Sage X3 V12 L4G code — every change has to keep that mission sharp.

## What's most useful

**Great PRs:**
- Real-world V12 patterns I haven't covered (integration recipes, class idioms, batch templates)
- Corrections when Sage X3 behavior differs from what a reference claims (include the version / patch level where you verified)
- New `examples/*.src` or `*.trt` that are compilable on V12 and illustrate one idea cleanly
- Cross-references between files when a topic spans two (e.g. "see `web-services-integration.md` for …")

**Less useful (will likely be declined):**
- Renaming / reorganizing without a concrete problem to fix
- V6-only tips that don't apply in V12
- Generic 4GL tips not specific to Sage X3
- Stylistic rewrites that don't add information

## L4G style in examples

Match the style used throughout the skill, which matches mainstream X3 codebases:

- **PascalCase for keywords**: `If`, `Endif`, `For`, `Next`, `Local`, `Value`, `Return`, `End`
- **UPPERCASE for identifiers**: variables, fields, table aliases, message codes
- **2 spaces** for indentation — never tabs (tabs render unpredictably in the Sage editor)
- **Class prefixes in brackets are explicit**: `[L]COUNT`, `[F:BPC]BPCNUM`, `[M:SOH]SOHNUM` — even when unambiguous
- **`Y` or `Z` prefix on every *custom* symbol** — tables, scripts, classes, activity codes, message chapters you create. Never prefix standard Sage symbols (`BPCUSTOMER`, `GESBPC`, `NUMERO`…) — they stay as shipped.
- **French/English mixed comments** are fine and match real X3 codebases
- **`fstat` check immediately after** every DB / file operation
- **Transactional writes** use the `If adxlog` nested-transaction idiom (see `database.md`)

## Structure

```
.
├── .claude-plugin/
│   └── marketplace.json
├── plugins/
│   └── sage-x3-l4g/
│       ├── SKILL.md              # entry point, auto-loaded
│       └── references/*.md       # consulted on demand
├── examples/                     # compilable fixtures
├── tests/triggers.md             # manual trigger validation
├── README.md / README_FR.md
├── CHANGELOG.md
├── CONTRIBUTING.md               # you are here
└── CLAUDE.md                     # instructions when Claude edits this repo
```

## Testing locally

### Option A — Claude Code (fastest loop)

From this repo's root:

```bash
claude plugin install --local .
```

Then in a Claude Code session:

```
> Écris un Subprog YTRANSFER qui transfère un montant entre deux comptes
```

Claude should consult `references/database.md` and produce transactional code with `If adxlog`.

### Option B — Claude Desktop

Sync the repo through the Customize → Skills flow, then test the same prompts.

### Option C — upload as a .skill

See the main README for the zip-based install flow. Slowest iteration loop; reserved for final validation.

## Validating a change before PR

Run the validation script (checks JSON + ref links):

```bash
./scripts/validate.sh
```

If it passes and CI passes, you're good.

## Writing a new reference

1. Add the file under `plugins/sage-x3-l4g/references/<topic>.md`.
2. Keep it under ~300 lines. If the topic is bigger, split by sub-concern rather than bloating a single file — Claude's progressive disclosure works better with focused files.
3. Follow the existing structure: introductory paragraph, tables for option grids, `l4g` code blocks, and a **Gotchas** section at the end.
4. Add a row to the reference table in `SKILL.md`.
5. Add a bullet under "What's inside" in `README.md` and `README_FR.md`.
6. Cross-link from other references where the topic overlaps.
7. Bump the version in `marketplace.json` (minor = new content, patch = corrections) and add a `CHANGELOG.md` entry.

## PR process

1. Fork, branch from `main` with a descriptive name (`feat/rest-streaming`, `fix/updtick-gotcha`).
2. One topic per PR. Small PRs get reviewed fast.
3. Describe the motivation — a one-line "why" beats five lines of "what changed".
4. If you're citing Sage X3 behavior, mention the patch level you verified on.

## License

By contributing, you agree your work is licensed under the repo's MIT license.

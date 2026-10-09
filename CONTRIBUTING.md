# Contributing to sage-x3-l4g

Thanks for considering a contribution. This skill teaches Claude how to write and debug Sage X3 V12 L4G code — every change has to keep that mission sharp, and every fact has to be right.

## What's most useful

**Great PRs:**
- Corrections when Sage X3 behaviour differs from what a reference claims — include the source (online help page) or the version / patch level where you verified it
- Real-world V12 patterns not covered yet (class scripts, entry points, integration recipes, AXUNIT tests)
- New `plugins/sage-x3-l4g/examples/*.src` scripts that compile on V12 and illustrate one idea cleanly
- New eval cases under `plugins/sage-x3-l4g/evals/` for prompts the skill handles badly

**Less useful (will likely be declined):**
- Renaming / reorganizing without a concrete problem to fix
- V6-only tips that don't apply in V12
- Generic 4GL tips not specific to Sage X3
- Content without a source ("I think `FOO` exists")

## Sources are mandatory

Every reference ends with a `## Sources` section. Every keyword, function, signature, function code (`GESxxx`), host script, menu path or default value must come from a page you can link:

1. [Sage X3 online help](https://online-help.sagex3.com/) — `V7DEV/4gl_*` pages for the language, `FCT/<CODE>.htm` for function codes, `V7DEV/developer-guide_*` / `how-to_*` / `api-guide_*` for the frameworks.
2. [L.V. Expertise X3](https://lvexpertisex3.com/) mirror of the same help.
3. Community sources ([Sage Community Hub](https://communityhub.sage.com/), partner blogs) — acceptable, but mark the claim *(community-reported)* in prose.

If you cannot source it, leave it out. Earlier versions of this skill shipped invented APIs (`ENVMAIL`, `ECRAN_TRACE`, `AFNC.JSONGET`, a `Class … Endclass` syntax…); `scripts/validate.sh` now rejects them.

## L4G style in examples

Match the style used throughout the skill, which matches mainstream X3 codebases:

- **PascalCase for keywords**: `If`, `Endif`, `For`, `Next`, `Local`, `Value`, `Return`, `End`
- **UPPERCASE for identifiers**: variables, fields, table abbreviations, message codes
- **2 spaces** for indentation — never tabs
- **Class prefixes in brackets are explicit**: `[L]COUNT`, `[F:BPC]BPCNAM`, `[M:BPC0]BPCNUM`
- **`X`, `Y` or `Z` prefix on every custom symbol** — tables, scripts, classes, activity codes. Never rename standard Sage symbols.
- **`fstat` check immediately after** every DB / file operation; **`adxuprec`** after `Update` and **`adxdlrec`** after `Delete` when a row count matters
- **Transactions** use the idiom from `database.md`: `[L]TRANS_OPEN = adxlog`, then `Trbegin` / `Commit` / `Rollback` only when `TRANS_OPEN = 0`. No `Trbegin` in class events — the supervisor owns that transaction.
- **Continuation lines** start with `&`; **inline comments** use `: #`
- **French/English mixed comments** are fine and match real X3 codebases

## Structure

```
.
├── .claude-plugin/
│   └── marketplace.json          # marketplace (no version here)
├── plugins/
│   └── sage-x3-l4g/
│       ├── .claude-plugin/
│       │   └── plugin.json       # name + version (single source of truth)
│       ├── SKILL.md              # entry point, loaded when the skill triggers
│       ├── references/*.md       # consulted on demand
│       ├── examples/             # .src scripts shipped with the skill
│       └── evals/                # `claude plugin eval` suite (not shipped in the zip)
├── scripts/
│   ├── validate.sh               # structure, sources, versions, L4G deny-list
│   └── release-notes.sh          # extracts one CHANGELOG section
├── .github/workflows/            # validate.yml (CI), release.yml (tag → GitHub Release)
├── index.md, _config.yml         # GitHub Pages site
├── README.md / README_FR.md
├── CHANGELOG.md
├── CONTRIBUTING.md               # you are here
└── CLAUDE.md                     # instructions when Claude edits this repo
```

## Testing locally

### Load your working copy in Claude Code

```bash
claude --plugin-dir ./plugins/sage-x3-l4g
```

The working copy takes priority over an installed copy for that session. After editing a file, run `/reload-plugins` in the session. Try a prompt such as:

```
> Écris un Funprog YTRANSFER qui transfère un montant entre deux comptes
```

Claude should load the skill, read `references/database.md`, and produce code with the `TRANS_OPEN = adxlog` idiom and `adxuprec` checks.

### Run the evals

The suite in `plugins/sage-x3-l4g/evals/` checks that the skill fires on Sage X3 prompts, stays silent on unrelated ones (Informix 4GL, ABAP, Oracle Forms, plain SQL…), and that key answers use real APIs. Each run is a real model call billed to your account:

```bash
cd plugins/sage-x3-l4g
claude plugin eval . --threshold 0.8 --max-cost-usd 35 --no-publish        # full suite: 3 runs, with and without the skill
claude plugin eval . --case 'fr-*' --threshold 0.8 --no-publish             # one group of cases
claude plugin eval . --tag negative --no-publish                            # trigger precision only
```

The default `--ablation with-without` adds a no-plugin baseline arm and reports the score delta: a case is only useful if the skill beats the baseline. Keep the default three runs before trusting a change — one run is noise. `tool_used: Skill` graders count as a "skill fired" indicator, not in the score. Results land in `evals/results/` (git-ignored). Re-run the suite after any change to the `description` in `SKILL.md`, and the cases of any reference you touch.

### Validate before a PR

```bash
./scripts/validate.sh
claude plugin validate . --strict
claude plugin validate plugins/sage-x3-l4g --strict
```

`validate.sh` checks the manifests (the marketplace entry must not override `plugin.json`), version sync between `plugin.json` and `CHANGELOG.md`, the SKILL.md frontmatter (description ≤ 1024 characters, portable keys), every reference (`## Contents` above 100 lines, `## Sources`, ≤ 340 lines, listed in SKILL.md / READMEs / `index.md`), every example (listed in SKILL.md and `examples/README.md`), cross-links, and the L4G code of SKILL.md, references and examples (deny-list of invented keywords and APIs, 2-space indentation, no L4G in an untagged fence). CI runs the same checks.

### What CI does *not* check

- **L4G compilation** — needs a Sage X3 folder. Compile new examples in your own sandbox and state the V12 patch level in the PR.
- **Model behaviour** — the evals cost money, so CI doesn't run them; run them locally when you touch `SKILL.md` or a reference that an eval case covers.
- **Prose** — the deny-list only scans ```` ```l4g ```` blocks and examples; identifiers named as invented in prose (`code-review-checklist.md`) are intentional.

## Writing a new reference

1. Add `plugins/sage-x3-l4g/references/<topic>.md`: intro paragraph, `## Contents` (if > 100 lines), sections, `## Gotchas`, a `See also:` line, `## Sources`.
2. Keep it under ~300 lines (hard limit 340). Split by sub-concern rather than bloating a file.
3. Add a row to the reference table in `SKILL.md`, and a bullet in `README.md`, `README_FR.md` and `index.md`.
4. Cross-link from other references where the topic overlaps, using bare backticked filenames (`database.md`) — the validator checks they resolve.
5. Add an eval case under `plugins/sage-x3-l4g/evals/<case>/` (`prompt.md` + `graders/`) that fails without the reference.
6. Add an entry under `## [Unreleased]` in `CHANGELOG.md`.

When splitting an existing reference, keep the original filename as a slim router if other files link to it, and grep for stale pointers (`grep -rn 'old-file.md' plugins/`).

## Releases and tags

Releases follow SemVer: **minor** for new content, **patch** for corrections, **major** when an existing reference changes shape in a breaking way.

1. In the release PR: bump `version` in `plugins/sage-x3-l4g/.claude-plugin/plugin.json`, rename `## [Unreleased]` to `## [x.y.z] — YYYY-MM-DD`, add the `[x.y.z]: https://github.com/actouf/sage-x3-l4g/releases/tag/vx.y.z` link.
2. After merging to `master`, tag the merge commit and push the tag:
   ```bash
   git tag -a vX.Y.Z <merge-sha> -m "vX.Y.Z"
   git push origin vX.Y.Z
   ```
3. `.github/workflows/release.yml` validates the tag against `plugin.json`, creates the GitHub Release with the CHANGELOG section as notes, and attaches `sage-x3-l4g.zip` (the folder to upload on claude.ai).

## PR process

1. Fork, branch from `master` with a descriptive name (`feat/entry-points-aimp3`, `fix/rdseq-eof`).
2. One topic per PR. Small PRs get reviewed fast.
3. Describe the motivation — a one-line "why" beats five lines of "what changed".
4. Link the sources you used and, when relevant, the V12 patch level you verified on.

## License

By contributing, you agree your work is licensed under the repo's MIT license.

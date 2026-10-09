# CLAUDE.md

Instructions for Claude when editing this repo. (This is **not** consumed by the skill itself — it's a project-level convention file read by Claude Code when working on the skill's source.)

## What this repo is

A Claude skill (`plugins/sage-x3-l4g/`: `SKILL.md`, `references/`, `examples/`, `evals/`, `.claude-plugin/plugin.json`) plus a marketplace wrapper (`.claude-plugin/marketplace.json`). The skill teaches Claude how to write and debug Sage X3 V12 L4G code.

## Rules for edits

1. **Target V12 by default.** Classic (V6) content stays only where it's still running in V12. When introducing a new idiom, choose the V12 form (dictionary classes + class scripts, representations, Syracuse REST).
2. **Keep references focused.** Each `references/*.md` covers one concern. Target ≤ 300 lines (hard limit 340, enforced). Files over 100 lines start with a `## Contents` list. If a file grows past the limit, split it rather than bloating.
3. **L4G examples use the house style.** PascalCase keywords (`If`, `For`, `Return`), UPPERCASE identifiers, 2-space indent, explicit `[L]`/`[F:]`/`[M:]` prefixes, X/Y/Z prefix on every custom symbol, `fstat` check after every DB/file op, `adxuprec` check after `Update` (`adxdlrec` after `Delete`), the transaction idiom `[L]TRANS_OPEN = adxlog : If [L]TRANS_OPEN = 0 : Trbegin … : Endif` (never `If adxlog : Trbegin`, never `Trbegin` inside class events), `Break` to leave a loop, `& ` at the start of continuation lines, `: #` for inline comments.
4. **Every addition updates all surfaces.** A new reference requires: (1) the file itself, (2) a row in `SKILL.md`'s reference table, (3) a bullet in `README.md`, `README_FR.md` and `index.md`, plus a `CHANGELOG.md` entry under `[Unreleased]`. A new function code goes in `references/function-codes.md` first.
5. **Source every technical claim.** Every reference ends with a `## Sources` section listing the pages actually used (online-help.sagex3.com first). A claim backed only by a community post is marked *(community-reported)* in prose. Cross-reference explicitly (`See also: \`web-services-rest.md\``). Run `scripts/validate.sh` before proposing the change.
6. **Description discipline.** The `description` field in `SKILL.md` is the skill's trigger surface and must stay ≤ 1024 characters (Agent Skills spec; claude.ai rejects longer ones), written in the third person. Adding a keyword is fine while it fits; remove one only to make room, and move it to the "When to use" section of the body rather than dropping it. Re-run the evals (`claude plugin eval`) after any change.
7. **SemVer, single source of truth.** The version lives only in `plugins/sage-x3-l4g/.claude-plugin/plugin.json` (never in `marketplace.json`). Bump minor for new content, patch for corrections, major only if existing references change shape in a breaking way. The top `## [x.y.z]` of `CHANGELOG.md` must match it.
8. **Never invent X3 facts.** No guessed supervisor signatures, host scripts, function codes (`GESxxx`), menu paths, index names, field names or patch numbers. If a fact cannot be verified against Sage's documentation, leave it out — this skill is consumed by people under support contracts. `scripts/validate.sh` keeps a deny-list of identifiers that were invented in earlier versions (`ENVMAIL`, `ECRAN_TRACE`, `Readseq`, `Continue`, `Class … Endclass`…); never work around it.
9. **French + English in examples is fine.** Real X3 codebases mix both; echoing that is honest and helpful.
10. **No emojis in code files, references, or frontmatter.** README badges are the exception.

## Releases

1. Changes accumulate under `## [Unreleased]` in `CHANGELOG.md`.
2. A release PR renames that section to `## [x.y.z] — YYYY-MM-DD`, bumps `plugin.json`, and adds the `[x.y.z]: …/releases/tag/vx.y.z` link.
3. After merge, tag the merge commit (`git tag -a vx.y.z <sha> -m "vx.y.z"`) and push the tag. `.github/workflows/release.yml` creates the GitHub Release with the CHANGELOG section and the claude.ai zip.

## Definitely do not

- Add features, scaffolding, or "placeholder" files the user didn't ask for.
- Create new top-level directories without asking.
- Commit compiled artifacts (`.adx`, `.adp`), even as examples — the `.src` source is the artifact that matters.
- Commit `plugins/sage-x3-l4g/evals/results/` (eval reports).
- Push to `origin/master` or push tags without an explicit ask (even after a successful local test).
- Bypass the validation script — when it fails, fix the root cause, don't silence the check.

## When in doubt

Read `CONTRIBUTING.md` — the rules for external contributors also apply to automated edits.

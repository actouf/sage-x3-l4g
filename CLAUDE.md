# CLAUDE.md

Instructions for Claude when editing this repo. (This is **not** consumed by the skill itself — it's a project-level convention file read by Claude Code when working on the skill's source.)

## What this repo is

A Claude skill (`plugins/sage-x3-l4g/`) plus a marketplace wrapper (`.claude-plugin/marketplace.json`). The skill teaches Claude how to write and debug Sage X3 V12 L4G code.

## Rules for edits

1. **Target V12 by default.** Classic (V6) content stays only where it's still running in V12. When introducing a new idiom, choose the V12 form (classes, representations, REST).
2. **Keep references focused.** Each `references/*.md` covers one concern. If a file exceeds ~300 lines, split it rather than bloating.
3. **L4G examples use the house style.** PascalCase keywords (`If`, `For`, `Return`), UPPERCASE identifiers, 2-space indent, explicit `[L]`/`[F:]`/`[M:]` prefixes, Y/Z prefix on every custom symbol, `fstat` check after every DB/file op, `If adxlog` idiom for nested-transaction safety.
4. **Every addition updates three surfaces.** A new reference requires: (1) the file itself, (2) a row in `SKILL.md`'s reference table, (3) a bullet in `README.md` and `README_FR.md`, plus a `CHANGELOG.md` entry.
5. **Cross-reference explicitly.** If a topic spans two files, say so: `See also: references/web-services-integration.md`. Run `scripts/validate.sh` before proposing the change.
6. **Never weaken the frontmatter description.** The `description` field in `SKILL.md` is the skill's trigger surface. Adding keywords expands trigger reliability; removing them narrows it. Only remove if the skill is no longer intended to fire on that topic.
7. **SemVer.** Bump minor for new content, patch for corrections, major only if existing references change shape in a breaking way.
8. **Don't invent supervisor signatures.** If unsure whether `AFNC.JSONGET` or `ENVMAILHTML` exists at a given patch level, say so in prose rather than guessing — this skill is consumed by people under support contracts.
9. **French + English in examples is fine.** Real X3 codebases mix both; echoing that is honest and helpful.
10. **No emojis in code files, references, or frontmatter.** README badges are the exception.

## Definitely do not

- Add features, scaffolding, or "placeholder" files the user didn't ask for.
- Create new top-level directories without asking.
- Commit compiled artifacts (`.adx`, `.adp`), even as examples — the `.src` / `.trt` is the artifact that matters.
- Push to `origin/main` without an explicit ask (even after a successful local test).
- Bypass the validation script — when it fails, fix the root cause, don't silence the check.

## When in doubt

Read `CONTRIBUTING.md` — the rules for external contributors also apply to automated edits.

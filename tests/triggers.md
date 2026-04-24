# Trigger tests

Catalog of prompts the skill should react to, used for manual non-regression testing when we change `SKILL.md`'s frontmatter description or add / remove references.

**How to use:** after a `description` change, run these prompts in a fresh Claude Code session (or Claude.ai) with the skill installed. Claude should auto-invoke the skill on every prompt marked ✅ and consult the expected reference file(s).

## Core language and DB

| # | Prompt | Should trigger | Consult |
|---|--------|----------------|---------|
| 1 | Écris un Subprog L4G qui transfère un montant entre deux comptes | ✅ | `language-basics.md`, `database.md` |
| 2 | Write a Funprog that returns the next value from a counter in Sage X3 | ✅ | `language-basics.md`, `common-patterns.md` |
| 3 | Quelle est la différence entre `Read` et `Readlock` en L4G ? | ✅ | `database.md` |
| 4 | Comment marcher sur une table avec un `For` et filtrer par date ? | ✅ | `database.md` |
| 5 | How do I check `fstat` after a write in X3? | ✅ | `database.md`, `SKILL.md` mental model |

## UI — Classic and V12

| # | Prompt | Should trigger | Consult |
|---|--------|----------------|---------|
| 6 | Action sur champ qui valide un SIREN en L4G | ✅ | `screens-and-masks.md`, `examples/YCTRL_FIELD.trt` |
| 7 | Remplir un tableau d'écran `[M:ZTK0]` depuis un fichier CSV | ✅ | `screens-and-masks.md`, `common-patterns.md` |
| 8 | Écris une classe V12 qui réserve du stock sur un article | ✅ | `v12-classes-representations.md`, `examples/YSRV_RESERVE.src` |
| 9 | Show me a V12 representation action script | ✅ | `v12-classes-representations.md` |
| 10 | Migration Classic → V12 pour un écran de saisie de commande | ✅ | `v12-classes-representations.md`, `SKILL.md` |

## Integration and operations

| # | Prompt | Should trigger | Consult |
|---|--------|----------------|---------|
| 11 | Publie ce Subprog comme web service REST dans X3 | ✅ | `web-services-integration.md` |
| 12 | Appeler une API REST externe depuis L4G et parser le JSON | ✅ | `web-services-integration.md` |
| 13 | Comment importer un CSV avec une validation par ligne ? | ✅ | `imports-exports.md`, `examples/YIMP_HOOK.src` |
| 14 | Lancer un état Crystal depuis une action d'écran X3 | ✅ | `reports-printing.md` |
| 15 | Règle de workflow qui envoie un mail quand une commande > 10000 EUR est validée | ✅ | `workflow-email.md` |
| 16 | Envoyer un email avec pièce jointe PDF depuis un batch L4G | ✅ | `workflow-email.md`, `reports-printing.md` |
| 17 | Comment débugger un `fstat=2` dans mon script ? | ✅ | `debugging-traces.md` |
| 18 | Performance: mon `For` est lent, comment investiguer ? | ✅ | `debugging-traces.md` |

## Review / paste-code

| # | Prompt | Should trigger | Consult |
|---|--------|----------------|---------|
| 19 | `Relis ce code: Subprog YFOO ... [F:BPC]BPCNUM = "BP001" ... Write [BPC]` | ✅ | `SKILL.md` red flags list |
| 20 | `[M:BPC]BPCNAM = "Test" : Inpbox ...` — what does this do? | ✅ (Classic fragments) | `screens-and-masks.md` |
| 21 | `Class YFOO Public Method ... Endclass` — is this V12? | ✅ | `v12-classes-representations.md` |

## Should NOT trigger

| # | Prompt | Consult |
|---|--------|---------|
| N1 | "How do I write a 4GL program in Informix?" | generic 4GL, not Sage — skill should stay silent |
| N2 | "Explain OpenEdge ABL transactions" | different vendor |
| N3 | "What's Oracle Forms?" | different vendor |

If a ✅ prompt fails to trigger, the `description` field in `SKILL.md`'s frontmatter is likely missing a keyword. Add the term and re-test.

If an N-prompt triggers, the description is too broad — narrow the phrasing (e.g. replace "4GL" with "Sage X3 4GL / L4G" in the surrounding sentence).

## Quality checks (after trigger)

For a ✅ prompt, verify the output:

- Uses **Y or Z prefix** on every custom symbol
- Checks **`fstat`** after every DB or file op
- Wraps writes in **`Trbegin` / `Commit` / `Rollback`**
- Uses the **`If adxlog`** idiom when the Subprog may be nested
- Formats with **PascalCase keywords, UPPERCASE identifiers, 2-space indent**
- Uses **`[L]` / `[F:XXX]` / `[M:XXX]`** prefixes explicitly
- References **`mess(n, chapter, 1)`** for user-facing strings, not hardcoded literals

Any failure → open an issue against the relevant reference file, not the frontmatter.

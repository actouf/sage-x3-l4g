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
| 6 | Bonne façon d'utiliser `Onerrgo` avec un handler qui ferme les ressources | ✅ | `language-basics.md`, `common-patterns.md` |

## UI — Classic and V12

| # | Prompt | Should trigger | Consult |
|---|--------|----------------|---------|
| 7 | Action sur champ qui valide un SIREN en L4G | ✅ | `screens-and-masks.md`, `examples/YCTRL_FIELD.trt` |
| 8 | Remplir un tableau d'écran `[M:ZTK0]` depuis un fichier CSV | ✅ | `screens-and-masks.md`, `common-patterns.md` |
| 9 | Écris une classe V12 qui réserve du stock sur un article | ✅ | `v12-classes-representations.md`, `examples/YSRV_RESERVE.src` |
| 10 | Show me a V12 representation action script | ✅ | `v12-classes-representations.md` |
| 11 | Migration Classic → V12 pour un écran de saisie de commande | ✅ | `v12-classes-representations.md`, `SKILL.md` |
| 12 | Classe V12 héritée qui surcharge une méthode standard | ✅ | `v12-classes-representations.md` |

## Integration and operations

| # | Prompt | Should trigger | Consult |
|---|--------|----------------|---------|
| 13 | Publie ce Subprog comme web service REST dans X3 | ✅ | `web-services-rest.md` |
| 14 | Appeler une API REST externe depuis L4G et parser le JSON | ✅ | `web-services-rest.md` |
| 15 | Comment importer un CSV avec une validation par ligne ? | ✅ | `imports-exports.md`, `examples/YIMP_HOOK.src` |
| 16 | Lancer un état Crystal depuis une action d'écran X3 | ✅ | `reports-printing.md` |
| 17 | Règle de workflow qui envoie un mail quand une commande > 10000 EUR est validée | ✅ | `workflow-email.md` |
| 18 | Envoyer un email avec pièce jointe PDF depuis un batch L4G | ✅ | `workflow-email.md`, `reports-printing.md` |
| 19 | Comment débugger un `fstat=2` dans mon script ? | ✅ | `debugging-traces.md` |
| 20 | Performance: mon `For` est lent, comment investiguer ? | ✅ | `performance.md`, `debugging-traces.md` |
| 21 | Publie ce Subprog comme web service SOAP avec déclaration GESAWE | ✅ | `web-services-soap.md` |
| 22 | Synchronisation delta entre X3 et un système externe via export incrémental | ✅ | `imports-exports.md` |
| 23 | Consommer une API SOAP externe avec WS-Security UsernameToken | ✅ | `web-services-soap.md` |

## Batch / scheduling / personalisation

| # | Prompt | Should trigger | Consult |
|---|--------|----------------|---------|
| 24 | Écris un batch X3 qui s'exécute toutes les nuits et envoie un récap par email | ✅ | `batch-scheduling.md`, `common-patterns-v12.md`, `workflow-email.md` |
| 25 | Comment déclarer une tâche dans GESABA et la planifier dans GESAPL ? | ✅ | `batch-scheduling.md` |
| 26 | Mon batch tourne en boucle infinie avec `While 1 + Sleep`, est-ce correct ? | ✅ | `batch-scheduling.md` |
| 27 | Code activité YINT pour gater un module custom dans X3 | ✅ | `personalisation-activity.md` |
| 28 | Ajouter un champ custom à GESBPC sans modifier la source standard | ✅ | `personalisation-activity.md` |
| 29 | Comment générer et appliquer un patch X3 entre dossiers ? | ✅ | `personalisation-activity.md` |

## Localisation and security

| # | Prompt | Should trigger | Consult |
|---|--------|----------------|---------|
| 30 | Mon Errbox affiche du français à un utilisateur anglais, comment corriger ? | ✅ | `localization.md`, `code-review-checklist.md` |
| 31 | Formater un montant en EUR vs JPY (zéro décimale) en L4G | ✅ | `localization.md` |
| 32 | Convertir une date entre format français et ISO pour un export | ✅ | `localization.md`, `builtin-functions.md` |
| 33 | Email multilingue dans un workflow X3 selon la langue du destinataire | ✅ | `localization.md`, `workflow-email.md` |
| 34 | Revue de code : check-list pour valider un .src custom | ✅ | `code-review-checklist.md` |
| 35 | Comment poser une ACL sur un service REST custom ? | ✅ | `security-permissions.md` |
| 36 | Ajouter un index custom sur une table standard pour un `For` lent | ✅ | `performance.md` |
| 37 | Empêcher l'injection SQL dans un `Exec Sql` qui prend une saisie utilisateur | ✅ | `security-permissions.md` |
| 38 | Stocker une clé API partenaire sans la coder en dur dans le .src | ✅ | `security-permissions.md` |
| 39 | Audit trail : tracer qui a modifié quoi et quand sur une table sensible | ✅ | `security-permissions.md`, `debugging-traces.md` |

## Review / paste-code

| # | Prompt | Should trigger | Consult |
|---|--------|----------------|---------|
| 40 | `Relis ce code: Subprog YFOO ... [F:BPC]BPCNUM = "BP001" ... Write [BPC]` | ✅ | `code-review-checklist.md`, `SKILL.md` red flags |
| 41 | `[M:BPC]BPCNAM = "Test" : Inpbox ...` — what does this do? | ✅ (Classic fragments) | `screens-and-masks.md` |
| 42 | `Class YFOO Public Method ... Endclass` — is this V12? | ✅ | `v12-classes-representations.md` |
| 43 | `Trbegin [SOH] : For [SOH] Where SOHSTA = 1 : Rewrite [SOH] : Next : Commit` — qu'est-ce qui cloche ? | ✅ | `code-review-checklist.md`, `performance.md` |
| 44 | `Readlock [SOH]SOHNUM0 = NUM : Rewrite [SOH] : Return` — verrou bien libéré ? | ✅ | `code-review-checklist.md`, `database.md` |

## Should NOT trigger

| # | Prompt | Consult |
|---|--------|---------|
| N1 | "How do I write a 4GL program in Informix?" | generic 4GL, not Sage — skill should stay silent |
| N2 | "Explain OpenEdge ABL transactions" | different vendor |
| N3 | "What's Oracle Forms?" | different vendor |
| N4 | "How do I write a stored procedure in PostgreSQL?" | not L4G |

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
- For batch / service / REST output: returns a status, logs entry/exit, no `Infbox`/`Errbox`
- For perf / index questions: mentions `Order By Key`, `Link`, per-row transactions
- For security questions: mentions ACL, function profile, encrypted parameter storage

Any failure → open an issue against the relevant reference file, not the frontmatter.

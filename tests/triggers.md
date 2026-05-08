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

## Diagnostics and post-mortem

| # | Prompt | Should trigger | Consult |
|---|--------|----------------|---------|
| 40 | Comment lire un `adxlog.log` pour retrouver l'erreur d'un user ? | ✅ | `diagnostics-postmortem.md` |
| 41 | `fstat=4` qu'est-ce que ça veut dire et comment je règle ça ? | ✅ | `diagnostics-postmortem.md`, `database.md` |
| 42 | Une session est bloquée sur un `Readlock` qui ne se libère pas, comment la débloquer ? | ✅ | `diagnostics-postmortem.md` |
| 43 | Mon pool AWS GESAPO est saturé, les SOAP timeoutent — diagnostic ? | ✅ | `diagnostics-postmortem.md`, `web-services-soap.md`, `performance.md` |
| 44 | Un batch a fini avec status 4 dans GESAEX, par où je commence ? | ✅ | `diagnostics-postmortem.md`, `batch-scheduling.md` |
| 45 | Le moteur adonix a crashé avec un SIGSEGV, qu'est-ce qu'on fait ? | ✅ | `diagnostics-postmortem.md` |
| 46 | Modèle de rapport d'incident pour un P1 X3 | ✅ | `diagnostics-postmortem.md` |

## Data migration

| # | Prompt | Should trigger | Consult |
|---|--------|----------------|---------|
| 47 | Plan de migration de notre legacy ERP vers Sage X3, par où on commence ? | ✅ | `data-migration.md` |
| 48 | Pourquoi passer par une table de staging YSTAGING au lieu de charger direct ? | ✅ | `data-migration.md` |
| 49 | Mon script de chargement crashe à la ligne 800k sur 1M, comment le rendre idempotent ? | ✅ | `data-migration.md`, `code-review-checklist.md` |
| 50 | Réconciliation post-migration : comment je prouve que la donnée est complète ? | ✅ | `data-migration.md` |
| 51 | Stratégie dual-write entre legacy et X3 pendant le cutover | ✅ | `data-migration.md` |
| 52 | Ajouter un champ obligatoire à BPCUSTOMER avec backfill sur 5M de lignes | ✅ | `data-migration.md`, `personalisation-activity.md`, `performance.md` |
| 53 | Consolider trois dossiers X3 en un seul, gestion des collisions de clés | ✅ | `data-migration.md` |

## Audit, compliance, retention

| # | Prompt | Should trigger | Consult |
|---|--------|----------------|---------|
| 54 | Implémenter un audit trail RGPD-compliant sur BPCUSTOMER | ✅ | `audit-compliance.md`, `security-permissions.md` |
| 55 | Politique de rétention sur les logs d'intégration et les commandes archivées | ✅ | `audit-compliance.md` |
| 56 | Droit à l'effacement RGPD : effacer un client tout en gardant les écritures comptables | ✅ | `audit-compliance.md`, `security-permissions.md` |
| 57 | Export des données personnelles d'un BPC pour répondre à une demande RGPD | ✅ | `audit-compliance.md`, `imports-exports.md` |

## Review / paste-code

| # | Prompt | Should trigger | Consult |
|---|--------|----------------|---------|
| 58 | `Relis ce code: Subprog YFOO ... [F:BPC]BPCNUM = "BP001" ... Write [BPC]` | ✅ | `code-review-checklist.md`, `SKILL.md` red flags |
| 59 | `[M:BPC]BPCNAM = "Test" : Inpbox ...` — what does this do? | ✅ (Classic fragments) | `screens-and-masks.md` |
| 60 | `Class YFOO Public Method ... Endclass` — is this V12? | ✅ | `v12-classes-representations.md` |
| 61 | `Trbegin [SOH] : For [SOH] Where SOHSTA = 1 : Rewrite [SOH] : Next : Commit` — qu'est-ce qui cloche ? | ✅ | `code-review-checklist.md`, `performance.md` |
| 62 | `Readlock [SOH]SOHNUM0 = NUM : Rewrite [SOH] : Return` — verrou bien libéré ? | ✅ | `code-review-checklist.md`, `database.md` |

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

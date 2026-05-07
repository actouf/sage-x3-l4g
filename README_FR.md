# sage-x3-l4g

> Skill Claude pour écrire, relire et déboguer du code Sage X3 V12 L4G — classes, représentations, REST, workflows, états, conventions Y/Z et recettes prêtes à l'emploi.

_[English version → README.md](README.md)_

Donne à Claude le vocabulaire, les idiomes et les conventions du L4G (4GL / X3 script / Adonix) pour qu'il produise du code correct dès le premier essai. Focus V12 — le Classic (V6) est couvert uniquement là où il tourne encore en V12.

## Contenu

**Point d'entrée**
- `SKILL.md` — modèle mental, règles de déclenchement, idiomes V12 vs Classic, subprogram transactionnel de référence

**Langage et conventions**
- `references/language-basics.md` — variables, scopes (`[L]`/`[V]`/`[S]`), types, flux de contrôle, subprograms, `Onerrgo`
- `references/database.md` — `Read`/`Readlock`/`Write`/`For`, pattern `If adxlog`, `UPDTICK`, `Link`, SQL embarqué
- `references/builtin-functions.md` — chaînes, dates, `pat`, `System`, fichiers séquentiels, `filpath`/`filinfo`
- `references/conventions-and-naming.md` — règle Y/Z, alias 3 lettres, chapitres de messages, arborescence
- `references/common-patterns.md` — recettes core / Classic (transactions, grilles, gestion d'erreurs, actions champ, paramètres, batch)
- `references/common-patterns-v12.md` — recettes V12 (classe CRUD avec `UPDTICK`, service REST, consommation REST externe, hook d'import, batch planifié + mail)

**IHM — Classic et V12**
- `references/screens-and-masks.md` — masques V6/Classic (`[M:...]`, `Inpbox`, actions standard, grilles) toujours actifs en V12
- `references/v12-classes-representations.md` — V12 natif : `Class`/`Method`/`this`, représentations, pages, objets métier, surface REST

**Intégration et exploitation**
- `references/web-services-integration.md` — vue d'ensemble : comparaison des protocoles, échange de fichiers, logs d'intégration, pièges transverses
- `references/web-services-soap.md` — publication SOAP classique (`GESAWE` / `GESAPO`), appel de services SOAP externes, WS-Security
- `references/web-services-rest.md` — publication REST (Syracuse), consommation d'API REST externes, JSON, OAuth, SData
- `references/imports-exports.md` — templates IMP/EXP (`LECFIC`/`EXPFIC`), hooks d'import, synchronisation delta
- `references/reports-printing.md` — lancement d'états via `IMPRIM`, destinations (`GESADI`), Crystal / états natifs, export Excel
- `references/workflow-email.md` — règles workflow (`GESAWR`), templates, destinataires, emails (`ENVMAIL`), HTML
- `references/debugging-traces.md` — `ECRAN_TRACE`, `stat1`/`funfat`, traces superviseur, logs d'intégration
- `references/performance.md` — index, `Order By Key`, jointures `Link`, granularité des transactions, profilage, anti-patterns
- `references/security-permissions.md` — `GESAUT` / `GACTION` / `GESAFP`, ACL sur services, stockage de secrets, audit, prévention des injections

**Méta**
- `references/code-review-checklist.md` — passe structurée avant d'approuver une modif `.src` / `.trt`, red flags classés par criticité
- `references/version-caveats.md` — quelles primitives / helpers / URLs dérivent selon le patch level V12, à vérifier avant de déployer

## Installation

### Option 1 — Claude.ai (web / mobile)

1. Clique sur le bouton vert **Code ▾** en haut de ce dépôt → **Download ZIP**
2. Le fichier téléchargé est `sage-x3-l4g-main.zip` (ou similaire)
3. Extrais-le, puis re-zippe **uniquement le dossier `plugins/sage-x3-l4g/`** de manière à ce que `SKILL.md` soit à la racine de l'archive
4. Renomme le nouveau zip en `sage-x3-l4g.skill`
5. Dans Claude.ai : **Paramètres → Fonctionnalités → Skills → Uploader un skill** et sélectionne le fichier

### Option 2 — Claude Desktop

1. Ouvre l'app Desktop → barre latérale **Personnaliser** → **Skills**
2. À côté de *Plugins personnels*, clique sur le bouton **+**
3. Colle `actouf/sage-x3-l4g` et clique sur **Sync**
4. Clique sur **Install** dans la ligne `sage-x3-l4g`

### Option 3 — Claude Code (CLI / extension VS Code)

```bash
claude plugin marketplace add actouf/sage-x3-l4g
claude plugin install sage-x3-l4g@sage-x3-l4g
```

## Utilisation

Le skill se déclenche automatiquement. Demande à Claude normalement :

- "Écris une classe V12 qui réserve du stock sur un article"
- "Publie ce Subprog comme web service REST"
- "Relis ce script L4G et dis-moi ce qui cloche"
- "Comment on peuple un tableau à partir d'un fichier CSV en L4G ?"
- "C'est quoi la différence entre `Read` et `Readlock` en L4G ?"
- "Comment on appelle un état Crystal depuis une action d'écran ?"
- "Règle de workflow qui envoie un mail au manager quand une commande > 10000 EUR est validée"

Claude consulte automatiquement les références pertinentes.

## FAQ

**V12 ou V7 ? V6 est-il couvert ?**
Le skill cible V12 en priorité (les exemples utilisent classes et représentations). V7 partage la majorité de la syntaxe — c'est compatible. Pour V6/Classic, le langage de base, les masques et les web services SOAP sont couverts parce qu'ils tournent encore tels quels en V12 ; les patterns purement V6 (sans équivalent V12) ne sont pas prioritaires.

**Pourquoi vérifier `fstat` plutôt qu'utiliser des exceptions ?**
Le runtime X3 ne lève pas d'exceptions pour les erreurs DB — il positionne `[S]fstat`. Ignorer la vérification produit des bugs silencieux (écritures perdues, verrous fantômes). Le skill insiste sur ce point parce que c'est la cause n°1 des incidents en production.

**Quel patch V12 est testé ?**
Le skill reflète les pratiques de V12 patch 26+ (2024). Certaines signatures (`ENVMAIL`, `HTTPPOST`, `AFNC.JSONGET`) varient entre patches — vérifie la bibliothèque standard de ton dossier avant de coder. Si tu trouves une divergence, ouvre une issue.

**Peut-on mélanger français et anglais dans les exemples ?**
Oui. Les vraies codebases X3 mélangent les deux (commentaires métiers en français, identifiants anglais). Le skill reflète ce réel.

**Pourquoi "IMP/EXP templates" plutôt qu'un parser maison ?**
Les templates sont dictionnaire-driven : validation automatique, rejets tracés, ACL respectées, survivent aux patches. Un parser L4G fait main finit par diverger. Le skill recommande les templates par défaut et garde le parser manuel pour les formats réellement non structurés (`imports-exports.md`).

**Issues / feature requests**
Ouvre une issue sur [GitHub](https://github.com/actouf/sage-x3-l4g/issues) — précisez la version V12 et le patch level quand tu signales une divergence.

## Contribuer

Les issues et PR sont bienvenues — voir [CONTRIBUTING.md](CONTRIBUTING.md) pour le style d'exemple attendu, le flux de test local, et le process de PR.

## Licence

MIT — utilise, modifie, redistribue librement.

## Remerciements

Références issues de l'[aide en ligne Sage X3](https://online-help.sagex3.com/), de [L.V. Expertise X3](https://lvexpertisex3.com/), et du [Sage Community Hub](https://communityhub.sage.com/). Non affilié à Sage.

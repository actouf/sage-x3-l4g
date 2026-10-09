# sage-x3-l4g

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Release](https://img.shields.io/github/v/release/actouf/sage-x3-l4g)](https://github.com/actouf/sage-x3-l4g/releases/latest)
[![Validate skill](https://github.com/actouf/sage-x3-l4g/actions/workflows/validate.yml/badge.svg)](https://github.com/actouf/sage-x3-l4g/actions/workflows/validate.yml)
[![Docs](https://img.shields.io/badge/docs-actouf.github.io-brightgreen)](https://actouf.github.io/sage-x3-l4g/)

> Skill Claude pour écrire, relire et déboguer du code Sage X3 V12 L4G — classes du dictionnaire et scripts de classe, représentations, objets Classic et points d'entrée, transactions, REST Syracuse et SOAP, imports, workflows, batchs, tests AXUNIT.

_[English version → README.md](README.md)_

Donne à Claude le vocabulaire, les idiomes et les conventions du L4G Sage X3 (4GL / X3 script / Adonix) pour qu'il écrive du code qui n'utilise que de vrais mots-clés et de vraies API superviseur. Centré sur la V12 ; le Classic est couvert là où il tourne encore en V12.

**Chaque référence cite les pages de l'aide en ligne Sage sur lesquelles elle s'appuie** (section `## Sources` en fin de fichier), et le script de validation rejette les identifiants qui n'existent pas en X3. Le contenu est vérifié sur la documentation Sage, pas compilé sur un dossier réel — voir [Limites](#limites).

**[Parcourir les références en ligne → actouf.github.io/sage-x3-l4g](https://actouf.github.io/sage-x3-l4g/)**

## Contenu

**Point d'entrée**
- `SKILL.md` — quand l'utiliser, discipline de vérification, modèle mental (préfixes, `fstat` / `adxuprec`, un seul niveau de transaction), idiomes V12 vs Classic, Funprog transactionnel de référence

**Langage**
- `references/language-basics.md` — types, déclarations, modes de passage, flux de contrôle, `Break`, sous-programmes, `Gosub`, `Onerrgo` / `Resume`
- `references/database.md` — `Read` / `For` / `Filter` / `Link`, `Update … With`, `Readlock`, `Rewritebykey` et UPDTICK, `Execsql`, fstat / adxuprec, l'idiome transactionnel
- `references/builtin-functions.md` — fonctions chaînes, dates, nombres et système (`format$`, `gdat$`, `instr`, `vireblc`, `ctrans`, `pat`, `filinfo`, `System`)
- `references/sequential-files.md` — `Openi` / `Openo` / `Openio`, `Rdseq` / `Wrseq` / `Getseq` / `Putseq`, `Iomode`, encodages, `filpath`
- `references/conventions-and-naming.md` — préfixes X / Y / Z, codes activité, chapitres de messages, nommage des scripts et tables
- `references/function-codes.md` — liste vérifiée des fonctions GESxxx, et codes qui n'existent pas

**Modèles objet et IHM**
- `references/v12-classes-representations.md` — aiguillage : classes, représentations ou objets Classic, migration Classic → V12
- `references/v12-classes.md` — dictionnaire des classes, scripts de classe (`$PROPERTIES` / `$EVENTS` / `$METHODS` / `$OPERATIONS`), règles, événements, instances, `fmet`, `ASETERROR`
- `references/v12-representations.md` — représentations, facettes, scripts et événements de représentation
- `references/classic-objects.md` — objets Classic : scripts spécifiques `$ACTION`, actions de création / modification, `OK` / `GOK`
- `references/entry-points.md` — points d'entrée (GESAPE, `GPOINT`, `GPE`) pour adapter les traitements standard sans les modifier
- `references/screens-and-masks.md` — masques Classic, `[M:...]`, actions champs, `mkstat`, instructions d'écran dépréciées

**Intégration**
- `references/web-services-integration.md` — aiguillage : REST, SOAP, HTTP sortant ou fichiers, journal d'intégration, checklist de publication
- `references/web-services-rest.md` — exposer X3 en REST Syracuse (`/api1/...`, représentations, facettes, pagination, authentification)
- `references/web-services-rest-client.md` — appeler des API HTTP / REST externes (`ASYRRESTCLI.EXEC_REST_WS`), JSON avec `ParseInstance`
- `references/web-services-soap.md` — publier des web services SOAP Classic (GESASU, GESAWE, pools Syracuse, callContext)
- `references/web-services-soap-client.md` — appeler un service SOAP externe depuis X3 : enveloppe, échappement, analyse, faults
- `references/imports-exports.md` — modèles d'import / export (GESAOE), lancement depuis le code, échanges de fichiers
- `references/reports-printing.md` — dictionnaire des états, destinations, impression depuis le code
- `references/workflow-email.md` — règles workflow (GESAWA), règles d'affectation, modèles de données, envoi d'e-mails (`ASEND_MAIL`)

**Exploitation**
- `references/batch-scheduling.md` — tâches batch (GESABT), tâches récurrentes (GESABA), calendriers, suivi des requêtes, reprise sur incident
- `references/personalisation-activity.md` — codes activité (GESACV), hiérarchie des dossiers, patchs (APATCH / PATCH), personnalisation
- `references/localization.md` — messages et `mess()`, langue de connexion, formats de date et de nombre
- `references/localization-formats.md` — devises, pays et formats d'adresse, jeux de caractères
- `references/data-migration.md` — tables de staging, chargements idempotents, rapprochement, bascule
- `references/debugging-traces.md` — fichiers de log (classe `ALOG` en V7+, `OUVRE_TRACE` / `ECR_TRACE` en Classic), log moteur, profileur, variables d'erreur, débogueur
- `references/diagnostics-postmortem.md` — incidents de production : verrous, batchs en échec, logs, modèle de rapport d'incident

**Qualité**
- `references/performance.md` — accès par index, `Link` plutôt que N+1 lectures, `Columns`, taille des transactions, SQL ensembliste
- `references/security-permissions.md` — profils fonctionnels, contrôle d'accès, authentification des web services, secrets, injection
- `references/audit-compliance.md` — table d'audit, compteurs, RGPD accès / effacement / portabilité, rétention
- `references/unit-testing-axunit.md` — suites de tests AXUNIT (scripts `QLF*`), assertions, exécution
- `references/code-review-checklist.md` — passe de revue structurée, signaux d'alerte classés par gravité
- `references/common-patterns.md` — recettes Classic / cœur
- `references/common-patterns-v12.md` — recettes V12
- `references/version-caveats.md` — comportements dépendant de la version et points à vérifier sur votre dossier

**Exemples** (`plugins/sage-x3-l4g/examples/`, livrés avec le skill)

| Fichier | Sujet |
|---------|-------|
| [`YACCLIB.src`](plugins/sage-x3-l4g/examples/YACCLIB.src) | Funprog transactionnel YTRANSFER et contrôle ALOG des soldes |
| [`QLFYAC_TRANSFER.src`](plugins/sage-x3-l4g/examples/QLFYAC_TRANSFER.src) | Suite de tests AXUNIT pour YTRANSFER |
| [`YTRFPOST.src`](plugins/sage-x3-l4g/examples/YTRFPOST.src) | Traitement batch d'une table de transit, transaction par ligne, ALOG |
| [`SPEYCU.src`](plugins/sage-x3-l4g/examples/SPEYCU.src) | Actions d'objet Classic refusant création ou modification par OK = 0 |
| [`YSUBITM.src`](plugins/sage-x3-l4g/examples/YSUBITM.src) | Point d'entrée BEFWRIITF de SUBITM : ligne d'audit, GOK = 0 |
| [`YCONTRACT_CSPE.src`](plugins/sage-x3-l4g/examples/YCONTRACT_CSPE.src) | Script de classe V12 : règle CONTROL, événements de contrôle, méthode ARET_VALUE |
| [`YRESTRATE.src`](plugins/sage-x3-l4g/examples/YRESTRATE.src) | Appel REST sortant EXEC_REST_WS, analyse JSON, journal d'intégration |
| [`YIMPLAUNCH.src`](plugins/sage-x3-l4g/examples/YIMPLAUNCH.src) | Import silencieux IMPORTSIL et archivage du fichier importé |

## Installation

### Claude Code (CLI, VS Code, JetBrains)

```bash
claude plugin marketplace add actouf/sage-x3-l4g
claude plugin install sage-x3-l4g@sage-x3-l4g
```

Ou depuis une session : `/plugin marketplace add actouf/sage-x3-l4g`, puis `/plugin install sage-x3-l4g@sage-x3-l4g`. Mise à jour : `claude plugin update sage-x3-l4g@sage-x3-l4g` (la mise à jour automatique est désactivée par défaut pour les marketplaces tierces ; elle s'active dans `/plugin`).

### Claude Desktop

**Personnaliser → Plugins → Plugins personnels → +** → ajouter la marketplace `actouf/sage-x3-l4g`, puis installer `sage-x3-l4g`.

### Claude.ai (web)

1. Télécharger `sage-x3-l4g.zip` depuis la [dernière release](https://github.com/actouf/sage-x3-l4g/releases/latest/download/sage-x3-l4g.zip) (il contient le dossier du skill `sage-x3-l4g/`).
2. Dans Claude.ai : **Personnaliser → Skills → + → Importer un skill**, puis choisir le zip.

## Utilisation

Le skill se déclenche tout seul. Demandez simplement :

- « Écris un Funprog qui transfère un montant entre deux comptes, appelable dans ou hors transaction »
- « Dans ma classe V12 YCONTRACT, refuse la création si ENDDAT < STRDAT »
- « Ajoute un contrôle à la création d'un client sans toucher au standard »
- « Appelle une API REST externe depuis X3 et lis une valeur dans la réponse JSON »
- « Relis ce script L4G et dis-moi ce qui cloche »
- « Écris un test AXUNIT pour mon Funprog YTRANSFER »

## FAQ

**V12 ou V7 ? Le V6 est-il couvert ?**
La V12 est la cible principale ; la V7 partage le même modèle classes / représentations. Le Classic (masques, scripts d'objet `$ACTION`, SOAP) est couvert parce qu'il tourne encore en V12. Les patterns purement V6 ne le sont pas.

**Pourquoi tester `fstat` plutôt que des exceptions ?**
Les instructions base de données et fichiers ne lèvent pas d'exception : elles positionnent `[S]fstat`, et `Update` / `Delete … Where` positionnent aussi `[S]adxuprec`. Un `Update` sur une ligne absente réussit avec zéro ligne. Sans ces tests, les bugs sont silencieux.

**Quel niveau de patch ?**
Les références suivent l'aide en ligne V12 et signalent ce qui dépend de la version (par exemple l'analyse JSON native). Vérifiez sur votre dossier avant de livrer ; `version-caveats.md` liste les points à contrôler.

**Peut-on mélanger français et anglais dans les exemples ?**
Oui, comme dans les vraies bases de code X3.

**Où signaler une erreur ?**
Dans les [issues GitHub](https://github.com/actouf/sage-x3-l4g/issues), avec la source ou le patch V12 qui contredit la référence.

## Limites

- Aucun dossier X3 réel n'est utilisé : les exemples sont vérifiés sur la documentation, pas compilés. Compilez-les dans votre bac à sable avant usage.
- Les routines superviseur documentées uniquement par la communauté sont signalées *(community-reported)*.

## Contribuer

Issues et PR bienvenues — voir [CONTRIBUTING.md](CONTRIBUTING.md) : politique des sources, style, tests locaux (`claude --plugin-dir`, evals) et processus de release.

## Licence

MIT — utilisez, modifiez et redistribuez librement.

## Remerciements

Construit à partir de l'[aide en ligne Sage X3](https://online-help.sagex3.com/), de [L.V. Expertise X3](https://lvexpertisex3.com/) et du [Sage Community Hub](https://communityhub.sage.com/). Non affilié à Sage.

# sage-x3-l4g

> 🇬🇧 Claude Skill for writing, reviewing, and debugging Sage X3 V12 L4G code — classes, representations, REST, workflows, reports, Y/Z conventions, ready-to-use recipes.
>
> 🇫🇷 Skill Claude pour écrire, relire et déboguer du code Sage X3 V12 L4G — classes, représentations, REST, workflows, états, conventions Y/Z et recettes prêtes à l'emploi.

Gives Claude the vocabulary, idioms, and conventions of Sage X3 V12 L4G (4GL / X3 script / Adonix) so it produces correct code on the first try. V12-focused — Classic (V6) syntax covered where it's still running in V12.

## What's inside

**Entry point**
- `SKILL.md` — mental model, triggering rules, V12-vs-Classic idioms, a canonical transactional subprogram

**Core language and conventions**
- `references/language-basics.md` — variables, scopes (`[L]`/`[V]`/`[S]`), types, control flow, subprograms, `Onerrgo`
- `references/database.md` — `Read`/`Readlock`/`Write`/`For`, the `If adxlog` nested-transaction pattern, `UPDTICK`, `Link`, embedded SQL
- `references/builtin-functions.md` — strings, dates, `pat`, `System`, sequential files, file info (`filpath`, `filinfo`)
- `references/conventions-and-naming.md` — the Y/Z rule, 3-letter aliases, message chapters, folder layout
- `references/common-patterns.md` — core / Classic recipes (transactions, grids, error handling, action-on-field, sub-prog params, batch)
- `references/common-patterns-v12.md` — V12 recipes (class CRUD with `UPDTICK`, REST service, external REST consumption, import hook, scheduled batch + email)

**UI — Classic and V12**
- `references/screens-and-masks.md` — legacy V6/Classic masks (`[M:...]`, `Inpbox`, standard actions, grids) still running in V12
- `references/v12-classes-representations.md` — V12-native: `Class`/`Method`/`this`, representations, pages, business objects, REST surface

**Integration and operations**
- `references/web-services-integration.md` — overview and router: protocol comparison, file exchange, integration logs, cross-cutting gotchas
- `references/web-services-soap.md` — publishing classic SOAP (`GESAWE` / `GESAPO`), calling external SOAP, WS-Security
- `references/web-services-rest.md` — publishing REST (Syracuse), consuming external REST APIs, JSON, OAuth, SData
- `references/imports-exports.md` — IMP/EXP templates (`LECFIC`/`EXPFIC`), custom import hooks, delta sync patterns
- `references/reports-printing.md` — launching reports via `IMPRIM`, destinations (`GESADI`), Crystal / native states, Excel exports
- `references/workflow-email.md` — workflow rules (`GESAWR`), templates, recipients, sending emails (`ENVMAIL`), HTML bodies
- `references/debugging-traces.md` — `ECRAN_TRACE`, `stat1`/`funfat`, supervisor tracing, integration logging
- `references/performance.md` — indexes, `Order By Key`, `Link` joins, transaction granularity, profiling, anti-patterns
- `references/security-permissions.md` — `GESAUT` / `GACTION` / `GESAFP`, ACL on services, credential storage, audit logging, injection prevention

**Meta**
- `references/code-review-checklist.md` — structured pass before approving a `.src` / `.trt` change, red flags ranked by blast radius
- `references/version-caveats.md` — which primitives / helpers / URLs drift across V12 patch levels, what to verify before copy-pasting to production

## Install

### Option 1 — Claude.ai (web / mobile)

1. Click the green **Code ▾** button on this repo page → **Download ZIP**
2. The downloaded file is `sage-x3-l4g-main.zip` (or similar)
3. Extract it, then re-zip **only the `plugins/sage-x3-l4g/` folder** so that `SKILL.md` is at the root of the archive
4. Rename the new zip to `sage-x3-l4g.skill`
5. In Claude.ai go to **Settings → Capabilities → Skills → Upload skill** and select the file

### Option 2 — Claude Desktop

1. Open the Desktop app → sidebar **Customize** → **Skills**
2. Next to *Personal plugins*, click the **+** button
3. Paste `<your-github-user>/sage-x3-l4g` and click **Sync**
4. Click **Install** on the `sage-x3-l4g` entry

### Option 3 — Claude Code (CLI / VS Code extension)

```bash
claude plugin marketplace add actouf/sage-x3-l4g
claude plugin install sage-x3-l4g@sage-x3-l4g
```

## Using the skill

The skill is designed to auto-trigger. Just ask Claude normally:

- "Écris une classe V12 qui réserve du stock sur un article"
- "Publie ce Subprog comme web service REST"
- "Relis ce script L4G et dis-moi ce qui cloche"
- "Comment on peuple un tableau à partir d'un fichier CSV en L4G ?"
- "C'est quoi la différence entre `Read` et `Readlock` en L4G ?"
- "Comment on appelle un état Crystal depuis une action d'écran ?"
- "Règle de workflow qui envoie un mail au manager quand une commande > 10000 EUR est validée"

Claude will consult the relevant reference files automatically.

## FAQ

**V12 or V7? Is V6 covered?**
The skill targets V12 as its primary — examples use V12 classes and representations. V7 shares most of the syntax, so it works well. V6/Classic is covered only where it still runs unchanged in V12 (masks, `Inpbox`, SOAP web services). Pure V6 patterns with no V12 equivalent are not prioritized.

**Why check `fstat` instead of using exceptions?**
The X3 runtime does not raise exceptions for database errors — it sets `[S]fstat`. Skipping the check produces silent bugs (lost writes, stuck locks). The skill emphasizes this because it's the #1 incident root cause in production.

**Which V12 patch level is the skill validated against?**
Patterns here reflect V12 patch 26+ (2024). Some supervisor signatures (`ENVMAIL`, `HTTPPOST`, `AFNC.JSONGET`) drift between patches — verify your folder's standard library before coding. File an issue if you spot a divergence.

**Can examples mix French and English?**
Yes — real X3 codebases mix both (business comments in French, English identifiers). The skill reflects that reality.

**Why IMP/EXP templates over hand-rolled parsers?**
Templates are dictionary-driven: automatic validation, traced rejects, ACL-respecting, survive patches. Hand-rolled parsers drift. The skill recommends templates by default and keeps manual parsing for genuinely unstructured formats. See `imports-exports.md`.

**Where do I file bugs / feature requests?**
On [GitHub issues](https://github.com/actouf/sage-x3-l4g/issues) — please include your V12 patch level when reporting a behavioral divergence.

## Contributing

Issues and PRs welcome — see [CONTRIBUTING.md](CONTRIBUTING.md) for style guide, local testing flow, and PR process. Especially valuable:

- Real-world V12 patterns I've missed
- Version-specific quirks (patches where a standard signature changed)
- Additional common-pattern recipes
- Corrections when the runtime's behaviour differs from the reference docs
- Translations of user-facing examples

## License

MIT — use, modify, and redistribute freely.

## Credits

Built with references from the official [Sage X3 online help](https://online-help.sagex3.com/), [L.V. Expertise X3](https://lvexpertisex3.com/), and the [Sage Community Hub](https://communityhub.sage.com/). Not affiliated with or endorsed by Sage.

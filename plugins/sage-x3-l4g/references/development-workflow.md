# Development workflow: scripts, Eclipse, compiling, delivery

Where L4G scripts live in a folder, how they are registered (GESADC), edited and debugged with Safe X3 Studio
for Eclipse, what Sage does and does not document about compiling, and the write → compile → fix → test →
patch loop to follow when Claude writes code it cannot run. Read it when the user asks how to compile, where
errors show up or how to set up Eclipse, and before handing over new code. Patches are in
`personalisation-activity.md`, tests in `unit-testing-axunit.md`, logs and error variables in
`debugging-traces.md`.

## Contents
- [Where scripts live](#where-scripts-live)
- [Script dictionary (GESADC)](#script-dictionary-gesadc)
- [Safe X3 Studio (Eclipse)](#safe-x3-studio-eclipse)
- [Debugging in Eclipse](#debugging-in-eclipse)
- [Compiling: what is documented](#compiling-what-is-documented)
- [Reading a runtime error](#reading-a-runtime-error)
- [VS Code and other editors](#vs-code-and-other-editors)
- [Feedback loop when Claude writes code](#feedback-loop-when-claude-writes-code)
- [Gotchas](#gotchas)
- [Sources](#sources)

## Where scripts live

- **Source.** A folder's `TRT` sub-directory holds the "source of the processes" (field help AREP). Script
  sources are `.src` files: the AXUNIT guide requires test files named `QLF*_*.src`.
- **Executable.** When validated, objects, windows and queries "create processes with the .adx extension
  executable by the engine" (VALDICO). `.adx` files are the compiled form of the source, and some standard
  scripts ship as compiled files only, so their source cannot be opened *(community-reported)*.
- **Generated scripts.** Scripts starting with `W` are "generated when you hit the Validate button in several
  functions" *(community-reported)*. Never edit them, or standard `SUB*` scripts (`code-review-checklist.md`, V8).
- **Lookup.** A script missing from a folder is read from its reference folder, and a specific copy that keeps
  a standard name shadows the standard one: `personalisation-activity.md`.
- **Delivery.** A patch carries a script as `TRT` ("the script will be compiled on patch installation") or
  `ADX` (compiled form only) (APATCH).
- **Naming.** X/Y/Z prefixes and the names patch tools treat as specific: `conventions-and-naming.md`.

## Script dictionary (GESADC)

The V12 page is titled "Processings" (V11 menu: Development > Script dictionary > Scripts > Script dictionary).
One record per script:

| Field | Use |
|---|---|
| Script (`CODTRT`) | "Identifier on 12 characters" |
| Description | Title shown in screens and reports |
| Activity code (`CODACT`) | X/Y/Z marks the script as specific; when the code is disabled the element "will not be useable". Put the delivery's code here so it travels with the patch |
| Source processing delivered (`SRC`) | "Flag used during the industrialization of the product" |

- **Add** lists in a grid "the processes not identified in the process dictionary" ("This search selects the
  processes compiled in the current folder") and generates one record per line. "The processes starting with
  one of the following letters W, X, Y and Z are not taken into account": **create the record of each specific
  script by hand**.
- **INFO** shows, on a UNIX application server, the supervisor's entries about the source and the executable:
  "For the executable, the owner is the last to have compiled the process", because "during the compilation,
  the supervisor deletes the executable prior to recreating it".

## Safe X3 Studio (Eclipse)

"The Studio component is an Eclipse plug-in" (online help). Sage's plug-in site calls Safe X3 Studio "the Sage
development environment" for "editing and debugging Sage X3 scripts".

- **Requirements.** "Any environment able to run Eclipse with a Luna SR2 version or higher", and "Only the usage
  on Windows workstations is certified" (online help). The plug-in site recommends Eclipse 2019-03; its
  ready-to-use packages need a JVM 1.7 or later with the same bitness as Eclipse.
- **Install.** First install: the ready-to-use package from the Downloads page of
  `https://plugin-x3.sagex3.com/safex3/studio/` (licence to accept). Existing Eclipse: Help > Install New
  Software…, paste the update site `https://plugin-x3.sagex3.com/safex3/studio/updates` in **Work with**.
- **Version 2.2** is the recommended one: full HTTP(S) communication layer for product update 8.0 and later,
  support of the debug proxy introduced by product update 8.0, and Connected App authentication (2.2.0
  removed Sage ID in its favour).
- **Outdated page.** The online-help how-to "Debugging Scripts with Eclipse Indigo" still installs Eclipse
  Indigo from an old download site. Use the plug-in site to install; the how-to remains the source for the
  user parameters and the attach procedure.
- **Project.** "Create a new Sage X3 project in Eclipse"; "The project must point to the Sage X3 endpoint
  (folder) where the script has to be created and run"; then "Create a new Sage X3 source file within your
  project". The project dialog asks for the server, port, folder, user and language and has a **Check
  connection** button *(community-reported, V7-era support blog)*.
- **Default editor.** In GESAUS, open the user, Parameters tab, row "Chapter=Supervisor, Group=Dev", Actions >
  Detail, and set `AECLIDBG`, `AECLIDBGTR` and `AECLIPSE` to Yes: "Eclipse is now your default script editor."
  The page does not say what each parameter does.
- **Console.** The Eclipse console evaluates expressions. To run one AXUNIT suite, "type a `func` call with
  the full qualified name of the test suite" (`=>func QLFYAC_TRANSFER.TESTSUITE`). Running all tests there is
  not recommended (too long): `unit-testing-axunit.md`.
- **User guide.** The plug-in ships a "Safe X3 Studio User Guide" (Help > Help Contents). It is the place to
  look for editor commands, compiling included, which the online help does not describe.

## Debugging in Eclipse

The online-help procedure (written for Eclipse Indigo):

1. Open the script in Eclipse, then Window > Open Perspective > Debug.
2. Click **Attach to process and debug**, select your process, click **Attach**.
3. Put the cursor on the line where debugging starts, then Run > Run to line.
4. Run the transaction in the X3 client: it stops on that line. Then debug "using the standard Eclipse
   functionality".

- **From code.** With `dbgmode` non-zero, `Dbgaff` gives "the focus ... to the Eclipse debugger". Snippet and
  the rule never to deliver it: `debugging-traces.md`.
- **Debug proxy.** Sage's security guide lists the "Node web server (debug proxy)" on port 9514 for
  "Development environment only with restricted access". *Community-reported* (verified answer, V11/V12): the
  Eclipse debugger goes through this proxy on the Syracuse side, TCP 9514 must be open on Syracuse for the
  runtimes to trigger debugging, the proxy starts when the Eclipse project is open, and a direct connection to
  the engine (port 10000) is no longer possible.
- **Extra parameters** *(community-reported, 2022 Sage support post)*: `AECLIMAC` (web server name) and
  `AECLIPRT` (port) in the same parameter group; Project > User Parameters in Eclipse; Project > Attach process
  lists the sessions; double-click beside a line number to set a breakpoint. For "Debugger not active. Launch
  impossible", open the port shown in the message in the server firewall.
- **Other sessions.** The Studio changelog lists fixes for attaching to a batch session (2.0.4) and for
  debugging a web-service pool (2.1.7).

## Compiling: what is documented

**The public online help has no page that explains how to compile a script, nor how compilation errors are
displayed.** Never invent a menu, button, shortcut or function for it: tell the user to compile with the tool
their folder uses (Safe X3 Studio, or the in-product script editor) and to paste the exact messages. What can
be stated:

- The supervisor compiles a script into an executable: "during the compilation, the supervisor deletes the
  executable prior to recreating it" (GESADC).
- A `TRT` patch element is compiled when the patch is installed (APATCH).
- Dictionary validation (VALDICO, see `data-dictionary.md`) covers tables, screens, objects, windows and
  queries; its page does not mention scripts. Dictionary validation does not compile specific scripts, and no
  standard function to recompile them all is known *(community-reported)*.
- Sage's Studio changelogs (plug-in site, not the online help) mention "Compile" and "Compile and run"
  commands, "compiling error markers", script errors "reported in the Eclipse console", and a syntax analyser
  "independent and complementary to the actual compilation made with VALTRT". VALTRT has no online-help page
  (404 on V11 and V12): do not present it as a documented function.
- Sage's security guide says to "Remove the access to the ADOTRT function in all X3 function profiles" without
  describing it. ADOTRT is the in-product script editor, shown as "Development > Script editor (ADOTRT)"
  *(community-reported)*; it has no online-help page (404 on V11 and V12).

## Reading a runtime error

Runtime errors name the compiled script *(community-reported, V12 p37 thread)*:

```text
@X3.TRT/SUBSOHA1$adx (1367) Error 6 : Variable Non-existent SPJT
```

- `@X3.TRT/SUBSOHA1$adx`: folder `X3`, script `SUBSOHA1`. In another thread, `@IE.TRT/XSUBBIH$adx (115)` was
  answered with "XSUBBIH line 115" and the file `\\Folders\IE\TRT\XSUBBIH.src` *(community-reported)*.
- The SUBSOHA1 case came from a customised copy of a standard script left in the folder after an upgrade:
  removing it fixed the error (`personalisation-activity.md`, "Never shadow a standard script").
- Errors trapped in code (`Onerrgo`, `errn`, `errl`, `errp`): `debugging-traces.md`.

## VS Code and other editors

- No Sage-published VS Code extension for 4GL scripts was found. Sage's VS Code statement concerns the **Sage
  X3 Services developer studio**, used "to customize or extend your GraphQL APIs" (the Extensibility framework
  runs on Node.js): "You can use another TypeScript IDE, but Sage only officially supports Visual Studio Code."
- The **Sage X3 Builder Developer Studio** VS Code extension manages X3 Builder projects ("creating a project,
  updating a project, installing, generating, building, and managing Node.js versions") and is downloaded from
  the Sage Knowledgebase portal *(community-reported)*. It is not a 4GL editor or debugger.
- Third-party extensions on the VS Code Marketplace add 4GL syntax highlighting; a Community Hub answer points
  to `Sage Enterprise Management (Sage X3)` "for syntax highlighting only" *(community-reported)*. Whatever the
  editor, the script is compiled in the folder before the engine can run it.

## Feedback loop when Claude writes code

This is the skill's recommended workflow, not a Sage procedure. Claude cannot compile or run L4G: **never say
that code compiles, runs or passes its tests unless the user reports it**. Say it is checked against the
documentation, not compiled. Copy the checklist into the answer and tick what the user confirms:

```text
- [ ] 1. Write in house style, X/Y/Z names; record in GESADC with the delivery's activity code
- [ ] 2. Self-check: SKILL.md "Self-check before you answer", code-review-checklist.md tiers 1-3,
         nothing from the "never write them" list of SKILL.md
- [ ] 3. User compiles in a development folder (Safe X3 Studio or the script editor) and pastes
         the exact messages: script, line, error number, text
- [ ] 4. Fix only what the messages point to; user recompiles until clean
- [ ] 5. User runs the AXUNIT suite in the Eclipse console: =>func QLF<area>_<case>.TESTSUITE
- [ ] 6. Functional test in a test folder with representative data; read the logs
- [ ] 7. Remove Dbgaff / dbgmode; APATCH with the activity code; PATCH in simulation, then
         integration on a copy of the target folder before production
```

- **Step 3.** Ask for copied text, not a paraphrase. For a runtime error, ask for the whole
  `@FOLDER.TRT/SCRIPT$adx (N) Error …` line.
- **Step 4.** When a message rejects a keyword or function, replace it with one from the references instead
  of arguing that it exists. A message about a standard script can come from a shadowing copy (see above).
- **Step 5.** Write a `QLF*_*.src` suite alongside every reusable Funprog (`unit-testing-axunit.md`).
- **Step 7.** Patch types, the activity-code grid and simulation: `personalisation-activity.md`.

## Gotchas

- GESADC **Add** skips scripts starting with W, X, Y or Z: a specific script has no dictionary record, so no
  activity code, until someone creates it.
- *Community-reported* (v12p36): APATCH preloading by activity code did not collect a specific script; the
  workaround was to add a `TRT` line (or `ADX` for compiled only) with the script name. Check the element list
  before generating the patch.
- The debug proxy (9514) is for development environments only; in production, Sage's security guide also
  removes ADOTRT from every function profile and the development privilege from every role
  (`security-permissions.md`).
- *Community-reported* (V11): "Nombre d'instructions ou d'expressions trop important" while compiling a
  4,636-line script in Eclipse; the answers were a newer runtime or splitting the script, as the standard does
  with SUBSOH / SUBSOHA / SUBSOHB.
- *Community-reported* (Sage announcement): with three folder levels or a historical folder, a runtime issue
  could corrupt scripts during validation; fixed in runtime 96.2.100 (2024 R1, R2) and 96.1.222 (2023 R2).
- A clean compile is not a test: `Error 6 : Variable Non-existent` above surfaced at run time. Run the AXUNIT
  suite and a functional test before any patch.

See also: `personalisation-activity.md`, `unit-testing-axunit.md`, `debugging-traces.md`,
`code-review-checklist.md`, `conventions-and-naming.md`, `data-dictionary.md`, `function-codes.md`,
`security-permissions.md`.

## Sources
- https://online-help.sagex3.com/erp/12/en-us/Content/FCT/GESADC.htm (V11 menu: https://online-help.sagex3.com/erp/11/en-US/FCT/GESADC.htm)
- https://online-help.sagex3.com/erp/11/en-US/FLD/AREP.htm (TRT: "source of the processes")
- https://online-help.sagex3.com/erp/12/en-us/Content/FCT/VALDICO.htm
- https://online-help.sagex3.com/erp/12/en-us/Content/FCT/APATCH.htm
- https://online-help.sagex3.com/erp/12/en-us/Content/V7DEV/prerequisites_safe-x3-studio.html
- https://online-help.sagex3.com/erp/12/en-us/Content/V7DEV/how-to_how-to-install-eclipse-and-use-it-to-debug-version-7-code.html
- https://online-help.sagex3.com/erp/12/en-us/Content/V7DEV/how-to_how-to-create-and-run-an-automatic-unit-test-on-a-data-class.html
- https://online-help.sagex3.com/erp/12/en-us/Content/V7DEV/how-to_how-to-use-axunit.html
- https://online-help.sagex3.com/erp/12/en-us/Content/V7DEV/4gl_dbgaff.html , …/4gl_dbgmode.html
- https://online-help.sagex3.com/erp/12/en-us/Content/V7DEV/getting-started_security-best-practices.html
- https://online-help.sagex3.com/erp/12/en-us/Content/V7DEV/getting-started_Sage-X3-Services-dev-studio-installation.htm
- https://online-help.sagex3.com/erp/12/en-us/Content/FCT/ADOTRT.htm , …/VALTRT.htm (404, also on V11)
- https://plugin-x3.sagex3.com/safex3/studio/ (Sage plug-in site: home, updates.html, 2.2/updates/, downloads/index.html)
- https://plugin-x3.sagex3.com/safex3/studio/changelog-2.x.html , …/changelog-1.2.html
- https://lvexpertisex3.com/x3help/ENG/FLD/AREP.htm
- https://lvexpertisex3.com/x3help/ENG/V7DEV/how-to_how-to-install-eclipse-and-use-it-to-debug-version-7-code.html
- https://communityhub.sage.com/sage-global-solutions/sage_x3/f/general-discussion/232105/compile-all-specific-scripts (community)
- https://communityhub.sage.com/sage-global-solutions/sage_x3/f/general-discussion/199401/about-adx-binary-files-in-trt-folder (community)
- https://communityhub.sage.com/sage-global-solutions/sage_x3/f/general-discussion/206019/trt-folder-significance-of-w-files (community)
- https://communityhub.sage.com/sage-global-solutions/sage_x3/f/north-america-general-discussion/244557/patch-creation---include-scripts (community)
- https://communityhub.sage.com/sage-global-solutions/sage_x3/f/general-discussion/254832/v12p37-x3-trt-subsoha1-adx-1367-error-6-variable-non-existent-spjt (community)
- https://communityhub.sage.com/sage-global-solutions/sage_x3/f/ame-general-discussion/228016/ie-trt-xsubbih-adx-115-error-6-variable-non-existent-zlev/555117 (community)
- https://communityhub.sage.com/fr/sage-x3/f/technique/232826/nombre-d-instructions-ou-d-expressions-trop-important/563792 (community)
- https://communityhub.sage.com/za/sage-x3/f/announcements/240722/runtime-96-2-100-for-2024-r1-2024-r2-releases-and-runtime-96-1-222-for-2023-r2-release-are-available (community)
- https://communityhub.sage.com/fr/sage-x3/f/technique/167849/comment-faire-fonctionner-correctement-mon-debuggueur (community)
- https://communityhub.sage.com/sage-global-solutions/sage_x3/b/sageerp_x3_product_support_blog/posts/how-to-setup-and-configure-eclipse-for-debugging-in-v7 (community)
- https://communityhub.sage.com/sage-global-solutions/sage_x3/b/sage-x3-support-insights-ame/posts/how-to-set-up-safe-x3-studio-for-eclipse-for-debugging (community)
- https://communityhub.sage.com/sage-global-solutions/sage_x3/f/announcements/257592/now-available-new-sage-x3-builder-developer-studio-vscode-extension-1-0-3 (community)
- https://communityhub.sage.com/sage-global-solutions/sage_x3/f/general-discussion/211660/visual-studio-code-instead-eclipse-ide-with-x3 (community)
- https://marketplace.visualstudio.com/items?itemName=momente.x3-code (third-party extension)

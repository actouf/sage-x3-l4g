# Function codes (GESxxx)

Single source of truth for the Sage X3 function codes this skill cites: what each code opens, where it sits
in the menu, and which commonly quoted codes do not exist. Read it before naming a function in an answer.
Every code below was checked against its online-help page (`FCT/<CODE>.htm`), except GESASW, which is stated on
the Representations workbench page; a code whose page returns 404 is listed under
[Codes that do not exist or are often confused](#codes-that-do-not-exist-or-are-often-confused).

## Contents
- [How this table was built](#how-this-table-was-built)
- [Dictionary and development](#dictionary-and-development)
- [Script dictionary](#script-dictionary)
- [Patches, logs and locks](#patches-logs-and-locks)
- [Integration and import/export](#integration-and-importexport)
- [Batch server](#batch-server)
- [Workflow](#workflow)
- [Printing](#printing)
- [Users, security and folders](#users-security-and-folders)
- [Archiving and purge](#archiving-and-purge)
- [Common data and localisation](#common-data-and-localisation)
- [Codes that do not exist or are often confused](#codes-that-do-not-exist-or-are-often-confused)
- [Gotchas](#gotchas)
- [Sources](#sources)

## How this table was built

- **Verified** means the page `https://online-help.sagex3.com/erp/12/en-us/Content/FCT/<CODE>.htm` exists
  and its title matches the meaning given. V12 pages carry no menu breadcrumb, so the **menu path** comes
  from the V11 page `https://online-help.sagex3.com/erp/11/en-US/FCT/<CODE>.htm`. V12 menu labels can differ
  slightly; a dash means no breadcrumb could be verified.
- To check a code yourself, open the URL above: a 404 means the code does not exist in the public help.
- "V12" / "V11" in the Source column link to those two pages.

## Dictionary and development

| Code | Function | Menu path (V11 help) | Source |
|---|---|---|---|
| GESATB | Tables (table dictionary, validation) | Development > Data and parameters > Tables > Tables | [V12](https://online-help.sagex3.com/erp/12/en-us/Content/FCT/GESATB.htm) · [V11](https://online-help.sagex3.com/erp/11/en-US/FCT/GESATB.htm) |
| GESATY | Data types | Development > Data and parameters > Tables > Data types | [V12](https://online-help.sagex3.com/erp/12/en-us/Content/FCT/GESATY.htm) · [V11](https://online-help.sagex3.com/erp/11/en-US/FCT/GESATY.htm) |
| TXT | Local menus and message chapters (table APLSTD) | Development > Data and parameters > Tables > Local menus - messages | [V12](https://online-help.sagex3.com/erp/12/en-us/Content/FCT/TXT.htm) · [V11](https://online-help.sagex3.com/erp/11/en-US/FCT/TXT.htm) |
| GESAVW | Views | Development > Data and parameters > Views | [V12](https://online-help.sagex3.com/erp/12/en-us/Content/FCT/GESAVW.htm) · [V11](https://online-help.sagex3.com/erp/11/en-US/FCT/GESAVW.htm) |
| GESACLA | Classes (V7+ class dictionary) | Development > Data and parameters > Classes > Classes | [V12](https://online-help.sagex3.com/erp/12/en-us/Content/FCT/GESACLA.htm) · [V11](https://online-help.sagex3.com/erp/11/en-US/FCT/GESACLA.htm) |
| GESASW | Representations (code given on the workbench page; no FCT page) | — | [Workbench](https://online-help.sagex3.com/erp/12/en-us/Content/V7DEV/workbench-reference_representation-management.html) |
| GESACV | Activity codes | Development > Data and parameters > Development setup > Activity codes | [V12](https://online-help.sagex3.com/erp/12/en-us/Content/FCT/GESACV.htm) · [V11](https://online-help.sagex3.com/erp/11/en-US/FCT/GESACV.htm) |
| GESADP | Parameter definitions ("Setup definitions") | Development > Data and parameters > Development setup > Parameter definition | [V12](https://online-help.sagex3.com/erp/12/en-us/Content/FCT/GESADP.htm) · [V11](https://online-help.sagex3.com/erp/11/en-US/FCT/GESADP.htm) |
| GESAGB | Global variables (V6 mechanism) | Development > Data and parameters > Development setup > Global variables | [V12](https://online-help.sagex3.com/erp/12/en-us/Content/FCT/GESAGB.htm) · [V11](https://online-help.sagex3.com/erp/11/en-US/FCT/GESAGB.htm) |
| GESACM | Sequence Number Definition (V12 title): supervisor counters, the `[C]` variables stored in table APLCOM — not document numbering | Development > Data and parameters > Development setup > Sequence number type variables | [V12](https://online-help.sagex3.com/erp/12/en-us/Content/FCT/GESACM.htm) · [V11](https://online-help.sagex3.com/erp/11/en-US/FCT/GESACM.htm) |
| GESANM | Sequence number structures (Structures): the document counters read by `NUMERO`, assigned with GESTCA | Setup > General parameters > Sequence number definition > Structures | [V12](https://online-help.sagex3.com/erp/12/en-us/Content/FCT/GESANM.htm) · [V11](https://online-help.sagex3.com/erp/11/en-US/FCT/GESANM.htm) |
| GESAWM | Data models (a main table and its linked tables; used by workflow rules) | Development > Data and parameters > Development setup > Data models | [V12](https://online-help.sagex3.com/erp/12/en-us/Content/FCT/GESAWM.htm) · [V11](https://online-help.sagex3.com/erp/11/en-US/FCT/GESAWM.htm) |
| GESADV | Miscellaneous tables, definition | Development > Data and parameters > Miscellaneous tables > Definition | [V12](https://online-help.sagex3.com/erp/12/en-us/Content/FCT/GESADV.htm) · [V11](https://online-help.sagex3.com/erp/11/en-US/FCT/GESADV.htm) |
| GESADI | Miscellaneous tables, data | Development > Data and parameters > Miscellaneous tables > Data | [V12](https://online-help.sagex3.com/erp/12/en-us/Content/FCT/GESADI.htm) · [V11](https://online-help.sagex3.com/erp/11/en-US/FCT/GESADI.htm) |
| GESACO | Headings (standard 3-character field roots) | Development > Data and parameters > Coding abbreviations > Headings | [V12](https://online-help.sagex3.com/erp/12/en-us/Content/FCT/GESACO.htm) · [V11](https://online-help.sagex3.com/erp/11/en-US/FCT/GESACO.htm) |
| GESAAB | Abbreviations (for long labels) | Development > Data and parameters > Coding abbreviations > Abbreviations | [V12](https://online-help.sagex3.com/erp/12/en-us/Content/FCT/GESAAB.htm) · [V11](https://online-help.sagex3.com/erp/11/en-US/FCT/GESAAB.htm) |
| GESADO | Documentation | Development > Data and parameters > Documentation > Documentation | [V12](https://online-help.sagex3.com/erp/12/en-us/Content/FCT/GESADO.htm) · [V11](https://online-help.sagex3.com/erp/11/en-US/FCT/GESADO.htm) |
| GESACL | Control tables | Setup > General parameters > Control tables | [V12](https://online-help.sagex3.com/erp/12/en-us/Content/FCT/GESACL.htm) · [V11](https://online-help.sagex3.com/erp/11/en-US/FCT/GESACL.htm) |

GESASW is the only code here without an `FCT/<CODE>.htm` page (404): the Representations workbench page gives
it as the representation function code. GESAREP returns 404.

## Script dictionary

| Code | Function | Menu path (V11 help) | Source |
|---|---|---|---|
| GESADC | Script dictionary ("Processings"; activity code per script) | Development > Script dictionary > Scripts > Script dictionary | [V12](https://online-help.sagex3.com/erp/12/en-us/Content/FCT/GESADC.htm) · [V11](https://online-help.sagex3.com/erp/11/en-US/FCT/GESADC.htm) |
| GESASU | Subprograms (incl. the flag used for SOAP publication) | Development > Script dictionary > Scripts > Subprograms | [V12](https://online-help.sagex3.com/erp/12/en-us/Content/FCT/GESASU.htm) · [V11](https://online-help.sagex3.com/erp/11/en-US/FCT/GESASU.htm) |
| GESAWE | Web services (SOAP publication) | Development > Script dictionary > Scripts > Web services | [V12](https://online-help.sagex3.com/erp/12/en-us/Content/FCT/GESAWE.htm) · [V11](https://online-help.sagex3.com/erp/11/en-US/FCT/GESAWE.htm) |
| GESAPE | Entry points | Development > Script dictionary > Scripts > Entry points | [V12](https://online-help.sagex3.com/erp/12/en-us/Content/FCT/GESAPE.htm) · [V11](https://online-help.sagex3.com/erp/11/en-US/FCT/GESAPE.htm) |
| GESAMK | Screens (Classic) | Development > Script dictionary > Screens > Screens | [V12](https://online-help.sagex3.com/erp/12/en-us/Content/FCT/GESAMK.htm) · [V11](https://online-help.sagex3.com/erp/11/en-US/FCT/GESAMK.htm) |
| GESAUR | Screen components (URLs for browser blocks) | Development > Script dictionary > Screens > Screen components | [V12](https://online-help.sagex3.com/erp/12/en-us/Content/FCT/GESAUR.htm) · [V11](https://online-help.sagex3.com/erp/11/en-US/FCT/GESAUR.htm) |
| GESAOB | Objects (Classic) | Development > Script dictionary > Objects | [V12](https://online-help.sagex3.com/erp/12/en-us/Content/FCT/GESAOB.htm) · [V11](https://online-help.sagex3.com/erp/11/en-US/FCT/GESAOB.htm) |
| GESAWI | Windows (Classic) | Development > Script dictionary > Windows | [V12](https://online-help.sagex3.com/erp/12/en-us/Content/FCT/GESAWI.htm) · [V11](https://online-help.sagex3.com/erp/11/en-US/FCT/GESAWI.htm) |
| GESACT | Actions | Development > Script dictionary > Actions > Actions | [V12](https://online-help.sagex3.com/erp/12/en-us/Content/FCT/GESACT.htm) · [V11](https://online-help.sagex3.com/erp/11/en-US/FCT/GESACT.htm) |
| GESAFC | Functions (menu items and processes) | Development > Script dictionary > Functions | [V12](https://online-help.sagex3.com/erp/12/en-us/Content/FCT/GESAFC.htm) · [V11](https://online-help.sagex3.com/erp/11/en-US/FCT/GESAFC.htm) |
| GESACN | Inquiries | Development > Script dictionary > Inquiries | [V12](https://online-help.sagex3.com/erp/12/en-us/Content/FCT/GESACN.htm) · [V11](https://online-help.sagex3.com/erp/11/en-US/FCT/GESACN.htm) |
| GESARP | Reports dictionary (Crystal Reports) | Development > Script dictionary > Reports | [V12](https://online-help.sagex3.com/erp/12/en-us/Content/FCT/GESARP.htm) · [V11](https://online-help.sagex3.com/erp/11/en-US/FCT/GESARP.htm) |

## Patches, logs and locks

| Code | Function | Menu path (V11 help) | Source |
|---|---|---|---|
| APATCH | Patch creation | Development > Utilities > Patches > Patch creation | [V12](https://online-help.sagex3.com/erp/12/en-us/Content/FCT/APATCH.htm) · [V11](https://online-help.sagex3.com/erp/11/en-US/FCT/APATCH.htm) |
| PATCH | Patch integration (also a standard batch task) | Development > Utilities > Patches > Patch integration | [V12](https://online-help.sagex3.com/erp/12/en-us/Content/FCT/PATCH.htm) · [V11](https://online-help.sagex3.com/erp/11/en-US/FCT/PATCH.htm) |
| PATCHT | Patch test (impact analysis before integration) | Development > Utilities > Patches > Patch test | [V12](https://online-help.sagex3.com/erp/12/en-us/Content/FCT/PATCHT.htm) · [V11](https://online-help.sagex3.com/erp/11/en-US/FCT/PATCHT.htm) |
| GESAPT | Patch inquiry (integration history of the folder) | Development > Utilities > Patches > Patch inquiry | [V12](https://online-help.sagex3.com/erp/12/en-us/Content/FCT/GESAPT.htm) · [V11](https://online-help.sagex3.com/erp/11/en-US/FCT/GESAPT.htm) |
| LECTRACE | Log reading (`.tra` files in the folder's TRA sub-directory) | — | [V12](https://online-help.sagex3.com/erp/12/en-us/Content/FCT/LECTRACE.htm) |
| VERSYMB | Locked symbols (table APLLCK; symbols set by `Lock`) | Development > Utilities > Verifications > Locks > Locked symbols | [V12](https://online-help.sagex3.com/erp/12/en-us/Content/FCT/VERSYMB.htm) · [V11](https://online-help.sagex3.com/erp/11/en-US/FCT/VERSYMB.htm) |

Since 2019 R4 the PATCH page directs standard product updates to the **Updates** function
(Administration > Utilities > Update > Updates) and keeps PATCH for add-ons and bespoke developments.

## Integration and import/export

| Code | Function | Menu path (V11 help) | Source |
|---|---|---|---|
| GESAOE | Import/export templates | Setup > Usage > Imports / exports > Import/export templates | [V12](https://online-help.sagex3.com/erp/12/en-us/Content/FCT/GESAOE.htm) · [V11](https://online-help.sagex3.com/erp/11/en-US/FCT/GESAOE.htm) |
| GESAEN | Import/export sequences (group of templates) | Setup > Usage > Imports / exports > Sequences | [V12](https://online-help.sagex3.com/erp/12/en-us/Content/FCT/GESAEN.htm) · [V11](https://online-help.sagex3.com/erp/11/en-US/FCT/GESAEN.htm) |
| GESAOR | Transcoding of import/export data | Setup > Usage > Imports / exports > Transcribe import/export | [V12](https://online-help.sagex3.com/erp/12/en-us/Content/FCT/GESAOR.htm) · [V11](https://online-help.sagex3.com/erp/11/en-US/FCT/GESAOR.htm) |
| GIMPOBJ | Imports (run a template; **Test** button) | Usage > Imports / exports > Imports | [V12](https://online-help.sagex3.com/erp/12/en-us/Content/FCT/GIMPOBJ.htm) · [V11](https://online-help.sagex3.com/erp/11/en-US/FCT/GIMPOBJ.htm) |
| GEXPOBJ | Export (total or chronological) | Usage > Imports / exports > Exports | [V12](https://online-help.sagex3.com/erp/12/en-us/Content/FCT/GEXPOBJ.htm) · [V11](https://online-help.sagex3.com/erp/11/en-US/FCT/GEXPOBJ.htm) |
| GESAOW | Import/export temporary storage spaces (rejected records) | Usage > Imports / exports > Import/export temporary storage space | [V12](https://online-help.sagex3.com/erp/12/en-us/Content/FCT/GESAOW.htm) · [V11](https://online-help.sagex3.com/erp/11/en-US/FCT/GESAOW.htm) |

SOAP publication uses GESASU and GESAWE (see [Script dictionary](#script-dictionary)).

## Batch server

| Code | Function | Menu path (V11 help) | Source |
|---|---|---|---|
| GESABT | Task management | Usage > Batch server > Task management | [V12](https://online-help.sagex3.com/erp/12/en-us/Content/FCT/GESABT.htm) · [V11](https://online-help.sagex3.com/erp/11/en-US/FCT/GESABT.htm) |
| GESABA | Recurring task management | Usage > Batch server > Recurring task management | [V12](https://online-help.sagex3.com/erp/12/en-us/Content/FCT/GESABA.htm) · [V11](https://online-help.sagex3.com/erp/11/en-US/FCT/GESABA.htm) |
| GESABG | Groups of tasks | Usage > Batch server > Groups of tasks | [V12](https://online-help.sagex3.com/erp/12/en-us/Content/FCT/GESABG.htm) · [V11](https://online-help.sagex3.com/erp/11/en-US/FCT/GESABG.htm) |
| GESABH | Hourly constraints | Setup > Usage > Batch server > Hourly constraints | [V12](https://online-help.sagex3.com/erp/12/en-us/Content/FCT/GESABH.htm) · [V11](https://online-help.sagex3.com/erp/11/en-US/FCT/GESABH.htm) |
| GESABC | Batch server calendar | Setup > Usage > Batch server > Batch server calendar | [V12](https://online-help.sagex3.com/erp/12/en-us/Content/FCT/GESABC.htm) · [V11](https://online-help.sagex3.com/erp/11/en-US/FCT/GESABC.htm) |
| ASYRREQMAN | Query (request) management: tracks requests sent to the batch server | — | [V12](https://online-help.sagex3.com/erp/12/en-us/Content/FCT/ASYRREQMAN.htm) |
| EXERQT | Request submission (task or group at a date and time) | Usage > Batch server > Query submission | [V12](https://online-help.sagex3.com/erp/12/en-us/Content/FCT/EXERQT.htm) · [V11](https://online-help.sagex3.com/erp/11/en-US/FCT/EXERQT.htm) |
| ABATPAR | Batch server parameters | Setup > Usage > Batch server > Batch server parameters | [V12](https://online-help.sagex3.com/erp/12/en-us/Content/FCT/ABATPAR.htm) · [V11](https://online-help.sagex3.com/erp/11/en-US/FCT/ABATPAR.htm) |

## Workflow

| Code | Function | Menu path (V11 help) | Source |
|---|---|---|---|
| GESAWA | Workflow rules | Setup > Workflow > Workflow rules | [V12](https://online-help.sagex3.com/erp/12/en-us/Content/FCT/GESAWA.htm) · [V11](https://online-help.sagex3.com/erp/11/en-US/FCT/GESAWA.htm) |
| GESAWR | User allocation (assignment) rules | Setup > Workflow > User rules of assignment | [V12](https://online-help.sagex3.com/erp/12/en-us/Content/FCT/GESAWR.htm) · [V11](https://online-help.sagex3.com/erp/11/en-US/FCT/GESAWR.htm) |
| GESAWV | User allocation (criteria values) | Setup > Workflow > User assignment | [V12](https://online-help.sagex3.com/erp/12/en-us/Content/FCT/GESAWV.htm) · [V11](https://online-help.sagex3.com/erp/11/en-US/FCT/GESAWV.htm) |
| GESAWW | Workbench parameters | Setup > Workflow > Workbench parameters | [V12](https://online-help.sagex3.com/erp/12/en-us/Content/FCT/GESAWW.htm) · [V11](https://online-help.sagex3.com/erp/11/en-US/FCT/GESAWW.htm) |
| SAIWRKPLN | Workflow monitor (events pending signature) | Usage > Workflow monitor | [V12](https://online-help.sagex3.com/erp/12/en-us/Content/FCT/SAIWRKPLN.htm) · [V11](https://online-help.sagex3.com/erp/11/en-US/FCT/SAIWRKPLN.htm) |

Data models (GESAWM) are listed under [Dictionary and development](#dictionary-and-development).

## Printing

| Code | Function | Menu path (V11 help) | Source |
|---|---|---|---|
| AIMP | Reports (print a report: parameters and destination) | Reports > Reports | [V12](https://online-help.sagex3.com/erp/12/en-us/Content/FCT/AIMP.htm) · [V11](https://online-help.sagex3.com/erp/11/en-US/FCT/AIMP.htm) |
| GESAIM | Destinations | Setup > Destinations > Destinations | [V12](https://online-help.sagex3.com/erp/12/en-us/Content/FCT/GESAIM.htm) · [V11](https://online-help.sagex3.com/erp/11/en-US/FCT/GESAIM.htm) |
| GESARX | Print codes | Setup > Destinations > Print code | [V12](https://online-help.sagex3.com/erp/12/en-us/Content/FCT/GESARX.htm) · [V11](https://online-help.sagex3.com/erp/11/en-US/FCT/GESARX.htm) |
| GESARE | Archiving parameters (EDM metadata) | Setup > Destinations > Archiving parameters | [V12](https://online-help.sagex3.com/erp/12/en-us/Content/FCT/GESARE.htm) · [V11](https://online-help.sagex3.com/erp/11/en-US/FCT/GESARE.htm) |

The report dictionary itself is GESARP (see [Script dictionary](#script-dictionary)).

## Users, security and folders

| Code | Function | Menu path (V11 help) | Source |
|---|---|---|---|
| GESAUS | Users | Setup > Users > Users | [V12](https://online-help.sagex3.com/erp/12/en-us/Content/FCT/GESAUS.htm) · [V11](https://online-help.sagex3.com/erp/11/en-US/FCT/GESAUS.htm) |
| GESAFT | User function profiles (the profile codes) | Setup > Users > Function profile | [V12](https://online-help.sagex3.com/erp/12/en-us/Content/FCT/GESAFT.htm) · [V11](https://online-help.sagex3.com/erp/11/en-US/FCT/GESAFT.htm) |
| GESAFP | Functional profile (functional authorizations: functions granted to a profile) | Setup > Users > Functional authorization | [V12](https://online-help.sagex3.com/erp/12/en-us/Content/FCT/GESAFP.htm) · [V11](https://online-help.sagex3.com/erp/11/en-US/FCT/GESAFP.htm) |
| GESACS | Access codes | Setup > Users > Access codes | [V12](https://online-help.sagex3.com/erp/12/en-us/Content/FCT/GESACS.htm) · [V11](https://online-help.sagex3.com/erp/11/en-US/FCT/GESACS.htm) |
| GESADS | Folders (activity codes per folder, validation) | Setup > General parameters > Folders | [V12](https://online-help.sagex3.com/erp/12/en-us/Content/FCT/GESADS.htm) · [V11](https://online-help.sagex3.com/erp/11/en-US/FCT/GESADS.htm) |
| GESAPO | Process menu (floating process browser) | Setup > Interactive dashboard > Process menu | [V12](https://online-help.sagex3.com/erp/12/en-us/Content/FCT/GESAPO.htm) · [V11](https://online-help.sagex3.com/erp/11/en-US/FCT/GESAPO.htm) |
| GESAPR | Processes (charts used by the process menu) | Setup > Interactive dashboard > Processes | [V12](https://online-help.sagex3.com/erp/12/en-us/Content/FCT/GESAPR.htm) · [V11](https://online-help.sagex3.com/erp/11/en-US/FCT/GESAPR.htm) |

## Archiving and purge

| Code | Function | Menu path (V11 help) | Source |
|---|---|---|---|
| AHISTO | Archive/purge (launch purging and archiving) | Usage > History/purge | [V12](https://online-help.sagex3.com/erp/12/en-us/Content/FCT/AHISTO.htm) · [V11](https://online-help.sagex3.com/erp/11/en-US/FCT/AHISTO.htm) |
| APARHIS | Purge parameters | Setup > Usage > Data > Purge parameters | [V12](https://online-help.sagex3.com/erp/12/en-us/Content/FCT/APARHIS.htm) · [V11](https://online-help.sagex3.com/erp/11/en-US/FCT/APARHIS.htm) |
| CREHISTO | Creation of purge (archive) folder | Development > Utilities > Folders > Create archive folder | [V12](https://online-help.sagex3.com/erp/12/en-us/Content/FCT/CREHISTO.htm) · [V11](https://online-help.sagex3.com/erp/11/en-US/FCT/CREHISTO.htm) |

## Common data and localisation

| Code | Function | Menu path (V11 help) | Source |
|---|---|---|---|
| GESTCY | Countries (table TABCOUNTRY [TCY]) | Common data > Common tables > Countries | [V12](https://online-help.sagex3.com/erp/12/en-us/Content/FCT/GESTCY.htm) · [V11](https://online-help.sagex3.com/erp/11/en-US/FCT/GESTCY.htm) |
| GESTCU | Currencies (table TABCUR [TCU]) | Common data > Common tables > Currencies | [V12](https://online-help.sagex3.com/erp/12/en-us/Content/FCT/GESTCU.htm) · [V11](https://online-help.sagex3.com/erp/11/en-US/FCT/GESTCU.htm) |
| GESTLA | Languages (table TABLAN [TLA]) | Common data > Common tables > Languages | [V12](https://online-help.sagex3.com/erp/12/en-us/Content/FCT/GESTLA.htm) · [V11](https://online-help.sagex3.com/erp/11/en-US/FCT/GESTLA.htm) |
| FUNCURRAT | Update currency rates from the Sage FX Rate Service | Common data > Common tables > Update currency rates | [V12](https://online-help.sagex3.com/erp/12/en-us/Content/FCT/FUNCURRAT.htm) · [mirror](https://lvexpertisex3.com/x3help/ENG/FCT/FUNCURRAT.htm) |
| GESBPR | BPs (business partners, with addresses, contacts, bank details) | Common data > BPs > BPs | [V12](https://online-help.sagex3.com/erp/12/en-us/Content/FCT/GESBPR.htm) · [V11](https://online-help.sagex3.com/erp/11/en-US/FCT/GESBPR.htm) |
| GESBPC | Customers | Common data > BPs > Customers | [V12](https://online-help.sagex3.com/erp/12/en-us/Content/FCT/GESBPC.htm) · [V11](https://online-help.sagex3.com/erp/11/en-US/FCT/GESBPC.htm) |
| GESAIN | Contacts | Common data > Common tables > Contact relationships | [V12](https://online-help.sagex3.com/erp/12/en-us/Content/FCT/GESAIN.htm) · [V11](https://online-help.sagex3.com/erp/11/en-US/FCT/GESAIN.htm) |

The manual **Currency rates** entry screen (table TABCHANGE) has no verified function code; see
`localization-formats.md`.

## Codes that do not exist or are often confused

| Code seen in the wild | Status | Use instead |
|---|---|---|
| GESAOI | 404 | GESAOE (import/export templates) |
| GESAPL | 404 | GESABT, GESABA (batch tasks) |
| GESAUT, GESAAC | 404 | GESAUS (users), GESAFT / GESAFP (profiles), GESACS (access codes) |
| GESAPO | Exists: **Process menu** | Not SOAP pools: those are configured in Syracuse (see `web-services-soap.md`) |
| GESADI | Exists: **Miscellaneous tables (data)** | Destinations are GESAIM |
| GESACO | Exists: **Headings** (field roots) | Countries are GESTCY |
| GESAPE | Exists: **Entry points** | Not "personalisation"; see `entry-points.md` and `personalisation-activity.md` |
| GESCUR, GESDEV, GESTCUR | 404 | GESTCU (currencies) |
| GESAML, GESAMS | 404 | TXT (local menus and message chapters) |
| GESAPA | 404 | APATCH (creation), PATCH (integration), GESAPT (history) |
| GESVAL | 404 | Folder validation is done from GESADS; table validation from GESATB |
| GESAREP | 404 | GESASW (Representations; code stated on the workbench page) |
| GESACTX | 404 | The developer guide names the V7+ context dictionary "GESACTX", but there is no FCT page |
| GESAWS, GESAWT, GESAOT, GESBSV, GESACR, GESALI, GESAEX, GESALOCK | 404 | None: do not cite them |

## Gotchas
- A code that "sounds right" is not evidence: GESAPO, GESADI, GESACO and GESAPE all exist but mean
  something else than the v0.5 references claimed.
- GESAFT and GESAFP are two different screens: profile codes (User function profiles) vs the functions
  granted to each profile (Functional profile).
- GESACM (supervisor `[C]` counters) and GESANM (document sequence numbers used by `NUMERO`) are different.
- TXT is a real function code, not a placeholder: it is the screen for local menus and message chapters.
- Menu paths drift between versions and between Classic and Syracuse menus; quote the function code first
  and the path second.

See also: `conventions-and-naming.md`, `personalisation-activity.md`, `security-permissions.md`,
`batch-scheduling.md`, `localization.md`.

## Sources
- https://online-help.sagex3.com/erp/12/en-us/Content/FCT/ (one page per code, linked in the tables above)
- https://online-help.sagex3.com/erp/11/en-US/FCT/ (V11 pages, menu breadcrumbs)
- https://online-help.sagex3.com/erp/12/en-us/Content/FCT/PATCH.htm (PATCHT, Updates function)
- https://online-help.sagex3.com/erp/12/en-us/Content/V7DEV/developer-guide_context-global-variables.html (GESACTX mention)
- https://lvexpertisex3.com/x3help/ENG/FCT/FUNCURRAT.htm
- https://online-help.sagex3.com/erp/12/en-us/Content/V7DEV/workbench-reference_representation-management.html (GESASW)
- https://online-help.sagex3.com/erp/12/en-us/Content/V7DEV/api-guide_get-a-sequence-number-value.html (NUMERO counter)

# Entry points (GESAPE)

Entry points let specific code run at precise places inside standard Sage processes without modifying
the standard source. Read this when a requirement says "when the standard does X, also do Y" and the
standard script is a Classic process (`SUBxxx`, `TRTxxx`, `GESUSER`...). Object actions of a Classic
object (`SPE<OBJ>`) are in `classic-objects.md`; V12 class events are in `v12-classes.md`.

## Contents
- [How an entry point works](#how-an-entry-point-works)
- [Declaring it (GESAPE)](#declaring-it-gesape)
- [The specific script](#the-specific-script)
- [GPE and other return variables](#gpe-and-other-return-variables)
- [Finding available entry points](#finding-available-entry-points)
- [Context and transactions](#context-and-transactions)
- [Example: connection entry points of GESUSER](#example-connection-entry-points-of-gesuser)
- [Activity code protection](#activity-code-protection)
- [Entry points and V12 classes](#entry-points-and-v12-classes)
- [Gotchas](#gotchas)
- [Sources](#sources)

## How an entry point works

1. The standard script contains a call point. Community-reported (Greytrix; a Sage community thread
   quoting the standard `SUBEXPOBJ` source), the call is written:
   `GPOINT = "MODTRTEXP" : Gosub ENTREE From EXEFNC`. `GPOINT` holds the entry point name.
2. The supervisor looks up, in the entry points table (GESAPE), the specific script(s) attached to
   that standard script and runs their `$ACTION` label with the variable `ACTION` = entry point name.
3. The specific code "conserves the environment of the standard program": the standard script's
   variables, open tables and masks are visible, as listed on each entry point's help page.
4. Back in the standard script, return variables (often `GPE`) are tested.

The entry points table is shipped empty: an entry point does nothing until you declare a line.

## Declaring it (GESAPE)

| Field | Use |
|---|---|
| Standard script (`TRTSTD`) | Standard process containing the `GPOINT` calls |
| Specific script (`TRTSPE`) | Your script with the `$ACTION` label |
| Type (`TYP`), Object (`OBJ`), Description (`LIBTRT`) | Classification |
| Module (`MODULE`) | Line created only when the module is active in the folder |
| Activity (`CODACT`) | Null value = entry point optional/off; X, Y or Z = specific line |
| Order (`RNG`) | Execution order when several implementations target the same standard script (ascending) |
| Setup (`TRTPAR`) | Leave blank in V12 |

All entry points you implement for one standard script go in the **same** specific script. A vertical
and a customer layer each have their own script, ordered by *Order*.

## The specific script

```l4g
# YSUBITM - entry points of standard script SUBITM (product management)
$ACTION
  Case ACTION
    When "ITMNUM"    : Gosub Y_ITMNUM
    When "BEFWRIITF" : Gosub Y_BEFWRIITF
  Endcase
Return
```

- Unknown `ACTION` values must fall through silently: the same script receives every entry point of
  the standard script.
- Name the script with your X/Y/Z prefix. Community-reported (RKL): for standard `SUBSOH`, name it
  `YSUBSOH` or `ZSUBSOH`.
- Each label ends with `Return`. Because you run inside the standard program, declare your own
  variables and tables in a `Subprog`/`Funprog` you call, rather than as `Local` in the label, to avoid
  clashing with the standard's names.

## GPE and other return variables

`GPE` has no single meaning: each entry point page says how it is tested. Documented cases:

| Script / entry point | Documented behaviour |
|---|---|
| `CONTOBJ` LECTURE, CONTROLE | `GPE = 1` prevents the standard processing that follows |
| `TRTSYN` UPDRECAP | `GPE` set to 0 before the call; `GPE <> 0` skips the standard update |
| `AIMP3` IMPRIME | `GPE <> 0` prohibits the entry of a printer |
| `GESUSER` CHGPASS | `GPE <> 0` lets a user with an expired password connect |
| `GESUSER` DISCONNECT | `GPE = 1` forces the "session already open" warning |

Other entry points use other variables: `SUBITM` ITMNUM documents `GOK = 0` to abandon the
transaction; `GESUSER` SCONNECT documents `GMENDEP = ""` to refuse the connection; `GESUSER` UCONNECT
provides the error text in `GMESSAGE`. In Classic objects, `GPE = 1` also means "do not call
`SUB<OBJ>` after `SPE<OBJ>`" (`classic-objects.md`); that is the object template, not GESAPE.

## Finding available entry points

- **Online help**: each standard script that offers entry points has a page "Script `<NAME>`: ..." or
  "Process `<NAME>`: ..." at `https://online-help.sagex3.com/erp/12/en-us/Content/OBJ/ADC_<NAME>.htm`
  (for example `ADC_SUBITM.htm`, `ADC_GESUSER.htm`, `ADC_AIMP3.htm`). Per entry point it gives the
  context: transaction or not, log file, call cases, available variables and masks, open tables.
- **Standard source**: search for `GPOINT` in the standard script (community-reported, RKL).
- Variable names in the translated help pages can be translated too (the French and English pages of
  `SUBITM` ITMNUM name the reference variable "Numéro" / "Number"): confirm names in the source.
- Entry points can disappear when Sage rewrites a process (community-reported: `MODTRTEXP` is no
  longer called in `SUBEXPOBJ` after the V12 import/export changes). Recheck after each upgrade.

## Context and transactions

- Read the "Transaction" line of the entry point page. Inside a transaction (`SUBITM` ITMNUM: "one
  transaction in progress"): never `Trbegin`/`Commit`/`Rollback`, and use the documented abort flag.
  Outside (`TRTSYN` entry points: "no current transaction"): if you write, use the `adxlog` idiom of
  `database.md`.
- Some entry points run with a log file open: `TRTSYN` documents that `GTRACE <> ""` means a log is open
  (ADC_TRTSYN.htm); see `debugging-traces.md`.
- Standard processes also run in batch and web-service contexts: avoid `Infbox`/`Errbox` (deprecated,
  Classic-only) in entry points.

## Example: connection entry points of GESUSER

Documented on `ADC_GESUSER.htm`: SCONNECT runs after the access controls with `GUSER` set; setting
`GMENDEP = ""` refuses the connection. CHGPASS runs when the password has expired; `adxusr` contains
the login and `GPE <> 0` authorises the connection (intended for generic batch users).

```l4g
# YGESUSER - declared in GESAPE: standard GESUSER, specific YGESUSER, activity YEPT
$ACTION
  Case ACTION
    When "SCONNECT" : Gosub Y_SCONNECT
    When "CHGPASS"  : Gosub Y_CHGPASS
  Endcase
Return

$Y_SCONNECT
  # Refuse users listed in the custom table YUSRLOCK
  If func YGESUSER.Y_LOCKED(GUSER)
    GMENDEP = ""
  Endif
Return

$Y_CHGPASS
  # Generic batch login keeps running although its password has expired
  If adxusr = "YBATCH"
    GPE = 1
  Endif
Return

Funprog Y_LOCKED(USR)
Value Char USR()
Local File YUSRLOCK [YUL]
  Read [YUL]YUL0 = USR
  If fstat = 0
    End 1
  Endif
End 0
```

The helper `Funprog` has its own local scope, so its `Local File` cannot collide with the standard
program's abbreviations.

## Activity code protection

- Put an X/Y/Z activity code (5 characters max, e.g. `YEPT`) on the GESAPE line: it marks the line as
  specific, and deactivating the code stops the call without deleting anything.
- Use the same activity code on the related dictionary elements so that one switch disables the whole
  customisation (`personalisation-activity.md`).

## Entry points and V12 classes

GESAPE attaches code to a standard **script** that contains `GPOINT` calls. For V7+ classes and
representations, Sage documents events (the `$EVENTS` label of scripts declared in the class or
representation Scripts grid) as the way to change the standard supervisor behaviour; see
`v12-classes.md`. Pick the mechanism by where the standard logic you need actually runs: a Classic
process with a documented entry point, a Classic object action, or a class event.

## Gotchas

- An entry point fires only if the standard script still contains the `GPOINT` call at your patch
  level: check after upgrades.
- Only some pages state that `GPE` is reset to 0 before the call (`TRTSYN`); elsewhere set it
  explicitly in every branch where it matters.
- Do not modify the standard script to add a `GPOINT`: patches overwrite it.
- Several implementations attached to the same standard script run in ascending *Order*: keep
  your customer layer after any vertical layer.

See also: `classic-objects.md`, `v12-classes.md`, `personalisation-activity.md`,
`conventions-and-naming.md`, `debugging-traces.md`.

## Sources
- https://online-help.sagex3.com/erp/12/en-us/Content/FCT/GESAPE.htm
- https://online-help.sagex3.com/erp/12/en-us/Content/OBJ/ADC_GESUSER.htm
- https://online-help.sagex3.com/erp/12/en-us/Content/OBJ/ADC_CONTOBJ.htm
- https://online-help.sagex3.com/erp/12/en-us/Content/OBJ/ADC_TRTSYN.htm
- https://online-help.sagex3.com/erp/12/en-us/Content/OBJ/ADC_AIMP3.htm
- https://online-help.sagex3.com/erp/12/en-us/Content/OBJ/ADC_SUBITM.htm
- https://online-help.sagex3.com/erp/12/fr-fr/Content/OBJ/ADC_SUBITM.htm
- https://online-help.sagex3.com/erp/12/en-us/Content/MODEL/fon_objet.htm
- https://online-help.sagex3.com/erp/12/en-us/Content/V7DEV/developer-guide_classes-events.html
- https://www.rklesolutions.com/blog/sage-x3-entry-points (community-reported)
- https://www.greytrix.com/blogs/sagex3/2016/04/27/how-to-call-entry-point-from-the-code/ (community-reported)
- https://communityhub.sage.com/fr/sage-x3/f/technique/214506/point-d-entree-modtrtexp-et-nouvelles-releases-de-la-v12/531832 (community-reported)

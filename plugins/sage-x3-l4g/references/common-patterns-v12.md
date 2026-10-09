# Common L4G patterns — V12 recipes

Short recipes for V7+/V12 code: property rules, control events, methods, using a class instance
from any script, calling a REST API, running a silent import, sending a mail and logging a
batch-callable routine with `ALOG`. The class snippets come from `examples/YCONTRACT_CSPE.src`
(persistent class `YCONTRACT` on table `YCONTRACT [YCT]`, properties `YCTNUM`, `BPCNUM`, `YSTRDAT`,
`YENDDAT`, `YAMOUNT`, `YSTATUS` with 1 Draft / 2 Active / 3 Closed). Classic and core recipes are in
`common-patterns.md`; the class model itself is in `v12-classes.md`.

## Contents
- [CONTROL rule on a property](#control-rule-on-a-property)
- [Defaults and cross-property checks at insert](#defaults-and-cross-property-checks-at-insert)
- [Method returning ARET_VALUE](#method-returning-aret_value)
- [Read and update an entity from code](#read-and-update-an-entity-from-code)
- [Call an external REST API](#call-an-external-rest-api)
- [Silent import from code](#silent-import-from-code)
- [Send an e-mail](#send-an-e-mail)
- [ALOG log in a batch-callable subprogram](#alog-log-in-a-batch-callable-subprogram)
- [Stock and standard documents](#stock-and-standard-documents)
- [Gotchas](#gotchas)
- [Sources](#sources)

## CONTROL rule on a property

```l4g
$PROPERTIES
  Case [L]CURPRO
    When "YAMOUNT" : Gosub Y_PROP_YAMOUNT
  Endcase
Return

$Y_PROP_YAMOUNT
  Case [L]ARULE
    When "CONTROL"
      If this.YAMOUNT < 0
        [L]ASTATUS = fmet this.ASETERROR("YAMOUNT", mess(21, 160, 1), [V]CST_AERROR)
      Endif
  Endcase
Return
```

CONTROL runs on every assignment (except in `AREAD_AFTER`) and again before insert/update; it may
only check and call `ASETERROR`, never assign properties (that is PROPAGATE). `this.snapshot.YAMOUNT`
holds the value at operation start. Always assign `[L]ASTATUS`: the supervisor tests it.

## Defaults and cross-property checks at insert

Sage describes `AINSERT_CONTROL_BEFORE` as the place to "assign default values" (before the property
controls) and the `*_CONTROL_AFTER` events as running after all controls, before the database write —
the place for checks that involve several properties. Neither runs in a transaction.

```l4g
$EVENTS
  Case [L]CURPTH
    When ""
      Case [L]AEVENT
        When "AINSERT_CONTROL_BEFORE" : Gosub Y_INS_DEFAULTS
        When "AINSERT_CONTROL_AFTER"  : Gosub Y_CHECK_DATES
        When "AUPDATE_CONTROL_AFTER"  : Gosub Y_CHECK_DATES
      Endcase
  Endcase
Return

$Y_INS_DEFAULTS
  If this.YSTATUS = 0 : this.YSTATUS = 1 : Endif
  If this.YSTRDAT = [0/0/0] : this.YSTRDAT = date$ : Endif
Return

$Y_CHECK_DATES
  If this.YENDDAT <> [0/0/0] and this.YENDDAT < this.YSTRDAT
    [L]ASTATUS = fmet this.ASETERROR("YENDDAT", mess(22, 160, 1), [V]CST_AERROR)
  Endif
Return
```

An `ASTATUS` of `[V]CST_AERROR` or more returned by a control event cancels the operation. No
database update and no `Trbegin` in these events (`v12-classes.md`).

## Method returning ARET_VALUE

Declare the method in the class Methods tab (code `YCLOSE`, return type Integer), validate, then:

```l4g
$METHODS
  Case [L]AMETHOD
    When "YCLOSE" : Gosub Y_CLOSE
  Endcase
Return

$Y_CLOSE
  If this.YSTATUS = 3
    [L]ARET_VALUE = [V]CST_AWARNING           : # already closed
  Else
    this.YSTATUS = 3                          : # rules of YSTATUS run here
    If this.YENDDAT = [0/0/0] or this.YENDDAT > date$ : this.YENDDAT = date$ : Endif
    [L]ARET_VALUE = [V]CST_AOK
  Endif
Return
```

The method changes the instance only; the caller persists it with `AUPDATE`. `$METHODS` is called
only in the scripts of the class that defines the method. Stateless work belongs in an operation
(`$OPERATIONS`, `[L]AOPERATION`).

## Read and update an entity from code

```l4g
# Script YCTLIB - close one contract from a batch, a web service or a Classic action
Funprog YCONTRACT_CLOSE(CTNUM)
Value Char CTNUM()
Local Instance YCTI Using C_YCONTRACT
Local Integer  YSTA
  YCTI = NewInstance C_YCONTRACT AllocGroup Null
  [L]YSTA = fmet YCTI.AREAD([L]CTNUM)         : # key segments of the class key
  If [L]YSTA < [V]CST_AERROR
    [L]YSTA = fmet YCTI.YCLOSE()              : # ARET_VALUE of the method
  Endif
  If [L]YSTA = [V]CST_AOK
    [L]YSTA = fmet YCTI.AUPDATE()             : # controls, events, database update
  Endif
  FreeGroup YCTI                              : # always, on every path
End [L]YSTA
```

Creation follows the same shape with `fmet YCTI.AINIT()`, property assignments and
`fmet YCTI.AINSERT()` (`v12-classes.md`). The errors stay on the instance until `FreeGroup`: dump
them first with `APUTINSTERRS` (last recipe) or `LOG_CLASS` in a test (`unit-testing-axunit.md`).

## Call an external REST API

```l4g
  [L]HCOD(1) = "Accept"
  [L]HVAL(1) = '"application/json"'           : # values are JSON constants
  [L]HTTPSTA = func ASYRRESTCLI.EXEC_REST_WS("YFXRATES", "GET", "/latest?base=EUR&symbols=USD",
  & [L]PCOD, [L]PVAL, [L]HCOD, [L]HVAL, "{}", 0, "", [L]RESHEAD, [L]RESBODY)
  If [L]HTTPSTA = 200
    ParseInstance OBJ With [L]RESBODY         : # Local Instance OBJ Using OBJECT
    If OBJ.Contains$("/rates/USD") = 0        : # 0 = the path exists
      [L]RATE = val(OBJ.Select$("$.rates.USD"))
    Endif
    FreeGroup OBJ
  Endif
```

The service name refers to a Syracuse "Outgoing REST web services" record (base URL, certificates,
Basic credentials). Retries, logging through `YINTLOG_WRITE` and the declarations:
`examples/YRESTRATE.src`; long bearer tokens, pagination, runtime availability of the JSON parser:
`web-services-rest-client.md`, `version-caveats.md`.

## Silent import from code

```l4g
  # Inside a routine that owns an ALOG instance YLOG (last recipe)
  [L]STA = func YIMPLAUNCH.YIMP_FILE("YCU", "ycust0001", [L]MSG)
  If [L]STA <> [V]CST_AOK
    [L]LOGST = fmet YLOG.APUTLINE("Import YCU:" - [L]MSG, [V]CST_AERROR)
  Endif
```

`YIMP_FILE` (`examples/YIMPLAUNCH.src`) checks the file, runs `Call IMPORTSIL(TEMPLATE, PATH) From
GIMPOBJ` with the trace handling of Sage's appendix, then renames the file `.done` or `.err`. The
template runs the object's controls as screen entry would (`imports-exports.md`).

## Send an e-mail

```l4g
Local Char    YFROM(250), YSUBJECT(250)
Local Char    YTO(250)(1..), YCC(250)(1..), YATTACH(250)(1..)
Local Clbfile YBODY(0)
Local Integer YSTA
  YFROM    = "erp@example.com"
  YTO(1)   = "finance@example.com"
  YSUBJECT = "Contrats clos"
  Append YBODY, "Bonjour," + chr$(10)
  Append YBODY, "Le traitement de clôture est terminé." + chr$(10)
  YSTA = func ASYRMAIL.ASEND_MAIL(GACTX, YFROM, YTO, YCC, YSUBJECT, YBODY, YATTACH, [V]CST_ANO)
  # [V]CST_AOK sent, [V]CST_AINFO an attachment is missing, [V]CST_AERROR failed
```

SMTP lives in Syracuse notification servers (parameters SYRMAIL / SYRMAILSRV). HTML content and the
routing through the notification server are not documented for this API: test before promising them
(`workflow-email.md`).

## ALOG log in a batch-callable subprogram

```l4g
# Script YCTBATCH - close the expired active contracts, one class update per contract
Subprog YCT_CLOSE_EXPIRED(NBOK, NBKO, LOGNAME)
Variable Integer NBOK, NBKO
Variable Char    LOGNAME()
Local File YCONTRACT [YCT]
Local Instance YLOG Using C_ALOG
Local Instance YCTI Using C_YCONTRACT
Local Integer  YSTA, LOGST
Local Date     TODAY
  [L]NBOK = 0 : [L]NBKO = 0
  If adxlog <> 0 : [L]NBKO = -1 : End : Endif  : # each AUPDATE needs its own supervisor transaction
  [L]TODAY = date$
  YLOG = NewInstance C_ALOG AllocGroup Null
  [L]LOGST = fmet YLOG.ABEGINLOG("YCT_CLOSE_EXPIRED")
  LOGNAME = fmet YLOG.AGETNAME()
  For [YCT]YCT0 Where YSTATUS = 2 and YENDDAT <> [0/0/0] and YENDDAT < [L]TODAY
    YCTI = NewInstance C_YCONTRACT AllocGroup Null
    [L]YSTA = fmet YCTI.AREAD([F:YCT]YCTNUM)
    If [L]YSTA < [V]CST_AERROR : [L]YSTA = fmet YCTI.YCLOSE() : Endif
    If [L]YSTA = [V]CST_AOK : [L]YSTA = fmet YCTI.AUPDATE() : Endif
    If [L]YSTA >= [V]CST_AERROR
      [L]NBKO += 1
      [L]LOGST = fmet YLOG.APUTLINE("Contrat" - [F:YCT]YCTNUM - "non clos", [V]CST_AERROR)
      [L]LOGST = fmet YLOG.APUTINSTERRS(YCTI)  : # the class errors, before FreeGroup
    Else
      [L]NBOK += 1
    Endif
    FreeGroup YCTI
  Next
  [L]LOGST = fmet YLOG.APUTLINE(num$([L]NBOK) - "clos," - num$([L]NBKO) - "en erreur", [V]CST_AINFO)
  [L]LOGST = fmet YLOG.AENDLOG()
  FreeGroup YLOG
End
```

It refuses to run inside a caller's transaction (`NBKO = -1`): called with no transaction open, each
`AUPDATE` runs in its own supervisor transaction, so one failing contract does not undo the others.
To run it as a batch task, call it from the `EXEC` action of a Standard process script, as
`examples/YTRFPOST.src` does (`batch-scheduling.md`). ALOG methods: `debugging-traces.md`.

## Stock and standard documents

Never `Update` / `Write` standard business tables such as `STOCK`, `SORDER` or `GACCOUNT` from specific
code: quantities, allocations, statuses and journals are maintained together by the standard
functions. Create stock movements and documents through the standard functions, their import
templates or their published web services, and check which one applies to your module and patch
level. This skill does not document a stock-movement API, and none should be invented.

## Gotchas

- `NewInstance` without `FreeGroup` on every path leaks memory in long batches.
- `ASETERROR` without `[L]ASTATUS = ...` records a message but does not stop the operation.
- Use `mess(N, CHAPTER, 1)` for texts (`localization.md`); literals are not translated.
- `GACTX` / `this.ACTX` give the user, folder and language; do not rely on Classic globals in class
  code.
- `Contains$` returns 0 when the path exists.
- Validate the class after every dictionary change: the generated code is what runs.

See also: `common-patterns.md`, `v12-classes.md`, `v12-representations.md`,
`web-services-rest-client.md`, `imports-exports.md`, `workflow-email.md`, `debugging-traces.md`.

## Sources
- https://online-help.sagex3.com/erp/12/en-us/Content/V7DEV/developer-guide_classes-events.html
- https://online-help.sagex3.com/erp/12/en-us/Content/V7DEV/developer-guide_event-control.html
- https://online-help.sagex3.com/erp/12/en-us/Content/V7DEV/developer-guide_classes-script.html
- https://online-help.sagex3.com/erp/12/en-us/Content/V7DEV/developer-guide_error-handling.html
- https://online-help.sagex3.com/erp/12/en-us/Content/V7DEV/developer-guide_managing-log-files.html
- https://online-help.sagex3.com/erp/12/en-us/Content/V7DEV/api-guide_api-asyrrestcli.html
- https://online-help.sagex3.com/erp/12/en-us/Content/V7DEV/4gl_parse-instance.html
- https://online-help.sagex3.com/erp/12/en-us/Content/V7DEV/api-guide_send-mail.html
- https://online-help.sagex3.com/erp/12/en-us/Content/FCT/GES_AOE1.htm
- https://online-help.sagex3.com/erp/12/en-us/Content/FCT/GESACLA.htm

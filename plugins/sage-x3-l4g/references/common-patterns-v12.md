# Common L4G patterns — V12 idioms

Recipes that lean on the V12 stack: classes, representations, REST services, IMP/EXP templates, scheduled batches with notification.

For the core / Classic recipes (transactions, sequential file, error handling, action-on-field, calling standard functions, debug traces, embedded SQL, sub-prog parameter passing, batch processing) see `common-patterns.md`.

## 1. V12 class with CRUD — wrapping a custom table

```l4g
##############################################################
# YCUSTLOG — class wrapping the YCUSTLOG table
##############################################################
Class YCUSTLOG

    Public Char    CODE(20)
    Public Char    LABEL(60)
    Public Decimal AMT
    Public Integer UPDTICK

    Public Method Load(CODE_IN)
    Value Char CODE_IN()
        Local File YCUSTLOG [YCL]
        Read [YCL]CODE0 = CODE_IN
        If fstat
            End 1
        Endif
        this.CODE    = [F:YCL]CODE
        this.LABEL   = [F:YCL]LABEL
        this.AMT     = [F:YCL]AMT
        this.UPDTICK = [F:YCL]UPDTICK
    End 0

    Public Method Save()
        # Optimistic update using UPDTICK
        Update YCUSTLOG Where CODE = this.CODE And UPDTICK = this.UPDTICK
            With LABEL = this.LABEL, AMT = this.AMT, UPDTICK = UPDTICK + 1
        If [S]adxuprec = 0
            End 1                          # changed by someone else
        Endif
        this.UPDTICK += 1
    End 0

Endclass
```

Call site:

```l4g
Local YCUSTLOG R
If R.Load("LOG001") = 0
    R.AMT = R.AMT + 100
    If R.Save() <> 0
        Errbox "Record changed, please refresh."
    Endif
Endif
```

See `v12-classes-representations.md` for representation wiring and `database.md` for `UPDTICK` semantics.

## 2. V12 REST service — transactional business operation

```l4g
##############################################################
# YSRV_RESERVE — POST /api/x3/erp/SEED/YSRV_RESERVE
# Reserves stock for an item; returns remaining quantity.
##############################################################
Class YSRV_RESERVE

    Public Char    ITMREF(30)
    Public Decimal QTY
    Public Decimal REMAINING                # out
    Public Char    STATUS(30)               # out

    Public Method Execute()
        Local File ITMMASTER [ITM], STOCK [STO]
        Local Integer IF_TRANS
        Local Decimal AVAIL

        Read [ITM]ITMREF0 = this.ITMREF
        If fstat
            this.STATUS = "UNKNOWN_ITEM"
            End 1
        Endif

        # Sum available stock
        AVAIL = 0
        For [STO] Where ITMREF = this.ITMREF
            AVAIL += [F:STO]QTYSTU
        Next

        If AVAIL < this.QTY
            this.REMAINING = AVAIL
            this.STATUS = "INSUFFICIENT"
            End 1
        Endif

        If adxlog
            Trbegin [STO]
            IF_TRANS = 0
        Else
            IF_TRANS = 1
        Endif

        Update STOCK Where ITMREF = this.ITMREF With QTYSTU = QTYSTU - this.QTY Top 1
        If fstat Or [S]adxuprec = 0
            If IF_TRANS = 0 : Rollback : Endif
            this.STATUS = "WRITE_FAILED"
            End 1
        Endif

        If IF_TRANS = 0 : Commit : Endif
        this.REMAINING = AVAIL - this.QTY
        this.STATUS = "OK"
    End 0

Endclass
```

Published as a service representation; callers POST JSON. See `web-services-rest.md`.

## 3. Consume an external REST API

```l4g
##############################################################
# YFETCH_RATE — get the EUR/USD rate from an external API
##############################################################
Funprog YFETCH_RATE(CUR)
Value Char CUR()

Local Char    URL(500), RESP(4000), BODY(200)
Local Integer HTTPCODE
Local Decimal RATE

URL = "https://api.exchangerate.example/latest?base=EUR&symbols=" - CUR
BODY = ""

Call HTTPGET(URL, RESP, HTTPCODE) From YHTTP

If HTTPCODE <> 200
    Call ECRAN_TRACE("HTTP " + num$(HTTPCODE), 2) From GESECRAN
    End 0
Endif

# Parse a simple {"rates":{"USD":1.08}} payload
RATE = val(func AFNC.JSONGET(RESP, "rates." - CUR))
End RATE
```

Caller:

```l4g
Local Decimal R
R = func YEXCHANGE.YFETCH_RATE("USD")
If R > 0
    Infbox "1 EUR = " + num$(R) + " USD"
Endif
```

See `web-services-rest.md` for OAuth, retry, and pagination patterns.

## 4. Import with custom validation via template hook

```l4g
##############################################################
# YIMP_CUST_CTRL — validation hook on import template YIMPCUS
# Declared in GESAOI as the CTRL call for each line
##############################################################
Subprog YIMP_CUST_CTRL()
    # The template has already populated [M:BPC] from the file

    # 1. Mandatory SIREN for French customers
    If [M:BPC]CRY = "FR" And [M:BPC]BPCCRN = ""
        [V]GOK = 0
        Call ECRAN_TRACE("SIREN obligatoire pour FR: " - [M:BPC]BPCNUM, 2) From GESECRAN
        End
    Endif

    # 2. Deduplicate against existing
    Local File BPCUSTOMER [BPX]
    Read [BPX]BPCNUM0 = [M:BPC]BPCNUM
    If !fstat
        # Already exists: let the template update it, but log
        Call ECRAN_TRACE("MAJ: " - [M:BPC]BPCNUM, 0) From GESECRAN
    Endif

    # 3. Set a default currency if missing
    If [M:BPC]CUR = ""
        [M:BPC]CUR = "EUR"
    Endif
End
```

Trigger the import:

```l4g
Call LECFIC("YIMPCUS", "TMP/customers.csv", "", "") From IMPOBJ
```

See `imports-exports.md` for template declaration details.

## 5. Scheduled batch with email summary

```l4g
##############################################################
# YBATCH_ORPHAN_ORDERS — daily, emails list of orders with no customer
##############################################################
$MAIN
Local File SORDER [SOH], BPCUSTOMER [BPC]
Local Char BODY(8000), SUBJECT(100)
Local Integer N
N = 0
BODY = "Commandes orphelines au " - num$(date$, "J/M/A") - ":" + chr$(13) + chr$(10)

For [SOH] Where SOHSTA <= 2 Order By Key SOHNUM0
    Link [BPC] With [F:SOH]BPCORD = [F:BPC]BPCNUM0
    If fstat                                 # customer missing
        Incr N
        BODY = BODY - [F:SOH]SOHNUM - "  (" - [F:SOH]BPCORD - ")" + chr$(13) + chr$(10)
    Endif
Next

If N = 0 : Return : Endif                    # nothing to report

BODY = BODY + chr$(13) + chr$(10) + num$(N) + " total"
SUBJECT = "[X3] " + num$(N) + " commandes orphelines"

Call ENVMAIL("ops@example.com", "", "", SUBJECT, BODY, "", "") From AMAIL
If [S]stat1
    Call ECRAN_TRACE("Email failed stat1=" + num$([S]stat1), 2) From GESECRAN
Endif
Return
```

Schedule with `GESABA` / `GESAPL`. See `workflow-email.md` for the `ENVMAIL` signature, `debugging-traces.md` for the retry-monitoring pattern, and `performance.md` for batch scheduling guidance.

See also: `common-patterns.md` (core / Classic recipes), `v12-classes-representations.md` (class and representation idioms), `web-services-rest.md` and `web-services-soap.md` (publishing services), `imports-exports.md` (templates and hooks), `workflow-email.md` (email and workflow rules).

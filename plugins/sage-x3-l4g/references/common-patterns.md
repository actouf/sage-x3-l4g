# Common L4G patterns — core recipes

Drop-in templates for the tasks that come up constantly in Classic and core L4G. Each one is complete and runnable; adapt table and field names for your case.

For V12-specific recipes (class with CRUD + `UPDTICK`, REST service, external REST consumption, import hook, scheduled batch with email), see `common-patterns-v12.md`.

## 1. Safe multi-table write inside a transaction

```l4g
##############################################################
# YCREATE_ORDER — create a sales order header and line atomically
##############################################################
Subprog YCREATE_ORDER(NUM, CUS, ITM, QTY)
Value   Char     NUM(), CUS(), ITM()
Value   Decimal  QTY
Local   Integer  IF_TRANS

Local File SORDER [SOH], SORDERQ [SOQ]

If adxlog
    Trbegin [SOH], [SOQ]
    IF_TRANS = 0
Else
    IF_TRANS = 1
Endif

# Header
Raz [F:SOH]
[F:SOH]SOHNUM = NUM
[F:SOH]BPCORD = CUS
[F:SOH]ORDDAT = date$
Write [SOH]
If fstat
    If IF_TRANS = 0 : Rollback : Endif
    End
Endif

# Line
Raz [F:SOQ]
[F:SOQ]SOHNUM = NUM
[F:SOQ]SOQSEQ = 1
[F:SOQ]ITMREF = ITM
[F:SOQ]QTYSTU = QTY
Write [SOQ]
If fstat
    If IF_TRANS = 0 : Rollback : Endif
    End
Endif

If IF_TRANS = 0 : Commit : Endif
End
```

## 2. Read a sequential file into a screen grid

```l4g
##############################################################
# $LIENS2 — populate the grid [M:ZTK0] from a text file
##############################################################
$LIENS2
Local Char    LINE(500)
Local Integer I, HDL

HDL = 1
Raz [M:ZTK0]
I = 0

Openi "TMP/data.csv" Using HDL
If fstat
    Errbox "Cannot open data file."
    Return
Endif

Repeat
    Readseq LINE Using HDL
    If fstat : Exit : Endif             # error or EOF
    Incr I
    If I > maxtab([M:ZTK0]) : Decr I : Exit : Endif
    [M:ZTK0]COL1(I) = mid$(LINE, 1, 30)
    [M:ZTK0]COL2(I) = val(mid$(LINE, 31, 10))
Until fstat

Close HDL
[M:ZTK0]NBLIG = I
Return
```

## 3. Pattern-match / filter an iteration

```l4g
Local File ITMMASTER [ITM]
Local Integer N
N = 0

For [ITM] Where pat(ITMREF, "Y*") <> 0 And ITMSTA = 1
    Incr N
    Call ECR_TRACE([F:ITM]ITMREF - " - " - [F:ITM]ITMDES1, 1) From GESECRAN
Next

Infbox num$(N) + " items found."
```

## 4. Error-handling boilerplate with `Onerrgo`

```l4g
Subprog YRISKY_CALL()

Onerrgo ERR_HANDLER

# --- risky code ---
Call ECR_TRACE("Starting risky block", 0) From GESECRAN
Openi "/some/file" Using 1
Readseq [L]DATA Using 1
# ... more code ...
Close 1
Return

$ERR_HANDLER
    # runs on any error above
    Close 1                              # release resources
    Call ECR_TRACE("Error " + num$([S]stat1) + " at " + num$([S]curpos), 2) From GESECRAN
    Infbox "An error occurred. See trace."
End
```

## 5. Standard action-on-field control (Sortie champ)

Validate a custom field on exit; block saving if invalid.

```l4g
##############################################################
# $CTRL_YCODE — control action on ZGESBPC.YCODE field
##############################################################
$CTRL_YCODE
If [M:BPC]YCODE = ""
    Return                              # empty is allowed, skip
Endif

If not pat([M:BPC]YCODE, "!!####")       # 2 letters + 4 digits
    Call ECRAN_TRACE("Format YCODE invalide (ex: AB1234)", 2) From GESECRAN
    GOK = 0
    Return
Endif

# Check uniqueness
Local File BPCUSTOMER [BPX]
Read [BPX]YCODEIDX = [M:BPC]YCODE
If !fstat And [F:BPX]BPCNUM <> [M:BPC]BPCNUM
    Call ECRAN_TRACE("YCODE déjà utilisé par " - [F:BPX]BPCNUM, 2) From GESECRAN
    GOK = 0
Endif
Return
```

## 6. Call a standard X3 function from custom code

Common examples:

```l4g
# Get the next number from a counter (sequence)
Call NUMERO("SOHNUM", [L]LEG, [L]SIT, [L]FCY, [L]DAT, "", [L]NUM) From GESNUM
# [L]NUM now holds the generated number

# Open a business object screen
Call OUVRE_TRT("GESBPC", "", "", [L]BPC, "", "", "", "", "") From GESAUT

# Get a parameter value
Local Char PVAL(50)
PVAL = func AFNC.PARAMG("CUR", "EUR", "SYM")   # currency symbol for EUR
```

## 7. Writing debug traces during development

```l4g
# Simple inline trace
Call ECRAN_TRACE("DEBUG: value=" + num$([L]VAL), 0) From GESECRAN

# Conditional trace (only when GDEBUG global is set)
If [V]YDEBUG
    Call ECRAN_TRACE("Detail: " + [L]MSG, 0) From GESECRAN
Endif

# Writing to a log file
Openo "TMP/ytrace.log" Using 9 Append
If !fstat
    Writeseq [L]MSG Using 9
    Close 9
Endif
```

## 8. SQL escape for complex queries

```l4g
Local Char QRY(1000)
Local Integer HDL
QRY = "SELECT COUNT(*) FROM ITMMASTER WHERE ITMREF LIKE 'Y%' AND ITMSTA = 1"

Local File FROM_SQL [SQL]
Local Decimal NB

Exec Sql QRY On 0 Into NB
If fstat
    Errbox "SQL error " + num$([S]stat1)
Else
    Infbox num$(NB) + " custom active items."
Endif
```

## 9. Sending data back from a subprogram via parameters

```l4g
##############################################################
# YGET_CUSTOMER — returns name and credit limit by reference
##############################################################
Subprog YGET_CUSTOMER(CUSID, CUSNAM, CREDIT)
Value    Char    CUSID()
Variable Char    CUSNAM()            # out
Variable Decimal CREDIT              # out

Local File BPCUSTOMER [BPC]
Read [BPC]BPCNUM0 = CUSID
If fstat
    CUSNAM = ""
    CREDIT = 0
Else
    CUSNAM = [F:BPC]BPCNAM(0)
    CREDIT = [F:BPC]CDTUNL            # or whatever your credit field is
Endif
End
```

Call site:

```l4g
Local Char    NAME(60)
Local Decimal LIMIT
Call YGET_CUSTOMER("BP001", NAME, LIMIT) From YCUSTOMER
```

## 10. Process an entry transaction end-to-end

The common template for a whole process script (`.trt`):

```l4g
##############################################################
# ZPROCESS_ORDERS — batch-close old orders
##############################################################
$MAIN
Local Integer N
N = 0

Local File SORDER [SOH]

For [SOH] Where SOHSTA = 1 And ORDDAT < date$ - 180
    Trbegin [SOH]
    Readlock [SOH]SOHNUM0 = [F:SOH]SOHNUM
    If fstat : Rollback : Continue : Endif
    [F:SOH]SOHSTA = 9                    # archived
    Rewrite [SOH]
    If fstat : Rollback : Continue : Endif
    Commit
    Incr N
Next

Call ECRAN_TRACE(num$(N) + " orders archived.", 1) From GESECRAN
Return
```

Note: short per-row transactions avoid holding locks across the whole iteration — a much better pattern for batch processing than a single big `Trbegin` around the `For`. See `performance.md` for the bounded-batch variant.

See also: `common-patterns-v12.md` (V12 class CRUD, REST service, external REST consumption, import hook, scheduled batch + email).

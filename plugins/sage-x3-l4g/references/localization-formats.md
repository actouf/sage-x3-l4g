# Localisation: currencies, countries and character sets

Currency data (decimals, rounding, symbols, formats), exchange-rate rows, country rules (postal code and
phone formats, ISO codes), address columns, and the character-set facts that matter when text crosses the
database or a file. Read it before formatting an amount, converting between currencies, validating an
address, or loading non-Latin text. Messages, languages, dates and numbers are in `localization.md`.

## Contents
- [Currencies (GESTCU, TABCUR)](#currencies-gestcu-tabcur)
- [Rounding and formatting an amount](#rounding-and-formatting-an-amount)
- [Exchange rates (TABCHANGE)](#exchange-rates-tabchange)
- [Countries (GESTCY, TABCOUNTRY)](#countries-gestcy-tabcountry)
- [Addresses](#addresses)
- [Character sets and text length](#character-sets-and-text-length)
- [Gotchas](#gotchas)
- [Sources](#sources)

## Currencies (GESTCU, TABCUR)

Currencies are maintained in GESTCU (Common data > Common tables > Currencies) and stored in table TABCUR
`[TCU]`, index `TCU0` = CUR. Column names come from the table dictionary; the GESTCU screen uses other
field codes for some of them (FM1/FM2/FM3 on screen are CURFMT1/CURFMT2/CURFMT3 in the table).

| Column | Meaning |
|---|---|
| CUR | Currency code (ISO 4217 code advised) |
| INTDES, INTSHO | Description, short description (types AX3 / AX1: translated text in ATEXTRA) |
| ISOCOD, ISONUMCOD | ISO 4217 alphabetic and numeric codes |
| CURSYM | Monetary symbol |
| DECNBR | Number of significant decimals of amounts in this currency |
| CURRND | Rounding: all amounts in the currency are rounded to this precision |
| CURFMT1, CURFMT2, CURFMT3 | Display formats for standard amounts, small amounts (unit prices) and totals |
| EURFLG, EURRAT, EURDAT | Euro-zone flag (local menu 1), counter-value in euros, euro changeover date |
| CURENDDAT | Date the currency leaves circulation (no exchange rates after it) |

The effective number of decimals of **unit prices** is driven by the `GDECPRI` variable, not by DECNBR
(GESTCU help).

## Rounding and formatting an amount

`arr(VALUE, STEP)` rounds half away from zero to a step (`arr(x, 0.05)`); `arr(VALUE, 0)` returns the
value unchanged. Use CURRND as the step, DECNBR for the number of decimals to display:

```l4g
# Amount rounded to the currency precision and formatted with its symbol
Funprog YFMT_AMOUNT(AMT, CUR)
Value Decimal AMT
Value Char    CUR()
Local File TABCUR [TCU]
Local Char FMT(20)
  Read [TCU]TCU0 = [L]CUR
  If fstat : End num$([L]AMT) : Endif
  If [F:TCU]DECNBR > 0
    [L]FMT = "N3:15." + num$([F:TCU]DECNBR) : # 15 integer digits, grouped by 3
  Else
    [L]FMT = "N3:15#"                       : # no decimals (JPY...)
  Endif
End format$([L]FMT, arr([L]AMT, [F:TCU]CURRND)) + " " + [F:TCU]CURSYM
```

In V7+ class code, small tables such as currencies can be read through the context cache instead of a
`Local File`. The developer guide's example declares a cache class `ACUR` (properties CUR, CURRND,
EURFLG, EURDAT) and reads it through `this.ACTX.ACACHE`; check in GESACLA which cache class and
properties exist in your folder before reusing the names:

```l4g
Local Integer CURIDX
  [L]CURIDX = fmet this.ACTX.ACACHE.ACUR.AGETINDEX(this.YCUR)
  If [L]CURIDX <> [V]CST_ANOTDEFINED
    this.YAMOUNT = arr(this.YAMOUNT, fmet this.ACTX.ACACHE.ACUR.AGETVALDEC(this.YCUR, "CURRND"))
  Endif
```

When the currency is unknown, raise an error on the property instead (ASETERROR, see `v12-classes.md`).
Cached values stay as loaded until the session restarts.

## Exchange rates (TABCHANGE)

Rates live in table TABCHANGE `[TCH]`:

| Column | Meaning |
|---|---|
| CHGTYP | Rate type (local menu 202; read labels with `mess(TYPE, 202, 1)`) |
| CURDEN | Currency of the pair, titled "Destination currency" in the dictionary |
| CUR | Other currency of the pair |
| CHGSTRDAT | Rate date (start of validity) |
| CHGRAT, CHGDIV, REVCOURS | Rate, divisor, reverse rate |

Indexes: `TCH0` = CHGTYP+CURDEN+CUR+CHGSTRDAT, `TCH1` = CHGTYP+CURDEN+CHGSTRDAT+CUR.

- Rates are typed in the **Currency rates** screen (Common data > Common tables > Currency rates,
  community-reported; no function code could be verified) or loaded by FUNCURRAT from the Sage FX Rate
  Service. FUNCURRAT needs a REST web service named CURRATAPI, only updates currencies that already have a
  manually entered rate, and saves the rate on the day after the rate date.
- The FUNCURRAT screen labels CURDEN "Source currency" while the table dictionary says "Destination
  currency". Before writing a conversion formula, check the direction of CHGRAT / CHGDIV on a known pair in
  your folder.
- Euro-zone legacy currencies use EURFLG / EURRAT on the currency instead of the rate table.
- No standard conversion subprogram is documented in the public help: do not guess a name. To read the
  row in force at a date:

```l4g
# Latest rate row of type RTYPE for (CURDEN, CUR) dated on or before RDATE
Funprog YRATE_ROW(RTYPE, CURDEN, CUR, RDATE, RATE, DIVISOR)
Value    Integer RTYPE
Value    Char    CURDEN(), CUR()
Value    Date    RDATE
Variable Decimal RATE, DIVISOR
Local File TABCHANGE [TCH]
  [L]RATE = 0
  [L]DIVISOR = 0
  Read [TCH]TCH0 <= [L]RTYPE; [L]CURDEN; [L]CUR; [L]RDATE
  If fstat <> 0 and fstat <> 2 : End [V]CST_AFALSE : Endif
  # <= may stop on the previous pair or rate type: check the key segments
  If [F:TCH]CHGTYP <> [L]RTYPE or [F:TCH]CURDEN <> [L]CURDEN or [F:TCH]CUR <> [L]CUR
    End [V]CST_AFALSE
  Endif
  [L]RATE = [F:TCH]CHGRAT
  [L]DIVISOR = [F:TCH]CHGDIV
End [V]CST_ATRUE
```

Store the rate and the rate date next to every converted amount you persist: recomputing later with the
current rate gives a different result.

## Countries (GESTCY, TABCOUNTRY)

Countries are maintained in GESTCY (Common data > Common tables > Countries) and stored in TABCOUNTRY
`[TCY]`, index `TCY0` = CRY. GESACO is **not** the country function (it manages field headings).

| Column | Meaning |
|---|---|
| CRY, CRYDES | Country code, name (translatable) |
| ISO, ISOA3, ISONUM | ISO 3166-1 alpha-2, alpha-3, numeric |
| CUR, LAN | Default currency and language |
| POSCODFMT | Postal code format applied at address entry (postal code: 10 characters maximum) |
| MINZIP | Number of leading characters used by the postal code control (0 = whole code) |
| POSCODCTL, POSOBL | Postal code control; postal code and city mandatory on addresses |
| CTYCODFMT, CTYUPP | City format; force cities to upper case |
| ADRCODFMT | Address entry format |
| TELFMT, TELTCY, TELREG | Phone number format and the positions of country and region prefixes |
| EECFLG, EECFMT | EU member; VAT number format |
| CTLPRG | Control script holding the identifier checks (bank ID...) |

- The formats are 4GL formatting strings: the help's US postal example is `5#[-]4#` (5 digits, a dash,
  4 digits); with MINZIP = 5, the city is looked up on the first 5 characters when no city matches the
  full code.
- Standard address entry applies these controls. Read the country's format instead of hard-coding one
  pattern per country in specific code, and remember that a direct `Write` into an address table bypasses
  entry controls.
- GESTCY documents the standard subprogram `DECOUPE(PAYS, TEL, INTER, REGION, NUTEL) From CONTNUM`, which
  splits a formatted phone number using TELTCY / TELREG.

## Addresses

Business-partner addresses are in BPADDRESS `[BPA]`, index `BPA0` = BPATYP+BPANUM+BPAADD, with
`BPAADDLIG` (3 address lines), `POSCOD`, `CTY`, `SAT` (county / state), `CRY` and `CRYNAM`. The public help
documents no address-formatting API: earlier versions of this skill cited `FORMAT_ADDR From GESACO`, which
does not exist. Build a printed layout in your own `Y` function from these columns and the country record,
or in the report.

## Character sets and text length

- **Database**: a folder's character format (GESADS, field CODDBA) is ASCII (one byte per character,
  European languages) or UNICODE. UCS2 is the only Unicode format supported by SQL Server; Oracle commonly
  uses UTF8. Unicode is needed for languages with more than 256 characters (Chinese, for example);
  TABLAN.LANUNI flags such languages.
- **Engine**: works internally in UTF8, and script sources are UTF8.
- **Char**: `Char NAME(N)` holds up to N characters (1 to 255), stored as double-byte characters; `len`
  and `mid$` count characters, not bytes. Assigning a longer string truncates it to N characters, so check
  `len()` before assigning external data; use `Clbfile` beyond 255 characters.
- **Accents**: `ctrans(S)` with one argument replaces accented characters by unaccented ones and
  non-printable characters by spaces. It loses information: use it for search keys or 7-bit exports only.
- **Files**: choose the encoding per file with `Iomode adxium VALUE Using [ABV]`: 50 = ASCII, 122 = UCS2,
  any other value = UTF8 (the default). `strencode` / `strdecode(SOURCE, DEST, TYPE)` transcode strings
  with the same codes (50, 122, 0). Details: `sequential-files.md`.
- **Right-to-left and CJK text**: test screens, printed reports and exported files with real data in the
  target script before go-live.

## Gotchas
- GESCUR does not exist: currencies are GESTCU. Countries are GESTCY, not GESACO.
- DECNBR is a number of decimals; CURRND is a rounding precision. Do not mix them.
- Screen field codes are not always column names (FM1 on GESTCU is column CURFMT1).
- A `Read ... <=` on TABCHANGE can return a row of another pair: always check the key segments.
- `GDEV.DEVISE`, `AFNC.PARAMG` and `FORMAT_ADDR` from earlier versions of this skill are not documented
  APIs; do not use them.
- A Char variable truncates without error: a 40-character Chinese name fits in `Char(40)`, a 41-character
  one is cut.

See also: `localization.md`, `function-codes.md`, `builtin-functions.md`, `sequential-files.md`,
`imports-exports.md`.

## Sources
- https://online-help.sagex3.com/erp/12/en-us/Content/FCT/GESTCU.htm
- https://online-help.sagex3.com/erp/12/en-us/Content/MCD/TABCUR.htm
- https://online-help.sagex3.com/erp/12/en-us/Content/MCD/TABCHANGE.htm
- https://online-help.sagex3.com/erp/12/en-us/Content/FCT/FUNCURRAT.htm
- https://online-help.sagex3.com/erp/12/en-us/Content/FCT/GESTCY.htm
- https://online-help.sagex3.com/erp/12/en-us/Content/MCD/TABCOUNTRY.htm
- https://online-help.sagex3.com/erp/12/en-us/Content/MCD/BPADDRESS.htm
- https://online-help.sagex3.com/erp/12/en-us/Content/MCD/TABLAN.htm
- https://online-help.sagex3.com/erp/12/en-us/Content/FCT/GESADS.htm
- https://online-help.sagex3.com/erp/12/en-us/Content/V7DEV/developer-guide_cached-classes.html
- https://online-help.sagex3.com/erp/12/en-us/Content/V7DEV/4gl_arr.html
- https://online-help.sagex3.com/erp/12/en-us/Content/V7DEV/4gl_format$.html
- https://online-help.sagex3.com/erp/12/en-us/Content/V7DEV/4gl_read.html
- https://online-help.sagex3.com/erp/12/en-us/Content/V7DEV/4gl_char.html
- https://online-help.sagex3.com/erp/12/en-us/Content/V7DEV/4gl_len.html
- https://online-help.sagex3.com/erp/12/en-us/Content/V7DEV/4gl_ctrans.html
- https://online-help.sagex3.com/erp/12/en-us/Content/V7DEV/4gl_adxium.html
- https://online-help.sagex3.com/erp/12/en-us/Content/V7DEV/4gl_strencode.html
- https://communityhub.sage.com/sage-global-solutions/sage_x3/b/sageerp_x3_product_support_blog/posts/reviewing-the-currency-rate-history (community: Currency rates screen path)

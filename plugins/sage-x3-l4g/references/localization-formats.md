# Localisation — currencies, addresses, RTL/CJK

How to handle currency-aware amounts, country-specific address layouts, and right-to-left / double-byte languages in L4G. Companion to `localization.md` (which covers messages, language, dates, and numbers).

## Currencies (`GESCUR` / `GESDEV`)

Path: **Setup → Currencies → Currencies**.

`GESCUR` declares currency codes (`EUR`, `USD`, `JPY`, etc.) with their attributes:

| Field | Use |
|-------|-----|
| `CUR` | 3-letter code |
| `CURDES` | Description (per language) |
| `CURSYM` | Symbol (`€`, `$`, `¥`) |
| `CURDEC` | Number of decimals (`2` for EUR, `0` for JPY) |
| `EUR` | Euro flag (legacy zone-EUR rules) |

Read them via `func AFNC.PARAMG`:

```l4g
Local Char    SYM(5)
Local Integer DEC

SYM = func AFNC.PARAMG("CUR", "EUR", "SYM")     # "€"
DEC = val(func AFNC.PARAMG("CUR", "EUR", "DEC"))  # 2

Local Char AMT_STR(20)
AMT_STR = format$("F" + num$(DEC), [F:SOH]AMT) - " " - SYM
```

### Multi-currency calculation

Always store amounts with their currency code (`AMT` + `CUR` columns). When converting:

```l4g
Local Decimal RATE, AMT_EUR
Call DEVISE([F:SOH]CUR, "EUR", [F:SOH]ORDDAT, RATE) From GDEV
AMT_EUR = [F:SOH]AMT * RATE
```

`GDEV.DEVISE` looks up the rate from `GESCURRATE` for the given pair and date. Use the order date for historical rates, not `date$`.

### Rounding and reporting

Each currency has a rounding precision (`CURDEC` decimals). Apply consistently:

```l4g
Local Decimal AMT_RND
AMT_RND = round([L]AMT, val(func AFNC.PARAMG("CUR", [F:SOH]CUR, "DEC")))
```

`round()` ties to even by default — for legal-accounting jurisdictions that require half-up, wrap with an explicit helper.

For multi-currency reports, always store both the raw and the base-currency value to avoid rate drift between calculation and display:

```l4g
[F:YREP]AMT_RAW = [L]AMT
[F:YREP]CUR_RAW = [L]CUR
[F:YREP]AMT_EUR = [L]AMT * [L]RATE
[F:YREP]RATE_AT = [L]RATE
[F:YREP]RATE_DAT = [L]ORDDAT
```

## Address formats — country-specific

Customer addresses don't fit a single template:

```
US:                    UK:                    JP:
Name                   Name                   〒postcode
Street                 Street                 prefecture city
City, State Zip        City                   street block-house
                       Postcode               Name
```

`GESACO` (countries) defines the address layout per country, including:

- Field order (street → city → zip vs zip → city → street)
- Postcode format / validation pattern
- Mandatory fields per country

When displaying or printing an address, call the standard formatter:

```l4g
Local Char ADDR_FMT(500)
Call FORMAT_ADDR([F:BPA]CRY, [F:BPA]ADDLIG(0), [F:BPA]CTY, [F:BPA]POSCOD, ADDR_FMT) From GESACO
# ADDR_FMT contains a country-correctly-formatted multi-line address
```

`FORMAT_ADDR` is one of several standard helpers — verify the exact signature on your patch level (`version-caveats.md`).

### Validating a postcode

Per-country postcode patterns live in `GESACO`. Check on data entry:

```l4g
Local Char PATTERN(50)
PATTERN = func AFNC.PARAMG("CRY", [M:BPA]CRY, "POSCODFMT")
If PATTERN <> "" And not pat([M:BPA]POSCOD, PATTERN)
    GOK = 0
    Errbox mess(102, 1000, 1)             # "Postcode format invalide"
Endif
```

Don't hardcode `pat([M:BPA]POSCOD, "#####")` — France is 5 digits, UK is alphanumeric variable length, US is 5 or 9 digits with optional dash, etc.

## Right-to-left and double-byte languages

Arabic, Hebrew (RTL), and CJK languages bring extra concerns:

- **Field lengths** in bytes vs characters — UTF-8 multi-byte characters fill `Char(60)` faster than Latin. Increase widths for fields holding non-Latin text.
- **`len$()` vs `nchar$()`** — `len$()` returns byte count, `nchar$()` (when available) returns character count. Use the right one for length checks.
- **String trimming** — `left$`, `right$`, `mid$` work on bytes; truncating mid-character corrupts UTF-8.
- **Sort order** — locale-aware sort requires `Order By` with explicit collation, not `Order By Key` alone. SQL-side `Exec Sql` with the right collation works; pure L4G ordering may misorder accents and CJK.

For these languages, test every screen and every printed report with real content before signing off.

### CJK-specific

- Font availability — printed reports rendered through Crystal need a font that has full CJK glyph coverage installed on the report server.
- Half-width vs full-width characters — Japanese inputs may produce either; normalize on entry if the data is queried later.

### RTL-specific

- Bidirectional rendering — mixing Arabic / Hebrew with Latin script in the same field. Syracuse handles this in browser; printed PDFs depend on the renderer.
- Number formatting in RTL — numerals stay left-to-right but appear in an RTL paragraph. Don't reverse them manually.

## Format-related pitfalls

- **Hardcoded currency decimals** — `format$("F2", AMT)` ships and breaks for JPY (which has 0 decimals). Look up `CURDEC` per currency.
- **Currency mismatch in totals** — summing `[F:SOH]AMT` across orders without converting to a base currency. Always convert and store both raw and base.
- **Stale exchange rate** — recomputing `AMT_EUR` from `AMT_RAW` at display time uses *today's* rate, not the order date's. Persist the rate at write time.
- **Rounding once vs at each step** — converting then summing loses pennies vs summing then converting once. Pick one and document it.
- **Address truncation** — `left$([F:BPA]ADDLIG(0), 30)` cuts mid-character on UTF-8 input. Use `nchar$()` or test with real Japanese / Arabic addresses.
- **Hardcoded postcode pattern** — see above. Pull from `GESACO`.
- **`FORMAT_ADDR` not available on the patch** — check before relying. If absent, build a small `YFMTADDR` helper that reads the country's layout from `GESACO` and falls back to "name / lines / city / postcode" generic order.
- **Sort by `Order By Key` for a customer-name search** — case- and accent-insensitive search needs a collation-aware index or `Exec Sql LOWER(strip(...))`. Plain `Order By Key` follows the column's stored byte order.
- **Mixing left-to-right and right-to-left** in the same printed line — renderers handle differently. Test on the actual production renderer before sign-off.

## Format / currency / address checklist

1. Every amount display reads `CURDEC` / `CURSYM` from `GESCUR`?
2. Currency conversions use the right date and a real exchange rate?
3. Reports persist both raw and base-currency amounts with the rate used?
4. Address output uses `FORMAT_ADDR` or the country-specific layout?
5. Postcode validation pulls the pattern from `GESACO`?
6. Field lengths sized for UTF-8 multi-byte content?
7. CJK / RTL tested on real content (screen + print) before sign-off?
8. Sort and search behaviour verified for accents / collation?

See also: `localization.md` (messages, `[V]GLANGUE`, dates, numbers), `conventions-and-naming.md` (Y/Z rule), `workflow-email.md` (multi-language templates), `version-caveats.md` (`FORMAT_ADDR` availability), `code-review-checklist.md` (Tier 2 hardcoded-format flags).

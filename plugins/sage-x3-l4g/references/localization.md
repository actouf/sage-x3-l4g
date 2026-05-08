# Localisation — messages, currencies, dates, formats

How to write code that runs in a French folder, an English folder, a German folder, and a Japanese folder without rewriting strings, dates, numbers, currency symbols, or address formats. Covers `mess()`, `GESAML` chapters, `[V]GLANGUE`, multi-currency parameters, date / time format codes, and translation discipline for templates and emails.

For naming conventions (chapters, three-letter codes), see `conventions-and-naming.md`. For email templates that need to localise their body, see `workflow-email.md`.

## The localisation surfaces in X3

| Surface | Mechanism | Where it lives |
|---------|-----------|----------------|
| User-facing messages | `mess(num, chapter, lang)` | `GESAML` (message chapters) |
| Field labels | Dictionary table descriptions per language | `GESATB` |
| Menu / function names | Function code + per-language label | `GESAFC` |
| Date / time display | `format$` codes + `[V]GFORMA` | Folder parameters |
| Currency | `GESCUR` + `GESDEV` | Per-folder |
| Address layout | `GESACO` + country-specific rules | Per-country |
| Email templates | Per-language body | Workflow templates |

Three rules you internalise once and never break:

1. **Never put a literal user-facing string in code.** Always `mess()` with a chapter and number.
2. **Never assume a date format.** Always `format$` or read the user's `[V]GFORMA`.
3. **Never assume a currency or its decimal places.** Always look it up via `GESCUR` / `func AFNC.PARAMG("CUR", code, "...")`.

## Messages and chapters (`mess` / `GESAML`)

Path: **Setup → General parameters → Messages**.

Messages are organised in **chapters**:

| Chapter | Standard or custom | Use |
|---------|--------------------|-----|
| 1 – 999 | Reserved standard | Don't add to these |
| 1000+ | Custom (Y or Z prefixed by convention) | Your project's messages |

Each chapter is a number; each message inside has a number and a translation per supported language.

### `mess()` signature

```l4g
Errbox mess(num, chapter, lang)
```

| Arg | Meaning | Common value |
|-----|---------|--------------|
| `num` | Message number within the chapter | `123` |
| `chapter` | Chapter number | `1000` for your custom chapter |
| `lang` | Language flag | `1` = current session language (`[V]GLANGUE`) |

Almost always pass `1` for `lang` — the engine resolves to the user's current language. Pass an explicit code (`"FRA"`, `"ENG"`) only when generating a document in a non-default language (e.g. emailing a partner in their own language).

```l4g
# Display the right language to the user
Errbox mess(45, 1000, 1)

# Force a specific language (sending an email to a French partner from an English session)
Local Char SUBJECT(100)
SUBJECT = mess(45, 1000, [F:BPC]LAN)         # use the partner's language
```

### Defining a message

In `GESAML`:

1. Open the chapter (or create one with a `Y`/`Z` prefix for your custom range).
2. Add the message number (e.g. `45`).
3. Fill the translation grid for every supported language: `FRA`, `ENG`, `GER`, `SPA`, etc.
4. Save and validate — messages are now resolvable from L4G.

If you use a number / chapter that has no translation in the user's language, the engine falls back to language code 1 (typically French in default installs) — never `mess()` returns blank, so a missing translation surfaces as the wrong language, not as a crash.

### Custom chapter numbering

| Range | Use |
|-------|-----|
| 1000 – 1999 | General custom messages for your project |
| 2000 – 2999 | Module / vertical-specific (e.g. all `YINT` messages) |
| 8000 – 8999 | Reserved for partner / customer-specific extensions |

Reserve chapters per module to avoid collisions when integrating multiple custom modules.

### `mess` vs `messa` vs literals

| Use | When |
|-----|------|
| `mess(n, ch, 1)` | Standard message lookup |
| `messa(n, ch, 1)` | Returns trimmed string (no trailing spaces) |
| String literal | Only for log messages, traces (developer-facing), and code comments |

```l4g
# DEV-facing — literal is fine
Call ECRAN_TRACE("YBATCH started, args=" + [V]GPARAM1, 0) From GESECRAN

# USER-facing — always mess()
Errbox mess(45, 1000, 1)
```

The line: anything a non-developer will read is `mess()`. Traces and ECRAN_TRACE strings stay literal because they're only seen in dev or by support engineers reading the log.

## Session language — `[V]GLANGUE`

The engine sets `[V]GLANGUE` from the user's profile at session start. Common values:

| Code | Language |
|------|----------|
| `FRA` | French |
| `ENG` | English |
| `GER` | German |
| `SPA` | Spanish |
| `ITA` | Italian |
| `DUT` | Dutch |
| `POR` | Portuguese |
| `JPN` | Japanese |
| `CHI` | Chinese |

Read it when you need to vary behaviour by language (rare — usually you want `mess()` to handle it):

```l4g
If [V]GLANGUE = "FRA"
    Local Char DATE_FMT(10)
    DATE_FMT = "JJ/MM/AAAA"
Else
    DATE_FMT = "MM/DD/YYYY"
Endif
```

Better: use `[V]GFORMA` (date format) which the engine already populates from the language / folder.

## Date and time formatting

Date formats are language- and folder-dependent.

### `format$()` codes

| Code | Meaning | Example |
|------|---------|---------|
| `J` / `D` | Day | `15` |
| `M` | Month | `12` |
| `A` / `Y` | Year | `2024` |
| `JJ/MM/AAAA` | French long | `15/12/2024` |
| `MM/DD/YYYY` | US long | `12/15/2024` |
| `DD-MMM-YYYY` | UK with month name | `15-DEC-2024` |
| `H` | Hour (24h) | `14` |
| `M` (in time context) | Minute | `35` |
| `S` | Second | `42` |

### Pattern: format dates in user's language

```l4g
Local Char DATE_STR(20)

# Use the folder's default format
DATE_STR = num$([F:SOH]ORDDAT, [V]GFORMA)

# Or force a specific format (e.g. logging)
DATE_STR = num$(date$, "AAAA-MM-JJ")            # ISO-like, language-agnostic
```

Two safe defaults:

- **For display to the user** — use `[V]GFORMA` to respect their preference.
- **For logs, files, integration payloads** — use ISO `AAAA-MM-JJ`. Never assume a locale.

### Pattern: parse a date from a string

```l4g
Local Date    D
Local Integer ERR
D = gdat([L]DATE_STR, [V]GFORMA, ERR)
If ERR
    Errbox mess(46, 1000, 1)                     # "Invalid date format"
Endif
```

`gdat` returns `[1841-12-29]` (epoch) on parse failure; the `ERR` out-param is the diagnostic. Always check it.

## Numbers and decimal separators

Decimal separator varies by language: `.` in English, `,` in French. The engine handles display via `num$()` based on `[V]GLANGUE`, but **string parsing of numbers is locale-sensitive**:

```l4g
# val() expects the engine's internal locale (typically "."); fine for code-internal.
Local Decimal V
V = val("12.50")                                  # works

# For user-supplied input, convert separators first
[L]INPUT = replace$([L]INPUT, ",", ".")
V = val([L]INPUT)
```

For amounts, decimals depend on the currency (`GESCUR` defines them per code) — see the currency section below.

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

## Translation discipline for emails and templates

Workflow rule emails (`GESAWR`) support per-language templates:

1. In `GESAWS` (templates), the body is stored once per language.
2. Recipients receive the version matching their language profile.
3. `[V_xxx]` substitutions resolve from the rule's variable bindings; the surrounding text is the translated template.

Pattern for code-built emails:

```l4g
Local Char SUBJECT(100), BODY(8000), LAN(3)

# Use the recipient's language, not the sender's
LAN = [F:BPC]LAN
If LAN = "" : LAN = [V]GLANGUE : Endif

SUBJECT = mess(100, 1000, val(num$(LAN)))         # if mess accepts numeric language flag
# Or pass the language code as the third arg if your patch level supports it:
# SUBJECT = mess(100, 1000, LAN)

BODY = mess(101, 1000, val(num$(LAN)))
BODY = replace$(BODY, "%CUSTOMER%", [F:BPC]BPCNAM(0))
BODY = replace$(BODY, "%AMOUNT%",   num$([L]AMT, "F2"))

Call ENVMAIL([F:BPC]EMAIL, "", "", SUBJECT, BODY, "", "") From AMAIL
```

The template-with-placeholder pattern (`%CUSTOMER%` etc.) keeps translatable copy separate from variable substitution.

## Right-to-left and double-byte languages

Arabic, Hebrew (RTL), and CJK languages bring extra concerns:

- **Field lengths** in bytes vs characters — UTF-8 multi-byte characters fill `Char(60)` faster than Latin. Increase widths for fields holding non-Latin text.
- **`len$()` vs `nchar$()`** — `len$()` returns byte count, `nchar$()` (when available) returns character count. Use the right one for length checks.
- **String trimming** — `left$`, `right$`, `mid$` work on bytes; truncating mid-character corrupts UTF-8.
- **Sort order** — locale-aware sort requires `Order By` with explicit collation, not `Order By Key` alone. SQL-side `Exec Sql` with the right collation works; pure L4G ordering may misorder accents and CJK.

For these languages, test every screen and every printed report with real content before signing off.

## Common pitfalls

- **Literal English string** in production code that runs in French — caught by `code-review-checklist.md` Tier 2.
- **Hardcoded date format** — `num$(D, "MM/DD/YYYY")` ships, French users see `12/15/2024` and read it as 12 December 15 (which doesn't exist). Use `[V]GFORMA`.
- **Hardcoded currency decimals** — `format$("F2", AMT)` ships and breaks for JPY (which has 0 decimals). Look up `CURDEC`.
- **Currency mismatch in totals** — summing `[F:SOH]AMT` across orders without converting to a base currency. Always convert and store both raw and base.
- **Mess number reused across chapters** — `mess(45, 100, 1)` and `mess(45, 1000, 1)` are different messages. Document chapters in a per-project chapter map.
- **Non-existent language code** — `mess(n, ch, "XXX")` returns the language-1 fallback silently, which looks fine in dev (where the engine is in French) and broken in prod.
- **Truncating a UTF-8 string** with `left$()` — display garbage on screen for the cut-mid-character row. Use `nchar$()`-aware truncation.
- **Email template not translated** — recipients in other languages get the default-language body. Always provide translations or fall back to a marked "untranslated" version.

## Localisation checklist

1. Every user-facing string goes through `mess()`?
2. Every date display uses `[V]GFORMA` or an explicit ISO format for logs?
3. Every amount display reads `CURDEC` / `CURSYM` from `GESCUR`?
4. Currency conversions use the right date and a real exchange rate?
5. Address output uses `FORMAT_ADDR` or the country layout?
6. Email templates exist in every supported language?
7. Field lengths sized for UTF-8 multi-byte content?
8. New custom chapter declared in `GESAML` and reserved in your project's chapter map?

See also: `conventions-and-naming.md` (chapter ranges, Y/Z rule), `workflow-email.md` (`ENVMAIL`, multi-language email templates), `builtin-functions.md` (`format$`, `num$`, `gdat`), `code-review-checklist.md` (Tier 2 — hardcoded strings), `version-caveats.md` (`mess` signature variants, `FORMAT_ADDR` availability).

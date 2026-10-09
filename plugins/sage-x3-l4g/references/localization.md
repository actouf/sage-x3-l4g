# Localisation: messages, language, dates and numbers

How translatable texts are stored and read (`mess`, APLSTD, ATEXTE, ATEXTRA), how to find the session
language, how to produce text in another language than the session's, and how dates and numbers are
formatted and parsed. Read it whenever code shows text to a user, writes a document for a partner, or
reads dates and amounts from a file. Currencies, countries and character sets are in
`localization-formats.md`.

## Contents
- [Where translatable text lives](#where-translatable-text-lives)
- [mess and message chapters](#mess-and-message-chapters)
- [Local menu values](#local-menu-values)
- [Session, folder and partner language](#session-folder-and-partner-language)
- [Text in another language than the session](#text-in-another-language-than-the-session)
- [Dates](#dates)
- [Numbers](#numbers)
- [Gotchas](#gotchas)
- [Sources](#sources)

## Where translatable text lives

| Table | Holds | Read in the connection language | Maintained in |
|---|---|---|---|
| APLSTD `[AST]` | Message chapters and local menus, one row per chapter + number + language | `mess(NUM, CHAPTER, 1)` | TXT |
| ATEXTE `[ATX]` | Dictionary texts (field titles...), identified by a number | `func AFNC.TEXTE(NUMBER)` | the dictionary functions |
| ATEXTRA `[AXX]` | Translatable data: columns whose data type starts with `AX` (descriptions of currencies, languages, miscellaneous tables...) | `func AFNC.TEXTRA(TABLE, FIELD, KEY1, KEY2)` | the function owning the data |

- The help gives the two AFNC calls in formula (calculator) syntax; the text is returned in the current
  connection language.
- An `AX*` column is not really stored in its table: the text sits in ATEXTRA under the key table + field
  + language + record key (`AXX0` = CODFIC+ZONE+LANGUE+IDENT1+IDENT2). The help's example for
  miscellaneous table 23, code COD, field LNGDES in French is the key `ATABDIV` / `LNGDES` / `FRA` /
  `23` / `COD`.
- ATEXTE numbers below 100,000 are standard and stable; specific texts get numbers above 100,000,
  assigned automatically and possibly renumbered by patch integration. Never hard-code an ATEXTE number of
  a specific text.

## mess and message chapters

```
mess(NUMBER, CHAPTER, TABLE)
```

| Argument | Meaning |
|---|---|
| NUMBER | Message number in the chapter |
| CHAPTER | Chapter number |
| TABLE | Message table: `1` = application messages (table APLSTD, whose name is in the `adxtms` variable), `0` = engine messages (a file in the engine's `lan` directory) |

- The result is a `Char` in the **language of the connection**. The third argument is not a language.
- Engine chapter 13 holds the engine error messages: `errmes$(N)` equals `mess(N, 13, 0)`.
- In table 1, chapters 1-99 and most chapters above 200 are local menus; chapters 100-199 hold error
  messages. Specific developments use chapters 160-164 and 6000-6199 for messages and 6200-6999 for local
  menus: full range table in `conventions-and-naming.md`.
- Chapters are created in **TXT** (Local menus - messages): chapter number, description, a "Local menu"
  box (unchecked for a plain message chapter), module, activity code (X/Y/Z to protect it from standard
  patches), "Do not translate", and the grid of numbered texts. Translations are entered in the same
  screen after switching the connection language.
- A local menu flagged "Changeable" can be edited by users in setup and is not overwritten by
  revalidation, version installation or patches.

```l4g
Local Char MSG(250)
  [L]MSG = mess(12, 6000, 1)            : # specific chapter 6000, message 12
  [L]MSG = errmes$(5)                   : # engine error message 5 (= mess(5, 13, 0))
```

## Local menu values

A field whose data type is a local menu stores the **rank** of the choice (local menu 1: 1 = No,
2 = Yes). Compare ranks in code; convert to a label only for display.

```l4g
Local Char LABEL(30)
Local Integer NBCHOICES
  [L]LABEL = mess([F:YTK]YSTATUS, 6200, 1)       : # label of the stored rank (specific local menu 6200)
  [L]LABEL = format$("LA6200:30X", [F:YTK]YSTATUS) : # same, through a local-menu format
  [L]NBCHOICES = len(mess(0, 6200, 1))           : # message 0 has one character per choice
```

Titles of local menus 1-99 are messages of chapter 0; titles of local menus above 200 are in chapter 200
(message 1 = title of local menu 201).

## Session, folder and partner language

| Need | V12 code | Notes |
|---|---|---|
| Session language in class code | `this.ACTX.LAN` | Context property, read-only |
| Session language outside a class | `GACTX.LAN` | `GACTX` is the default context created at connection |
| Default language of the folder | `this.ACTX.AFOLD.ALANGDEF` | Context chapter AFOLD |
| Classic code | `[V]GLANGUE` | Community-reported as the folder language; prefer the context |
| Language of a business partner | `[F:BPR]LAN` | Column LAN of BPARTNER, linked to TABLAN |

- `messname` and `isomess` are flagged **Internal** in the keyword glossary: do not use them.
- Languages are maintained in GESTLA, table TABLAN `[TLA]` (index TLA0 = LAN): `LANISO` (ISO code),
  `LANCON` (usable as a connection language), `LANRPL` (backup language), `LANUNI` (needs Unicode).
- A context for another language can be built with `fmet CTX.ACTX_INIT_LAN(FOLDER, LAN, LOGIN)` (status
  -1 = language not supported, folder default used). The help does not say that `mess` follows such a
  secondary context, so do not rely on it for translations.

## Text in another language than the session

`mess` always answers in the connection language, so a batch that writes to partners in their own
language cannot use it directly. Read APLSTD with its key `CLE` (LANCHP + LANNUM + LAN) and fall back to
the connection language when the translation is missing:

```l4g
# Message NUM of chapter CHAP in language LAN (for example [F:BPR]LAN of the recipient)
Funprog YMESS_LAN(NUM, CHAP, LAN)
Value Integer NUM, CHAP
Value Char    LAN()
Local File APLSTD [AST]
  Read [AST]CLE = [L]CHAP; [L]NUM; [L]LAN
  If fstat = 0
    End [F:AST]LANMES
  Endif
End mess([L]NUM, [L]CHAP, 1)
```

For translatable data (`AX*` columns) the same approach applies to ATEXTRA with index `AXX0`. Put your
own placeholders (for example `%1`) in the message text and substitute the values after reading it, so
translators never see code. Sending the result by e-mail: `workflow-email.md`.

## Dates

| Expression | Result |
|---|---|
| `[31/12/2024]` | Date literal (day/month/year) |
| `date$` | Current date |
| `gdat$(DAY, MONTH, YEAR)` | Builds a date; out-of-range days and months are normalised, not rejected |
| `[0/0/0]`, `gdat$(0, 0, 0)` | Null date |
| `num$(DATE)` | Always `DD/MM/YYYY`, whatever the language |
| Assigning a Date to a Char | `YYYYMMDD` |
| `left$(num$(datetime$), 10)` | Current UTC date as `YYYY-MM-DD` |

`format$` with a `D` format formats a date; literal text goes between square brackets:

| Format code | Meaning |
|---|---|
| `DD`, `MM`, `YYYY` / `YY` | Day, month number, year |
| `MMM` | Three-letter English month abbreviation |
| `M` repeated more than 3 times | Month name truncated to the number of positions |
| `D` repeated more than 2 times | Day name |
| `h`, `m`, `s` | Hour, minutes, seconds |
| `DZ:` prefix | Accept the null date (blank output) |
| `DD1`..`DD5` | Standard formats following the connection locale: DD1 `01/01`, DD2 `01/01/2013`, DD3 `01 January 2013`, DD4 / DD5 add `15:20` / `15:20:45` (the page's text names DD1-DD4; its examples go to DD5) |

```l4g
Local Char TXT(30)
  [L]TXT = format$("D:DD[/]MM[/]YYYY", date$)   : # fixed day/month/year layout
  [L]TXT = format$("D:YYYY[-]MM[-]DD", date$)   : # ISO layout for files and APIs
  [L]TXT = format$("DD2", date$)                : # user-facing, follows the connection locale
```

There is no documented function that parses a date string. Split it, build it with `gdat$`, and reject
values that `gdat$` normalised:

```l4g
# "DD/MM/YYYY" from an external file -> Date, or the null date when invalid
Funprog YPARSE_DMY(TXT)
Value Char TXT()
Local Integer DD, MM, YY
Local Date    RESULT
  If len([L]TXT) <> 10 : End [0/0/0] : Endif
  [L]DD = val(mid$([L]TXT, 1, 2))
  [L]MM = val(mid$([L]TXT, 4, 2))
  [L]YY = val(mid$([L]TXT, 7, 4))
  If [L]DD < 1 or [L]MM < 1 or [L]MM > 12 or [L]YY < 1600 : End [0/0/0] : Endif
  [L]RESULT = gdat$([L]DD, [L]MM, [L]YY)
  If day([L]RESULT) <> [L]DD : End [0/0/0] : Endif : # 31/04 became 01/05
End [L]RESULT
```

## Numbers

- `format$("N:10.2", X)` formats a number; option `3` groups digits by three (`"N3:12.2"`), `0` pads
  with zeros, `z` returns blanks for zero. The decimal separator is the 4th character of the internal
  variable `adxsca`, the thousands separator the 3rd and the overflow character the 5th; read it if you
  need the separators, but do not rewrite it in application code.
- `num$(X)` returns the plain decimal representation with a dot and no spaces: use it for files and APIs.
- `val(S)` accepts leading spaces and stops at the first character that is not a digit or at the second
  dot: `val("12,50")` is 12. Normalise external input first:

```l4g
# "1 234,50" (space thousands, comma decimals) -> 1234.5
Funprog YVAL_COMMA(TXT)
Value Char TXT()
Local Char CLEAN(60)
  [L]CLEAN = ctrans([L]TXT, " ", "")   : # third string shorter: spaces are removed
  [L]CLEAN = ctrans([L]CLEAN, ",", ".")
End val([L]CLEAN)
```

For `1.234,50`, remove the dots before swapping the comma. Rounding to a currency: `arr(VALUE, STEP)`
(half away from zero) with the currency's rounding step, see `localization-formats.md`. All format masks:
`builtin-functions.md`.

## Gotchas
- `mess(n, ch, 1)` cannot return another language: the `1` selects the application message table.
- `[F:AST]LANMES` read directly is only filled if the text was translated: always keep a fallback.
- `num$` on a date and Date-to-Char assignment ignore the user's locale; never show them to users.
- `MMM` gives English abbreviations in every language.
- `gdat$(31, 4, 2024)` silently returns 1 May 2024.
- `format$` returns a string of spaces when the value does not match the format: test for it.
- A local menu stores ranks; inserting a choice in the middle of the chapter changes existing data.

See also: `localization-formats.md`, `conventions-and-naming.md`, `builtin-functions.md`,
`workflow-email.md`, `v12-classes.md`.

## Sources
- https://online-help.sagex3.com/erp/12/en-us/Content/V7DEV/4gl_mess.html
- https://online-help.sagex3.com/erp/12/en-us/Content/V7DEV/4gl_adxtms.html
- https://online-help.sagex3.com/erp/12/en-us/Content/FCT/TXT.htm
- https://online-help.sagex3.com/erp/12/en-us/Content/FCT/TXT_TRA.htm
- https://online-help.sagex3.com/erp/12/en-us/Content/FCT/GESTLA.htm
- https://online-help.sagex3.com/erp/12/en-us/Content/MCD/APLSTD.htm , MCD/ATEXTE.htm , MCD/ATEXTRA.htm , MCD/TABLAN.htm , MCD/BPARTNER.htm
- https://online-help.sagex3.com/erp/12/en-us/Content/V7DEV/developer-guide_context.html
- https://online-help.sagex3.com/erp/12/en-us/Content/V7DEV/developer-guide_context-global-variables.html
- https://online-help.sagex3.com/erp/12/en-us/Content/V7DEV/4gl_x3script-keywords-glossary.html
- https://online-help.sagex3.com/erp/12/en-us/Content/V7DEV/4gl_format$.html
- https://online-help.sagex3.com/erp/12/en-us/Content/V7DEV/4gl_adxsca.html
- https://online-help.sagex3.com/erp/12/en-us/Content/V7DEV/4gl_gdat$.html
- https://online-help.sagex3.com/erp/12/en-us/Content/V7DEV/4gl_num$.html
- https://online-help.sagex3.com/erp/12/en-us/Content/V7DEV/4gl_val.html
- https://online-help.sagex3.com/erp/12/en-us/Content/V7DEV/4gl_ctrans.html
- https://online-help.sagex3.com/erp/12/en-us/Content/V7DEV/4gl_char.html
- https://online-help.sagex3.com/erp/12/en-us/Content/V7DEV/4gl_date$.html
- https://www.greytrix.com/blogs/sagex3/?p=12640 (community: GLANGUE)

# Sequential files

Reading and writing text and binary files on the X3 servers with `Openi` / `Openo` / `Openio`,
`Rdseq` / `Wrseq`, `Getseq` / `Putseq` and `Iomode`. Read this before any file import, export or
log-file code. Names often seen in old or invented code (`Readseq`, `Writeseq`, `Close 1`, `Using 1`,
`fstat = 100`) do not exist.

## Contents
- [Instructions at a glance](#instructions-at-a-glance)
- [Opening, appending and closing](#opening-appending-and-closing)
- [Separators and encoding](#separators-and-encoding)
- [Reading a text file](#reading-a-text-file)
- [Writing a text file](#writing-a-text-file)
- [Binary files with Getseq and Putseq](#binary-files-with-getseq-and-putseq)
- [Large content](#large-content)
- [Gotchas](#gotchas)
- [Sources](#sources)

## Instructions at a glance

| Instruction | Purpose |
|---|---|
| `Openi PATH [, OFFSET] [Using [ABV]]` | Open for reading; the file must exist |
| `Openo PATH [, OFFSET] [Using [ABV]]` | Open for writing; creates a missing file when OFFSET is 0, omitted or negative |
| `Openio PATH [, OFFSET] [Using [ABV]]` | Open for reading and writing; never creates the file |
| `Openi [Using [ABV]]` (same for `Openo`, `Openio`) | **Close** the channel: same instruction without a path |
| `Rdseq VAR1, VAR2... [Using [ABV]]` | Read one text record into the variables |
| `Wrseq EXPR1, EXPR2... [Using [ABV]]` | Write the values as text, then the record separator |
| `Getseq N, VARS [Using [ABV]]` | Read N elements in binary (engine internal) format |
| `Putseq N, VARS [Using [ABV]]` | Write N elements in binary format |
| `Iomode adxifs` / `adxirs` / `adxium VALUE Using [ABV]` | Field separator, record separator, encoding of one channel |
| `Seek [First+ / Curr+ / Curr- / Last-] BYTES [Using [ABV]]` | Move the pointer; `Seek 0` flushes pending writes |
| `adxseek(0)`, `adxseek(1)`, `adxseek("ABV")` | Read / write position in bytes; -1 when nothing is open |

`fstat` is 1 when `Rdseq` or `Getseq` reaches the end of the file. `Close` is for database tables, not
for sequential files.

## Opening, appending and closing

- `[ABV]` is a channel name chosen freely (Y-prefixed in house style). Without `Using` the default
  channel is used. One file per channel: opening another file on a channel closes the previous one.
  The maximum number of open sequential files is given by `adxmso`.
- Second argument (bytes) of `Openo`: omitted or 0 truncates the file; **negative (-1) appends** at the
  end; positive N truncates to N bytes. Of `Openi`: offset where reading starts. Of `Openio`: initial
  position, negative = end of file; `Openio` never truncates.
- Paths: build them with `filpath("TMP", NAME, EXT)`; `"server@path"` reaches another server running an
  X3 engine. In cloud environments a sandbox white list applies: `checkpath(PATH, 1)` tests write access.
- Opening failures are **runtime errors, not fstat values**: 20 missing file or folder, 27 access denied,
  44 disk full, 60 too many channels. Test `filinfo(PATH, 0) < 0` first or arm `Onerrgo`.
- Writes are buffered and complete only when the channel is closed; `Seek 0 Using [ABV]` flushes.
- Files are **not transactional**: `Trbegin` / `Commit` / `Rollback` do not affect them. Nothing
  prevents two sessions from writing the same file: guard with a `Lock` symbol (`database.md`).

## Separators and encoding

| Variable | Meaning | Values |
|---|---|---|
| `adxifs` | Field separator between the elements of one record (1 character) | `";"`, `chr$(9)`, `''` for none |
| `adxirs` | Record separator (up to 2 characters) | `chr$(10)` (LF), `chr$(13) + chr$(10)` (CRLF) |
| `adxium` | Text encoding of `Rdseq` / `Wrseq` | 50 = ASCII, 122 = UCS2, any other value = UTF8 (default UTF8) |

- For a channel opened `Using [ABV]` set them with `Iomode ... Using [ABV]`. Assigning `adxifs = ";"`
  changes the global value used by files opened without abbreviation; Sage recommends `Iomode`.
- Always set all three explicitly: do not depend on the defaults of another routine.
- With a space as field separator, consecutive spaces count as one separator.
- `Wrseq` cannot write UCS2; `Rdseq` can read it (`adxium` 122).
- `Rdseq` with fewer variables than fields skips the extra fields; with more, the missing ones are
  set to null values. `Wrseq` writes values like `num$` does (dates as `DD/MM/YYYY`).
- A `Wrseq` list ending with `,` or `;` ends with the field separator instead of the record separator:
  the next `Wrseq` continues the same record.

## Reading a text file

```l4g
Funprog YIMPORT_ACC(FILE_PATH)
Value Char FILE_PATH()
Local Char    ACCNUM(20), AMOUNT_TXT(30)
Local Integer NB, ST
  If filinfo([L]FILE_PATH, 0) < 0 : End -1 : Endif   : # -20 missing, -27 access denied
  Openi [L]FILE_PATH Using [YIN]
  Iomode adxium 0 Using [YIN]                         : # UTF8
  Iomode adxifs ";" Using [YIN]
  Iomode adxirs chr$(13) + chr$(10) Using [YIN]       : # CRLF
  Rdseq [L]ACCNUM Using [YIN]                         : # skip the header line
  Repeat
    Rdseq [L]ACCNUM, [L]AMOUNT_TXT Using [YIN]
    [L]ST = fstat                                     : # the called code may change fstat
    If [L]ST = 0 or [L]ACCNUM <> ""
      # YLOAD_LINE: your own subprogram that stores one line
      Call YLOAD_LINE([L]ACCNUM, val(ctrans([L]AMOUNT_TXT, ",", "."))) From YACCLIB
      [L]NB += 1
    Endif
  Until [L]ST <> 0
  Openi Using [YIN]                                   : # close the channel
End [L]NB
```

- At end of file `fstat` is 1 and the variables are null. Testing `[L]ACCNUM <> ""` as well keeps a
  last line that has no final separator, as Sage's own `adxium` sample does.
- Size the receiving `Char` variables for the longest field (255 maximum).
- Do not copy the loops of Sage's `Iomode`, `adxifs`, `adxirs` and `adxseek` pages: they end with
  `Until fstat=0` (stop after the first line) and one sets `adxifs` where `adxirs` is meant. The
  `adxium` page loop (`Until fstat`) is the correct one.

## Writing a text file

```l4g
Subprog YEXPORT_ACC(FILE_NAME, NB)
Value    Char    FILE_NAME()
Variable Integer NB
Local Char     PATH(250), TODAY(10)
Local Shortint OPENED
  Local File YACCOUNT [YACC]
  [L]NB = 0
  [L]PATH = filpath("TMP", [L]FILE_NAME, "csv")
  [L]TODAY = format$("D:4Y[-]2M[-]2D", date$)
  Onerrgo YEXPORT_ERR
  Openo [L]PATH, 0 Using [YOUT]                       : # 0 truncates, -1 would append
  [L]OPENED = 1
  Iomode adxium 0 Using [YOUT]
  Iomode adxifs ";" Using [YOUT]
  Iomode adxirs chr$(13) + chr$(10) Using [YOUT]
  Wrseq "ACCOUNT", "BALANCE", "EXPORTED" Using [YOUT]
  For [YACC]YAC0
    Wrseq [F:YACC]Y_ACCNUM, [F:YACC]Y_BALANCE, [L]TODAY Using [YOUT]
    [L]NB += 1
  Next
  Openo Using [YOUT]                                  : # close = everything flushed to disk
  Onerrgo
End

$YEXPORT_ERR
  # errn: 27 access denied (sandbox), 44 disk full, 24 write error
  If [L]OPENED : Openo Using [YOUT] : Endif
  [L]NB = -errn
End
```

- `Openo` / `Wrseq` failures arrive as runtime errors, so the routine traps them with `Onerrgo`
  (`language-basics.md`); `fstat` is meaningful for reads.
- Numbers are written as `num$` text with a `.` decimal point; format dates yourself with `format$`.
- To append to a daily log, open with `Openo PATH, -1`.

## Binary files with Getseq and Putseq

`Putseq N, VARS` writes N elements in the engine's internal format and `Getseq N, VARS` reads them back
(`fstat` 1 at end of file). Formats: `Tinyint` 1 byte; `Shortint`, `Date`, `Datetime` big-endian
integers; `Decimal` BCD; `Char` UCS2 (2 bytes per character, padded to the declared length); `Schar`
1-byte ASCII padded with zeros; `Uuident` 16 bytes; `Blbfile` its exact content and size.

```l4g
Local Blbfile DOC(3)
Local Integer NBYTES
  [L]NBYTES = b64decode([L]B64_TEXT, [L]DOC)          : # error 26 if B64_TEXT is not Base64
  Openo filpath("TMP", "YDOC", "pdf"), 0 Using [YBIN]
  Putseq 1, [L]DOC Using [YBIN]                       : # the exact BLOB content is written
  Openo Using [YBIN]
```

Use `Getseq` / `Putseq` for binary payloads or fixed-width records; use `Rdseq` / `Wrseq` for text.

## Large content

- `Wrseq` of a `Clbfile` writes its whole content: build long text in a `Clbfile` with `Append`
  (`language-basics.md`) and write it once. Sage's `Rdseq` page also reads into a LOB variable.
- `Setlob CHAR_ARRAY With CLOB` splits a CLOB into `Char` chunks (and `Setlob CLOB With CHAR_ARRAY(1..N)`
  joins them back), useful to process large text piece by piece.
- `filinfo(PATH, 7)` gives the file size in bytes before reading; `lobsize(VAR)` the memory used by a
  LOB, `len(VAR)` its length in characters.
- `delfile(PATH)` and `renamefile(OLD, NEW)` (0 = success, -20 missing, -27 denied) clean up or rotate
  files without spawning a shell (`builtin-functions.md`).

## Gotchas

- `Readseq` / `Writeseq` do not exist: use `Rdseq` / `Wrseq`. End of file is `fstat = 1`, not 100.
- There is no `Close 1`, no numeric channel, no `Append` mode keyword for files: close with
  `Openi` / `Openo` without a path, name channels `Using [ABV]`, append with `Openo PATH, -1`
  (`Append` exists, but it concatenates strings and CLOBs).
- `Openi` on a missing file raises error 20 instead of setting `fstat`.
- `val()` stops at the first non-numeric character: `"12,50"` reads as 12. Convert decimal commas
  with `ctrans(S, ",", ".")` first.
- Set `adxirs` to match the file: with LF on a CRLF file the CR stays at the end of the last field.
- A file opened without `Using` takes the global `adxifs` / `adxirs` / `adxium` values, which any other
  routine of the process may have changed: prefer named channels and `Iomode`.

See also: `builtin-functions.md`, `imports-exports.md`, `database.md`, `language-basics.md`.

## Sources
- https://online-help.sagex3.com/erp/12/en-us/Content/V7DEV/4gl_openi.html
- https://online-help.sagex3.com/erp/12/en-us/Content/V7DEV/4gl_openo.html
- https://online-help.sagex3.com/erp/12/en-us/Content/V7DEV/4gl_openio.html
- https://online-help.sagex3.com/erp/12/en-us/Content/V7DEV/4gl_rdseq.html
- https://online-help.sagex3.com/erp/12/en-us/Content/V7DEV/4gl_wrseq.html
- https://online-help.sagex3.com/erp/12/en-us/Content/V7DEV/4gl_getseq.html
- https://online-help.sagex3.com/erp/12/en-us/Content/V7DEV/4gl_putseq.html
- https://online-help.sagex3.com/erp/12/en-us/Content/V7DEV/4gl_iomode.html
- https://online-help.sagex3.com/erp/12/en-us/Content/V7DEV/4gl_adxium.html
- https://online-help.sagex3.com/erp/12/en-us/Content/V7DEV/4gl_adxirs.html
- https://online-help.sagex3.com/erp/12/en-us/Content/V7DEV/4gl_adxifs.html
- https://online-help.sagex3.com/erp/12/en-us/Content/V7DEV/4gl_seek.html
- https://online-help.sagex3.com/erp/12/en-us/Content/V7DEV/4gl_adxseek.html
- https://online-help.sagex3.com/erp/12/en-us/Content/V7DEV/4gl_filpath.html
- https://online-help.sagex3.com/erp/12/en-us/Content/V7DEV/4gl_filinfo.html
- https://online-help.sagex3.com/erp/12/en-us/Content/V7DEV/4gl_fstat.html
- Same V7DEV base, pages `4gl_<name>.html` for: close, checkpath, setlob, lobsize, append, delfile,
  renamefile, b64decode, clbfile.

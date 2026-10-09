# Audit, compliance and data retention

What Sage X3 V12 already provides for audit trails, personal-data (GDPR) handling and purging, and how to write
the specific pieces correctly when the standard does not cover a need: an append-only audit table fed by one
helper, sequence numbers with `NUMERO`, pseudonymisation and retention batches. Access control itself is in
`security-permissions.md`; legal retention periods are a question for your legal team, not for code.

## Contents
- [Standard tools first](#standard-tools-first)
- [Custom audit table YAUDIT](#custom-audit-table-yaudit)
- [The single audit helper](#the-single-audit-helper)
- [Sequence numbers with NUMERO](#sequence-numbers-with-numero)
- [GDPR: where personal data lives](#gdpr-where-personal-data-lives)
- [GDPR: access and portability](#gdpr-access-and-portability)
- [GDPR: erasure by pseudonymisation](#gdpr-erasure-by-pseudonymisation)
- [Retention and purge](#retention-and-purge)
- [Gotchas](#gotchas)
- [Sources](#sources)

## Standard tools first

| Need | Standard feature |
|---|---|
| Who changed which field of a table, before/after values | Activity code **AUDIT** + *Audit* tab of the table dictionary (GESATB): generated database triggers write to **AUDITH**/**AUDITL**; inquiry via Usage > Audit > Tables / Fields; workflow rule **UPDFLD** for notifications |
| Who connected | Usage > Audit > Connections (same activity code) |
| Trail of operations per user | Parameter **TABTRA** (all operations, or deletions/renamings only; user or global level) |
| Changes to administrative data (Syracuse) | V12 audit collection in MongoDB |
| Purge / archive closed data | **AHISTO** (archive/purge), **APARHIS** (purge parameters), **CREHISTO** (create the archive folder) |
| Inventory of personal data, breach contact lists | "Data protection" functions: check companies for DPO, data protection setup, data protection search, lists of email / phone / personal data exported to CSV (community-reported, menu Usage > GDPR) |

Sage warns that TABTRA and the MongoDB audit collection can significantly impact performance: enable them for a
period or a limited set of users. Table auditing only covers tables configured before the change happened.

## Custom audit table YAUDIT

Use a specific table only for **business events** the standard trail cannot express: GDPR exports and
pseudonymisations, integration decisions, overrides of a control, mass updates by a batch.

| Column | Type | Content |
|---|---|---|
| `AUDNUM` | Char(20), unique key | Sequence number (`NUMERO`) |
| `AUDDATE` | Date | `date$` (index for retention and searches) |
| `AUDDTM` | Datetime | `datetime$` (GMT) |
| `USR` | Char(10) | `GACTX.USER` |
| `TBL`, `TBLKEY` | Char(12), Char(60) | Business table and key concerned |
| `EVT` | Char(20) | `GDPR_EXPORT`, `GDPR_PSEUDO`, `OVERRIDE`, … |
| `FLD`, `OLDVAL`, `NEWVAL` | Char(30), Char(250), Char(250) | Optional field-level detail |
| `REASON` | Char(250) | Ticket / justification |

Declare it in GESATB under a specific activity code with keys on (`AUDNUM`), (`TBL`, `TBLKEY`, `AUDDATE`) and
(`AUDDATE`). Append-only: no class/representation with update or delete, no `Update`/`Delete` in code except the
retention batch, protect the table and its inquiry with an access code (GESACS), and ask the DBA to restrict direct
SQL grants. `Char` is limited to 255 characters — use a `Clbfile` column for larger payloads.

## The single audit helper

All code writes through one Funprog. There is only one transaction level in X3: the helper **joins** the
caller's transaction when there is one (the audit row then commits or rolls back with the business change, which is
what an auditor expects) and opens its own otherwise. To record a *failed* attempt, call it after the caller's
`Rollback`.

```l4g
##############################################################
# YAUDIT_LOG - append one row to YAUDIT [YAUD] (script YAUDLIB)
# Returns [V]CST_AOK, or [V]CST_AERROR with ERRMSG filled.
##############################################################
Funprog YAUDIT_LOG(TBL, TBLKEY, EVT, FLD, OLDVAL, NEWVAL, REASON, ERRMSG)
Value Char TBL(), TBLKEY(), EVT(), FLD(), OLDVAL(), NEWVAL(), REASON()
Variable Char ERRMSG()
Local File YAUDIT [YAUD]
Local Shortint TRANS_OPEN
Local Integer STA
Local Char YNUM(20)
  ERRMSG = ""
  [L]TRANS_OPEN = adxlog
  If [L]TRANS_OPEN = 0 : Trbegin [YAUD] : Endif
  STA = func ANM_TOOL.NUMERO(GACTX, "YAU", "", date$, "", YNUM, ERRMSG)
  If STA <> [V]CST_AOK
    If [L]TRANS_OPEN = 0 : Rollback : Endif
    End [V]CST_AERROR
  Endif
  Raz [F:YAUD]
  [F:YAUD]AUDNUM = YNUM
  [F:YAUD]AUDDATE = date$
  [F:YAUD]AUDDTM = datetime$
  [F:YAUD]USR = GACTX.USER
  [F:YAUD]TBL = [L]TBL : # [L] because parameters share the column names
  [F:YAUD]TBLKEY = [L]TBLKEY
  [F:YAUD]EVT = [L]EVT
  [F:YAUD]FLD = [L]FLD
  [F:YAUD]OLDVAL = left$([L]OLDVAL, 250)
  [F:YAUD]NEWVAL = left$([L]NEWVAL, 250)
  [F:YAUD]REASON = left$([L]REASON, 250)
  Write [YAUD]
  If fstat
    ERRMSG = "YAUDIT write failed, fstat" - num$(fstat)
    If [L]TRANS_OPEN = 0 : Rollback : Endif
    End [V]CST_AERROR
  Endif
  If [L]TRANS_OPEN = 0 : Commit : Endif
End [V]CST_AOK
```

Inside class code, call it from update events (transaction already open, `this.ACTX` available) — never open a
transaction there (`v12-classes.md`).

## Sequence numbers with NUMERO

Documented API (script **ANM_TOOL**):
`Funprog NUMERO(ACTX, COUNTER, FCY, DAT, COMP, VAL, ERRMS)` — `Value Instance ACTX` (context), `Value Char COUNTER`,
`Value Char FCY` (site, mandatory if the counter structure uses it — no default), `Value Date DAT`,
`Value Char COMP` (complement), `Variable Char VAL` (returned number), `Variable Char ERRMS`. Returns
`[V]CST_AOK` or `[V]CST_AERROR`.

- It **must run inside a transaction** (e.g. `AINSERT_BEFORE`, `AUPDATE_BEFORE`, `AINSERT_AFTER`, `AUPDATE_AFTER`
  events, or after `Trbegin` in a script — test `adxlog`).
- The counter (here `YAU`) is set up in the sequence number functions (structures: GESANM).
- Script `SUBANM` hosts the entry points `NUMERO` (add logic to a number assignment) and `NUMEROCHG` (change the
  number) — use GESAPE to hook them, see `entry-points.md`.

## GDPR: where personal data lives

- **Contacts** (GESAIN): last/first name, title, date of birth, phones, mobile, email, ID card, residence permit,
  social security fund; a contact's personal address/email differ from his professional ones per BP.
- **BP addresses and contacts** tabs (GESBPR, GESBPC): address lines, phones, email, contact names.
- Users (GESAUS), sales reps, employees in HR modules, free-text texts and attachments, and every specific table
  or `Y` field you added.
- Underlying tables named in Sage's TRTBPA entry-point documentation: `BPADDRESS` [BPA] (BP addresses),
  `CONTACT` [CNT] (contacts) and `CONTACTCRM` (contact relationships). Check column names in GESATB before
  coding against them; do not assume email/phone columns on BPCUSTOMER.
- Start the inventory with the standard "List of personal data" export (community-reported) and complete it with
  your specific tables.

## GDPR: access and portability

- Produce a structured, machine-readable export (JSON or CSV) of the subject's data: an import/export template
  (GESAOE, `imports-exports.md`) or a REST query on the relevant representations (`web-services-rest.md`).
- When code builds JSON by hand, escape every value with `escjson` (`security-permissions.md`).
- The export is itself a personal-data access: log it with
  `STA = func YAUDLIB.YAUDIT_LOG("BPCUSTOMER", YBPC, "GDPR_EXPORT", "", "", "", YTICKET, YERR)`.

## GDPR: erasure by pseudonymisation

Accounting and commercial documents usually have a legal retention period that overrides erasure: keep the
documents, remove what identifies the person. Prefer the standard functions (Contacts, BP management, data
protection search/update) so business rules and the standard audit run. For **specific** data:

```l4g
##############################################################
# YGDPR_PSEUDO - pseudonymise specific personal data of a customer
# YCUSTNOTE [YCN]: specific table; Y_GDPRSTA/Y_GDPRDAT: specific fields added to BPCUSTOMER
##############################################################
Funprog YGDPR_PSEUDO(YBPC, YTICKET, ERRMSG)
Value Char YBPC(), YTICKET()
Variable Char ERRMSG()
Local File BPCUSTOMER [BPC], YCUSTNOTE [YCN]
Local Shortint TRANS_OPEN
Local Integer STA
  ERRMSG = ""
  [L]TRANS_OPEN = adxlog
  If [L]TRANS_OPEN = 0 : Trbegin [BPC], [YCN] : Endif
  Update [YCN] Where YBPCNUM = YBPC
  & With YNOTE = "", YEMAIL = "", YPHONE = ""
  If fstat
    ERRMSG = "YCUSTNOTE update failed, fstat" - num$(fstat)
    If [L]TRANS_OPEN = 0 and adxlog = 1 : Rollback : Endif : # fstat 1/3: already rolled back
    End [V]CST_AERROR
  Endif
  Update [BPC] Where BPCNUM = YBPC With Y_GDPRSTA = 2, Y_GDPRDAT = date$
  If fstat or adxuprec <> 1
    ERRMSG = "Customer" - YBPC - "not updated"
    If [L]TRANS_OPEN = 0 and adxlog = 1 : Rollback : Endif
    End [V]CST_AERROR
  Endif
  # Never log the erased values: OLDVAL stays "[redacted]"
  STA = func YAUDLIB.YAUDIT_LOG("BPCUSTOMER", YBPC, "GDPR_PSEUDO", "", "[redacted]", "", YTICKET, ERRMSG)
  If STA <> [V]CST_AOK
    If [L]TRANS_OPEN = 0 : Rollback : Endif
    End [V]CST_AERROR
  Endif
  If [L]TRANS_OPEN = 0 : Commit : Endif
End [V]CST_AOK
```

`Update` always targets the abbreviation (`[BPC]`), never the table name. Direct `Update` bypasses class rules:
keep it for specific columns; change standard personal fields through the standard functions.

## Retention and purge

1. Write the policy per data class: retention period (from legal), start event, end action (delete, pseudonymise,
   archive), approver.
2. Standard transactional data: configure archive/purge (APARHIS, AHISTO, archive folder via CREHISTO); only
   closed data with an expired shelf life is eligible.
3. Specific tables: a recurring batch task (GESABT task, GESABA schedule — `batch-scheduling.md`) that deletes or
   pseudonymises by date, logs counts, and runs in short transactions:

```l4g
Subprog YPURGE_AUDIT(KEEPDAYS)
Value Integer KEEPDAYS
Local File YAUDIT [YAUD]
Local Date YLIMIT
Local Integer YNB
Local Shortint TRANS_OPEN
  [L]TRANS_OPEN = adxlog
  If [L]TRANS_OPEN <> 0 : End : Endif
  YLIMIT = date$ - KEEPDAYS
  Trbegin [YAUD]
  Delete [YAUD] Where AUDDATE < YLIMIT
  If fstat
    Rollback
    End
  Endif
  YNB = adxdlrec
  Commit
End
```

Report `YNB` in the task log (`ALOG`, `debugging-traces.md`): the log is your proof that the policy runs.

## Gotchas

- There is no nested transaction: an "independent" audit sub-transaction inside a caller's transaction is impossible
  (`Trbegin` while `adxlog` = 1 raises an error).
- `NUMERO` must run inside a transaction; in class code use the update events, not the control events.
- Logging the old value of an erased field defeats the erasure; logging full payloads copies personal data.
- Table auditing (AUDITH/AUDITL) grows fast on busy tables and is not a backup: purge it like any other data.
- A retention batch that deletes before the legal floor is a compliance incident: default to "keep" until legal
  signs the policy.
- Free-text fields (comments, texts, attachments) hold personal data too.

See also: `security-permissions.md`, `batch-scheduling.md`, `database.md`, `imports-exports.md`,
`web-services-rest.md`, `entry-points.md`, `v12-classes.md`, `debugging-traces.md`, `data-migration.md`.

## Sources
- https://online-help.sagex3.com/erp/11/en-US/OBJ/ACV_AUDIT.htm
- https://online-help.sagex3.com/erp/12/en-us/Content/V7DEV/getting-started_security-best-practices.html
- https://online-help.sagex3.com/erp/11/en-US/V7DEV/api-guide_get-a-sequence-number-value.html
- https://online-help.sagex3.com/erp/12/en-us/Content/OBJ/ADC_SUBANM.htm
- https://online-help.sagex3.com/erp/12/en-us/Content/FCT/GESANM.htm
- https://online-help.sagex3.com/erp/12/en-us/Content/FCT/AHISTO.htm , …/APARHIS.htm , …/CREHISTO.htm
- https://online-help.sagex3.com/erp/12/en-us/Content/FCT/GESAIN.htm , …/GESBPR.htm
- https://online-help.sagex3.com/erp/12/en-us/Content/V7DEV/4gl_trbegin.html , …/4gl_delete.html , …/4gl_adxdlrec.html , …/4gl_datetime$.html
- https://communityhub.sage.com/us/sage_x3/b/sageerp_x3_product_support_blog/posts/how-to-get-the-next-sequence-number-using-v7-style-coding (community)
- https://www.greytrix.com/blogs/sagex3/2022/01/03/gdpr-in-sage-x3/ (community)
- https://www.greytrix.com/blogs/sagex3/?p=22096 (community)
- https://online-help.sagex3.com/erp/12/en-us/Content/OBJ/ADC_TRTBPA.htm

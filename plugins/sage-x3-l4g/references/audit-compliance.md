# Audit, compliance, and data retention

How to make X3 customisations satisfy regulatory requirements: GDPR (right to access, erasure, portability), SOX-style financial audit trail, retention policies, and the audit-log discipline that supports them.

For ACL and access control, see `security-permissions.md`. For the technical audit-log table pattern, see also `security-permissions.md` § Audit trail. This file focuses on **what** to log, **how long** to keep it, and the regulator-facing mechanics.

## The compliance surfaces in X3

| Concern | Where it touches L4G |
|---------|---------------------|
| Right to access (GDPR Art. 15) | Export of all personal data for a subject |
| Right to erasure / "to be forgotten" (Art. 17) | Selective delete or pseudonymisation |
| Data portability (Art. 20) | Structured export in a machine-readable format |
| Financial audit trail (SOX, French Code de Commerce, etc.) | Immutable record of every accounting-relevant change |
| Retention policy | When and how to purge / archive old data |
| Consent tracking | Who agreed to what, when |

**Not in scope of this file:** raw infrastructure (encryption-at-rest, backup retention, network logging). Those live with the DBA / sysadmin team. L4G's job is the application-layer audit trail and the data-subject-rights workflows.

## The audit log table — pattern

Every compliance-relevant change writes a row into a dedicated table that:

- Cannot be modified by application code (insert-only)
- Persists longer than the data it audits
- Is queryable by user, by entity, by date range

Schema:

```l4g
##############################################################
# YAUDITLOG — append-only audit trail
# Declared in GESATB. Never expose Update or Delete actions.
##############################################################
```

| Column | Type | Use |
|--------|------|-----|
| `LOGID` | Char(20) | Generated key (`NUMERO`) |
| `LOGDAT` | Date | When the change happened |
| `LOGTIM` | Time | Sub-second precision |
| `LOGUSER` | Char(10) | `[V]GUSER` |
| `LOGFOLDER` | Char(10) | `[V]GFOLDER` |
| `TBL` | Char(20) | Affected table |
| `TBLKEY` | Char(60) | Primary key of the affected row |
| `ACTION` | Char(20) | `CREATE`, `UPDATE`, `DELETE`, `ANONYMIZE`, `EXPORT`, `LOGIN`, `LOGOUT` |
| `FIELD` | Char(40) | (For UPDATE) the column changed |
| `OLDVAL` | Char(2000) | (For UPDATE) prior value, truncated |
| `NEWVAL` | Char(2000) | (For UPDATE) new value, truncated |
| `REASON` | Char(200) | Why (e.g. "GDPR erasure ticket #123") |
| `CONTEXT` | Char(500) | Source (function code, batch ID, REST endpoint) |
| `IP` | Char(45) | Source IP for service callers (IPv6 fits) |

Indexes: `(TBL, TBLKEY, LOGDAT)`, `(LOGUSER, LOGDAT)`, `(LOGDAT)` for time-range queries.

### Writing audit rows safely

```l4g
##############################################################
# YAUDIT_LOG — single entry point for all audit writes
##############################################################
Subprog YAUDIT_LOG(TBL, KEY, ACTION, FIELD, OLDV, NEWV, REASON)
Value Char TBL(), KEY(), ACTION(), FIELD(), OLDV(), NEWV(), REASON()

    Local File YAUDITLOG [YAU]
    Local Char NEWID(20)

    Call NUMERO("YAULOGN", "", "", "", date$, "", NEWID) From GESNUM

    Raz [F:YAU]
    [F:YAU]LOGID    = NEWID
    [F:YAU]LOGDAT   = date$
    [F:YAU]LOGTIM   = time$
    [F:YAU]LOGUSER  = [V]GUSER
    [F:YAU]LOGFOLDER = [V]GFOLDER
    [F:YAU]TBL      = TBL
    [F:YAU]TBLKEY   = KEY
    [F:YAU]ACTION   = ACTION
    [F:YAU]FIELD    = FIELD
    [F:YAU]OLDVAL   = left$(OLDV, 2000)
    [F:YAU]NEWVAL   = left$(NEWV, 2000)
    [F:YAU]REASON   = left$(REASON, 200)

    # Run in a sub-transaction; never let an audit failure roll back the business write
    Trbegin [YAU]
    Write [YAU]
    If fstat
        Rollback
        Call ECRAN_TRACE("YAUDIT_LOG WRITE failed fstat=" + num$(fstat), 2) From GESECRAN
    Else
        Commit
    Endif
End
```

The audit must not couple the business transaction. If logging fails, you record the failure (in `adxlog.log`), but the business change still commits — the alternative ("roll back the whole sale because the audit log is full") is worse than logging gaps.

## GDPR — right to access (Art. 15)

The data subject asks "what do you have on me?". You return all personal data.

Pattern: a Subprog or REST endpoint that, given a subject identifier, walks every table holding personal data and exports rows as JSON. Skeleton:

```l4g
##############################################################
# YGDPR_EXPORT — collect everything tied to a BPC for GDPR
# (skeleton — fill per-table sections to suit your schema)
##############################################################
Subprog YGDPR_EXPORT(BPC, OUTFILE)
Value    Char BPC()
Variable Char OUTFILE()

    Local Char    PATH(500)
    Local Integer HDL

    PATH = filpath("TMP", "YGDPR_" - BPC - "_" - num$(date$, "AAAAMMJJ") - ".json", "")
    Openo PATH Using HDL
    If fstat : Call ECRAN_TRACE("Cannot open " - PATH, 2) From GESECRAN : End : Endif

    Writeseq "{" Using HDL
    Writeseq '  "subject": "' - BPC - '",' Using HDL
    Writeseq '  "extracted_at": "' - num$(date$, "AAAA-MM-JJ") - '",' Using HDL
    # Sections: customer master, orders, addresses, audit excerpts.
    # Use func YJSON_ESC for any free-text field.
    # Use For [SOH] Where BPCORD = BPC … Next for related-entity lists.
    Writeseq "}" Using HDL
    Close HDL

    OUTFILE = PATH

    # The export itself is a personal-data access — record it
    Call YAUDIT_LOG("BPCUSTOMER", BPC, "EXPORT", "", "", "",
        "GDPR access request") From YAUDITHELPER
End
```

For the JSON-build escape helpers, see `web-services-rest.md`. The export itself is a personal-data access — log it in the audit trail with `ACTION = "EXPORT"`.

## GDPR — right to erasure (Art. 17)

The subject asks to be deleted. You **cannot** literally `Delete` a customer if there are accounting entries — French / EU / US law all require keeping financial records for 7-10 years.

The pattern is **pseudonymisation**: replace identifying fields with a non-identifying token, keep the row and its accounting links intact.

```l4g
##############################################################
# YGDPR_ANONYMIZE — replace personal data with non-identifying tokens
##############################################################
Subprog YGDPR_ANONYMIZE(BPC, TICKET)
Value Char BPC(), TICKET()

    Local Char NEWNAM(60), NEWMAIL(80)
    NEWNAM = "ANON_" - BPC
    NEWMAIL = "anon_" - BPC - "@anonymized.local"

    Local File BPCUSTOMER [BPC1]
    Read [BPC1]BPCNUM0 = BPC
    If fstat : End : Endif

    Trbegin [BPC1]
    Update BPCUSTOMER Where BPCNUM = BPC
        With BPCNAM = NEWNAM,
             EMAIL = NEWMAIL,
             PHONE = "",
             FAX = "",
             YGDPR_STATUS = "ANONYMIZED",
             YGDPR_ANONDAT = date$,
             UPDTICK = UPDTICK + 1
    If fstat Or [S]adxuprec = 0
        Rollback
        End 1
    Endif
    Commit

    # Log every field overwrite — value pre-anonymisation must NOT be in the log
    Call YAUDIT_LOG("BPCUSTOMER", BPC, "ANONYMIZE", "BPCNAM", "[redacted]", NEWNAM, TICKET) From YAUDITHELPER
    Call YAUDIT_LOG("BPCUSTOMER", BPC, "ANONYMIZE", "EMAIL",  "[redacted]", NEWMAIL, TICKET) From YAUDITHELPER

    # Apply to related personal-data tables
    # — addresses, contacts, custom YPROFILE columns, etc.
    Call YGDPR_ANONYMIZE_RELATED(BPC, TICKET) From YGDPRHELPER
End
```

Critical: do **not** log the original value in `OLDVAL` for an anonymisation — that defeats the erasure. Use `[redacted]` as the placeholder.

### What you can keep

| Keep (legal basis) | Anonymise / remove |
|--------------------|-------------------|
| Order numbers, amounts, dates (accounting) | Customer name, email, phone |
| Item references in the orders | Free-text comments containing personal data |
| Aggregated transaction history | Marketing preferences, profile, contact persons |
| Audit log of the anonymisation itself | Direct identifiers in custom tables |

The accounting record stays; the link to a person doesn't.

## GDPR — data portability (Art. 20)

Same as access (Art. 15) but the format is constrained: machine-readable (JSON, XML, CSV — not PDF), structured (each field clearly labelled), commonly used.

The Art. 15 export pattern above already produces JSON and satisfies Art. 20. Keep one export pipeline serving both rights.

## Financial audit trail (SOX, FCC, etc.)

Accounting-relevant changes (`GACCDUDATE`, `GACCENTRY`, posted journals, validated invoices) must be:

1. **Pre-validation** — recorded with the user who entered, when, with what values.
2. **Post-validation** — every modification logged: what was the prior value, what it became, who changed it, when.
3. **Reversal** — never an in-place delete. Use a counter-entry that nets to zero, with a reference back to the original.

Standard X3 enforces most of this on its own (validated entries cannot be modified). Custom code touching accounting tables must follow the same discipline: never `Update GACCENTRY` to rewrite an amount — instead create a reversal entry that nets to zero with `REFNUM` pointing back to the original, and call `YAUDIT_LOG("GACCENTRY", NUM, "REVERSED", …)` to record the link.

## Retention policies

Define for each personal / sensitive data class:

- **What is the retention period?** (legal floor: 5y commercial, 7-10y accounting in many EU countries, 30 years for HR pension data in France, etc.)
- **What event starts the clock?** (creation, last activity, contract end?)
- **What happens at the end?** (delete, anonymise, archive to cold storage?)
- **Who approves a deletion?** (legal, compliance, function owner)

Implement as a recurrent batch:

```l4g
##############################################################
# YBATCH_RETENTION — apply retention rules
# Runs nightly. Reads YRETENTION_POLICY for the rules.
##############################################################
$MAIN
Local File YRETENTION_POLICY [YRP]
For [YRP] Where ACTIVE = 1
    Call YAPPLY_RETENTION([F:YRP]TBL, [F:YRP]CONDITION, [F:YRP]ACTION,
                          [F:YRP]RETENTION_DAYS) From YRETENTIONHELPER
Next
Return
```

`YRETENTION_POLICY` table holds rules: "anonymise BPCUSTOMER inactive for 7 years", "delete YINTLOG older than 13 months", "archive SORDER status 9 older than 10 years to YARCHIVE_SORDER".

The batch logs every action it takes — that's the legal proof retention is enforced.

## Consent tracking

For data collected with consent (marketing, optional profile fields), track:

| Column | Use |
|--------|-----|
| `CONSENT_TYPE` | `MARKETING`, `PROFILING`, `THIRD_PARTY_SHARE` |
| `CONSENT_GIVEN` | Boolean |
| `CONSENT_DAT` | When |
| `CONSENT_SRC` | Where the consent came from (web form, contract, phone) |
| `CONSENT_TXT_VER` | Version of the consent text the user agreed to |

Withdrawn consent ⇒ stop using the data, even if you keep the record. Anonymise on withdrawal if the data has no other legal basis.

## Reporting and proof

Auditors and DPAs ask "show me what happened to subject X". The query is the audit table:

```l4g
For [YAU] Where TBLKEY = SUBJECT_ID Order By Key LOGDAT0
    # Print row: date, user, action, field, reason
Next
```

Pre-build a Crystal report or REST endpoint over `YAUDITLOG` keyed by subject ID — auditors should not need a developer to answer this. See `reports-printing.md`.

## Common pitfalls

- **Audit log table writable by application users** — anyone with table-write rights can edit history. Restrict to the audit helper's user, expose via `YAUDIT_LOG` only.
- **Truncating values to 50 chars in the audit table** — loses the actual change. Allow at least 2000 characters; truncate only what's logged from a specific call.
- **Forgetting to log reads** — Art. 15 access exports are themselves audit events.
- **Logging the `OLDVAL` during an anonymisation** — defeats the erasure. Use `[redacted]`.
- **Hard-deleting a customer with accounting history** — illegal in most jurisdictions. Anonymise instead.
- **Retention batch deleting before the legal floor** — confirm the floor with legal before automating. The default is "keep forever" until proven you may delete.
- **Audit table shares the same DB as production** — fine, but back it up separately and consider a different retention from the operational data it audits.
- **No DPA-readable export** — when a regulator asks, "give me everything on subject X" must be one query, one click, one CSV.
- **Free-text fields contain personal data** — comments on orders / invoices may contain names. Anonymisation must scan and pseudonymise these too.

## Audit / compliance checklist

1. `YAUDITLOG` table declared, indexed, write-only at the application layer?
2. Single `YAUDIT_LOG` helper used by all custom code?
3. Audit log write is in a sub-transaction — failure does not roll back business?
4. Anonymisation pattern wired for every table holding personal data?
5. Right-to-access export covers customer master, related transactions, audit trail?
6. Right-to-erasure preserves accounting links via pseudonymisation?
7. Retention policy table defined; nightly batch applies it?
8. Consent tracking columns where consent is the legal basis?
9. Auditor-readable report / endpoint pre-built over `YAUDITLOG`?
10. Free-text fields scanned for personal data during anonymisation?

See also: `security-permissions.md` (audit log foundations, ACL on the helper), `data-migration.md` (preserving audit trail through migrations), `batch-scheduling.md` (retention batch), `imports-exports.md` (Art. 20 export format), `reports-printing.md` (auditor-facing reports), `code-review-checklist.md` (Tier 4 audit-log review checks).

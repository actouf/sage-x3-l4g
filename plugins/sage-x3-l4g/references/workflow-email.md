# Workflow rules and e-mail

How the Sage X3 workflow engine reacts to events (object save, function entry, print, batch end,
import, signature, manual scan, miscellaneous events), how rules address recipients, build messages,
run your subprograms and drive signature circuits, and how to send e-mail directly from L4G with
`ASYRMAIL.ASEND_MAIL`. Also covers where SMTP lives in V12 (notification servers). Read this before
writing "when X happens, notify / update Y" logic.

## Contents
- [The workflow functions](#the-workflow-functions)
- [Event types](#event-types)
- [Anatomy of a rule (GESAWA)](#anatomy-of-a-rule-gesawa)
- [Calling your code from a rule](#calling-your-code-from-a-rule)
- [Sending e-mail from L4G (ASEND_MAIL)](#sending-e-mail-from-l4g-asend_mail)
- [Notification servers (SMTP in V12)](#notification-servers-smtp-in-v12)
- [Gotchas](#gotchas)
- [Sources](#sources)

## The workflow functions

| Code | Function | Role |
|---|---|---|
| GESAWA | Workflow rules | Event, conditions, recipients, message, signature, actions |
| GESAWR | User allocation rules | Criteria grid returning recipients in `[L]USER` (max count set by activity code AWR) |
| GESAWM | Data models | Linked tables loaded in the rule context; mandatory for Manual rules and allocation rules |
| SAIWRKPLN | Workflow monitor | Events pending signature/approval for a user (up to 8 tabs) |
| GESACT | Actions | An action of type "Miscellaneous process" with the **Workflow** box is callable from a rule |

`GESAWT` and `GESAWS` do not exist; there is no separate "template" or "recipient group" function.
The monitor's default start date is today minus the WRKDAY parameter.

## Event types

| Event type (TYPEVT) | Event code (CODEVT) | Notes |
|---|---|---|
| Object | Object code | Operations: C creation, M modification… plus object buttons/menus; End of transaction (TYPDEC) chooses before the table update (`[F]`/`[M]` usable in conditions) or after |
| Function entry | Function code | Fires when the function is entered |
| Print | Report code | Fires when the report is launched |
| End of task | Batch task code | The task must have **Message - user** checked (GESABT) |
| Task interruption | Batch task code | Only the `[ABR]` ABATRQT record is available (no `GUSER`); e-mail only |
| Import/Export | Template code | Up to 4 operation codes: beginning and/or end, import and/or export |
| Signature | Code of the rule being signed | Operation = answer code of the signature |
| Manual | (none) | Scans the tables of the data model; launchable in batch; the way to detect field changes (through the audit tables) |
| Miscellaneous | Code from a finite list | Generic events (connection, disconnection…) and application events; code mandatory |

There is **no field-change event**: use an Object rule with conditions evaluated before the update,
or a Manual rule over the audit tables (`audit-compliance.md`). An empty event code fires the rule
generically; filter with `GFONCTION` and similar context variables.

## Anatomy of a rule (GESAWA)

**General tab**: conditions grid (header or line conditions), Data model (MODELE), Assignment rule
(REGLE, a GESAWR rule), Workflow type header/line, line grouping (GROUPE, `;`-separated expressions),
switches **Trigger mail** (ENAMES), **Trigger action** (ENAACT), **Trigger tracking** (ENASUI),
**Debug mode** (DEBUG: evaluation errors displayed on screen).

**Addresses tab**: one line per recipient group — condition (`[L]COND(N)` refers to line N's
condition), type User or BP (+ contact function), Send mail (No / Yes / Copy), Milestone (No / Yes /
With signature), Delegate option (No / All / Cascade / First free).

**Message tab**: Sender e-mail (SENDMAIL, may be a formula), Object (the subject, a formula), Text.
Inside the text, formulas go **between vertical bars**:

```text
Subject: "Customer " + [F:YCU]YCODE + " blocked"
Text:    Event of |num$(date$)| raised by |GUSER|.
         |LIG|                          <- line text (TEXLIG) repeated per detail line
         |CLB/YHTML|                    <- inserts a Clbfile variable or expression (max 5)
         |SIG/VAL/"To approve, click:"| <- signature link for answer VAL
```

Attachments: **Linked trace file** (End of task rules: the batch log), **Attached document** (JOINT,
path formula evaluated at trigger time), record attachments (JOIOBJ, filtered by type — misc. table
902 — and category). Sending (TYPMES) Server is required for more than one attachment, and files
must be reachable from the application server. **Group by recipient** merges notifications of a
Line-type rule. **Message can be edited** works only in interactive triggering; read receipts only
when sent from the client.

**Approval request tab**: tracked text (stored in `[AWS]TEXSUI`), Signature flag and due date (stored
in AWRKHISSUI.DATREL), a Context grid evaluated at trigger time and available at signature time as
`[L]CTX(1..15)` (history VALCTX1..15), and an Answer grid: answer (misc. table 54), operation code
(misc. table 55), condition, reason table, field to update with a value; with Changeable the user
may edit the value, which reaches actions as `[L]RESULT`.

**Action tab**: actions with a trigger moment (local menu 2923): Workflow start (before the text is
built — returned values can be used in the text), Workflow end, Before line, Line, Signature; an
execution condition; parameters passed by value or as pointers (return values).

Transactions: actions belong to the workflow message transaction (a Rollback while the message is
built also undoes the actions' updates); for **Object** rules the record update and the actions run in
one single transaction (a failed save rolls back the actions' updates).

## Calling your code from a rule

1. GESACT: create action `YWRKLOG`, Template **Miscellaneous process**, Subprograms (SUBPRG)
   `YWRK_LOG`, Specific script `YWRKACT`, check **Workflow** (AMSFLG); declare the parameters
   (by value / by address) on the Parameter definitions tab. No window: it cannot talk to the user.
2. GESAWA Action tab: action `YWRKLOG`, trigger moment, parameter expressions (context variables
   such as `GUSER`, `GFONCTION`, `CLEOBJ` = current key of an object rule).

```l4g
# YWRKACT - subprogram of action YWRKLOG (GESACT, Miscellaneous process, Workflow checked)
Subprog YWRK_LOG(YRUL, YCLE, YRESULT)
Value    Char YRUL(), YCLE()
Variable Char YRESULT()
Local File YWRKLOG [YWL]
Local Shortint TRANS_OPEN
  [L]TRANS_OPEN = adxlog                : # normally 1: the workflow owns the transaction
  If [L]TRANS_OPEN = 0 : Trbegin [YWL] : Endif
  Raz [F:YWL]
  [F:YWL]YRULE = [L]YRUL
  [F:YWL]YKEY  = [L]YCLE
  [F:YWL]YDAT  = date$
  Write [YWL]
  If fstat
    If [L]TRANS_OPEN = 0 : Rollback : Endif
    [L]YRESULT = "KO"
    End
  Endif
  If [L]TRANS_OPEN = 0 : Commit : Endif
  [L]YRESULT = "OK"
End
```

Triggering a rule from your own code: `Call WORKFLOW(TYPEVT, CODEVT, OPERAT, CLEOBJ) From AWRK` is
community-reported (relayed from a Sage employee); the encoding of the arguments is not publicly
documented and a Manual-rule call was reported failing ("LNM_ table not found"). Validate on your
patch level, or prefer a Miscellaneous/Manual rule launched by the standard mechanisms.

## Sending e-mail from L4G (ASEND_MAIL)

Documented API (V11 and V12 help):

```l4g
# Declaration as published in the API guide (body not shown)
Funprog ASEND_MAIL(ACTX, ISSUERMAIL, A_USER, CC_USER, HEADER, BODY, ATTACHMENTS, MOD_TRACE)
Variable Instance ACTX Using =[V]CST_C_NAME_CLASS_CONTEXT : # context where errors are stored
Value Char    ISSUERMAIL           : # sender
Value Char    A_USER()(1..)        : # main recipients
Value Char    CC_USER()(1..)       : # copy recipients
Value Char    HEADER               : # subject
Value Clbfile BODY                 : # mail text
Value Char    ATTACHMENTS()(1..)   : # attachment paths
Value Integer MOD_TRACE            : # [V]CST_AYES writes a log file in the [TMP] volume
```

Returns `[V]CST_AOK`, `[V]CST_AINFO` (at least one attachment not available) or `[V]CST_AERROR`.

```l4g
# Send a generated PDF; returns the ASEND_MAIL status
Funprog YMAIL_DOC(YTO, YSUBJECT, YFILE)
Value Char YTO(), YSUBJECT(), YFILE()
Local Char    YFROM(250), YHEADER(250)
Local Char    YA_USER(250)(1..), YCC_USER(250)(1..), YATTACH(250)(1..)
Local Clbfile YBODY(0)
Local Integer YSTA
  [L]YFROM      = "erp@example.com"
  [L]YA_USER(1) = [L]YTO
  [L]YHEADER    = [L]YSUBJECT
  [L]YATTACH(1) = [L]YFILE             : # Sage's sample uses volume paths such as "[ATT]/file.doc"
  # Body texts: literal for brevity — use mess() in real code
  Append [L]YBODY, "Bonjour," + chr$(10)
  Append [L]YBODY, "Veuillez trouver le document en pièce jointe." + chr$(10)
  [L]YSTA = func ASYRMAIL.ASEND_MAIL(GACTX, [L]YFROM, [L]YA_USER, [L]YCC_USER, [L]YHEADER, [L]YBODY, [L]YATTACH, [V]CST_ANO)
  # The caller has opened the trace (OUVRE_TRACE From LECFIC, see debugging-traces.md)
  If [L]YSTA = [V]CST_AINFO
    Call ECR_TRACE("Mail sent, attachment missing: " + [L]YFILE, 1) From GESECRAN
  Elsif [L]YSTA <> [V]CST_AOK
    Call ECR_TRACE("Mail to " + [L]YTO + " failed", 1) From GESECRAN
  Endif
End [L]YSTA
```

- The API page says the library calls the classic `meladx` executable. It documents no content-type
  or HTML option; whether the call goes through the notification server when SYRMAIL = Yes is not
  documented either — test both points on your patch level before promising HTML or authenticated
  SMTP from code. For rich HTML mails, use a workflow rule (`|CLB/…|` text + notification theme).
- `ECR_TRACE` is community-reported (`debugging-traces.md`). A community comment reports that an
  empty BODY sends an empty mail.
- `ENVMAIL` / `ENVMAILHTML From AMAIL`, `%TOKEN%` placeholders and `ASYRMAILAPI` are not documented.

## Notification servers (SMTP in V12)

SMTP is not configured in GESADS (that is **Folders**) but in Syracuse:

- Parameter **SYRMAIL** (chapter SUP, group WRK) = Yes activates the notification server. Otherwise the
  classic `meladx` client is used — Sage: for testing only, no authentication, no HTML.
- Parameter **SYRMAILSRV** (SUP / WRK) names the server per folder, company or legislation.
- Administration page **Notification servers** (class `notificationServers`): Type SMTP, AWS Simple
  Email Service, SendGrid, Mailgun, Office 365 - Microsoft Graph (OAuth2); SMTP host, port, proxy;
  security mode None / STARTTLS when available / STARTTLS required / TLS; CA and client certificates;
  EHLO with a real FQDN as "Domain name of the sending host"; authentication none or user/password;
  pooled connections and timeouts; default **Sender email**; default **theme** (HTML envelope);
  **Test configuration** action. The X3 URL must be in the Global settings allowlist.
- Community-reported: HTML workflow e-mails are standard since 2022 R2 (V12 patch 30).

## Gotchas
- Codes: GESAWA = rules, GESAWR = allocation rules, GESAWM = data models, SAIWRKPLN = monitor.
- Saving a rule generates the script `WMK` + rule code; after **Copy** to another folder press
  **Validation** there.
- End of task rules stay silent unless the task's Message - user box is checked.
- Mass imports fire Object rules per record unless the template's Workflow box (ENAWRK) is cleared
  (`imports-exports.md`).
- Choose End of transaction (TYPDEC) deliberately: before the update, conditions can test the `[F]`
  and `[M]` classes; after it, the tables are already updated.
- An action of an Object rule shares the record's transaction: never `Trbegin`/`Rollback` in it.
- In Task interruption rules `GUSER` and the usual globals are empty.
- Debug mode reports evaluation errors on screen — no help when the rule fires in batch.

See also: `batch-scheduling.md`, `imports-exports.md`, `audit-compliance.md`, `entry-points.md`,
`debugging-traces.md`.

## Sources
- https://online-help.sagex3.com/erp/12/en-us/Content/FCT/GESAWA.htm
- https://online-help.sagex3.com/erp/12/en-us/Content/FCT/GESAWR.htm
- https://online-help.sagex3.com/erp/12/en-us/Content/FCT/GESAWM.htm
- https://online-help.sagex3.com/erp/12/en-us/Content/FCT/SAIWRKPLN.htm
- https://online-help.sagex3.com/erp/12/en-us/Content/FCT/GESACT.htm
- https://online-help.sagex3.com/erp/12/en-us/Content/V7DEV/api-guide_send-mail.html
- https://online-help.sagex3.com/erp/11/en-US/V7DEV/api-guide_send-mail.html
- https://online-help.sagex3.com/erp/12/en-us/Content/V7DEV/administration-reference_notification-servers.html
- https://online-help.sagex3.com/erp/12/en-us/Content/FCT/GESADS.htm
- https://communityhub.sage.com/sage-global-solutions/sage_x3/f/general-discussion/83786/how-to-call-trigger-a-workflow-rule-in-code
- https://communityhub.sage.com/sage-global-solutions/sage_x3/f/general-discussion/200055/html-email-text-in-workflow-rules
- https://communityhub.sage.com/sage-global-solutions/sage_x3/b/sageerp_x3_product_support_blog/posts/how-to-send-mail-programmatically

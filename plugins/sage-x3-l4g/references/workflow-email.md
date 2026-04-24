# Workflow rules and emails

X3 has a dedicated **workflow engine** that fires on events (record saved, field changed, batch ended…) and can send emails, call subprograms, or update records. It's almost always the right tool for "when X happens, do Y" — use it before reaching for a custom trigger in L4G.

## The workflow engine

### Where it's defined

- **`GESAWR`** — workflow rules (when + what + to whom)
- **`GESAWA`** — workflow recipients (named groups of users)
- **`GESAWT`** — workflow templates (email / message bodies)
- **`GESAWM`** — workflow monitor (history of fired events)

### Anatomy of a rule

A rule combines:

1. **Event type** — `OBJET` (business object event), `BATCH` (batch end), `CHAMP` (field change), `LIBRE` (free/custom)
2. **Condition** — L4G expression evaluated at firing time, e.g., `[F:SOH]SOHAMT > 10000 And [F:SOH]CURORD = "EUR"`
3. **Recipients** — static users, roles, or computed via `Funprog` (for dynamic targeting, e.g., "the order's sales rep")
4. **Action** — send email (template), call subprogram, insert/update record, display notification

### When to prefer a workflow rule over L4G

| Scenario | Choose |
|----------|--------|
| "Notify manager when a large order is saved" | Workflow |
| "Auto-validate record if all lines are approved" | Workflow |
| "On save, transform fields based on business rules" | `$AVBAS` action in L4G |
| "Pull data from external API on load" | Class method in L4G |
| "Apply a 10-step validation algorithm" | L4G (unreadable in workflow UI) |
| "Log every change of a field to an audit table" | Workflow with a subprogram target |

Rule of thumb: if the action fits in one paragraph, workflow. If it needs conditionals and DB writes across tables, L4G.

## Sending an email from L4G directly

When you need full control — attach a generated file, embed a computed HTML body, or drive the whole flow from code — use `Call ENVMAIL`.

**Note on the host script name:** `From AMAIL` in the examples below is the script exposing `ENVMAIL` on many V12 installs, but the exact name drifts (seen as `AMAIL`, `GESAML`, `GESAMS` depending on patch / vertical). Check your folder's standard library — the signature of `ENVMAIL` itself is what the examples capture.

### Minimal example

```l4g
Local Char RECIPIENT(200), SUBJECT(200), BODY(2000)
RECIPIENT = "ops@example.com;cc@example.com"
SUBJECT = "Commande " - [L]NUM - " confirmée"
BODY = "Bonjour," + chr$(13) + chr$(10) +
       "La commande " - [L]NUM - " a été validée le " - num$(date$, "J/M/A") + "." +
       chr$(13) + chr$(10) + "Cordialement."

Call ENVMAIL(RECIPIENT, "", "", SUBJECT, BODY, "", "") From AMAIL
If [S]stat1
    Call ECRAN_TRACE("Email send failed: " + num$([S]stat1), 2) From GESECRAN
Endif
```

Arguments (positional, supervisor-dependent; validate against your version):

1. To (semicolon-separated)
2. Cc
3. Bcc
4. Subject
5. Body (plain text)
6. Attachment file path (empty if none)
7. Attachment display name

### With attachment (generated PDF)

```l4g
Local Char ATTACH(200)
ATTACH = "TMP/order_" - [L]NUM - ".pdf"

# Generate the PDF via the report engine
Call IMPRIM0("YSOH_CONFIRM", "FILE_PDF", "SOHNUM=" - [L]NUM) From GIMP

# Send with attachment
Call ENVMAIL(RECIPIENT, "", "", SUBJECT, BODY, ATTACH, "Commande.pdf") From AMAIL
```

The destination `FILE_PDF` must be configured in `GESADI` to write to the expected path — see `reports-printing.md`.

### HTML emails

Some versions accept an HTML flag in `ENVMAIL`; others require a dedicated variant `ENVMAILHTML`. Check your supervisor. Pattern:

```l4g
Local Char HTML(4000)
HTML = "<html><body><h2>Commande " - [L]NUM - " validée</h2>" +
       "<p>Total: <strong>" + num$([L]AMT) + " EUR</strong></p>" +
       "</body></html>"

Call ENVMAILHTML(RECIPIENT, "", "", SUBJECT, HTML, "", "") From AMAIL
```

Escape any user-supplied string with a small helper — never interpolate raw values into HTML.

## SMTP configuration

Email goes through the SMTP config set at folder level:

- **`GESADS`** — SMTP servers and credentials
- **`ADOSSIER`** parameters — default sender, folder-wide overrides

If `ENVMAIL` succeeds but no email arrives, the issue is almost never the L4G — it's SMTP authentication, relay rules, or spam filtering. Check the Syracuse mail queue first.

## Workflow templates (email bodies)

Workflow emails use templates (`GESAWT`) with tokens resolved at send time:

```
Subject: Commande [F:SOH]SOHNUM - [F:BPC]BPCNAM
Body:
Bonjour,

La commande [F:SOH]SOHNUM passée par [F:BPC]BPCNAM le [F:SOH]ORDDAT
a été validée pour un montant de [F:SOH]ORDAMT EUR.

Cordialement,
```

At send time, the workflow engine substitutes `[F:SOH]SOHNUM` with the current record's value. No L4G needed for standard cases.

### When a template isn't enough

If you need conditional text or computed fields:

1. Create a `Funprog` that returns the computed string.
2. Reference it in the template: `[func MYSCRIPT.COMPUTE_LINE()]`.
3. The engine calls it during substitution.

Keep the function idempotent — the engine may call it multiple times during one send.

## Calling a subprogram from a workflow

Workflow action type = "Subprogram". Declare the target in `GESAWR`:

```
Script: YWORKFLOW
Subprog: YNOTIFY_SALES
```

And implement:

```l4g
##############################################################
# YNOTIFY_SALES — workflow target for OBJET event on SOH
# Parameters match the workflow signature (record + event type)
##############################################################
Subprog YNOTIFY_SALES(CLE, EVT)
Value Char CLE()                         # record key, e.g. "ORD00042"
Value Char EVT()                         # event code, e.g. "CRE", "MOD", "SUP"

Local File SORDER [SOH]
Read [SOH]SOHNUM0 = CLE
If fstat : End : Endif

# Custom logic here — update another table, call an API, etc.
Call ECRAN_TRACE("Event " - EVT - " on " - CLE - " amt=" + num$([F:SOH]ORDAMT), 1) From GESECRAN
End
```

## Recurring events — scheduled workflows

For "send me a summary every Monday morning", use a **batch task** that evaluates candidates and fires workflows, or a scheduled workflow rule:

```l4g
##############################################################
# YBATCH_WEEKLY_REVIEW — scheduled weekly via GESABA/GESAPL
##############################################################
$MAIN
Local File SORDER [SOH]
Local Char BODY(4000)
Local Integer N

BODY = "Résumé hebdomadaire:" + chr$(13) + chr$(10)
N = 0

For [SOH] Where ORDDAT >= date$ - 7 And SOHSTA = 2
    Incr N
    BODY = BODY - [F:SOH]SOHNUM - "  " - num$([F:SOH]ORDAMT) + " EUR" + chr$(13) + chr$(10)
Next

BODY = BODY + chr$(13) + chr$(10) + num$(N) + " commandes validées cette semaine."

Call ENVMAIL("manager@example.com", "", "", "Revue hebdo", BODY, "", "") From AMAIL
Return
```

Schedule via `GESAPL`; log every run to a `YBATCHLOG` table so failures can be investigated later.

## Monitoring workflow activity

- **`GESAWM`** — all fired events, with success/failure
- **Syracuse mail queue** — outbound messages with retry status
- Supervisor log — engine-level errors during workflow evaluation

Build the habit of checking `GESAWM` first when "the email didn't arrive" — 80% of the time the rule didn't fire (condition, ACL, recipient resolution) rather than the email failing to send.

## Recipients — computed targeting

For dynamic recipients like "the sales rep of this order":

```l4g
##############################################################
# YWF_GETREP — returns email of the sales rep for the given order
##############################################################
Funprog YWF_GETREP(SOHNUM)
Value Char SOHNUM()

Local File SORDER [SOH], SALESREP [REP]
Local Char EMAIL(100)
EMAIL = ""

Read [SOH]SOHNUM0 = SOHNUM
If fstat : End EMAIL : Endif

Read [REP]REP0 = [F:SOH]REP
If !fstat
    EMAIL = [F:REP]EMAIL
Endif

End EMAIL
```

Reference this in `GESAWA` as the recipient resolver. The workflow engine will call it per fired event.

## Gotchas

- **Loops.** A workflow that triggers on save, writes to the same table, triggers again = infinite loop. Always gate with a condition that changes state or use a flag field (`WF_DONE`).
- **Synchronous vs asynchronous.** Some actions run synchronously during the user's save (blocking). A long SMTP timeout freezes the UI — prefer asynchronous send via the mail queue.
- **ACL on the sender.** The workflow runs as a specific user (configured in `GESAWR`); that user needs read ACL on every field referenced in the template or it renders blank.
- **Template token depth.** Standard tokens like `[F:SOH]BPCORD` work; traversing foreign keys (`[F:SOH]BPCORD.BPCNAM`) doesn't — preload via a `Funprog` token instead.
- **Character encoding in subjects.** Non-ASCII subjects need RFC 2047 encoding; most recent supervisors handle it, old patches don't — test with accents.
- **`ENVMAIL` signature drift.** Parameter count varies across versions (some have 7, some 9 with HTML flag and charset). Always check the standard library on your folder before coding.

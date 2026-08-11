# Invoice Generation — ลำดับ Commit

ร่างข้อความคอมมิททั้งชุดสำหรับ `feature-invoice-generation`
บรรทัดหัวเรื่องใช้ได้ตามนี้ ส่วนคำอธิบายควรปรับตอนคอมมิทจริงให้ตรงกับสิ่งที่เจอระหว่างทาง
โดยเฉพาะตัวเลขจำนวนเทสต์และปัญหาที่โผล่ตอนรันบนเครื่องจริง

ทุกคอมมิทต้องผ่าน `flutter analyze` และ `flutter test` ก่อน

---

## 0 · สเปก

**Add design spec for invoice generation**

```
Add design spec for invoice generation

Bills in the app have no existence of their own. fetchInvoices rebuilds
them from meter readings on every screen open, so a bill the tenant paid
last month silently changes its numbers the moment the landlord corrects
a reading. Payment status is worse: hardcoded to unpaid on the landlord
side, and held in an in-memory MockPaymentLedger that empties when the
tenant closes the app.

The spec covers freezing issued bills into an invoices table, the full
payment lifecycle through slip review, posting an invoice card into the
room chat, and PDF export. It also records the decisions that shaped the
design and what was deliberately left out — dynamic PromptPay QR,
configurable due dates, and any charge beyond the four the dormitory
actually bills for.
```

---

## 1 · ฐานข้อมูล

**Add invoices table, policies, and history backfill**

```
Add invoices table, policies, and history backfill

SQL only — no Dart changes, so the app behaves exactly as before until
the next commit starts reading from the new table.

invoices stores the four charges frozen at issue time plus a generated
total column, so the sum can never disagree with its parts no matter
which client wrote the row. A partial unique index on
(room_id, billing_year, billing_month) WHERE status <> 'voided' enforces
one active bill per room per period in the database rather than in the
app, so two landlord devices issuing at once collide on the constraint
instead of quietly creating duplicates.

tenant_id is stored on the invoice rather than read through
rooms.current_tenant_id, because tenants move out and an outstanding
bill has to keep pointing at whoever actually owes it.

Invoice numbers are unique per dormitory, not per table. The number
carries no dormitory component and room numbers repeat across
dormitories, so a table-wide constraint would have collided the moment a
second landlord had a room 301 — and taken the whole backfill
transaction down with it. Scoping the index to (dorm_id, invoice_no)
keeps the number short enough to read aloud while making it unique
where it actually means something.

Landlords reach bills belonging to their own dormitory, following the
shape already established in rls_tenant_access.sql. Tenants get SELECT
on their own bills and no write policy at all: RLS cannot restrict which
columns an UPDATE touches, and both roles are the same `authenticated`
role, so column grants cannot separate them either. Submitting a slip
goes through submit_payment_slip, a SECURITY DEFINER function that
checks ownership and status itself and writes only the slip columns.
Calling the API directly cannot change an amount or self-approve.

invoices_backfill.sql reconstructs history from existing meter data
using the same rule MockPaymentLedger applied — current period unpaid,
earlier periods paid — so the tenant's six-month history looks the same
the day this ships. It guards with NOT EXISTS and is safe to re-run.

Create the private payment-slip bucket first, then run in the Supabase
SQL editor in order: invoices_schema.sql, invoices_rls.sql,
invoices_backfill.sql, payment_slip_bucket.sql.
```

---

## 2 · แยกตรรกะการคำนวณ

**Extract invoice calculation into a pure function**

```
Extract invoice calculation into a pure function

Refactor with no behaviour change, to make the next seven commits
testable.

Invoice logic lived inside SupabaseService.fetchInvoices, which opens
with a network call — which is why test/ has seven files and not one of
them covers billing, the part of the app that handles money.

invoice_calculator.dart is plain Dart with no supabase import. It builds
a draft from a room and its readings, and returns a SkipReason when the
room cannot be billed: no tenant, no meter reading, or already issued.
The caller supplies whether a bill exists, so the function never touches
the database. The skip rule now lives in one place and is tested in one
place, rather than being an unexplained `continue` in the middle of a
loop.

invoice_lifecycle.dart holds canTransition, kept separate because
deciding what a bill costs and deciding where its status may move are
different questions.

Due-date and invoice-number rules live here too. The due-date rule still
has a twin on MockPaymentLedger for now — that duplicate dies with the
mock in the next commit, and the comment says so rather than claiming a
move that hasn't happened.

Adding voided to InvoiceStatus broke three exhaustive switches, one of
them in a file the plan hadn't listed. The compiler finding it is the
argument for exhaustive switches over a default clause.

New tests cover the skip reasons and their precedence, the 9999 → 0000
meter rollover that models.dart has always handled but nothing ever
exercised through the billing path, December's due date landing on
5 January of the next year, and the transitions that must be refused —
paid back to pending, and anything at all out of voided.
```

---

## 3 · อ่านของจริงทั้งสองฝั่ง

รวมคอมมิท 3 และ 5 เดิมเข้าด้วยกัน เพราะการเปลี่ยนรูปร่างของ `Invoice`
ทำให้ `TenantBill` และ `MockTenantBillingSource` ที่ห่อมันอยู่พังทันที
การแยกจะบังคับให้เขียนอะแดปเตอร์ที่ถูกลบทิ้งในคอมมิทถัดไปอยู่ดี

**Read issued invoices from the database instead of recomputing them**

```
Read issued invoices from the database instead of recomputing them

Bills stop moving after the fact. Both sides now read rows that were
frozen when the bill was issued, rather than a figure reassembled from
whatever the meter readings happen to say today.

Invoice becomes the persisted type — invoice number, status, due date,
slip, revision — and InvoiceDraft the computed one. Keeping them apart
means the compiler refuses the mistake that matters most here: showing a
recomputed figure where a frozen one belongs.

That type change is why the tenant side moves in the same commit.
MockPaymentLedger and MockTenantBillingSource are deleted and
SupabaseTenantBillingSource takes their place behind the same interface.
TenantBill goes with them: it existed only to bolt a mocked status onto
a computed invoice, and now that Invoice carries its own status there is
nothing left to wrap. This contradicts the note left in models.dart
saying the swap would not touch the UI — but the wrapper has outlived
its reason, and only one line ever reached through it
(tenant_bill_card.dart:23). The other 51 references are the type name.

Slips upload to a private payment-slip bucket, kept apart from
chat-image because a payment record is not a chat photo, and are written
to the invoice through a SECURITY DEFINER function rather than a direct
update — RLS cannot restrict which columns a policy lets through. Upload
happens before the row update, and a failed update deletes the
just-uploaded file so storage does not accumulate files nothing
references.

Billing methods move out of supabase_service.dart into a new
invoice_service.dart. That file was 972 lines carrying six domains;
moving roughly 200 lines out makes it smaller, not larger.

The landlord's empty state stops giving one answer to two different
questions. It used to always say to record meters first, which becomes
wrong the moment meters exist but no bill has been issued. It now
distinguishes the two and points at the button that resolves each.

Cancelled bills are excluded from the "ทั้งหมด" filter and given their
own chip, so a period with a replacement bill does not read as two
outstanding debts. The tenant's card gains the invoice number, the real
due date, and the rejection reason when a slip was turned down — which
they need to read before paying a second time.

tenant_dashboard_unit_test.dart is updated to the new type, plus a case
for cancelled bills not counting toward the outstanding balance, the
easiest thing to get wrong when a fourth status appears.
```

---

## 4 · ออกบิล

**Issue invoices for a whole dormitory from a preview dialog**

```
Issue invoices for a whole dormitory from a preview dialog

The "ออกบิลใหม่" button has been calling loadInvoices() — it redrew the
screen and issued nothing. It now opens a preview and writes real rows.

The dialog lists what will be issued with a running total, and, above
all, lists what will be skipped and why. A silent skip means the
landlord does not discover the unrecorded meter on room 205 until its
tenant asks why no bill arrived.

All rows go in a single insert, so Postgres makes issuing all-or-nothing
on its own — there is no state where seven of twelve rooms got billed.
A double tap, or a second device, collides with the partial unique index
and comes back as 23505, which surfaces as a message telling the
landlord to reload rather than as a raw Postgres error.

invoice_issue_view_model.dart owns the dialog's state, kept out of
BillingViewModel whose job is displaying bills, not creating them.
```

---

## 5 · ช่องทางชำระเงินจริง

**Show the real payment channel in the payment sheet**

```
Show the real payment channel in the payment sheet

The payment sheet drops its "โหมดตัวอย่าง" banner and shows the
dormitory's actual channel: the QR image, Kasikorn Bank account
1438323216, and a copy button.

The QR is a static image this phase, so it carries no amount. The sheet
says so directly under it — without that line a tenant scans, finds an
empty amount field, types the wrong figure, and gets their slip
rejected. PaymentChannel is shaped so that swapping in a generated QR
later changes nothing for its callers.

When the channel fails to load the sheet still lets the tenant attach a
slip, rather than hiding itself — they may have paid through another
route already.
```

---

## 6 · การ์ดบิลในแชท

**Post an invoice card into the room chat when a bill is issued**

```
Post an invoice card into the room chat when a bill is issued

Tenants no longer have to think to check. Issuing a bill posts a summary
card into that room's conversation, the same way a repair request
already announces itself.

MessageType gains invoice and ChatMessage gains invoiceId, following
maintenanceRequestId exactly. The card shows the period, the total and
the due date, and opens the payment sheet for the tenant or the bill
detail sheet for the landlord.

The card reads its status live rather than freezing it at send time. The
chat view model resolves the referenced invoices in one query when the
conversation opens, batched the way attachment URLs already are. One
extra query per chat open buys never showing a card that still insists
฿5,240 is outstanding a day after it was paid.

Messages are inserted as one batch alongside the invoices. If that
insert fails the bills stand and the landlord is told the notification
did not go out, with a retry that skips rooms already notified —
the bill is the real thing, the message is an announcement about it.

If the status lookup fails the card still renders its period and amount
without a badge. Chat must not break because billing did.
```

---

## 7 · ตรวจสลิป

**Let the landlord approve or reject payment slips**

```
Let the landlord approve or reject payment slips

Closes the payment loop. The "ดูสลิป" button has had an empty
onPressed since the billing screen was written; it now opens the slip
full screen with approve and reject.

Approving stamps paid_at and approved_by. Rejecting requires a reason
and returns the bill to unpaid rather than introducing a fifth status,
because what the tenant has to do is unchanged — pay again — only now
with an explanation to read. Both post to the conversation, so the
tenant has the outcome in writing rather than as a number that shifted
in another tab.

Signed URLs for slips are minted per open and never cached across
sessions.
```

---

## 8 · ยกเลิกและออกใหม่

**Void an invoice and issue a corrected replacement**

```
Void an invoice and issue a corrected replacement

A misread meter or a forgotten cleaning fee no longer means editing a
bill after the fact. The landlord voids it with a reason and issues a
replacement, so what was originally billed stays auditable instead of
being overwritten.

The new bill carries revision + 1 and replaces_invoice_id pointing back,
which keeps an already-submitted slip traceable even when the bill it
paid is void. Its number gains an -R2 suffix so the two are never
confused on paper.

Voiding is allowed from paid as well as from unpaid and pending, since
approving the wrong slip is exactly the kind of mistake this exists to
undo. A reason is required in every case, and the room is told in chat.

The partial unique index lets the replacement exist because the voided
row no longer counts as active.
```

---

## 9 · PDF

**Export an invoice as a PDF**

```
Export an invoice as a PDF

Both sides can save or share a bill as a document. Generated on demand
and never stored, so there are no files to clean up when a bill is
voided.

Thai text is the whole risk here. The pdf package defaults to
Helvetica, which has no Thai glyphs, and renders an entire invoice as
empty boxes without a single compile-time complaint. Sarabun Regular and
Bold are bundled and registered explicitly.

The layout is A5 portrait, which reads without zooming on a phone. Paid
invoices carry a diagonal ชำระแล้ว watermark and voided ones ยกเลิก —
a shared PDF cannot be recalled, so a cancelled bill has to say so
itself.

buildInvoicePdf accepts only the persisted Invoice type, which makes
printing a recomputed figure impossible rather than merely unlikely.

Tests render a normal, a paid and a voided invoice and assert non-empty
output.
```

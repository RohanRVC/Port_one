# Progress log

A running account of what was tried, what was ruled out, and how each
variance was isolated — not just the final numbers. Written as the work
happened, in order.

## 1. Reading the brief and getting the real data

The task doc describes five files shared via a Google Drive folder. Pulled
all five directly (payments CSV 9.3MB/23,026 rows, settlements TXT
10.7MB/54,980 rows, both mapping configs, the sample xlsx) and worked from
the real data throughout — no synthetic/mocked data at any point.

First pass over the two config files (`amazon_payment_configs_au_old.csv`,
149 rows; `amazon_settlement_configs_au.csv`, 137 rows) by eye turned up two
candidate defects immediately, before any code was written:

- Payment config lines 71/72: both key on `(ORDER, any, sales_tax_collected)`
  but route to different buckets (`sales_product_charges` vs
  `sales_shipping`) — a duplicate, ambiguous lookup key.
- Payment config lines 5/6: the same shape of bug on `low_value_goods`
  (`sales_shipping` vs `sales_product_charges`).

Rather than trust a manual read of 286 config rows to be exhaustive, a
background research pass was run in parallel with scaffolding the Go
project: audit both config files for (1) duplicate/ambiguous keys, (2)
malformed `record_ref` templates, (3) `amount_field`/`amount_type` values
that don't exist in the real data schema, (4) cross-config placeholder
mismatches for the same semantic transaction, (5) any other anomaly — with
instructions to verify every finding's *actual occurrence count* against
the real data files, not just flag it as theoretically possible.

That pass confirmed both duplicate-key defects above (and gave exact
occurrence counts: the `sales_tax_collected` duplicate touches 9,121 of
22,783 real ORDER rows; `low_value_goods` touches 86) and found several
more, most importantly:

- Settlement config line 138: `record_ref` template
  `ADJUSTMENT_OTHER+settlement_id+date+record_type+settlement_id` — a
  `record_type` token that isn't a real column or a recognized placeholder,
  plus a duplicated `settlement_id`.
- Payment config lines 62/63 (`TRANSFER`): key on descriptions
  `TO_YOUR_ACCOUNT_ENDING` / `TO_ACCOUNT_ENDING`, neither of which matches
  the real payments data's actual Transfer description, `"To account
  ending with: 334"`.
- Two cross-config placeholder mismatches (`SERVICE_FEE` /
  `FBA_INBOUND_PLACEMENT_SERVICE_FEE` and `SERVICE_FEE` /
  `INBOUND_DEFECT_FEE`): payment config keys these on `txn_ref`, settlement
  config keys the same semantic fee on `shipment_id`.
- `marketplace_withheld_tax` referenced as an `amount_field` in three
  payment config rows, but no such column exists in this payments file's
  25-column header.
- A handful of lower-confidence/zero-occurrence items (a Unicode en dash in
  one description, a duplicate `VINE_ENROLLMENT_FEE`/`VINE_ENROLMENT_FEE`
  spelling, an inconsistent sibling rule for `FEE_CORRECTION`
  reimbursements, an asymmetric sign-routing rule for settlement
  `REFUND/ItemPrice/Tax`).

This static pass ran to completion *before* the pipeline had ingested a
single row — the plan from here was to build the pipeline, run it once
unmodified, and check every one of these predictions against real,
measured dollar variances, rather than fix anything blind.

## 2. Figuring out the Summary sheet's actual structure

`amazon_sample_output_report.xlsx` has all values zeroed out by design, so
the row *labels* and section grouping had to be extracted directly from the
xlsx XML (no `openpyxl` available in this environment, so parsed
`sharedStrings.xml` + `sheet1.xml` by hand). That gave the exact row
numbers, labels, and Sales/Refunds/Expenses section grouping used
everywhere else in this project.

Cross-referencing the Summary sheet's 21 line-item labels against the 22
distinct `summary_field` values used across both configs (extracted
programmatically, not by re-reading the CSVs) turned up:

- One bucket, `sales_gift_wrap_credits`, used only by payment config line
  70, that **has no corresponding row anywhere on the Summary sheet** —
  it's an orphan. Settlement's equivalent rule for the same real-world
  event (`ORDER`/`ItemPrice`/`GiftWrap`) instead routes to `sales_other`,
  which *does* have a slot ("Other", under Sales). This was finding #3 (not
  caught by the earlier record_ref-focused audit, since it's a bucket-name
  mismatch, not a record_ref mismatch).
- A second, same-shape defect: settlement's `ORDER`/`PROMOTION`/`PRINCIPAL`
  and `.../SHIPPING` rules route to `expenses_promotional_rebates` (which
  has its own "Promo rebates" line), but payment config line 65's
  equivalent rule (`ORDER`/any/`promotional_rebates`) routes to
  `expenses_other` instead. Same root cause pattern as the gift-wrap
  finding: the same real-world event is bucketed differently on each side.
- Three buckets (`amazon_carried_forward`, `beginning_balance`,
  `current_reserve_amount`) that are genuine settlement-only balance
  concepts with no template slot at all — not a defect, just a report-
  template gap (documented in README, not "fixed").
- Two Summary rows (Sales/"FBA Fees", Expenses/"Shipping Charges") that no
  current config rule routes anything to — left as 0/0/0, not forced.

These four findings (2 orphan/mis-bucketed buckets, 3 no-slot buckets, 2
no-rule rows) came entirely from mechanically diffing two lists against
each other — no guessing.

## 3. Building the pipeline

Go + `pgx/v5` + `excelize/v2`, Postgres via `docker compose`, everything
built and run inside Docker (no local Go install available in this
environment; verified `go build ./...` and `go vet ./...` clean on the
first real attempt after writing all packages). Design decisions
(single-table ingestion, exploding payments rows, the matching-precedence
algorithm, `record_ref` templating, dual-sign buckets, streaming the
summary calculation) are all in `README.md` — this log covers what
happened when it actually ran, not the design itself.

**The `date` token needed real investigation, not an assumption.** The
obvious choice for a payment row's date — its own `date/time` column,
matched against settlement's `posted-date` — was tested empirically before
committing to it:

```
checked pairs: 5005
exact datetime match: 4032
same-date-only match: 197
mismatched: 776   (turned out to be a sampling artifact -- see below)
```

Sampling 5,000 matched order-ids, converting each payment row's
`Transaction Release Date` from its embedded `GMT±N` offset to UTC, and
comparing to that same order's settlement `posted-date-time` (already
UTC): 80.6% matched to the exact second, 3.9% matched to the same day. The
remaining 15.5% mismatch was traced to the check pairing a payment line
against *every* settlement line for the same order-id, including lines
for other SKUs in a multi-item order — not a real date disagreement.
Meanwhile, checking the *originally obvious* candidate (payment `date/time`
vs settlement `posted-date`) came back **0 of 3,000 sampled pairs matching
even to the day** — the two columns are weeks apart by design (order date
vs. financial posting date), which would have made almost every
`record_ref` fail to match had it been used. This one check, done before
writing the matching engine, avoided building the entire reconciliation
key on a wrong assumption.

## 4. First real ingestion run (unfixed configs)

Two real data quirks surfaced immediately, both fixed in the ingestion code
itself (not the mapping config, since these are data-format issues, not
mapping-rule issues):

- `strconv.ParseInt` failed on `"97,919.76"` (thousands separator) — exactly
  2 rows in the whole payments file, both `Transfer` rows with unusually
  large amounts. Fixed by stripping commas before parsing
  (`internal/ingest/money.go`).
- The initial ambiguity log recorded 45,566 *distinct* entries — because it
  keyed on the triggering row's full free-text description, so every
  different product title under an ambiguous ORDER rule counted as a
  separate "ambiguity". Fixed to key on the sorted set of tied config
  `source_line`s instead, which correctly collapsed this to exactly **2**
  distinct ambiguities — matching the two duplicate-key defects predicted
  in step 1, with occurrence counts of 22,783 each (every ORDER row, since
  the ambiguous match fires regardless of whether that row's amount happens
  to be zero).

With that fixed, the first full run:

```
payments: 23026 source rows -> 253286 components (145346 zero-valued), 252456 matched (45566 ambiguous rows), 830 unmatched
settlements: 54980 rows (48 zero-valued), 54979 matched (0 ambiguous), 1 unmatched
reconciliation: 13289 reconciled, 9379 unreconciled-payment, 0 unreconciled-settlement
```

## 5. Is 0 unreconciled-settlement suspicious?

First instinct: with 54,980 settlement rows against 23,026 payment rows,
*zero* unreconciled-settlement record_refs looked too clean. Checked
directly:

```sql
SELECT count(DISTINCT settlement_id) FROM raw_records WHERE source_type='settlement';
-- 1
SELECT min(txn_date), max(txn_date) FROM raw_records WHERE source_type='settlement';
-- 2026-07-17 to 2026-07-31
SELECT min(txn_date), max(txn_date) FROM raw_records WHERE source_type='payment';
-- 2026-06-30 to 2026-07-31
```

This settlement file covers exactly **one** settlement (single
`settlement-id`, 12395580393), a 15-day window. The payments file spans a
wider range. Later (step 6) I found the payments file references **four**
settlement IDs (12370691583, 12382593803, 12395580393, 12407469483), so
the settlement side is a subset of what the payments file covers, which is
why every settlement-side dollar has a payment-side counterpart and not the
other way round. Ruled out as "not a bug" on that basis. The zero is also
consistent with the independent checks: the settlement lines sum to
212,118.95, exactly the `total-amount` the file declares for that
settlement.

## 6. Why are there 9,379 unreconciled-payment record_refs?

Broke the unreconciled-payment total down by `(transaction_type,
summary_field)`:

```
Transfer                              | (unrouted -- see step 7)        |    2 | -231676.27
Order                                 | sales_product_charges           | 9298 |  171072.17
Service fee                           | (unrouted)                      |    1 |   -1150.53
Adjustment                            | sales_inventory_reimbursements  |   48 |     988.67
Refund                                | refunded_sales                  |   25 |    -620.73
Fulfilment by Amazon transaction fees | expenses_fba_fees               |    1 |    -494.64
```

The dominant chunk (9,298 of 9,379) is ordinary `Order` activity. Spot-
checked 8 of these unreconciled order_refs directly:

```sql
EXISTS(SELECT 1 FROM raw_records x WHERE x.source_type='settlement' AND x.order_id=r.order_id)
-- false, for every single one of the 8 sampled
```

The order_id genuinely does not appear anywhere in the settlement file —
not under a different date, not under a different SKU pairing. Two of the
eight had no `Transaction Release Date` at all. My first conclusion from
that sample was "these orders belong to settlements we weren't given". That
turned out to be only part of it, so I checked the whole population instead
of extrapolating from 8 rows (this was done late, during final
verification, after the fixes):

```sql
-- every unreconciled_payment record_ref, classified
A  payment row is Released, settlement id is one we were not given        6,876 refs  123,953.39
B  payment row is Deferred (no release date), any settlement id           2,501 refs   45,813.08
   (2,373 carry our settlement id, 125 another, 3 are a deferred line of
    an order whose other line item did reconcile)
                                                                         -----       ----------
                                                                          9,377       169,766.47
```

Two causes, no residue, and the total matches the unreconciled sum to the
cent. Both are properties of the input files (which settlements we were
handed; which transactions Amazon has released yet), not mapping defects,
and no config change can close them. The payments file's own preamble says
post-2025 reports "include both released and deferred transactions", which
is what B is. This is also why the Summary's Product Charges line shows
such a large Payments-vs-Settlements gap even before any fix. The
Consolidated sheet now carries the payment side's `transaction_status`
so the reason is visible row by row.

## 7. The single biggest defect: $231,676.27 in the wrong bucket

The "Transfer" row's `-$231,676.27` appearing in `unreconciled_payment`
under an **empty** `summary_field` in the breakdown above was the loose
thread. If it's truly unrouted (no config match), it shouldn't be able to
contribute a dollar figure to *anything* — so something else was going on.
Traced it directly:

```sql
SELECT pc.source_line, pc.transaction_type, pc.description, pc.amount_field, count(*), sum(amount)
FROM raw_records r JOIN payment_mapping_configs pc ON pc.id = r.matched_config_id
WHERE pc.transaction_type = '' AND pc.amount_field = 'total';
-- source_line 110 | '' | any | total | 2 | -231676.27
```

Both real `Transfer` rows' `total` field (identical to their `other` field
in this data: `-97,919.76` and `-133,756.51`) were matching payment config
**line 110** — the blank-transaction_type catch-all for `amount_field =
total` — because their own dedicated rules (lines 62/63, `TRANSFER` +
`TO_YOUR_ACCOUNT_ENDING`/`TO_ACCOUNT_ENDING`) never match the real
description text (`"To account ending with: 334"`, confirmed in step 1).
Line 110, unlike every *other* `total`-amount_field rule in either config,
has **non-empty** routing (`expenses_amazon_fees`) — so instead of being
correctly excluded (per the "total is a checksum column" convention
documented in README), this money landed in "Amazon fees."

**Verified line 110 wasn't otherwise load-bearing** before touching it:

```sql
-- same query as above, run before any fix: exactly 2 rows, both Transfer. Nothing else in
-- this dataset currently depends on line 110 having non-empty routing.
```

Applied two fixes together (`MAPPING_FIXES.sql` FIX 3 + FIX 4): consolidated
the two dead Transfer rules into one, `description = 'any'`, keeping their
existing empty routing (so Transfer money is now excluded, matching every
other `total` rule); and separately closed line 110's inconsistent routing
to empty/empty as defense-in-depth, since it's a **generic** catch-all that
would silently repeat this exact failure mode for any future transaction
type this dataset doesn't happen to contain.

## 8. Second-biggest defect: $11,273.53 in the wrong bucket

Bucket-level breakdown, splitting each bucket's payment/settlement totals
by whether the *owning* record_ref actually reconciled overall (to
separate "same transaction, different bucket" from "no counterpart at
all"):

```sql
SELECT r.summary_field,
  SUM(amount) FILTER (WHERE source_type='payment'    AND rr.status='reconciled') AS pay_in_reconciled,
  SUM(amount) FILTER (WHERE source_type='settlement' AND rr.status='reconciled') AS settle_in_reconciled,
  ...
FROM raw_records r JOIN reconciliation_results rr ON rr.record_ref = r.record_ref
WHERE r.summary_field IS NOT NULL GROUP BY r.summary_field;
```

```
expenses_other                | -11273.53 | (none)     | -13834.85 | (none)
expenses_promotional_rebates  | (none)    | -11273.53  | (none)    | (none)
```

Exact, dollar-for-dollar match between what's sitting in payment's
`expenses_other` (within reconciled record_refs) and the entirety of
settlement's `expenses_promotional_rebates` — precisely the config
inconsistency identified in step 2 (payment config line 65 routes
`promotional_rebates` to `expenses_other` instead of
`expenses_promotional_rebates`). Fixed as `MAPPING_FIXES.sql` FIX 1.

The same query surfaced the gift-wrap finding from step 2 with equal
precision: `sales_other` had **$0 on the payment side, $11.97 on the
settlement side**, while a separate line, `sales_gift_wrap_credits`,
showed **$11.61 on the payment side** for the same reconciled record_refs —
confirming payment's gift-wrap money was sitting in the orphan bucket
instead of `sales_other`. Fixed as FIX 2. After the fix the gift-wrap
principal agrees exactly (11.61 both sides); the leftover $0.36 on that
line is settlement's `GiftWrapTax`, which I first mis-explained here as
part of the gift-wrap fix. It isn't: the payments report has no gift-wrap-tax
column, that money is inside the combined `sales tax collected` figure,
and it belongs to the tax re-bucketing in step 9.

## 9. The two duplicate-key defects: what actually changes, what doesn't

Before applying any fix, a natural question: does resolving the two
ambiguous-key defects (step 1) change any dollar totals in this run, or
only remove non-determinism? Checked what the matcher was *already*
deterministically choosing (lowest `source_line` wins): line 71
(`sales_product_charges`) over line 72, and line 5 (`sales_shipping`) over
line 6. Rather than switch either choice, we kept both as the sole
surviving rule and deleted the redundant one — for `sales_tax_collected`,
because settlement's dominant real-world equivalent
(`ItemPrice`/`Tax` → `sales_product_charges`, 5,248 occurrences) clearly
favors that choice anyway; for `low_value_goods`, because settlement splits
the equivalent tax 50/50 by *count* but ~71:1 by *dollar value*
(`LowValueGoodsTax-Principal` -$193.90 vs `-Shipping` -$2.72) — no
clearly-correct single bucket to collapse into, so we left the existing
behavior in place rather than switch it on a coin flip. Documented in
`MAPPING_FIXES.sql` FIX 5/FIX 6 as removing undefined behavior, not as
closing the +103.78 / -103.42 / -0.36 residual on Product Charges /
Shipping / Other. Confirmed: deleting the two duplicate rows leaves the
Product Charges and Shipping reconciled-only totals exactly as they were
(349,012.55 and 8,097.54 on the payment side), since the fix codified
existing behavior.

That residual is *not* an unexplained gap, and I was too quick to file it
under "schema limitation" the first time. Broken down by component on the
13,289 reconciled record_refs:

```
                                  payment      settlement
product_sales / ItemPrice.Principal  335,336.96  335,336.96   exact
shipping_credits / ItemPrice.Shipping  8,294.16    8,294.16   exact
gift_wrap_credits / ItemPrice.GiftWrap    11.61       11.61   exact
sales_tax_collected (one column)      13,675.59
  vs settlement Tax 13,765.71 + ShippingTax 581.68
     + Promotion/TaxDiscount -672.16 + GiftWrapTax 0.36 =      13,675.59   exact
low_value_goods (one column)            -196.62
  vs settlement LVG-Principal -193.90 + LVG-Shipping -2.72 =    -196.62   exact
```

Every component agrees to the cent; the payments file simply has one
combined tax column and one combined low-value-goods column, while the
settlement config sends its finer tax lines to Product Charges, Shipping
and Other. So the three lines move against each other and net to exactly
0.00, and the Sales subtotal on reconciled records ties. I did not
re-bucket the settlement side to force the lines to match: that would
override a deliberate classification to make a number agree, which is
exactly the "plug" the brief warns against.

## 10. Chasing the last $42.59

Before any fixes, the reconciled-side gap (payment sum minus settlement sum
over the 13,289 reconciled record_refs: 212,161.54 vs 212,118.95) was
exactly $42.59, small enough to be worth accounting for fully. Bucket by
bucket, same reconciled-only query as step 8:

- `expenses_other` / `expenses_promotional_rebates`: -$11,273.53 / +$11,273.53, nets to $0 (step 8).
- `sales_other` / `sales_gift_wrap_credits`: -$11.97 / +$11.61.
- `sales_product_charges` / `sales_shipping`: +$103.78 / -$103.42.
- `refunded_expenses`: +$42.59, on its own.

The first three net to $0.00 (the -0.36 and +0.36 cancel). The $42.59 is
entirely `refunded_expenses`.

**My first explanation of that $42.59 was wrong.** I looked at payment-side
`refunded_expenses` rows with no settlement `refunded_expenses` row under
the same record_ref, got 155.39 + 97.84 + 14.66 = 267.89, and wrote it up as
small refund-fee reversals posting a few days late plus a "$14.66 FBA-fee
refund config gap". That query spanned payment-only refunds across the whole
file, not the reconciled records where the 42.59 actually lives, so it
explained a different number. I caught it in the final verification pass
by asking what is *inside* the 42.59:

```
refunded_expenses inside reconciled refs, by source column / settlement line
payment    fba_fees             28.89    settlement ItemFees/ShippingChargeback     28.89   exact
payment    selling_fees        117.36    settlement Commission + RefundCommission  117.36   exact
payment    promotional_rebates 112.62    settlement Promotion/Principal + /Shipping 112.62  exact
                                         settlement ItemPrice/Tax                  -41.09
                                         settlement ItemPrice/ShippingTax           -3.19
                                         settlement Promotion/TaxDiscount           +1.69
                                                                                   ------
                                                                                   -42.59
```

Everything pairs off exactly except settlement-side refund *tax* lines that
total -42.59. The payments side has that money too: `REFUND` rows'
`sales_tax_collected` on the same 16 record_refs sums to exactly -42.59, but
payment config line 14 (`REFUND / any / sales_tax_collected`) has empty
routing, so tax refunded to customers never reaches the Summary from the
Payments report, while the settlement config counts it in
`refunded_expenses`. Same kind of defect as the promotional rebates one (the
same money bucketed differently on the two sides), and easy to miss by eye
because the row looks like the other intentionally-empty ones.

Fixed as `MAPPING_FIXES.sql` FIX 13 (route it to `refunded_expenses`). After
it, `refunded_expenses` agrees to the cent on reconciled records, and the
13,289 reconciled record_refs total 212,118.95 on both sides with none of
them carrying a nonzero difference. The Payments column moves by -71.06 in
total (-42.59 reconciled, -28.47 on payment-only refunds). The earlier
"$14.66 FBA-fee refund gap" does not exist: payment `fba_fees` 28.89 equals
settlement ShippingChargeback 28.89 exactly.

## 11. Applying the fixes and confirming the after-fix numbers

Applied all 13 fixes in `MAPPING_FIXES.sql` to the live config tables (with
the exact command from the README), then re-ran `ingest-data` (which reuses
the now-fixed config tables, it does not reload from CSV) and regenerated
the report.

```
before: payments ... 252456 matched (45566 ambiguous rows) ...   reconciliation: 13289 / 9379 / 0
after:  payments ... 252456 matched (0 ambiguous rows) ...       reconciliation: 13289 / 9377 / 0
```

Read straight from the two committed workbooks (Payments / Settlements):

| Summary line | Before | After | What changed |
|---|---|---|---|
| Sales / Other | 0.00 / 11.97 | 33.19 / 11.97 | gift-wrap credits now visible (11.61 reconciled + 21.58 payment-only) |
| Refunds (section) | -3,373.85 / -1,815.09 | -3,444.91 / -1,815.09 | FIX 13 |
| Refunds / Refund expenses | 526.76 / 216.28 | 455.70 / 216.28 | FIX 13: -71.06 |
| Expenses / Promo rebates | 0.00 / -11,273.53 | -25,108.38 / -11,273.53 | payment side now lands in the right line |
| Expenses / Other | -25,108.38 / 0.00 | 0.00 / 0.00 | that money moved out |
| Expenses / Amazon fees | -449,312.42 / -132,593.41 | -217,636.15 / -132,593.41 | +231,676.27 (Transfer rows out) |
| Expenses (section) | -476,066.38 / -143,867.35 | -244,390.11 / -143,867.35 | +231,676.27 |

The Settlements column is unchanged (only one settlement config row was
touched, and its positive branch never occurs in this data). Ambiguities:
2 -> 0. Unreconciled-payment 9,379 -> 9,377: the two Transfer rows, which
used to be counted as summarizable payment-only money via the fallback rule
and now correctly aren't.

On the reconciled records: before, payment 212,161.54 vs settlement
212,118.95 (diff 42.59, all of it in 16 refund record_refs). After, both
sides 212,118.95, and 0 of the 13,289 reconciled record_refs has a nonzero
difference.

## 11b. A pipeline bug that had nothing to do with the data

While verifying the fully-dockerized `docker compose run --rm app all` path
end to end (as opposed to the ad-hoc `docker run golang:...` commands used
for faster iteration up to this point), the report step hung for 4-5+
minutes immediately after a fresh ingest — but running `report` as its own
separate `docker compose run` right afterward took 6 seconds. Checked
`pg_stat_activity` while it hung: the query was `active` with no
`wait_event`, i.e. genuinely burning CPU, not blocked. Isolated it with
three experiments: (1) `EXPLAIN` showed a cheap, well-indexed plan
(~260k cost units, index scans throughout) — the plan itself wasn't the
problem; (2) running the same query with `SET jit = off` dropped it from
5+ minutes to 390ms in one comparison, implicating Postgres's JIT compiler
specifically; (3) but a later same-shape comparison with JIT left *on*
came back in 775ms, so it wasn't a deterministic "this query always
triggers slow JIT" issue either. What consistently reproduced the hang was
running a join-heavy `SELECT` *immediately* after a multi-hundred-thousand-
row `COPY` bulk load; running `CHECKPOINT; ANALYZE raw_records;` first
brought it straight back to ~1.7 seconds, every time. Fixed by disabling
JIT for the app's own connections (it buys nothing for queries this cheap
regardless) and running an explicit `ANALYZE` + `CHECKPOINT` at the end of
`ingest-data`, so `report` never has to race Postgres's own background
checkpoint I/O. Confirmed with a full clean `docker compose down -v` →
`all` → apply fixes → `ingest-data` → `report` cycle afterward: consistently
roughly a minute or two end to end (up to four on a busy machine), both before and after the mapping fixes.

## 12. What's left, and why

After 13 fixes, the Payments and Settlements columns of the Summary sheet
still differ. Every remaining difference is one of two things, both traced
to a specific, checkable cause:

1. **The 9,377 payment-only record_refs (169,766.47).** Checked across all of
   them (step 6): 6,876 are Released transactions belonging to three
   settlements that are not in the settlement file, and 2,501 are Deferred
   transactions with no release date. Properties of the input files, not
   mapping defects, so no config change can close them. The Consolidated
   sheet shows `transaction_status` and `settlement_id` per row so a
   reviewer can see which is which.
2. **Tax bucketing on the Sales lines: +103.78 / -103.42 / -0.36, net
   0.00** (step 9). Same money, different bucket, exact at the component
   level. Left as is on purpose; documented in FIX 5/6.

Nothing was hardcoded or pattern-matched to force a total; every fix in
`MAPPING_FIXES.sql` is traceable to a specific config row and a measured
(or explicitly zero) dollar effect. The remaining defects in that file
(shipment id vs order id, PROMOTION_FEE, the malformed `record_type` row,
and so on) don't occur in this data, so they are documented but have no
effect on these numbers.

## 13. Final verification pass, and what it corrected

Before writing the submission email I re-checked everything from scratch
rather than trusting the notes above. That found real problems in my own
write-up, all now corrected:

- The $42.59 was mis-explained (step 10) and hid a 13th config defect.
- The "unreconciled = other settlement periods" explanation was based on an
  8-row sample and was incomplete (step 6): there are two causes, and the
  Deferred one (2,501 refs) had been folded into the wrong story.
- The README claimed the reconciled lines "agree to the cent". Not true at
  the bucket level (the three tax lines), true at the record_ref level.
- The README's step 4 referenced a service that doesn't exist.
- "Byte-identical re-ingest" was stronger than what I had measured; it is
  now the md5 of all three derived tables before and after a second
  re-ingest.

What was added: unit tests, an independent Python re-implementation (zero
mismatches on 19 buckets and 22,666 record_refs), and the tie-outs listed
under "How the numbers were checked" in the README (the settlement total
Amazon declares, the payments `total` checksum, the per-type accounting of
every payments dollar).

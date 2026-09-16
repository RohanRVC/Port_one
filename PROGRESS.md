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

This settlement file covers exactly **one** settlement period (single
`settlement-id`), a 15-day window. The payments file spans a wider range
that overlaps but extends earlier. Every settlement-side dollar in this
file has a payment-side counterpart somewhere in the wider payments window
— unsurprising once you see it's one settlement drawing from a superset of
orders we do have visibility into, rather than evidence of a matching bug.
Ruled out as "not a bug" on this basis, not assumed.

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
eight had no `Transaction Release Date` at all (order not yet released).
Conclusion: these orders belong to settlement periods we were not given
data for (this dataset gives us one settlement out of presumably many the
seller has had) — a data-coverage gap, not a mapping defect. This also
explains why the Summary sheet's Sales/Product Charges line shows such a
large Payments-vs-Settlements gap even *before* any fix (see step 8): most
of that gap is coverage, and no config change can close it. Restated
explicitly in the README rather than left implicit.

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
instead of `sales_other`. Fixed as FIX 2 (the remaining $0.36 gap is the
`GiftWrapTax` settlement sub-component, which routes to `sales_other` too
and is now captured now that both sides land on the same bucket).

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
closing the ~$103/$0.36 residual between Product Charges and Shipping —
that residual is a genuine schema limitation (see README), confirmed by
checking that after the fix, `sales_product_charges`/`sales_shipping`'s
reconciled-only totals moved by $0.00 (as expected, since the fix codified
existing behavior rather than changing it).

## 10. Chasing the last $42.59

Before any fixes, the *entire* dataset's reconciled-side gap (summed across
every bucket) was exactly $42.59 — small enough to be worth fully
accounting for rather than writing off. Broke it down bucket by bucket
(same reconciled-only query as step 8) and found it resolves into three
independent pieces:

- `expenses_other` / `expenses_promotional_rebates`: -$11,273.53 / +$11,273.53 — nets to $0 (this is defect #2, step 8).
- `sales_other` / `sales_gift_wrap_credits`: -$11.97 / +$11.61 → nets to -$0.36 (defect #3, step 8, minus the small GiftWrapTax residual).
- `sales_product_charges` / `sales_shipping`: +$103.78 / -$103.42 → nets to +$0.36 (the duplicate-key/granularity residual, step 9).
- `refunded_expenses`: +$42.59, standalone.

The first three net to exactly $0.00 (the two $0.36 residuals are equal and
opposite). The remaining $42.59 is entirely `refunded_expenses`. Traced its
contributing rows directly:

```sql
SELECT p.amount_field, count(*), sum(p.amount)
FROM raw_records p
WHERE p.source_type='payment' AND p.summary_field='refunded_expenses'
  AND NOT EXISTS (SELECT 1 FROM raw_records s WHERE s.source_type='settlement'
                  AND s.record_ref = p.record_ref AND s.summary_field='refunded_expenses')
GROUP BY 1;
```
```
promotional_rebates | 43 | 155.39
selling_fees         | 30 |  97.84
fba_fees             |  4 |  14.66
```

Spread across 3 different amount fields on many different orders, each a
small individual refund-fee reversal with no exact-matching settlement
counterpart under the same `record_ref` — consistent with the same
settlement-timing-boundary effect documented in step 6 (a refund's fee
reversal posting a few days later than the refund itself, sometimes
crossing this settlement window's edge), just at much smaller scale. The
`fba_fees` sub-piece (4 records, $14.66) is additionally notable: the
settlement config has no explicit `REFUND`/`ItemFees`/(FBA-fee-reversal)
rule at all, unlike its `Commission`/`RefundCommission` siblings — a
genuine, narrow config gap, but $14.66 is too small and too
context-dependent (would need confirmation this combination ever appears
in a real settlement export) to fix with confidence rather than guess.
Documented, not force-fixed — this is the one variance in the whole
investigation we're calling "accounted for but not closeable with the
evidence available," per the assignment's own framing for exactly this
situation.

## 11. Applying the fixes and confirming the after-fix numbers

Applied all 12 fixes in `MAPPING_FIXES.sql` directly against the live
config tables, then re-ran `ingest-data` (which reuses the now-fixed config
tables — it does not reload from CSV) and regenerated the report.

```
before: payments ... 252456 matched (45566 ambiguous rows) ...
after:  payments ... 252456 matched (0 ambiguous rows) ...
```

Every predicted change matched exactly:

| Summary line | Before (Pay / Settle) | After (Pay / Settle) | Change |
|---|---|---|---|
| Sales / Other | 0.00 / 11.97 | 33.19 / 11.97 | +33.19 (= $11.61 reconciled + $21.58 unreconciled gift-wrap money, now visible) |
| Expenses / Promo rebates | 0.00 / -11273.53 | -25108.38 / -11273.53 | payment side now shows this bucket's real activity at all |
| Expenses / Other | -25108.38 / 0.00 | 0.00 / 0.00 | the promo-rebates money that used to sit here moved out entirely |
| Expenses / Amazon fees | -449312.42 / -132593.41 | -217636.15 / -132593.41 | improved by exactly $231,676.27 |
| Expenses (section) | -476066.38 / -143867.35 | -244390.11 / -143867.35 | improved by exactly $231,676.27 |

Settlement-side totals are **byte-identical** before and after (as
expected — only one settlement config row was touched, for a rule with
$0 measured impact in this run). Config-matching ambiguities: 2 → 0.
Reconciled/unreconciled counts moved by exactly 2 (9,379 → 9,377
unreconciled-payment — the two Transfer rows, now correctly excluded from
`unreconciled_payment`'s dollar total instead of being miscounted there via
the fallback bug).

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
under a minute end to end, both before and after the mapping fixes.

## 12. What's left unclosed, and why

Every remaining Payments-vs-Settlements gap on every Summary line, after
all 12 fixes, is one of exactly three things, each traced to a specific,
checkable cause rather than left as an unexplained residual:

1. **Settlement-period coverage** (step 5/6) — the large majority of every
   remaining gap. Not fixable via config; it's a property of which files we
   were given, not a mapping defect.
2. **The Product Charges/Shipping schema-granularity limit** (step 9) —
   ~$103 gross / $0.36 net, not expressible in the current config schema.
3. **The $14.66 FBA-fee-refund config gap** (step 10) — real but too small
   and too uncertain to fix without guessing at intent.

Nothing was hardcoded or pattern-matched to force a specific total; every
fix in `MAPPING_FIXES.sql` is traceable to a specific config row and a
specific, measured (or explicitly zero) dollar effect.

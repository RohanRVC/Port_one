# Amazon Payments vs Settlement Reconciliation

A Go + PostgreSQL pipeline that ingests Amazon's Payments and Settlement
reports, applies config-driven mapping rules to build a shared
reconciliation key, matches the two sources against each other, and
produces an accounting-grade Excel report — plus a from-scratch
investigation of the mapping defects planted in the given configs (see
`PROGRESS.md` and `MAPPING_FIXES.sql`).

## TL;DR results

- **13,289 reconciled**, **9,377 unreconciled-payment**, **0
  unreconciled-settlement** record_refs (after fixes; before fixes it was
  13,289 / 9,379 / 0 — the two extra unreconciled ones were the Transfer
  rows, see below).
- **Tie-out to Amazon's own number.** The settlement file declares a total
  of **212,118.95** for settlement 12395580393. The Settlements column of
  the Summary sheet (Sales + Refunds + Expenses) adds up to exactly that,
  and after the fixes the Payments side of the 13,289 reconciled
  `record_ref`s also adds up to exactly **212,118.95** — every one of those
  13,289 ties to the cent (0 with a nonzero difference).
- **13 applied config fixes** plus 3 defects documented as not fixable in
  config (and 1 open question) — see `MAPPING_FIXES.sql`. Payment config
  went from 149 to 144 rows (5 dead/duplicate rows removed); settlement
  config stays at 137 rows.
- Biggest single fix: a mis-keyed `TRANSFER` rule was dumping **$231,676.27**
  of unrelated bank-transfer money into the "Amazon fees" Summary line.
  Then **$11,273.53** of promotional rebates bucketed as generic "Other"
  instead of "Promo rebates"; **$42.59** of tax on refunds that never
  reached the Refunds section; and gift-wrap-credit money that was
  invisible on the Summary sheet entirely (routed to a bucket the template
  has no line for).
- Two duplicate config keys that made matching ambiguous on 45,566 rows are
  gone (0 ambiguities after the fixes).
- What is still different between the Payments and Settlements columns of
  the Summary sheet is fully accounted for, in two parts. **(1)** The 9,377
  payment-only `record_ref`s (169,766.47) have exactly two causes, checked
  across all of them, not a sample: **6,876** (123,953.39) are *Released*
  transactions belonging to three other settlements (12370691583,
  12382593803, 12407469483) that are not in the settlement file, and
  **2,501** (45,813.08) are *Deferred* transactions with no release date,
  i.e. not yet released to any settlement. **(2)** On the reconciled
  records, three Sales lines differ by +103.78 / −103.42 / −0.36 (net
  **0.00**) because the Payments report has one combined tax column where
  the Settlement report splits the same tax across three buckets — the
  money agrees to the cent, only the bucket differs (see "Known gaps").

## Repository layout

```
cmd/reconcile/         CLI entrypoint (migrate / load-configs / ingest-data / report / all)
internal/
  normalize/            case/separator-insensitive key matching
  ingest/               CSV/TSV parsing, date & money parsing, bulk COPY writer
  mapping/              config loading, the matching engine, record_ref templating,
                         the streaming summary accumulator
  reconcile/            record_ref aggregation -> reconciliation_results
  report/               excelize-based Summary + Consolidated Data sheet generation
  dbx/                  connection pool + migration runner
migrations/0001_schema.sql   the whole schema, one file
data/                   the five input files, as given (unmodified)
output/before_fix/      report generated from the ORIGINAL configs
output/after_fix/       report generated after MAPPING_FIXES.sql
dbdump/                 schema + full small tables + a representative raw_records sample
MAPPING_FIXES.sql       every config change, one commented block per defect
PROGRESS.md             the investigation trail: what we tried, ruled out, and why
```

## Steps to run the full flow end to end

Everything runs in Docker; you don't need Go or Postgres installed locally.

```bash
# 1. start Postgres
docker compose up -d postgres

# 2. build the app image
docker compose build app

# 3. first-time setup: schema + configs + ingest + report, in one shot
docker compose run --rm app all --out output/before_fix/report.xlsx

# 4. apply the mapping fixes directly to the config tables
cat MAPPING_FIXES.sql | docker compose exec -T postgres \
  psql -U recon -d amazon_recon -v ON_ERROR_STOP=1

# 5. re-ingest (idempotent: truncates and rebuilds raw_records/summary/reconciliation
#    from the two data files using the NOW-FIXED config tables — it does NOT reload
#    the config tables from CSV again, so your fixes persist) and regenerate the report
docker compose run --rm app ingest-data
docker compose run --rm app report --out output/after_fix/report.xlsx
```

`MAPPING_FIXES.sql` is applied with plain `psql` rather than through the Go
CLI on purpose: it's meant to be reviewed as ordinary SQL against the config
tables, not baked into the program. If you re-run step 3 (or `load-configs`)
after step 4, the config tables are reloaded from the original CSVs and the
fixes are gone; re-apply step 4 to get them back.

Step 3 takes one to four minutes depending on the machine (the ingest is
the slow part) and the rest a few seconds to a minute each; there is no
interactive input anywhere in the flow.

Unit tests (no database needed): `go test ./...` if Go is installed, or
`docker run --rm -v "$PWD":/src -w /src golang:1.23-bookworm go test ./...`.

Individual subcommands (all accept `DATABASE_URL` from the environment,
already set by `docker-compose.yml` for the `app` service):

```
reconcile migrate                                              apply schema (idempotent)
reconcile load-configs   --payment-config P --settlement-config S    (re)load config tables from CSV
reconcile ingest-data    --payments P --settlements S              (re)ingest data using CURRENT config tables
reconcile report         --out PATH                                 generate the .xlsx from current DB state
reconcile all            (all of the above, in order, first-time setup)
```

`ingest-data` always `TRUNCATE`s `raw_records`, `summary_totals`,
`config_match_ambiguities`, and `reconciliation_results` before rebuilding
them — re-running it is always safe and always reflects exactly the
current state of the two data files and the two config tables (idempotent
re-ingestion, no dependence on run history).

If you have Go installed locally and just want to point at the
docker-compose Postgres directly instead of building the app image:
```bash
export DATABASE_URL="postgres://recon:recon@localhost:5455/amazon_recon?sslmode=disable"
go run ./cmd/reconcile all
```

## Schema — what I went with and why

**Everything ingested from the two source files lands in one table,
`raw_records`** (per the assignment's explicit instruction), at the
granularity of **one row per amount component** — not one row per source
file line. That distinction matters: a settlement TSV row already *is* one
amount component (amount-type/amount-description/amount), but a payments
CSV row is a wide row with up to 11 typed dollar columns. Ingestion
explodes each payments row into one component row per amount column (see
"Ingestion: exploding the payments report" below), so both sources end up
at the same grain and can share one table's columns meaningfully:

```
raw_records
  id, source_type ('payment'|'settlement'), source_file, source_line   -- traceability
  raw_payload JSONB                                                     -- the ENTIRE original row, verbatim
  transaction_type, description, amount_type, amount_description,
  amount_field, amount NUMERIC(18,2)                                    -- the matching/business fields
  order_id, sku, settlement_id, shipment_id, merchant_order_id, txn_date
  record_ref, matched_config_id, matched_config_source,
  summary_field, match_ambiguous                                        -- resolved by the mapping engine
```

Every row keeps `raw_payload` (the full original row as JSON, every column,
untouched) plus `source_file`/`source_line`. That's the traceability the
assignment asks for: any number in the report can be traced to
`raw_records` by `record_ref`, then to the exact source file and line
number, then to the exact original row content — no lossy transformation
ever discards the source data, even for rows that don't end up mattering to
any total (see "What counts toward reconciliation" below for which rows
those are and why they're still ingested).

`description`/`amount_type`/`amount_description`/`amount_field` are
deliberately kept as separate nullable columns rather than generic
"key2"/"key3" columns, even though structurally payments and settlements
use them in analogous roles — self-documenting columns matter more here
than DRY-ing out four fields that mean different things on each side.

**Mapping configs get their own two tables** (the assignment says "tables",
plural, is fine — a payments row's schema and a settlement row's schema
genuinely differ, so one table per source keeps each self-describing):
`payment_mapping_configs` and `settlement_mapping_configs`, columns
matching the CSVs 1:1 plus a `source_line` (the CSV's own 1-indexed line
number, header included) so `MAPPING_FIXES.sql` can target rows precisely
and a reviewer can always find "line 65" by opening the original file in a
text editor. Fixing a mapping defect is an `UPDATE`/`DELETE` against these
tables — never a code change (see `MAPPING_FIXES.sql`).

**`summary_totals`** holds each bucket's positive and negative
contributions **separately**, not netted, one row per `(source_type,
summary_field)`. This is populated incrementally, in memory, as each row is
matched during ingestion (see "Streaming the summary calculation" below) —
not as a second pass after ingestion finishes. Keeping positive/negative
separate (rather than one net `total_amount`) turned out to be necessary,
not just cautious: a handful of summary buckets are deliberately rendered
on **two different Summary sheet lines by sign** (see "Dual-sign summary
buckets" below), which is impossible to reconstruct once positive and
negative contributions have been added together.

**`config_match_ambiguities`** exists because the matching engine doesn't
silently pick a winner when two config rows tie for the same lookup key —
it records the tie (which rows, how many times, which one it deterministically
chose) so the *pipeline itself* surfaces exactly this class of defect during
a normal run, rather than requiring a human to spot it by eye in a 150-row
CSV. This is how the two biggest duplicate-key defects in this assignment
were actually found — not by reading the config file, but by running the
pipeline and querying this table (see PROGRESS.md).

**`reconciliation_results`** is a persisted, one-row-per-`record_ref`
aggregate (payment sum, settlement sum, difference, row counts, status) —
computed by a single SQL query over `raw_records`, not held only in
application memory, so it's independently queryable/auditable and is what
both the report generator and this README's investigation queries actually
read from.

## Ingestion: exploding the payments report

The payments CSV has 25 columns per row, 11 of them typed dollar amounts
(`product sales`, `shipping credits`, `gift wrap credits`, `promotional
rebates`, `sales tax collected`, `low value goods`, `selling fees`,
`fulfilment by amazon fees`, `other transaction fees`, `other`, `total`).
The settlement TSV, by contrast, already has one row per amount component.
To make the two sources matchable at all, each payments row is exploded
into up to 11 component rows — one per dollar column — each carrying the
column's value as `amount` and the column's name (aliased — see below) as
`amount_field`, so it can be matched against the mapping config's
`amount_field` column exactly the way a settlement row's `amount_type` is.

**We ingest every component, including exact-zero ones** (253,286 = 23,026
rows × 11 columns exactly) rather than skipping zeros at explosion time.
Zero-amount components genuinely can't affect any total, but skipping them
would mean parts of the original row are simply absent from `raw_records` —
which fails the letter of "ingest the files as provided" for no real
performance benefit (308k rows ingests in seconds). Zero-valued components
still get matched against the config and get a `record_ref` computed (for
traceability), they just never get a non-null `summary_field` (see next
section) since a $0 contribution has no sign to route by.

**Amount field aliasing.** The mapping config's `amount_field` vocabulary
doesn't match the CSV headers 1:1 — most consequentially, `"fulfilment by
amazon fees"` (the CSV header) is aliased to `fba_fees` (what the config
calls it):

| CSV header | config `amount_field` |
|---|---|
| product sales | `product_sales` |
| shipping credits | `shipping_credits` |
| gift wrap credits | `gift_wrap_credits` |
| promotional rebates | `promotional_rebates` |
| sales tax collected | `sales_tax_collected` |
| low value goods | `low_value_goods` |
| selling fees | `selling_fees` |
| fulfilment by amazon fees | `fba_fees` |
| other transaction fees | `other_transaction_fees` |
| other | `other` |
| total | `total` |

This table (`internal/ingest/payments.go`, `amountColumns`) was built by
cross-referencing every distinct `amount_field` value that actually appears
in the payment config against the real CSV header — one config value,
`marketplace_withheld_tax`, has **no corresponding column at all** in this
file's schema (confirmed against the header directly, not assumed); see
`MAPPING_FIXES.sql` for why we left those three dead rules alone rather
than deleting them.

## Config matching precedence

Both config files support: an exact-match dimension that's never wildcarded
(payment: `amount_field`; settlement: `amount_type`), a
wildcard-or-exact dimension (payment: `description`; settlement:
`amount_description` — `"any"` means match anything), and a
`transaction_type` that's either an exact string or blank (blank = a
fallback/catch-all bucket that matches any transaction_type). A row is
matched by scoring every config candidate whose exact-dimension and
transaction_type/wildcard-dimension are compatible:

```
score = (2 if transaction_type matched exactly, else 0 for the blank fallback)
      + (1 if the wildcard dimension matched a literal value, else 0 for "any")
```

The highest-scoring candidate wins. **If more than one candidate ties for
the highest score, that's a config defect** (an ambiguous, duplicate
lookup key) — the engine picks the lowest `source_line` deterministically
so the pipeline still produces a number, but logs every such tie to
`config_match_ambiguities` (aggregated by which config rows actually tied,
not by the free-text value of the triggering row — see
`internal/mapping/matcher.go`). This is exactly how the two biggest
findings in this assignment were surfaced (see PROGRESS.md).

Case and separator normalization (`internal/normalize`) is applied to every
value on both sides of a comparison before matching: uppercase, then
collapse any run of spaces/hyphens/underscores into one underscore. This is
necessary because the real data and the config disagree on both dimensions
in different places — e.g. real settlement data has `"Order"`/`"ItemPrice"`
(PascalCase) against config's `"ORDER"`/`"ITEMPRICE"` (upper, no separator
at all), and `"FBA Inventory Reimbursement"` (spaces) against config's
`"FBA_INVENTORY_REIMBURSEMENT"` (underscores).

## `record_ref` construction

A template is a `+`-joined list of tokens. Seven tokens are recognized
placeholders substituted from the row's own values: `txn_ref` (→ order id
on both sides), `sku`, `settlement_id`, `shipment_id`, `merchant_order_id`,
`description`, and `date` (see below for what "date" means). **Any other
token is treated as a literal constant**, used verbatim — this is a
deliberate fallback, not an error path: both config files freely mix
literal constants (e.g. `ADJUSTMENT_OTHER`, `LOST:WAREHOUSE`) with
placeholders in the same template, and a config typo that produces an
unrecognized token (we found one — settlement config line 138's stray
`record_type` token) should degrade to a stable, still-comparable key
rather than fail the whole row closed.

**What "date" means took real investigation, not a guess.** The obvious
choice — a payments row's own `date/time` column, and a settlement row's
`posted-date` — turns out to be wrong: sampling 5,000 matched
order-id pairs across the two files, the payment side's `date/time` and the
settlement side's `posted-date` disagreed by **days to weeks**, 100% of the
time, with no pattern suggesting a timezone-only offset. The right
correspondence is the payments report's **`Transaction Release Date`**
column (not `date/time`), converted from its embedded `GMT±N` offset to
UTC, against the settlement's `posted-date`/`posted-date-time` (already
UTC): sampling the same 5,000 pairs, **80.6% matched to the exact second**,
another 3.9% matched to the same calendar day, and the remaining ~15.5%
were an artifact of the sampling method pairing a payment line against the
*wrong* settlement line for orders with multiple SKUs, not a real date
mismatch (see PROGRESS.md for the exact queries). We use `Transaction
Release Date` (payment) / `posted-date` (settlement), both normalized to a
UTC calendar date, for every `date` token.

## Aggregation across the granularity mismatch

A single (order, sku, date) key on the payments side and the same key on
the settlement side don't correspond 1:1 — a payments row's several amount
columns and a settlement order's several fee/price line items both
naturally collapse to the *same* `record_ref` under the templates given
(`txn_ref+sku+date` is shared by nearly every ORDER/REFUND rule on both
sides). We resolve this by **summing all `amount` values sharing a
`record_ref`, separately per `source_type`**, before comparing the two
sides (`internal/reconcile/reconcile.go`) — this is the one required design
decision the assignment calls out explicitly, and it's a single `GROUP BY
record_ref` with `FILTER (WHERE source_type = ...)`, not per-rule special
casing.

## What counts toward reconciliation

Only components whose config rule resolves a **non-empty** `summary_field`
for that row's actual sign participate in `reconciliation_results` and in
the Summary sheet's dollar totals — a component that matched a rule but
whose rule leaves that sign's routing blank is still ingested (full
`record_ref`, full traceability) but contributes $0 to any total. This
matters most for the payments report's own **`total`** column: it's a
per-row checksum (roughly, the sum of the row's other 10 amount columns),
not an independent transaction — every "total" `amount_field` rule in both
config files, without exception (after our fixes — see FIX 4 in
`MAPPING_FIXES.sql` for the one exception we found and fixed), routes to
nothing. Summing it in on top of its own components would silently double
every order's dollar figures. This is a design decision we made explicit
and verified empirically, not a silent hack: see PROGRESS.md for how a
violation of exactly this rule (a fallback rule that *did* route `total`
money somewhere) turned out to be the single biggest defect found.

## Dual-sign summary buckets

The Summary sheet template (`amazon_sample_output_report.xlsx`) places
three of the 22 distinct bucket names used across both configs on **two**
different lines, split by sign — the same bucket name is fed identically by
both the positive- and negative-routing columns of its config rule(s), but
the *template* wants the positive share shown under Sales/Refunds and the
negative share shown under Expenses:

| Bucket | Positive → | Negative → |
|---|---|---|
| `total_adjustment_other_buyer_recharge_amt` | Sales / Cross-account Debt Adjustment | Expenses / Cross-account Debt Adjustment |
| `bank_account_transfer_round_off` | Sales / Micro Deposit (Failed) | Expenses / Micro Deposit |
| `total_refund_expense_or_sales_amt` | Refunds / Refunded sales (added to `refunded_sales`) | Refunds / Refund expenses (added to `refunded_expenses`) |

This is why `summary_totals` keeps positive and negative contributions
separate rather than netting them at write time (`internal/report/summary.go`,
`positiveOf`/`negativeOf`/`netOf`).

## Summary sheet: bucket-to-row mapping

We reproduced `amazon_sample_output_report.xlsx`'s Summary sheet exactly —
same row numbers, same labels, same section grouping (`internal/report/summary.go`,
`summaryLayout()`) — and derived which of the 22 distinct `summary_field`
values used across both configs feeds which row by (a) grepping every
config row that produces each bucket name and (b) checking, for each
Summary sheet row label, which bucket name's semantics obviously match it.
Two rows in the given template — Sales/"FBA Fees" and Expenses/"Shipping
Charges" — have **no** bucket routed to them anywhere in either config as
currently written; they render as 0/0/0 for this dataset. Three bucket
names — `amazon_carried_forward`, `beginning_balance`,
`current_reserve_amount` — are genuine settlement-only balance-sheet
concepts (opening/closing reserve balance, payable-to-Amazon carried
forward) with **no Payments-report equivalent by nature** and **no line on
the given Summary template at all**; they're correctly routed and fully
visible in `raw_records`/Consolidated Data, just not surfaced on the
Summary sheet as given. Extending the template to include them is a report
change, not a config fix, so we didn't force it — see PROGRESS.md.

## Consolidated Data sheet

Ordered reconciled → unreconciled-payment → unreconciled-settlement, per
the spec. Rather than reproduce the sample's full ~100-column
per-bucket pivot (the sample workbook is explicitly "a structure reference,
not an answer key" for exact column layout, unlike the Summary sheet, which
the brief explicitly says to follow), we built a column set that satisfies
every column the brief lists by name: `record_ref`, `status`, `source`
(payment+settlement / payment only / settlement only), both sides'
`transaction_type`/`description`/`amount_field`/`amount_type`/
`amount_description`/`summary_field`, `sku`, `order_id`, `settlement_id`,
`date`, `payment_amount`, `settlement_amount`, `difference`, both sides'
contributing row counts, and the payment side's `transaction_status`
(Released/Deferred — this is what explains most payment-only rows at a
glance). Every value is a live join against
`raw_records`/`reconciliation_results` — nothing is precomputed or
hand-entered.

## Assumptions

- **`txn_ref` = order id** on both sides (there's no other shared
  transactional reference in either schema).
- **The `date` token uses `Transaction Release Date` (payment) / `posted-date`
  (settlement)**, both normalized to UTC — see above; this is the one
  design decision with the largest effect on match rate, and it was
  validated empirically against 5,000 real row pairs, not assumed.
- **A component whose matched rule leaves a sign's routing blank
  contributes nothing to any total** (still ingested, still traceable) —
  see "What counts toward reconciliation".
- **Reconciliation happens at `record_ref` granularity**, per the
  assignment's own wording ("Match records ... on the shared record_ref") —
  not at the finer (`record_ref`, `summary_field`) granularity. A
  `record_ref` whose payment-side money sits in one bucket and whose
  settlement-side money sits in a different one still counts as reconciled
  if the sums agree. This does happen here: it's exactly the tax case under
  "Known gaps" (all 13,289 reconciled refs tie to the cent, yet three
  Sales lines still differ by +103.78 / −103.42 / −0.36 because the same
  tax money is bucketed differently on the two sides).
- **A thousands separator (`,`) in an amount field is stripped, not
  treated as malformed input** — two real `Transfer` rows in the payments
  file are formatted `"-97,919.76"` while every other row in the file uses
  plain `"-97919.76"`.
- **Money is parsed and stored as exact cents (int64) internally**, never
  as a float, specifically to avoid the "silent rounding error" the
  assignment brief opens with — see `internal/ingest/money.go`.

## How the numbers were checked

Beyond the unit tests, the results were checked against things that don't
depend on this pipeline:

- **Amazon's own total.** The settlement TSV declares `total-amount`
  212,118.95 for its one settlement; the sum of every `amount` line in the
  same file is 212,118.95, and so is the Settlements column of the Summary
  sheet (Sales + Refunds + Expenses).
- **The `total` column is a checksum.** In the payments CSV, `total` equals
  the sum of the other ten amount columns on all 23,026 rows (0
  exceptions). That's why it's never summarized on top of its components.
- **Every payments dollar is accounted for.** Payments `total` summed over
  the file is 150,209.15; that equals the Summary's Payments net
  (381,885.42) minus the 231,676.27 of bank `Transfer` rows, which are
  deliberately not summarized. Every other transaction type
  (Order, Adjustment, Refund, Service fee, FBA fees) is 100% routed.
- **No money falls through the config.** The 831 components that matched no
  config rule at all (830 payment, 1 settlement) are all exactly zero.
- **An independent re-implementation.** A separate script that reads the raw
  files and the fixed config directly (own matching, own date and
  `record_ref` logic, no database) reproduces all 19 Summary buckets
  (positive, negative and row counts) and all 22,666 `record_ref` results
  (both amounts and status) with zero mismatches.
- **A fresh clone runs.** The steps above were run from a clean clone of
  the repository against an empty database; the regenerated reports match
  the committed ones cell for cell.

## Known gaps / things we did not force a fix for

Documented in detail, with dollar impact where measurable, in
`MAPPING_FIXES.sql`'s "NOT FIXABLE IN CONFIG" sections and in
`PROGRESS.md`:

1. Two config rules key shipment-level fees on `shipment_id`
   (settlement side) vs `txn_ref`/order id (payment side) — genuinely
   unfixable in config because the Payments CSV schema has no shipment id
   column at all. Zero impact in this run (neither fee type occurs in
   either file).
2. `PROMOTION_FEE` has a settlement-side rule but no payment-side
   equivalent (same root cause: no `merchant_order_id` column in the
   Payments CSV). Zero impact in this run.
3. **Tax bucketing on the Sales lines (net $0.00).** On the reconciled
   records, Product Charges differs by +103.78, Shipping by −103.42 and
   Other by −0.36. We traced it to the component level: the Payments
   report's single `sales tax collected` column (13,675.59) equals, to the
   cent, the settlement's Tax (13,765.71) + ShippingTax (581.68) +
   Promotion/TaxDiscount (−672.16) + GiftWrapTax (0.36), which the
   settlement config deliberately buckets into Product Charges, Shipping
   and Other respectively. The money agrees; only the bucket differs, and
   the Sales subtotal ties exactly. A flat (transaction_type, description,
   amount_field) → bucket rule can't split one payments column across
   three buckets. We could have forced the lines to match by re-bucketing
   the settlement side's tax lines into Product Charges, but that would
   override a deliberate classification purely to make a number agree, so
   we left it and documented it (`MAPPING_FIXES.sql`, FIX 5).

## Bonus: error handling, idempotency, performance

- **Idempotent re-ingestion**: `ingest-data` truncates and rebuilds
  `raw_records`/`summary_totals`/`config_match_ambiguities`/
  `reconciliation_results` from scratch every run. Checked by hashing all
  three derived tables (308,266 `raw_records` rows, `summary_totals`,
  `reconciliation_results`) before and after a second full re-ingest: the
  md5s are identical. `migrate` and `load-configs` are also safe to re-run.
- **Tests**: `go test ./...` covers money parsing (including the
  thousands-separator rows), the GMT→UTC timestamp conversion, key
  normalization, `record_ref` templating, the config-matching precedence
  and ambiguity handling, and the dual-sign Summary lines.
- **Performance**: ingesting both files (23,026 payment rows exploded to
  308,266 total components + 54,980 settlement rows, matched against 281
  config rules, bulk-loaded via `COPY`, with the summary accumulator
  flushed every 5,000 rows) takes roughly 45-70 seconds; `report`
  generation takes about 5-10 seconds; the full `all` sequence (schema +
  configs + ingest + report, from a cold database) takes roughly 1-4 minutes on a
  laptop-class container. `ingest-data` runs an explicit `ANALYZE` +
  `CHECKPOINT` right after the bulk load — without it, the report's
  join-heavy query ran immediately after a large `COPY` competed with
  Postgres's own background checkpoint I/O badly enough to turn a
  sub-second query into several minutes in this environment; settling
  both before returning avoids that entirely.
- **Error handling**: malformed CSV rows, unparseable dates, and unknown
  config placeholder tokens all degrade gracefully (skip/treat-as-literal)
  rather than crash the whole ingest; genuine data errors (e.g. an
  unparseable amount) fail loudly with the exact file and line number.

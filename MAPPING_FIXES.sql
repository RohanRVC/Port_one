-- MAPPING_FIXES.sql
--
-- Every UPDATE/DELETE below targets payment_mapping_configs /
-- settlement_mapping_configs (the tables the config CSVs were loaded into
-- by `reconcile load-configs`), keyed on source_line (the 1-indexed line
-- number in the original CSV, header included -- exactly what a reviewer
-- sees opening the file in a text editor). None of these touch raw_records,
-- reconciliation_results, or any report-generation code: every fix is a
-- data change to the mapping rules themselves, per the assignment's rule
-- that defects must be fixed in config data, not special-cased in Go.
--
-- Run against a database that already has `load-configs` applied. After
-- applying this file, re-run `ingest-data` + `report` to regenerate the
-- "after" numbers -- the mapping tables are NOT reloaded from the CSV
-- again by ingest-data, so these edits persist across re-ingestion.
--
-- Every block below states: what the rule was, what we changed it to (or
-- why we didn't), and why -- including the measured dollar impact where we
-- could compute one directly from this dataset. See PROGRESS.md for the
-- full investigation trail (queries run, hypotheses ruled out, etc.).


-- =====================================================================
-- FIX 1 — promotional_rebates routed to the wrong summary bucket
-- Impact measured in this dataset: $11,273.53 (exact)
-- =====================================================================
-- What it was: payment config line 65 routed ORDER/any/promotional_rebates
-- to `expenses_other`. Settlement's equivalent rule (ORDER/PROMOTION/PRINCIPAL
-- and ORDER/PROMOTION/SHIPPING, lines 72-73) routes to `expenses_promotional_rebates`
-- -- which is also the bucket the Summary sheet template has a dedicated
-- "Promo rebates" line for. The two sides of the same real-world event
-- (a promotional discount applied to an order) were landing in two
-- different Summary buckets.
-- What we changed it to: expenses_promotional_rebates, both signs.
-- Why: aligns the payment side with the settlement side and with the
-- Summary sheet's own line item. Verified in this dataset: before this fix,
-- "Promo rebates" showed Payments=$0.00 / Settlements=-$11,273.53; the
-- entire $11,273.53 was found sitting in the payment side's expenses_other
-- bucket for record_refs that otherwise reconciled cleanly (i.e. it's the
-- exact same money, just mis-bucketed) -- see PROGRESS.md "Promo rebates".
UPDATE payment_mapping_configs
SET summary_field_positive = 'expenses_promotional_rebates',
    summary_field_negative = 'expenses_promotional_rebates'
WHERE source_line = 65
  AND transaction_type = 'ORDER' AND amount_field = 'promotional_rebates';


-- =====================================================================
-- FIX 2 — gift_wrap_credits routed to an orphan bucket with no Summary slot
-- Impact measured in this dataset: ~$11.61-$11.97 (small, but a total loss
-- of that money from the Summary sheet, not just a misplacement -- see below)
-- =====================================================================
-- What it was: payment config line 70 routed ORDER/any/gift_wrap_credits to
-- `sales_gift_wrap_credits`. We cross-checked amazon_sample_output_report.xlsx's
-- Summary sheet row-by-row against every summary_field name used across both
-- config files: `sales_gift_wrap_credits` has NO corresponding row anywhere
-- on the Summary sheet. Every dollar routed there is silently invisible on
-- the Summary sheet (though still ingested and visible in Consolidated
-- Data / raw_records for audit). Settlement's equivalent rule
-- (ORDER/ItemPrice/GiftWrap and ORDER/ItemPrice/GiftWrapTax, lines 61 & 66)
-- routes to `sales_other`, which DOES have a Summary sheet slot ("Other",
-- under Sales).
-- What we changed it to: sales_other, both signs.
-- Why: makes the payment side consistent with the settlement side, and
-- makes this money actually appear on the Summary sheet at all. Verified:
-- before this fix, "Other" (Sales) showed Payments=$0.00 /
-- Settlements=$11.97, while the missing money sat in the now-defunct
-- sales_gift_wrap_credits bucket at $11.61 for the same reconciled
-- record_refs (the ~$0.36 gap between $11.97 and $11.61 is the
-- GiftWrapTax sub-component, which settlement tracks as a separate line
-- that also needs to land here -- already covered since both GiftWrap and
-- GiftWrapTax settlement rules route to sales_other).
UPDATE payment_mapping_configs
SET summary_field_positive = 'sales_other',
    summary_field_negative = 'sales_other'
WHERE source_line = 70
  AND transaction_type = 'ORDER' AND amount_field = 'gift_wrap_credits';


-- =====================================================================
-- FIX 3 — TRANSFER rows never match the real data, so a routine bank
-- transfer falls through to the wrong catch-all rule
-- Impact measured in this dataset: $231,676.27 (exact -- the sum of the
-- only two TRANSFER rows in the entire payments file)
-- =====================================================================
-- What it was: payment config lines 62-63 keyed TRANSFER's "total" amount_field
-- on the literal descriptions "TO_YOUR_ACCOUNT_ENDING" and "TO_ACCOUNT_ENDING".
-- The real payments data's only two Transfer rows have description literally
-- "To account ending with: 334" (the trailing digits are the seller's bank
-- account suffix and vary per transfer) -- neither config literal matches
-- this real string even after case/separator normalization (there's no
-- wildcard, prefix, or contains-match support for non-"any" description
-- values in this config, and the real string doesn't equal either literal
-- outright). Both rows are pure dead weight, and duplicate each other
-- entirely apart from that unmatchable description (identical amount_field,
-- identical record_ref template, identical -- empty -- routing).
--   Because neither matches, ingestion instead falls back to the blank-
--   transaction_type catch-all at line 110 ("",any,total,...,expenses_amazon_fees,
--   expenses_amazon_fees), which DOES have non-empty routing. That dumped
--   both real Transfer amounts (-$97,919.76 and -$133,756.51, exactly
--   -$231,676.27 combined) into "Amazon fees" under Expenses -- money that
--   has nothing to do with Amazon selling fees.
-- What we changed it to: consolidated the two dead rows into one, with
-- description = 'any' (so it matches every real-world wording Amazon has
-- used for this event, past or present) and kept the existing EMPTY
-- routing (both signs) -- which is what the config authors clearly
-- intended: every other "total" amount_field rule in this dataset,
-- without exception, is routed to nothing (it's a checksum column, not an
-- independent economic event -- see PROGRESS.md "Why the `total` column
-- is never summarized"). We are not inventing a bucket for bank transfers;
-- we're restoring the "don't summarize this" behavior the two dead rows
-- already encoded but couldn't reach.
-- Why delete rather than fix both: the two rows are 100% redundant once
-- generalized to "any" (same amount_field, same record_ref template, same
-- routing) -- keeping both would just recreate a duplicate-key ambiguity
-- (see FIX 5/6 below for why that's a problem in its own right).
DELETE FROM payment_mapping_configs
WHERE source_line = 63
  AND transaction_type = 'TRANSFER' AND description = 'TO_ACCOUNT_ENDING';

UPDATE payment_mapping_configs
SET description = 'any'
WHERE source_line = 62
  AND transaction_type = 'TRANSFER' AND description = 'TO_YOUR_ACCOUNT_ENDING';


-- =====================================================================
-- FIX 4 — the blank-transaction_type "total" catch-all is inconsistent
-- with the rest of the config, and is a latent trap for any future/other
-- transaction type this dataset doesn't happen to contain
-- =====================================================================
-- What it was: payment config line 110 (the blank-transaction_type
-- fallback bucket for amount_field=total) routes to expenses_amazon_fees
-- for BOTH signs. Every other "total" amount_field rule in both config
-- files (there are more than a dozen) routes to nothing -- "total" is a
-- per-row checksum column (roughly: the sum of a payments row's other
-- amount columns), not its own independent transaction, so summarizing it
-- on top of its own components would double-count. Line 110 is the lone
-- exception to that otherwise-universal pattern, and it exists specifically
-- to catch transaction types with NO dedicated rule at all -- exactly the
-- failure mode FIX 3 hit.
-- What we changed it to: empty routing, both signs -- consistent with
-- every other total-amount_field rule.
-- Why: this is a defense-in-depth fix, not required to close FIX 3 (FIX 3
-- already stops the Transfer rows from ever reaching this fallback). But
-- as long as this fallback keeps non-empty routing, ANY future/unknown
-- transaction_type whose "total" field is nonzero -- something this single
-- settlement period's data doesn't happen to contain, but a different
-- period could -- would silently corrupt "Amazon fees" the exact same way.
-- We confirmed (by joining raw_records to this exact config row before
-- applying this fix) that in this dataset, ONLY the two Transfer rows ever
-- hit line 110 -- so this change has zero additional effect on this run's
-- numbers beyond what FIX 3 already produces, and no regression risk.
UPDATE payment_mapping_configs
SET summary_field_positive = '',
    summary_field_negative = ''
WHERE source_line = 110
  AND transaction_type = '' AND amount_field = 'total';


-- =====================================================================
-- FIX 5 — duplicate/ambiguous config key: ORDER + sales_tax_collected
-- Impact: removes non-deterministic behavior; ~$103.78 / -$103.42 residual
-- explained but NOT closed by this fix alone (see note below)
-- =====================================================================
-- What it was: payment config lines 71 and 72 both key on the identical
-- tuple (ORDER, any, sales_tax_collected) but route to different buckets:
-- line 71 -> sales_product_charges, line 72 -> sales_shipping. A lookup on
-- this key is genuinely ambiguous -- nothing in the config schema says
-- which one should win. Our matcher resolves ties deterministically (lowest
-- source_line) and logs every such tie to config_match_ambiguities; this
-- rule alone accounted for 22,783 logged ambiguity events (once per ORDER
-- row) in this run.
-- What we changed it to: deleted line 72, keeping line 71
-- (sales_product_charges) as the sole, authoritative rule.
-- Why sales_product_charges and not sales_shipping: settlement's dominant
-- real-world equivalent for a plain sales tax line is ORDER/ItemPrice/Tax
-- -> sales_product_charges, which occurs 5,248 times in this settlement
-- file -- far more often than the shipping-tax-specific sub-type
-- (ItemWithheldTax/LowValueGoodsTax-Shipping, 50 occurrences). This also
-- matches what our matcher was already deterministically choosing, so this
-- fix changes no dollar figures in this run -- it only removes the
-- undefined, line-order-dependent behavior and makes the intent explicit.
-- What this does NOT fully close: Amazon's Payments report gives us ONE
-- combined "sales tax collected" number per order line; the Settlement
-- report sometimes splits the economically equivalent tax into a
-- product-price portion and a shipping portion (LowValueGoodsTax-Principal
-- vs -Shipping, both routed differently). Proportionally splitting a single
-- payments column across two summary buckets isn't expressible in this
-- config schema -- it only supports one flat (transaction_type,
-- description, amount_field) -> bucket mapping, not a conditional or
-- percentage split. This is the same underlying limitation as FIX 6
-- below, and together they leave a small (~$0.36 net, ~$103 gross,
-- <0.05% of either line) residual between "Product Charges" and
-- "Shipping" that we consider a genuine, documented, schema-level
-- limitation rather than an unresolved mapping defect. See PROGRESS.md.
DELETE FROM payment_mapping_configs
WHERE source_line = 72
  AND transaction_type = 'ORDER' AND amount_field = 'sales_tax_collected'
  AND summary_field_positive = 'sales_shipping';


-- =====================================================================
-- FIX 6 — duplicate/ambiguous config key: ORDER + low_value_goods
-- Impact: removes non-deterministic behavior (see FIX 5 for the same
-- underlying schema limitation this doesn't fully close)
-- =====================================================================
-- What it was: payment config lines 5 and 6 both key on the identical
-- tuple (ORDER, any, low_value_goods) but route to different buckets:
-- line 5 -> sales_shipping, line 6 -> sales_product_charges. Same defect
-- shape as FIX 5, on a different amount_field. Logged 22,783 ambiguity
-- events in this run (86 of those rows carry a nonzero amount).
-- What we changed it to: deleted line 6, keeping line 5 (sales_shipping)
-- as the sole rule -- matching what the matcher was already choosing, so
-- no dollar change in this run from this fix specifically.
-- Why we did not instead pick sales_product_charges: settlement's
-- equivalent split (ItemWithheldTax LowValueGoodsTax-Principal vs
-- -Shipping) occurs exactly 50/50 by COUNT in this dataset, but the
-- Principal portion is ~71x larger by dollar value (-$193.90 vs -$2.72) --
-- there is no clearly-dominant single bucket to collapse this into, and
-- picking either one is a real, honest approximation, not a fix. We left
-- the existing (line 5) behavior in place rather than switching it, to
-- avoid presenting a coin-flip decision as more authoritative than it is.
-- A true fix would require the Payments CSV to expose the same
-- Principal/Shipping split the Settlement report has -- a data schema
-- change on Amazon's side, not something expressible in this config.
DELETE FROM payment_mapping_configs
WHERE source_line = 6
  AND transaction_type = 'ORDER' AND amount_field = 'low_value_goods'
  AND summary_field_positive = 'sales_product_charges';


-- =====================================================================
-- FIX 7 — settlement REFUND/ItemPrice/Tax routes positive amounts
-- inconsistently with its own sibling rules
-- Impact measured in this dataset: $0.00 (see why below) -- fixed for
-- consistency/future-proofing, not because it changed today's numbers
-- =====================================================================
-- What it was: settlement config line 4 (REFUND, ITEMPRICE, TAX) routes
-- positive amounts to total_refund_expense_or_sales_amt but negative
-- amounts to refunded_expenses. Its three siblings under the same
-- transaction_type+amount_type (REFUND/ITEMPRICE: GIFTWRAP line 5,
-- GOODWILL line 6, RESTOCKINGFEE line 7) all route BOTH signs to
-- total_refund_expense_or_sales_amt.
-- What we changed it to: total_refund_expense_or_sales_amt for both signs,
-- matching its siblings.
-- Why the measured impact is $0.00 today: all 13 real occurrences of
-- REFUND/ItemPrice/Tax in this settlement file happen to be negative
-- amounts, and total_refund_expense_or_sales_amt's negative contributions
-- and refunded_expenses both ultimately land on the same Summary sheet
-- line ("Refund expenses", under Refunds) in our bucket-to-row mapping --
-- see README "Dual-sign summary buckets". So this specific dataset never
-- exercises the inconsistent (positive) branch. We fixed it anyway because
-- it's a genuine inconsistency that would misroute a positive refund-tax
-- amount if one ever occurs (to "Refunded sales" instead of a place
-- consistent with its own sibling rules).
UPDATE settlement_mapping_configs
SET summary_field_positive = 'total_refund_expense_or_sales_amt'
WHERE source_line = 4
  AND transaction_type = 'REFUND' AND amount_type = 'ITEMPRICE' AND amount_description = 'TAX';


-- =====================================================================
-- FIX 8 — malformed record_ref template: unrecognized placeholder token
-- plus a duplicated column
-- Impact measured in this dataset: $0.00 (this rule never fires against
-- either real data file -- OTHER-TRANSACTION/OTHER-TRANSACTION/
-- PROMOTION_ADJUSTMENT does not occur in this settlement file)
-- =====================================================================
-- What it was: settlement config line 138's record_ref template is
-- "ADJUSTMENT_OTHER+settlement_id+date+record_type+settlement_id".
-- "record_type" is not one of this pipeline's recognized placeholders
-- (txn_ref, sku, date, settlement_id, description, shipment_id,
-- merchant_order_id) and doesn't correspond to any column in either source
-- file -- our matching engine treats any unrecognized token as a literal
-- constant (a deliberate, documented fallback -- see
-- internal/mapping/recordref.go), so this doesn't crash, but it produces a
-- needlessly odd key with "RECORD_TYPE" embedded as literal text and
-- settlement_id duplicated. Its siblings (MISCADJUSTMENT line 28,
-- BUYERRECHARGE line 30) use the clean pattern
-- "ADJUSTMENT_OTHER+settlement_id+date" / "ADJUSTMENT_BUYER_RECHARGE+settlement_id+date".
-- What we changed it to: "ADJUSTMENT_OTHER+settlement_id+date", matching
-- its siblings' pattern exactly.
-- Why: this looks like a copy-paste error introducing a stray token that
-- was probably meant to reference a real column, never got resolved, and
-- was never caught because this transaction type/description combination
-- doesn't occur in the sample data anyone tested against. Even though it
-- doesn't affect this run's numbers, an unrecognized-token record_ref is a
-- correctness risk for any future period where PROMOTION_ADJUSTMENT does
-- occur, so we're closing it now while we can see exactly what the
-- intended pattern should be from its siblings.
UPDATE settlement_mapping_configs
SET record_ref_template = 'ADJUSTMENT_OTHER+settlement_id+date'
WHERE source_line = 138
  AND transaction_type = 'OTHER-TRANSACTION' AND amount_description = 'PROMOTION_ADJUSTMENT';


-- =====================================================================
-- FIX 9 — completely empty record_ref and routing on an otherwise
-- well-formed row
-- Impact measured in this dataset: $0.00 (does not occur in this file)
-- =====================================================================
-- What it was: settlement config line 124 is the only row in either
-- config file with an entirely blank record_ref AND blank routing for
-- both signs. Its amount_description is a full sentence -- Amazon's own
-- literal notification text about a failed bank transfer
-- ("TRANSFER_OF_FUNDS_UNSUCCESSFUL:_WE_COULD_NOT_TRANSFER_FUNDS_TO_YOUR_BANK_ACCOUNT_BECAUSE..."),
-- not a short enum token like every other row -- suggesting this row was
-- added hastily (e.g. pasted in as a placeholder while investigating a
-- support ticket) and never finished.
-- What we changed it to: gave it a record_ref
-- ("TRANSFER_OF_FUNDS_UNSUCCESSFUL+settlement_id+date", matching the
-- literal-constant pattern used by similar account-level, non-order-linked
-- events elsewhere in this config, e.g. MICRO_DEPOSIT, CURRENT_RESERVE_AMOUNT).
-- We deliberately left the summary routing EMPTY (both signs) rather than
-- guess a bucket: a failed-transfer notification is arguably not a real
-- money movement at all (it's Amazon telling the seller a transfer
-- bounced, not booking an amount), and we have no evidence for what
-- bucket, if any, it should contribute to. This is the closest thing in
-- our findings to "cannot be fixed with confidence" -- we fixed the
-- traceability half (every row can now at least be grouped/found by
-- record_ref) but explicitly did not invent a summary bucket assignment
-- with no evidentiary basis. A real fix would need input from whoever owns
-- this config on whether/how failed transfers should appear in the
-- Summary sheet at all.
UPDATE settlement_mapping_configs
SET record_ref_template = 'TRANSFER_OF_FUNDS_UNSUCCESSFUL+settlement_id+date'
WHERE source_line = 124;


-- =====================================================================
-- FIX 10 — cosmetic duplicate rows: VINE_ENROLLMENT_FEE vs VINE_ENROLMENT_FEE
-- Impact: $0.00 either way; pure cleanup
-- =====================================================================
-- What it was: payment config lines 79-80 (AMAZON_FEES, VINE_ENROLLMENT_FEE)
-- and lines 81-82 (AMAZON_FEES, VINE_ENROLMENT_FEE -- one L) are a
-- defensive duplicate covering two spellings of the same Amazon program fee.
-- "VINE_ENROLLMENT_FEE" (double-L, American spelling) is Amazon's actual,
-- documented system enum value used consistently across marketplaces
-- (including in this same config's own record_ref literal,
-- "AMAZON_FEES_VINE_ENROLLMENT_FEE", which both variants route to) --
-- the single-L "ENROLMENT" spelling in lines 81-82 does not match any
-- known Amazon API/report enum and looks like a typo that was
-- defensively duplicated rather than removed.
-- What we changed it to: deleted the misspelled duplicate (lines 81-82).
-- Both variants already routed identically, so this has zero effect on
-- output; it just removes dead-weight rows.
DELETE FROM payment_mapping_configs
WHERE source_line IN (81, 82)
  AND transaction_type = 'AMAZON_FEES' AND description = 'VINE_ENROLMENT_FEE';


-- =====================================================================
-- FIX 11 — non-ASCII character in a config key that can never match
-- real Amazon plain-text data
-- Impact: $0.00 (this ADJUSTMENT description doesn't occur in this
-- payments file)
-- =====================================================================
-- What it was: payment config lines 138-139
-- ("MULTI-CHANNEL_FULFILMENT_INVENTORY_REIMBURSEMENT_–_LOST") contain a
-- Unicode EN DASH (U+2013) where every other description in both config
-- files uses plain ASCII hyphens/underscores -- almost certainly introduced
-- by pasting from a word processor. Amazon's real report text is plain
-- ASCII, so this description could never match real data even after our
-- case/separator normalization (which only folds ASCII space/hyphen/
-- underscore).
-- What we changed it to: replaced the en dash with an ASCII underscore,
-- matching the pattern of every surrounding description
-- (MULTI-CHANNEL_FULFILMENT_INVENTORY_REIMBURSEMENT_LOST).
UPDATE payment_mapping_configs
SET description = 'MULTI-CHANNEL_FULFILMENT_INVENTORY_REIMBURSEMENT_LOST'
WHERE source_line IN (138, 139)
  AND transaction_type = 'ADJUSTMENT';


-- =====================================================================
-- FIX 12 — FEE_CORRECTION reimbursement inconsistent with every sibling
-- FBA_INVENTORY_REIMBURSEMENT_-_* rule
-- Impact: $0.00 (FEE_CORRECTION doesn't occur in this payments file)
-- =====================================================================
-- What it was: payment config line 31
-- (ADJUSTMENT/FBA_INVENTORY_REIMBURSEMENT_-_FEE_CORRECTION/other) routes
-- positive amounts to sales_other and leaves negative amounts completely
-- unrouted. Every other FBA_INVENTORY_REIMBURSEMENT_-_* sibling rule
-- (LOST:WAREHOUSE line 24, GENERAL_ADJUSTMENT line 26, CUSTOMER_RETURN
-- line 28, LOST:INBOUND line 32, DAMAGED:WAREHOUSE line 34,
-- CUSTOMER_SERVICE_ISSUE line 36, MULTI-CHANNEL...LOST line 138) routes
-- positive -> sales_inventory_reimbursements, negative ->
-- expenses_reversed_reimbursements.
-- What we changed it to: matched the sibling pattern exactly:
-- positive -> sales_inventory_reimbursements, negative ->
-- expenses_reversed_reimbursements.
UPDATE payment_mapping_configs
SET summary_field_positive = 'sales_inventory_reimbursements',
    summary_field_negative = 'expenses_reversed_reimbursements'
WHERE source_line = 31
  AND transaction_type = 'ADJUSTMENT'
  AND description = 'FBA_INVENTORY_REIMBURSEMENT_-_FEE_CORRECTION';


-- =====================================================================
-- NOT FIXABLE IN CONFIG (documented, no SQL applied) — #1
-- Cross-config record_ref placeholder mismatch: txn_ref (payment) vs
-- shipment_id (settlement) for shipment-level fees
-- =====================================================================
-- Affected rules:
--   Payment config lines 96-97 (SERVICE_FEE / FBA_INBOUND_PLACEMENT_SERVICE_FEE)
--     use txn_ref (order id) in their record_ref.
--   Settlement config line 24 (OTHER-TRANSACTION / OTHER-TRANSACTION /
--     FBA_INBOUND_PLACEMENT_SERVICE_FEE) uses shipment_id.
--   Payment config lines 83-84 (SERVICE_FEE / INBOUND_DEFECT_FEE) use txn_ref.
--   Settlement config line 49 (OTHER-TRANSACTION / INBOUND_DEFECT_FEE) uses
--     shipment_id.
-- Why this can't be fixed in the config: these are genuinely per-shipment
-- fees (one shipment can bundle multiple orders), which is exactly why the
-- settlement side correctly keys them on shipment_id. But the Payments CSV
-- schema we were given has NO shipment id column at all (confirmed against
-- the actual header: date/time, settlement ID, type, order ID, sku,
-- description, quantity, marketplace, fulfilment, order city, order state,
-- order postal, and the 11 amount columns -- no shipment id anywhere).
-- There is no column to point a payment-side txn_ref-style placeholder at
-- instead. Forcing both sides to use txn_ref would be actively wrong
-- whenever a shipment spans more than one order (it would fragment one
-- true shipment-level fee into multiple, non-matching per-order keys on
-- the settlement side, or double-count it on the payment side).
-- What would actually fix it: Amazon's Payments report would need to add a
-- shipment id column (it already reports "fulfilment" as Amazon/Merchant,
-- but not a shipment identifier). That's a source-data schema change we
-- have no control over, not a config change.
-- Real-world impact today: none measured -- neither
-- FBA_INBOUND_PLACEMENT_SERVICE_FEE nor INBOUND_DEFECT_FEE occurs in
-- either source file in this run. This is a latent defect that would only
-- surface in a period where the seller incurs one of these two specific
-- fee types.


-- =====================================================================
-- NOT FIXABLE IN CONFIG (documented, no SQL applied) — #2
-- PROMOTION_FEE has a settlement-side rule but no payment-side equivalent
-- =====================================================================
-- Affected rules: settlement config lines 90-93 (PROMOTION_FEE /
-- PROMOTIONFEE / PROMOTION_FEE(_SPECIAL), and PROMOTION_FEE / DEALS /
-- PROMOTION_FEE(_SPECIAL)) key on merchant_order_id. There is no
-- PROMOTION_FEE transaction_type rule anywhere in the payment config, and
-- the Payments CSV schema has no merchant order id column either (only
-- "order ID") -- so even if we added a payment-side rule, we could not
-- populate a matching merchant_order_id-keyed record_ref from this file.
-- What would actually fix it: same category as the previous item -- the
-- Payments report would need to expose a merchant order id column (used
-- when merchant_order_id differs from order_id, e.g. multi-channel
-- fulfillment) before a payment-side PROMOTION_FEE rule could be
-- constructed at all, let alone made to agree with the settlement side.
-- Real-world impact today: none measured -- PROMOTION_FEE and DEALS-type
-- promotion fees don't occur in either source file in this run.


-- =====================================================================
-- NOT FIXABLE / NOT NEEDED (documented, no SQL applied) — #3
-- marketplace_withheld_tax amount_field doesn't exist in this payments
-- schema
-- =====================================================================
-- Affected rules: payment config lines 13, 74, 77 (REFUND, ORDER, and
-- A-TO-Z_GUARANTEE_CLAIM respectively) all key on amount_field =
-- marketplace_withheld_tax. We confirmed against the actual payments CSV
-- header (25 columns, listed in FIX list above and in README) that no
-- column corresponds to this name under any alias. These three rules are
-- structurally dead for this file's schema, permanently, regardless of
-- data content.
-- Why we did NOT delete these rows: the payments file's own preamble
-- states "Reports with start date of 1 Jan 2025 or later ... have two new
-- columns" -- i.e. this config may be shared across multiple report
-- schema versions/date ranges, and a different export could plausibly
-- include a marketplace-withheld-tax column these rules were written for.
-- Deleting them on the strength of this one file's schema risks removing
-- something that's live for a different period. We are leaving them as
-- harmless no-ops and flagging this for the config owner to confirm.


-- =====================================================================
-- OPEN QUESTION, NOT CHANGED — FBA_TRANSACTION_FEES vs
-- FULFILMENT_BY_AMAZON_TRANSACTION_FEES
-- =====================================================================
-- Payment config has two transaction_type buckets that both appear to mean
-- "FBA transaction fees": the abbreviated FBA_TRANSACTION_FEES (lines
-- 120-127, AWD/customer-returns fees) and the spelled-out
-- FULFILMENT_BY_AMAZON_TRANSACTION_FEES (lines 140-149, removal/storage/
-- carrier fees). These are NOT case/separator variants of each other (FBA
-- vs FULFILMENT_BY_AMAZON is a different word, not a formatting
-- difference), so our normalization does not merge them, and we have no
-- way to confirm from this dataset alone whether Amazon genuinely emits
-- both as distinct "type" values or whether one of them is a stale/wrong
-- spelling. The only occurrences in this file's payments data (2 rows) use
-- the spelled-out form; the abbreviated form never appears. We are not
-- guessing at a fix here -- flagging for the config owner to confirm
-- against Amazon's own report-type documentation.

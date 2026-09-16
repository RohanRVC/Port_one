# Database dump

`raw_records` (308,266 rows after ingestion) is too large to dump in full for
a submission, so this directory has:

- `01_schema.sql` — full schema (all tables, indexes), no data.
- `02_mapping_configs_data.sql` — **full** data for `payment_mapping_configs`
  and `settlement_mapping_configs`, in their **post-fix** state (i.e. after
  `MAPPING_FIXES.sql` has been applied): 144 payment rows, 137 settlement
  rows.
- `03_summary_and_ambiguities_data.sql` — **full** data for `summary_totals`
  (the Summary sheet's source of truth) and `config_match_ambiguities`
  (empty after the fixes — see PROGRESS.md).
- `04_reconciliation_results_data.sql` — **full** data for
  `reconciliation_results` (22,666 rows: one per distinct `record_ref`).
- `05_raw_records_representative_sample.csv` — a ~1,900-row sample of
  `raw_records`: every row involved in the two biggest findings (the two
  `Transfer` rows, all nonzero `gift_wrap_credits` rows), every row that
  triggered a config-matching ambiguity in the *before-fix* run, plus a
  ~0.7% random sample across the rest of the table for general
  representativeness.

To restore into a fresh database:
```
psql -U recon -d amazon_recon -f 01_schema.sql
psql -U recon -d amazon_recon -f 02_mapping_configs_data.sql
psql -U recon -d amazon_recon -f 03_summary_and_ambiguities_data.sql
psql -U recon -d amazon_recon -f 04_reconciliation_results_data.sql
psql -U recon -d amazon_recon -c "\copy raw_records FROM '05_raw_records_representative_sample.csv' WITH (FORMAT csv, HEADER true)"
```
(`raw_records` won't have every row a full ingest would produce — it's a
sample, not the complete table — so reconciliation queries against it won't
reproduce the exact totals in `reconciliation_results`. For that, run the
actual pipeline per the root README instead.)

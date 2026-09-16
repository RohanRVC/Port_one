-- Amazon Payments vs Settlement reconciliation schema.
-- See README.md "Schema" section for the reasoning behind these choices.

CREATE TABLE IF NOT EXISTS payment_mapping_configs (
    id                      SERIAL PRIMARY KEY,
    source_line             INTEGER NOT NULL,
    transaction_type        TEXT NOT NULL DEFAULT '',
    description             TEXT NOT NULL,
    amount_field            TEXT NOT NULL,
    record_ref_template     TEXT NOT NULL,
    summary_field_positive  TEXT NOT NULL DEFAULT '',
    summary_field_negative  TEXT NOT NULL DEFAULT '',
    loaded_at               TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS settlement_mapping_configs (
    id                      SERIAL PRIMARY KEY,
    source_line             INTEGER NOT NULL,
    transaction_type        TEXT NOT NULL DEFAULT '',
    amount_type             TEXT NOT NULL,
    amount_description      TEXT NOT NULL,
    record_ref_template     TEXT NOT NULL,
    summary_field_positive  TEXT NOT NULL DEFAULT '',
    summary_field_negative  TEXT NOT NULL DEFAULT '',
    loaded_at               TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Single table for BOTH sources, at "one row per amount component" granularity
-- (a payments CSV row is exploded into one row per non-zero amount column, so
-- it lines up with the settlement file's native one-row-per-amount-component shape).
CREATE TABLE IF NOT EXISTS raw_records (
    id                      BIGSERIAL PRIMARY KEY,
    source_type             TEXT NOT NULL CHECK (source_type IN ('payment','settlement')),
    source_file             TEXT NOT NULL,
    source_line             INTEGER NOT NULL,
    raw_payload             JSONB NOT NULL,

    transaction_type        TEXT,
    description             TEXT,
    amount_type             TEXT,
    amount_description      TEXT,
    amount_field            TEXT,
    amount                  NUMERIC(18,2) NOT NULL,

    order_id                TEXT,
    sku                     TEXT,
    settlement_id           TEXT,
    shipment_id             TEXT,
    merchant_order_id       TEXT,
    txn_date                DATE,

    record_ref              TEXT,
    matched_config_id       INTEGER,
    matched_config_source   TEXT CHECK (matched_config_source IN ('payment','settlement')),
    summary_field           TEXT,
    match_ambiguous         BOOLEAN NOT NULL DEFAULT FALSE,

    created_at              TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_raw_records_record_ref   ON raw_records(record_ref);
CREATE INDEX IF NOT EXISTS idx_raw_records_source_type  ON raw_records(source_type);
CREATE INDEX IF NOT EXISTS idx_raw_records_order_id     ON raw_records(order_id);
CREATE INDEX IF NOT EXISTS idx_raw_records_settlement   ON raw_records(settlement_id);
CREATE INDEX IF NOT EXISTS idx_raw_records_payload_gin  ON raw_records USING GIN (raw_payload);
-- Supports the Consolidated Data report query's per-(record_ref, source_type)
-- "representative row" lookup (ORDER BY id LIMIT 1) as an index-only scan
-- instead of a sequential scan per one of 22k+ record_refs.
CREATE INDEX IF NOT EXISTS idx_raw_records_ref_source_id ON raw_records(record_ref, source_type, id);

-- Summary bucket totals, upserted incrementally AS EACH ROW is ingested
-- (not as a later pass) -- see internal/mapping.Accumulator. Positive and
-- negative contributions are kept separate (not netted) because a handful
-- of buckets (see README "Dual-sign summary buckets") are deliberately
-- rendered on two different Summary sheet lines by sign -- e.g. a bucket
-- fed by rules whose positive AND negative routing both point at the same
-- name still needs its positive share shown under "Sales" and its negative
-- share shown under "Expenses". Most buckets only ever populate one side.
CREATE TABLE IF NOT EXISTS summary_totals (
    source_type      TEXT NOT NULL CHECK (source_type IN ('payment','settlement')),
    summary_field    TEXT NOT NULL,
    positive_amount  NUMERIC(18,2) NOT NULL DEFAULT 0,
    negative_amount  NUMERIC(18,2) NOT NULL DEFAULT 0,
    record_count     INTEGER NOT NULL DEFAULT 0,
    PRIMARY KEY (source_type, summary_field)
);

-- Every time the matcher finds more than one config rule tied for the
-- most-specific match on a given lookup key, it records it here instead of
-- silently picking one -- this is how ambiguous/duplicate config rows (a
-- defect category called out in the assignment) surface themselves.
CREATE TABLE IF NOT EXISTS config_match_ambiguities (
    id                       SERIAL PRIMARY KEY,
    config_source            TEXT NOT NULL,
    lookup_key               TEXT NOT NULL,
    candidate_config_ids     INTEGER[] NOT NULL,
    chosen_config_id         INTEGER NOT NULL,
    occurrence_count         INTEGER NOT NULL DEFAULT 0,
    detected_at              TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (config_source, lookup_key)
);

-- Reconciliation result per record_ref, computed by aggregating raw_records.
-- Persisted (rather than computed ad-hoc at report time) purely for
-- auditability -- it's a stable, queryable artifact of "what happened".
CREATE TABLE IF NOT EXISTS reconciliation_results (
    record_ref            TEXT PRIMARY KEY,
    payment_amount         NUMERIC(18,2) NOT NULL DEFAULT 0,
    settlement_amount      NUMERIC(18,2) NOT NULL DEFAULT 0,
    difference             NUMERIC(18,2) NOT NULL DEFAULT 0,
    payment_row_count      INTEGER NOT NULL DEFAULT 0,
    settlement_row_count   INTEGER NOT NULL DEFAULT 0,
    status                 TEXT NOT NULL CHECK (status IN ('reconciled','unreconciled_payment','unreconciled_settlement')),
    computed_at             TIMESTAMPTZ NOT NULL DEFAULT now()
);

// Package reconcile aggregates raw_records by record_ref and classifies
// each key as reconciled / unreconciled_payment / unreconciled_settlement.
package reconcile

import (
	"context"

	"github.com/jackc/pgx/v5/pgxpool"
)

// Counts is the reconciled/unreconciled tally the submission checklist asks
// for explicitly.
type Counts struct {
	Reconciled             int
	UnreconciledPayment    int
	UnreconciledSettlement int
}

// Run rebuilds reconciliation_results from the current state of
// raw_records. Only rows with BOTH a record_ref and a resolved
// summary_field participate -- see README "What counts toward
// reconciliation" for why records with no summary routing (e.g. the
// payments report's own redundant "total" column) are deliberately
// excluded from the $ comparison: including them would double-count money
// already represented by its own component fields on the payments side,
// which has no settlement-side analogue, corrupting every single tie-out.
// Because a single payments row explodes into several amount components
// and a single settlement order/sku can span several settlement lines
// (different fee types), aggregation happens by SUMMING all amounts per
// (record_ref, source_type) BEFORE comparing the two sides -- this is the
// documented answer to the "granularity mismatch" the assignment calls out.
func Run(ctx context.Context, pool *pgxpool.Pool) (Counts, error) {
	tx, err := pool.Begin(ctx)
	if err != nil {
		return Counts{}, err
	}
	defer tx.Rollback(ctx)

	if _, err := tx.Exec(ctx, "TRUNCATE reconciliation_results"); err != nil {
		return Counts{}, err
	}

	_, err = tx.Exec(ctx, `
		INSERT INTO reconciliation_results
			(record_ref, payment_amount, settlement_amount, difference, payment_row_count, settlement_row_count, status)
		SELECT
			record_ref,
			COALESCE(SUM(amount) FILTER (WHERE source_type = 'payment'), 0)    AS payment_amount,
			COALESCE(SUM(amount) FILTER (WHERE source_type = 'settlement'), 0) AS settlement_amount,
			COALESCE(SUM(amount) FILTER (WHERE source_type = 'payment'), 0)
				- COALESCE(SUM(amount) FILTER (WHERE source_type = 'settlement'), 0) AS difference,
			COUNT(*) FILTER (WHERE source_type = 'payment')    AS payment_row_count,
			COUNT(*) FILTER (WHERE source_type = 'settlement') AS settlement_row_count,
			CASE
				WHEN COUNT(*) FILTER (WHERE source_type = 'payment') > 0
				 AND COUNT(*) FILTER (WHERE source_type = 'settlement') > 0 THEN 'reconciled'
				WHEN COUNT(*) FILTER (WHERE source_type = 'payment') > 0 THEN 'unreconciled_payment'
				ELSE 'unreconciled_settlement'
			END AS status
		FROM raw_records
		WHERE record_ref IS NOT NULL AND summary_field IS NOT NULL
		GROUP BY record_ref`)
	if err != nil {
		return Counts{}, err
	}

	var c Counts
	row := tx.QueryRow(ctx, `
		SELECT
			COUNT(*) FILTER (WHERE status = 'reconciled'),
			COUNT(*) FILTER (WHERE status = 'unreconciled_payment'),
			COUNT(*) FILTER (WHERE status = 'unreconciled_settlement')
		FROM reconciliation_results`)
	if err := row.Scan(&c.Reconciled, &c.UnreconciledPayment, &c.UnreconciledSettlement); err != nil {
		return Counts{}, err
	}

	return c, tx.Commit(ctx)
}

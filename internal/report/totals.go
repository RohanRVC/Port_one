package report

import (
	"context"

	"github.com/jackc/pgx/v5/pgxpool"

	"amazon-recon/internal/model"
)

// BucketTotal holds a summary bucket's positive and negative contributions
// SEPARATELY (see migrations/0001_schema.sql for why they aren't netted at
// storage time).
type BucketTotal struct {
	PositiveCents int64
	NegativeCents int64
}

// Net returns the signed sum of both contributions.
func (b BucketTotal) Net() int64 { return b.PositiveCents + b.NegativeCents }

// Totals is [source_type][summary_field] -> bucket total, in cents.
type Totals map[model.SourceType]map[string]BucketTotal

func FetchTotals(ctx context.Context, pool *pgxpool.Pool) (Totals, error) {
	rows, err := pool.Query(ctx, `SELECT source_type, summary_field, positive_amount, negative_amount FROM summary_totals`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	t := Totals{
		model.SourcePayment:    map[string]BucketTotal{},
		model.SourceSettlement: map[string]BucketTotal{},
	}
	for rows.Next() {
		var source, bucket string
		var pos, neg float64
		if err := rows.Scan(&source, &bucket, &pos, &neg); err != nil {
			return nil, err
		}
		t[model.SourceType(source)][bucket] = BucketTotal{
			PositiveCents: toCents(pos),
			NegativeCents: toCents(neg),
		}
	}
	return t, rows.Err()
}

func toCents(v float64) int64 {
	if v >= 0 {
		return int64(v*100 + 0.5)
	}
	return -int64(-v*100 + 0.5)
}

func toDollars(cents int64) float64 {
	return float64(cents) / 100.0
}

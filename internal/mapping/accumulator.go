package mapping

import (
	"context"

	"github.com/jackc/pgx/v5/pgxpool"

	"amazon-recon/internal/model"
)

type bucketKey struct {
	source model.SourceType
	bucket string
}

type bucketTotal struct {
	positiveCents int64
	negativeCents int64
	count         int
}

// Accumulator computes the Summary sheet's bucket totals INCREMENTALLY, in
// memory, as each row is matched during ingestion -- not as a separate pass
// once ingestion has finished. Call Add for every routed amount as it's
// produced, and Flush periodically (the ingest loop flushes once per
// source file) to upsert the deltas into summary_totals. This satisfies the
// assignment's "brownie points" ask: calculate the summary while the data
// is being ingested.
type Accumulator struct {
	deltas map[bucketKey]*bucketTotal
}

func NewAccumulator() *Accumulator {
	return &Accumulator{deltas: map[bucketKey]*bucketTotal{}}
}

// Add records amountCents against (source, bucket). bucket == "" means the
// amount didn't route to any summary field (e.g. the payments report's own
// "total" checksum column, or a rule whose routing for this sign is blank)
// and is silently ignored -- it was still ingested into raw_records for
// traceability, it just isn't summarized.
func (a *Accumulator) Add(source model.SourceType, bucket string, amountCents int64) {
	if bucket == "" {
		return
	}
	k := bucketKey{source, bucket}
	t := a.deltas[k]
	if t == nil {
		t = &bucketTotal{}
		a.deltas[k] = t
	}
	if amountCents > 0 {
		t.positiveCents += amountCents
	} else {
		t.negativeCents += amountCents
	}
	t.count++
}

// Flush upserts the accumulated deltas into summary_totals and clears them,
// so the next Flush only adds what's new since the last call.
func (a *Accumulator) Flush(ctx context.Context, pool *pgxpool.Pool) error {
	if len(a.deltas) == 0 {
		return nil
	}
	tx, err := pool.Begin(ctx)
	if err != nil {
		return err
	}
	defer tx.Rollback(ctx)

	for k, t := range a.deltas {
		_, err := tx.Exec(ctx, `
			INSERT INTO summary_totals (source_type, summary_field, positive_amount, negative_amount, record_count)
			VALUES ($1, $2, $3::numeric / 100.0, $4::numeric / 100.0, $5)
			ON CONFLICT (source_type, summary_field) DO UPDATE
				SET positive_amount = summary_totals.positive_amount + EXCLUDED.positive_amount,
				    negative_amount = summary_totals.negative_amount + EXCLUDED.negative_amount,
				    record_count    = summary_totals.record_count + EXCLUDED.record_count`,
			string(k.source), k.bucket, t.positiveCents, t.negativeCents, t.count)
		if err != nil {
			return err
		}
	}
	if err := tx.Commit(ctx); err != nil {
		return err
	}
	a.deltas = map[bucketKey]*bucketTotal{}
	return nil
}

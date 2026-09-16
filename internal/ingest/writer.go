package ingest

import (
	"context"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

// PreparedRow is one fully-resolved raw_records row, ready to COPY in.
// Pointer fields are nil when the column doesn't apply to this source type
// (e.g. ShipmentID is always nil for a payments-side row).
type PreparedRow struct {
	SourceType string
	SourceFile string
	SourceLine int
	RawPayload map[string]string

	TransactionType   *string
	Description       *string
	AmountType        *string
	AmountDescription *string
	AmountField       *string
	AmountCents       int64

	OrderID         *string
	SKU             *string
	SettlementID    *string
	ShipmentID      *string
	MerchantOrderID *string
	TxnDate         *time.Time

	RecordRef           *string
	MatchedConfigID     *int32
	MatchedConfigSource *string
	SummaryField        *string
	MatchAmbiguous      bool
}

var rawRecordColumns = []string{
	"source_type", "source_file", "source_line", "raw_payload",
	"transaction_type", "description", "amount_type", "amount_description", "amount_field", "amount",
	"order_id", "sku", "settlement_id", "shipment_id", "merchant_order_id", "txn_date",
	"record_ref", "matched_config_id", "matched_config_source", "summary_field", "match_ambiguous",
}

// WriteBatch bulk-loads rows into raw_records via COPY. Money is passed as
// a formatted decimal string (see FormatCents) rather than a float so
// Postgres's NUMERIC parser -- not floating point -- owns the precision.
func WriteBatch(ctx context.Context, pool *pgxpool.Pool, rows []PreparedRow) (int64, error) {
	if len(rows) == 0 {
		return 0, nil
	}
	src := pgx.CopyFromSlice(len(rows), func(i int) ([]any, error) {
		r := rows[i]
		return []any{
			r.SourceType, r.SourceFile, r.SourceLine, r.RawPayload,
			r.TransactionType, r.Description, r.AmountType, r.AmountDescription, r.AmountField, FormatCents(r.AmountCents),
			r.OrderID, r.SKU, r.SettlementID, r.ShipmentID, r.MerchantOrderID, r.TxnDate,
			r.RecordRef, r.MatchedConfigID, r.MatchedConfigSource, r.SummaryField, r.MatchAmbiguous,
		}, nil
	})
	return pool.CopyFrom(ctx, pgx.Identifier{"raw_records"}, rawRecordColumns, src)
}

func ptr[T any](v T) *T { return &v }

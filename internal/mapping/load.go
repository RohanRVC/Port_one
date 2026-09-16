package mapping

import (
	"context"
	"encoding/csv"
	"fmt"
	"os"

	"github.com/jackc/pgx/v5/pgxpool"
)

// LoadPaymentConfig truncates payment_mapping_configs and reloads it from
// the given CSV file, preserving the file's own line numbers for
// traceability (so MAPPING_FIXES.sql can refer to "payment config line N").
func LoadPaymentConfig(ctx context.Context, pool *pgxpool.Pool, path string) (int, error) {
	f, err := os.Open(path)
	if err != nil {
		return 0, fmt.Errorf("open %s: %w", path, err)
	}
	defer f.Close()

	r := csv.NewReader(f)
	r.FieldsPerRecord = -1
	rows, err := r.ReadAll()
	if err != nil {
		return 0, fmt.Errorf("parse %s: %w", path, err)
	}
	if len(rows) == 0 {
		return 0, fmt.Errorf("%s is empty", path)
	}

	tx, err := pool.Begin(ctx)
	if err != nil {
		return 0, err
	}
	defer tx.Rollback(ctx)

	if _, err := tx.Exec(ctx, "TRUNCATE payment_mapping_configs RESTART IDENTITY"); err != nil {
		return 0, err
	}

	n := 0
	for i, rec := range rows[1:] { // skip header
		lineNo := i + 2 // 1-indexed, +1 for header
		rec = padTo(rec, 6)
		_, err := tx.Exec(ctx, `
			INSERT INTO payment_mapping_configs
				(source_line, transaction_type, description, amount_field, record_ref_template, summary_field_positive, summary_field_negative)
			VALUES ($1,$2,$3,$4,$5,$6,$7)`,
			lineNo, rec[0], rec[1], rec[2], rec[3], rec[4], rec[5])
		if err != nil {
			return 0, fmt.Errorf("insert payment config line %d: %w", lineNo, err)
		}
		n++
	}
	return n, tx.Commit(ctx)
}

// LoadSettlementConfig is the settlement-config analogue of LoadPaymentConfig.
func LoadSettlementConfig(ctx context.Context, pool *pgxpool.Pool, path string) (int, error) {
	f, err := os.Open(path)
	if err != nil {
		return 0, fmt.Errorf("open %s: %w", path, err)
	}
	defer f.Close()

	r := csv.NewReader(f)
	r.FieldsPerRecord = -1
	rows, err := r.ReadAll()
	if err != nil {
		return 0, fmt.Errorf("parse %s: %w", path, err)
	}
	if len(rows) == 0 {
		return 0, fmt.Errorf("%s is empty", path)
	}

	tx, err := pool.Begin(ctx)
	if err != nil {
		return 0, err
	}
	defer tx.Rollback(ctx)

	if _, err := tx.Exec(ctx, "TRUNCATE settlement_mapping_configs RESTART IDENTITY"); err != nil {
		return 0, err
	}

	n := 0
	for i, rec := range rows[1:] {
		lineNo := i + 2
		rec = padTo(rec, 6)
		_, err := tx.Exec(ctx, `
			INSERT INTO settlement_mapping_configs
				(source_line, transaction_type, amount_type, amount_description, record_ref_template, summary_field_positive, summary_field_negative)
			VALUES ($1,$2,$3,$4,$5,$6,$7)`,
			lineNo, rec[0], rec[1], rec[2], rec[3], rec[4], rec[5])
		if err != nil {
			return 0, fmt.Errorf("insert settlement config line %d: %w", lineNo, err)
		}
		n++
	}
	return n, tx.Commit(ctx)
}

func padTo(rec []string, n int) []string {
	for len(rec) < n {
		rec = append(rec, "")
	}
	return rec
}

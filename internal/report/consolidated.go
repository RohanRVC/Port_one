package report

import (
	"context"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/xuri/excelize/v2"
)

var consolidatedHeaders = []string{
	"record_ref", "status", "source",
	"payment: transaction_type", "payment: description", "payment: amount_field", "payment: summary_field",
	"settlement: transaction_type", "settlement: amount_type", "settlement: amount_description", "settlement: summary_field",
	"sku", "order_id", "settlement_id", "date",
	"payment_amount", "settlement_amount", "difference",
	"payment_row_count", "settlement_row_count",
	"payment: transaction_status",
}

type consolidatedRow struct {
	recordRef                             string
	status                                string
	payTT, payDesc, payField, paySummary  *string
	setTT, setType, setDesc, setSummary   *string
	sku, orderID, settlementID            *string
	date                                  *time.Time
	paymentAmount, settlementAmount, diff float64
	paymentRowCount, settlementRowCount   int
	payStatus                             *string
}

// FetchConsolidatedRows joins reconciliation_results back to one
// representative raw_records row per side (per record_ref) to source the
// descriptive audit columns -- see README "Consolidated Data sheet".
// Ordered reconciled -> unreconciled payments -> unreconciled settlements,
// as the assignment specifies.
func FetchConsolidatedRows(ctx context.Context, pool *pgxpool.Pool) ([]consolidatedRow, error) {
	rows, err := pool.Query(ctx, `
		SELECT
			rr.record_ref, rr.status, rr.payment_amount, rr.settlement_amount, rr.difference,
			rr.payment_row_count, rr.settlement_row_count,
			p.transaction_type, p.description, p.amount_field, p.summary_field,
			s.transaction_type, s.amount_type, s.amount_description, s.summary_field,
			COALESCE(p.sku, s.sku), COALESCE(p.order_id, s.order_id), COALESCE(p.settlement_id, s.settlement_id),
			COALESCE(p.txn_date, s.txn_date),
				p.raw_payload->>'Transaction status'
		FROM reconciliation_results rr
		LEFT JOIN LATERAL (
			-- Prefer a component that actually routed to a summary bucket over one
			-- that didn't (e.g. a record_ref can have both a routed "total" component
			-- and an unrouted "other_transaction_fees" component; showing the latter's
			-- description next to the former's dollar amount would be misleading).
			SELECT * FROM raw_records WHERE record_ref = rr.record_ref AND source_type = 'payment'
			ORDER BY (summary_field IS NULL), id LIMIT 1
		) p ON true
		LEFT JOIN LATERAL (
			SELECT * FROM raw_records WHERE record_ref = rr.record_ref AND source_type = 'settlement'
			ORDER BY (summary_field IS NULL), id LIMIT 1
		) s ON true
		ORDER BY
			CASE rr.status WHEN 'reconciled' THEN 0 WHEN 'unreconciled_payment' THEN 1 ELSE 2 END,
			rr.record_ref`)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var out []consolidatedRow
	for rows.Next() {
		var r consolidatedRow
		if err := rows.Scan(
			&r.recordRef, &r.status, &r.paymentAmount, &r.settlementAmount, &r.diff,
			&r.paymentRowCount, &r.settlementRowCount,
			&r.payTT, &r.payDesc, &r.payField, &r.paySummary,
			&r.setTT, &r.setType, &r.setDesc, &r.setSummary,
			&r.sku, &r.orderID, &r.settlementID, &r.date, &r.payStatus,
		); err != nil {
			return nil, err
		}
		out = append(out, r)
	}
	return out, rows.Err()
}

func WriteConsolidatedSheet(f *excelize.File, rows []consolidatedRow) error {
	const sheet = "Consolidated Data"
	if _, err := f.NewSheet(sheet); err != nil {
		return err
	}

	bold, _ := f.NewStyle(&excelize.Style{Font: &excelize.Font{Bold: true}})
	money, _ := f.NewStyle(&excelize.Style{NumFmt: 4})

	for i, h := range consolidatedHeaders {
		cell, _ := excelize.CoordinatesToCellName(i+1, 1)
		f.SetCellValue(sheet, cell, h)
	}
	lastCol, _ := excelize.CoordinatesToCellName(len(consolidatedHeaders), 1)
	f.SetCellStyle(sheet, "A1", lastCol, bold)

	source := func(r consolidatedRow) string {
		switch r.status {
		case "reconciled":
			return "payment+settlement"
		case "unreconciled_payment":
			return "payment only"
		default:
			return "settlement only"
		}
	}

	for i, r := range rows {
		row := i + 2
		vals := []any{
			r.recordRef, r.status, source(r),
			deref(r.payTT), deref(r.payDesc), deref(r.payField), deref(r.paySummary),
			deref(r.setTT), deref(r.setType), deref(r.setDesc), deref(r.setSummary),
			deref(r.sku), deref(r.orderID), deref(r.settlementID), dateStr(r.date),
			r.paymentAmount, r.settlementAmount, r.diff,
			r.paymentRowCount, r.settlementRowCount,
			deref(r.payStatus),
		}
		for c, v := range vals {
			cell, _ := excelize.CoordinatesToCellName(c+1, row)
			f.SetCellValue(sheet, cell, v)
		}
		amtStart, _ := excelize.CoordinatesToCellName(16, row)
		amtEnd, _ := excelize.CoordinatesToCellName(18, row)
		f.SetCellStyle(sheet, amtStart, amtEnd, money)
	}

	for i := range consolidatedHeaders {
		col, _ := excelize.ColumnNumberToName(i + 1)
		f.SetColWidth(sheet, col, col, 22)
	}
	if err := f.SetPanes(sheet, &excelize.Panes{Freeze: true, Split: false, XSplit: 0, YSplit: 1, TopLeftCell: "A2", ActivePane: "bottomLeft"}); err != nil {
		return err
	}
	return nil
}

func deref(s *string) string {
	if s == nil {
		return ""
	}
	return *s
}

func dateStr(t *time.Time) string {
	if t == nil {
		return ""
	}
	return t.Format("2006-01-02")
}

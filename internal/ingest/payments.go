package ingest

import (
	"bufio"
	"context"
	"encoding/csv"
	"fmt"
	"io"
	"os"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"

	"amazon-recon/internal/mapping"
	"amazon-recon/internal/model"
)

// amountColumn is one of the payments CSV's typed dollar columns that gets
// exploded into its own amount-component row, paired with the alias name
// the mapping config uses to refer to it (amount_field).
type amountColumn struct {
	header string // exact CSV header text
	alias  string // config's amount_field name
}

// The payments report's header names don't always match the config's
// amount_field vocabulary 1:1 (most notably "fulfilment by amazon fees" ->
// "fba_fees") -- this table is the alias mapping, confirmed by
// cross-referencing every amount_field value in amazon_payment_configs_au_old.csv
// against the real CSV header (see README "Amount field aliasing").
var amountColumns = []amountColumn{
	{"product sales", "product_sales"},
	{"shipping credits", "shipping_credits"},
	{"gift wrap credits", "gift_wrap_credits"},
	{"promotional rebates", "promotional_rebates"},
	{"sales tax collected", "sales_tax_collected"},
	{"low value goods", "low_value_goods"},
	{"selling fees", "selling_fees"},
	{"fulfilment by amazon fees", "fba_fees"},
	{"other transaction fees", "other_transaction_fees"},
	{"other", "other"},
	{"total", "total"},
}

type PaymentsStats struct {
	SourceRows    int
	ComponentRows int
	ZeroValued    int // still ingested (full fidelity), just excluded from summary routing
	MatchedRows   int
	UnmatchedRows int
	AmbiguousRows int
}

const batchSize = 5000

// IngestPayments streams amazon_payments_data.csv, exploding each wide row
// into one component per non-zero amount column (see README "Ingestion:
// exploding the payments report"), matching each component against
// payment_mapping_configs, and bulk-loading the results into raw_records.
// The summary accumulator is flushed once per batch, so summary_totals is
// computed WHILE ingestion runs, not as a separate pass afterward.
func IngestPayments(ctx context.Context, pool *pgxpool.Pool, m *mapping.Matcher, acc *mapping.Accumulator, path string) (PaymentsStats, error) {
	var stats PaymentsStats

	f, err := os.Open(path)
	if err != nil {
		return stats, fmt.Errorf("open %s: %w", path, err)
	}
	defer f.Close()

	br := bufio.NewReader(f)
	stripBOM(br)

	r := csv.NewReader(br)
	r.FieldsPerRecord = -1
	r.LazyQuotes = true

	var header []string
	var colIndex map[string]int
	var amountColIdx []struct {
		idx   int
		alias string
	}
	lineNo := 0
	batch := make([]PreparedRow, 0, batchSize)

	flush := func() error {
		if len(batch) == 0 {
			return nil
		}
		if _, err := WriteBatch(ctx, pool, batch); err != nil {
			return fmt.Errorf("write payments batch ending line %d: %w", lineNo, err)
		}
		if err := acc.Flush(ctx, pool); err != nil {
			return fmt.Errorf("flush summary totals: %w", err)
		}
		batch = batch[:0]
		return nil
	}

	for {
		rec, err := r.Read()
		if err == io.EOF {
			break
		}
		if err != nil {
			return stats, fmt.Errorf("read %s line %d: %w", path, lineNo+1, err)
		}
		lineNo++

		if header == nil {
			if len(rec) > 0 && rec[0] == "date/time" {
				header = rec
				colIndex = map[string]int{}
				for i, h := range header {
					colIndex[h] = i
				}
				for _, ac := range amountColumns {
					if idx, ok := colIndex[ac.header]; ok {
						amountColIdx = append(amountColIdx, struct {
							idx   int
							alias string
						}{idx, ac.alias})
					}
				}
			}
			continue // skip preamble lines before the header
		}
		if len(rec) < len(header) {
			continue // defensive: skip any short/blank trailing line
		}
		stats.SourceRows++

		get := func(name string) string {
			if idx, ok := colIndex[name]; ok && idx < len(rec) {
				return rec[idx]
			}
			return ""
		}

		payload := make(map[string]string, len(header))
		for i, h := range header {
			if i < len(rec) {
				payload[h] = rec[i]
			}
		}

		transactionType := get("type")
		description := get("description")
		orderID := get("order ID")
		sku := get("sku")
		settlementID := get("settlement ID")

		var txnDate time.Time
		var hasTxnDate bool
		if releaseDateRaw := get("Transaction Release Date"); releaseDateRaw != "" {
			if t, err := ParsePaymentsTimestamp(releaseDateRaw); err == nil {
				txnDate = t
				hasTxnDate = true
			}
		}

		for _, ac := range amountColIdx {
			raw := rec[ac.idx]
			cents, err := ParseCents(raw)
			if err != nil {
				return stats, fmt.Errorf("%s line %d: amount field %s: %w", path, lineNo, ac.alias, err)
			}
			if cents == 0 {
				stats.ZeroValued++
			}
			stats.ComponentRows++

			comp := model.Component{
				SourceType:   model.SourcePayment,
				OrderID:      orderID,
				SKU:          sku,
				SettlementID: settlementID,
				Description:  description,
				TxnDate:      txnDate,
				HasTxnDate:   hasTxnDate,
			}

			cfg, ambiguous := m.MatchPayment(transactionType, description, ac.alias)

			row := PreparedRow{
				SourceType:      string(model.SourcePayment),
				SourceFile:      path,
				SourceLine:      lineNo,
				RawPayload:      payload,
				TransactionType: nilIfEmpty(transactionType),
				Description:     nilIfEmpty(description),
				AmountField:     ptr(ac.alias),
				AmountCents:     cents,
				OrderID:         nilIfEmpty(orderID),
				SKU:             nilIfEmpty(sku),
				SettlementID:    nilIfEmpty(settlementID),
				MatchAmbiguous:  ambiguous,
			}
			if hasTxnDate {
				row.TxnDate = &txnDate
			}

			if cfg != nil {
				id, recordRefTemplate, summaryPositive, summaryNegative := cfg.Fields()
				rr := mapping.BuildRecordRef(recordRefTemplate, comp)
				row.RecordRef = &rr
				row.MatchedConfigID = ptr(int32(id))
				row.MatchedConfigSource = ptr(string(model.SourcePayment))

				var bucket string
				switch {
				case cents > 0:
					bucket = summaryPositive
				case cents < 0:
					bucket = summaryNegative
				} // cents == 0: no bucket, contributes nothing either way
				if bucket != "" {
					row.SummaryField = ptr(bucket)
					acc.Add(model.SourcePayment, bucket, cents)
				}
				stats.MatchedRows++
				if ambiguous {
					stats.AmbiguousRows++
				}
			} else {
				stats.UnmatchedRows++
			}

			batch = append(batch, row)
			if len(batch) >= batchSize {
				if err := flush(); err != nil {
					return stats, err
				}
			}
		}
	}
	if err := flush(); err != nil {
		return stats, err
	}
	return stats, nil
}

func nilIfEmpty(s string) *string {
	if s == "" {
		return nil
	}
	return &s
}

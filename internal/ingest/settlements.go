package ingest

import (
	"bufio"
	"context"
	"encoding/csv"
	"fmt"
	"io"
	"os"

	"github.com/jackc/pgx/v5/pgxpool"

	"amazon-recon/internal/mapping"
	"amazon-recon/internal/model"
)

type SettlementsStats struct {
	SourceRows    int
	ZeroValued    int
	MatchedRows   int
	UnmatchedRows int
	AmbiguousRows int
}

// IngestSettlements streams amazon_settlements_data.txt (tab-separated, one
// row per amount component already) and bulk-loads it into raw_records,
// matched against settlement_mapping_configs. Unlike the payments file,
// settlement rows need no exploding -- they're already at the right grain.
func IngestSettlements(ctx context.Context, pool *pgxpool.Pool, m *mapping.Matcher, acc *mapping.Accumulator, path string) (SettlementsStats, error) {
	var stats SettlementsStats

	f, err := os.Open(path)
	if err != nil {
		return stats, fmt.Errorf("open %s: %w", path, err)
	}
	defer f.Close()

	br := bufio.NewReader(f)
	stripBOM(br)

	r := csv.NewReader(br)
	r.Comma = '\t'
	r.FieldsPerRecord = -1
	r.LazyQuotes = true

	var header []string
	var colIndex map[string]int
	lineNo := 0
	batch := make([]PreparedRow, 0, batchSize)

	flush := func() error {
		if len(batch) == 0 {
			return nil
		}
		if _, err := WriteBatch(ctx, pool, batch); err != nil {
			return fmt.Errorf("write settlements batch ending line %d: %w", lineNo, err)
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
			header = rec
			colIndex = map[string]int{}
			for i, h := range header {
				colIndex[h] = i
			}
			continue
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

		transactionType := get("transaction-type")
		amountType := get("amount-type")
		amountDescription := get("amount-description")
		orderID := get("order-id")
		merchantOrderID := get("merchant-order-id")
		shipmentID := get("shipment-id")
		sku := get("sku")
		settlementID := get("settlement-id")

		cents, err := ParseCents(get("amount"))
		if err != nil {
			return stats, fmt.Errorf("%s line %d: amount: %w", path, lineNo, err)
		}
		if cents == 0 {
			stats.ZeroValued++
		}

		comp := model.Component{
			SourceType:      model.SourceSettlement,
			OrderID:         orderID,
			SKU:             sku,
			SettlementID:    settlementID,
			ShipmentID:      shipmentID,
			MerchantOrderID: merchantOrderID,
		}
		if postedDate := get("posted-date"); postedDate != "" {
			if t, err := ParseSettlementDate(postedDate); err == nil {
				comp.TxnDate = t
				comp.HasTxnDate = true
			}
		}

		cfg, ambiguous := m.MatchSettlement(transactionType, amountType, amountDescription)

		row := PreparedRow{
			SourceType:        string(model.SourceSettlement),
			SourceFile:        path,
			SourceLine:        lineNo,
			RawPayload:        payload,
			TransactionType:   nilIfEmpty(transactionType),
			AmountType:        nilIfEmpty(amountType),
			AmountDescription: nilIfEmpty(amountDescription),
			AmountCents:       cents,
			OrderID:           nilIfEmpty(orderID),
			SKU:               nilIfEmpty(sku),
			SettlementID:      nilIfEmpty(settlementID),
			ShipmentID:        nilIfEmpty(shipmentID),
			MerchantOrderID:   nilIfEmpty(merchantOrderID),
			MatchAmbiguous:    ambiguous,
		}
		if comp.HasTxnDate {
			row.TxnDate = &comp.TxnDate
		}

		if cfg != nil {
			id, recordRefTemplate, summaryPositive, summaryNegative := cfg.Fields()
			rr := mapping.BuildRecordRef(recordRefTemplate, comp)
			row.RecordRef = &rr
			row.MatchedConfigID = ptr(int32(id))
			row.MatchedConfigSource = ptr(string(model.SourceSettlement))

			var bucket string
			switch {
			case cents > 0:
				bucket = summaryPositive
			case cents < 0:
				bucket = summaryNegative
			}
			if bucket != "" {
				row.SummaryField = ptr(bucket)
				acc.Add(model.SourceSettlement, bucket, cents)
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
	if err := flush(); err != nil {
		return stats, err
	}
	return stats, nil
}

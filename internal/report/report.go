package report

import (
	"context"
	"fmt"

	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/xuri/excelize/v2"
)

// Generate builds the two-sheet workbook (Summary, Consolidated Data) from
// the current database state and writes it to outPath.
func Generate(ctx context.Context, pool *pgxpool.Pool, outPath string) error {
	totals, err := FetchTotals(ctx, pool)
	if err != nil {
		return fmt.Errorf("fetch summary totals: %w", err)
	}
	rows, err := FetchConsolidatedRows(ctx, pool)
	if err != nil {
		return fmt.Errorf("fetch consolidated rows: %w", err)
	}

	f := excelize.NewFile()
	if err := WriteSummarySheet(f, totals); err != nil {
		return fmt.Errorf("write summary sheet: %w", err)
	}
	if err := WriteConsolidatedSheet(f, rows); err != nil {
		return fmt.Errorf("write consolidated sheet: %w", err)
	}
	f.DeleteSheet("Sheet1")
	f.SetActiveSheet(0)

	if err := f.SaveAs(outPath); err != nil {
		return fmt.Errorf("save %s: %w", outPath, err)
	}
	return nil
}

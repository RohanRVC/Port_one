// Command reconcile drives the Amazon Payments vs Settlement reconciliation
// pipeline: schema migration, mapping-config loading, data ingestion,
// reconciliation, and Excel report generation. See README.md for usage.
package main

import (
	"context"
	"flag"
	"fmt"
	"log"
	"os"

	"github.com/jackc/pgx/v5/pgxpool"

	"amazon-recon/internal/dbx"
	"amazon-recon/internal/ingest"
	"amazon-recon/internal/mapping"
	"amazon-recon/internal/reconcile"
	"amazon-recon/internal/report"
)

func main() {
	if len(os.Args) < 2 {
		usage()
		os.Exit(1)
	}
	cmd := os.Args[1]
	args := os.Args[2:]

	ctx := context.Background()

	switch cmd {
	case "migrate":
		runMigrate(ctx, args)
	case "load-configs":
		runLoadConfigs(ctx, args)
	case "ingest-data":
		runIngestData(ctx, args)
	case "report":
		runReport(ctx, args)
	case "all":
		runAll(ctx, args)
	default:
		usage()
		os.Exit(1)
	}
}

func usage() {
	fmt.Fprintln(os.Stderr, `usage: reconcile <command> [flags]

commands:
  migrate                                             apply database schema (idempotent)
  load-configs   --payment-config P --settlement-config S     (re)load mapping config tables from CSV
  ingest-data    --payments P --settlements S               (re)ingest raw data, using current config tables
  report         --out PATH                                  generate the Excel report from current DB state
  all            --payments --settlements --payment-config --settlement-config --out
                                                              migrate + load-configs + ingest-data + report, in order

DATABASE_URL must be set, e.g.:
  postgres://recon:recon@localhost:5433/amazon_recon?sslmode=disable`)
}

func mustPool(ctx context.Context) *pgxpool.Pool {
	pool, err := dbx.Connect(ctx)
	if err != nil {
		log.Fatalf("connect: %v", err)
	}
	return pool
}

func runMigrate(ctx context.Context, args []string) {
	fs := flag.NewFlagSet("migrate", flag.ExitOnError)
	dir := fs.String("dir", "migrations", "migrations directory")
	fs.Parse(args)

	pool := mustPool(ctx)
	defer pool.Close()
	if err := dbx.Migrate(ctx, pool, *dir); err != nil {
		log.Fatalf("migrate: %v", err)
	}
	log.Println("migrations applied")
}

func runLoadConfigs(ctx context.Context, args []string) {
	fs := flag.NewFlagSet("load-configs", flag.ExitOnError)
	paymentConfig := fs.String("payment-config", "data/amazon_payment_configs_au_old.csv", "payment mapping config CSV")
	settlementConfig := fs.String("settlement-config", "data/amazon_settlement_configs_au.csv", "settlement mapping config CSV")
	fs.Parse(args)

	pool := mustPool(ctx)
	defer pool.Close()

	n1, err := mapping.LoadPaymentConfig(ctx, pool, *paymentConfig)
	if err != nil {
		log.Fatalf("load payment config: %v", err)
	}
	n2, err := mapping.LoadSettlementConfig(ctx, pool, *settlementConfig)
	if err != nil {
		log.Fatalf("load settlement config: %v", err)
	}
	log.Printf("loaded %d payment config rows, %d settlement config rows", n1, n2)
}

func runIngestData(ctx context.Context, args []string) {
	fs := flag.NewFlagSet("ingest-data", flag.ExitOnError)
	payments := fs.String("payments", "data/amazon_payments_data.csv", "payments report CSV")
	settlements := fs.String("settlements", "data/amazon_settlements_data.txt", "settlement report TSV")
	fs.Parse(args)

	pool := mustPool(ctx)
	defer pool.Close()

	if _, err := pool.Exec(ctx, "TRUNCATE raw_records, summary_totals, config_match_ambiguities, reconciliation_results RESTART IDENTITY"); err != nil {
		log.Fatalf("truncate before re-ingest: %v", err)
	}

	m, err := mapping.Load(ctx, pool)
	if err != nil {
		log.Fatalf("load mapping configs: %v", err)
	}
	acc := mapping.NewAccumulator()

	pstats, err := ingest.IngestPayments(ctx, pool, m, acc, *payments)
	if err != nil {
		log.Fatalf("ingest payments: %v", err)
	}
	log.Printf("payments: %d source rows -> %d components (%d zero-valued), %d matched (%d ambiguous), %d unmatched",
		pstats.SourceRows, pstats.ComponentRows, pstats.ZeroValued, pstats.MatchedRows, pstats.AmbiguousRows, pstats.UnmatchedRows)

	sstats, err := ingest.IngestSettlements(ctx, pool, m, acc, *settlements)
	if err != nil {
		log.Fatalf("ingest settlements: %v", err)
	}
	log.Printf("settlements: %d rows (%d zero-valued), %d matched (%d ambiguous), %d unmatched",
		sstats.SourceRows, sstats.ZeroValued, sstats.MatchedRows, sstats.AmbiguousRows, sstats.UnmatchedRows)

	distinctAmbiguities, err := persistAmbiguities(ctx, pool, m)
	if err != nil {
		log.Fatalf("persist ambiguities: %v", err)
	}
	log.Printf("%d distinct ambiguous config lookup keys recorded in config_match_ambiguities (%d total ambiguous row-matches)",
		distinctAmbiguities, len(m.Ambiguities))

	counts, err := reconcile.Run(ctx, pool)
	if err != nil {
		log.Fatalf("reconcile: %v", err)
	}
	log.Printf("reconciliation: %d reconciled, %d unreconciled-payment, %d unreconciled-settlement",
		counts.Reconciled, counts.UnreconciledPayment, counts.UnreconciledSettlement)

	// A COPY-based bulk load this size leaves the planner without fresh
	// statistics and Postgres with a large backlog of dirty buffers; running
	// the report's join-heavy query immediately afterward (as `all` does)
	// was observed to contend with that backlog badly enough to turn a
	// sub-second query into several minutes. ANALYZE + CHECKPOINT right
	// after ingestion settles both before anything else runs.
	if _, err := pool.Exec(ctx, "ANALYZE raw_records, reconciliation_results, summary_totals"); err != nil {
		log.Fatalf("analyze: %v", err)
	}
	if _, err := pool.Exec(ctx, "CHECKPOINT"); err != nil {
		log.Fatalf("checkpoint: %v", err)
	}
}

func runReport(ctx context.Context, args []string) {
	fs := flag.NewFlagSet("report", flag.ExitOnError)
	out := fs.String("out", "output/report.xlsx", "output .xlsx path")
	fs.Parse(args)

	pool := mustPool(ctx)
	defer pool.Close()

	if err := os.MkdirAll(dirOf(*out), 0o755); err != nil {
		log.Fatalf("mkdir: %v", err)
	}
	if err := report.Generate(ctx, pool, *out); err != nil {
		log.Fatalf("generate report: %v", err)
	}
	log.Printf("report written to %s", *out)
}

func runAll(ctx context.Context, args []string) {
	fs := flag.NewFlagSet("all", flag.ExitOnError)
	payments := fs.String("payments", "data/amazon_payments_data.csv", "payments report CSV")
	settlements := fs.String("settlements", "data/amazon_settlements_data.txt", "settlement report TSV")
	paymentConfig := fs.String("payment-config", "data/amazon_payment_configs_au_old.csv", "payment mapping config CSV")
	settlementConfig := fs.String("settlement-config", "data/amazon_settlement_configs_au.csv", "settlement mapping config CSV")
	out := fs.String("out", "output/report.xlsx", "output .xlsx path")
	fs.Parse(args)

	runMigrate(ctx, nil)
	runLoadConfigs(ctx, []string{"--payment-config", *paymentConfig, "--settlement-config", *settlementConfig})
	runIngestData(ctx, []string{"--payments", *payments, "--settlements", *settlements})
	runReport(ctx, []string{"--out", *out})
}

// persistAmbiguities aggregates the (possibly very numerous -- once per
// affected row) ambiguity events the matcher recorded during ingestion by
// distinct lookup key, and upserts one row per key into
// config_match_ambiguities so the investigation can see, e.g., "this
// duplicate config key fired 9,121 times" without scanning raw_records.
func persistAmbiguities(ctx context.Context, pool *pgxpool.Pool, m *mapping.Matcher) (int, error) {
	type agg struct {
		source     string
		candidates []int32
		chosen     int32
		count      int
	}
	byKey := map[string]*agg{}
	for _, a := range m.Ambiguities {
		key := string(a.ConfigSource) + "|" + a.LookupKey
		e := byKey[key]
		if e == nil {
			ids := make([]int32, len(a.CandidateIDs))
			for i, id := range a.CandidateIDs {
				ids[i] = int32(id)
			}
			e = &agg{source: string(a.ConfigSource), candidates: ids, chosen: int32(a.ChosenID)}
			byKey[key] = e
		}
		e.count++
	}
	if len(byKey) == 0 {
		return 0, nil
	}

	tx, err := pool.Begin(ctx)
	if err != nil {
		return 0, err
	}
	defer tx.Rollback(ctx)

	for key, e := range byKey {
		lookupKey := key[len(e.source)+1:]
		_, err := tx.Exec(ctx, `
			INSERT INTO config_match_ambiguities (config_source, lookup_key, candidate_config_ids, chosen_config_id, occurrence_count)
			VALUES ($1, $2, $3, $4, $5)
			ON CONFLICT (config_source, lookup_key) DO UPDATE
				SET occurrence_count = config_match_ambiguities.occurrence_count + EXCLUDED.occurrence_count`,
			e.source, lookupKey, e.candidates, e.chosen, e.count)
		if err != nil {
			return 0, err
		}
	}
	return len(byKey), tx.Commit(ctx)
}

func dirOf(path string) string {
	for i := len(path) - 1; i >= 0; i-- {
		if path[i] == '/' || path[i] == '\\' {
			return path[:i]
		}
	}
	return "."
}

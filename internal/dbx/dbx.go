// Package dbx wires up the Postgres connection pool and applies migrations.
package dbx

import (
	"context"
	"fmt"
	"os"
	"path/filepath"
	"sort"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

// Connect opens a pool using DATABASE_URL from the environment.
//
// JIT is disabled on every connection: the report query's LATERAL joins
// have a high enough planner cost estimate to trigger Postgres's JIT
// compilation, and in this container environment JIT compilation itself
// takes minutes (observed: a query that runs in ~400ms with JIT off took
// 5+ minutes with it on, with Postgres burning CPU the whole time, not
// blocked on I/O or locks -- confirmed via pg_stat_activity). The query's
// own cost is trivial (a handful of indexed lookups over ~300k rows); JIT
// compilation overhead buys nothing here and isn't worth the risk in any
// container/virtualization environment with the same LLVM pathology.
func Connect(ctx context.Context) (*pgxpool.Pool, error) {
	url := os.Getenv("DATABASE_URL")
	if url == "" {
		return nil, fmt.Errorf("DATABASE_URL is not set")
	}
	cfg, err := pgxpool.ParseConfig(url)
	if err != nil {
		return nil, fmt.Errorf("parse DATABASE_URL: %w", err)
	}
	cfg.AfterConnect = func(ctx context.Context, conn *pgx.Conn) error {
		_, err := conn.Exec(ctx, "SET jit = off")
		return err
	}
	pool, err := pgxpool.NewWithConfig(ctx, cfg)
	if err != nil {
		return nil, fmt.Errorf("connect to postgres: %w", err)
	}
	if err := pool.Ping(ctx); err != nil {
		pool.Close()
		return nil, fmt.Errorf("ping postgres: %w", err)
	}
	return pool, nil
}

// Migrate applies every .sql file in dir, in filename order. It is
// idempotent: every statement in migrations/0001_schema.sql uses
// CREATE TABLE IF NOT EXISTS / CREATE INDEX IF NOT EXISTS, so re-running it
// is a no-op once the schema exists.
func Migrate(ctx context.Context, pool *pgxpool.Pool, dir string) error {
	entries, err := os.ReadDir(dir)
	if err != nil {
		return fmt.Errorf("read migrations dir %s: %w", dir, err)
	}
	var files []string
	for _, e := range entries {
		if !e.IsDir() && filepath.Ext(e.Name()) == ".sql" {
			files = append(files, e.Name())
		}
	}
	sort.Strings(files)
	for _, f := range files {
		body, err := os.ReadFile(filepath.Join(dir, f))
		if err != nil {
			return fmt.Errorf("read migration %s: %w", f, err)
		}
		if _, err := pool.Exec(ctx, string(body)); err != nil {
			return fmt.Errorf("apply migration %s: %w", f, err)
		}
	}
	return nil
}

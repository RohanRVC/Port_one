package mapping

import (
	"context"
	"fmt"
	"sort"

	"github.com/jackc/pgx/v5/pgxpool"

	"amazon-recon/internal/model"
	"amazon-recon/internal/normalize"
)

// candidate is the common shape both config tables reduce to for matching:
// a transaction_type (exact-or-fallback), an "exact dimension" that must
// always match precisely (amount_field for payments, amount_type for
// settlements), and a "wildcard dimension" that may be the literal "any"
// (description for payments, amount_description for settlements).
type candidate struct {
	id                   int
	sourceLine           int
	transactionType      string
	wildcardDim          string
	recordRefTemplate    string
	summaryFieldPositive string
	summaryFieldNegative string
}

// Ambiguity is recorded whenever more than one config row ties for the
// most-specific match on a lookup key -- see config_match_ambiguities.
type Ambiguity struct {
	ConfigSource model.SourceType
	LookupKey    string
	CandidateIDs []int
	ChosenID     int
}

// Matcher resolves ingested components to a config row using the priority
// rules documented in README.md ("Config matching precedence"):
//  1. exact transaction_type + exact wildcard-dimension value
//  2. exact transaction_type + wildcard ("any")
//  3. fallback (blank) transaction_type + wildcard ("any")
//
// The exact-dimension (amount_field / amount_type) is always required to
// match exactly; it is never wildcarded in either config file.
type Matcher struct {
	paymentByExactDim    map[string][]candidate
	settlementByExactDim map[string][]candidate

	Ambiguities []Ambiguity
}

// Load reads both config tables into memory and builds the lookup indices.
// Config files are tiny (~150 rows each) so this is a one-time, negligible cost.
func Load(ctx context.Context, pool *pgxpool.Pool) (*Matcher, error) {
	m := &Matcher{
		paymentByExactDim:    map[string][]candidate{},
		settlementByExactDim: map[string][]candidate{},
	}

	prows, err := pool.Query(ctx, `SELECT id, source_line, transaction_type, description, amount_field, record_ref_template, summary_field_positive, summary_field_negative FROM payment_mapping_configs`)
	if err != nil {
		return nil, fmt.Errorf("load payment configs: %w", err)
	}
	for prows.Next() {
		var c candidate
		var amountField string
		if err := prows.Scan(&c.id, &c.sourceLine, &c.transactionType, &c.wildcardDim, &amountField, &c.recordRefTemplate, &c.summaryFieldPositive, &c.summaryFieldNegative); err != nil {
			prows.Close()
			return nil, err
		}
		key := normalize.Key(amountField)
		m.paymentByExactDim[key] = append(m.paymentByExactDim[key], c)
	}
	prows.Close()
	if err := prows.Err(); err != nil {
		return nil, err
	}

	srows, err := pool.Query(ctx, `SELECT id, source_line, transaction_type, amount_type, amount_description, record_ref_template, summary_field_positive, summary_field_negative FROM settlement_mapping_configs`)
	if err != nil {
		return nil, fmt.Errorf("load settlement configs: %w", err)
	}
	for srows.Next() {
		var c candidate
		var amountType string
		if err := srows.Scan(&c.id, &c.sourceLine, &c.transactionType, &amountType, &c.wildcardDim, &c.recordRefTemplate, &c.summaryFieldPositive, &c.summaryFieldNegative); err != nil {
			srows.Close()
			return nil, err
		}
		key := normalize.Key(amountType)
		m.settlementByExactDim[key] = append(m.settlementByExactDim[key], c)
	}
	srows.Close()
	if err := srows.Err(); err != nil {
		return nil, err
	}

	return m, nil
}

// MatchPayment resolves a payments amount-component against
// payment_mapping_configs. A nil candidate means no config rule matched at
// all (the component is still ingested, just with no record_ref/summary_field).
func (m *Matcher) MatchPayment(transactionType, description, amountField string) (*candidate, bool) {
	list := m.paymentByExactDim[normalize.Key(amountField)]
	return m.resolve(model.SourcePayment, list, transactionType, description)
}

// MatchSettlement resolves a settlement amount-component against settlement_mapping_configs.
func (m *Matcher) MatchSettlement(transactionType, amountType, amountDescription string) (*candidate, bool) {
	list := m.settlementByExactDim[normalize.Key(amountType)]
	return m.resolve(model.SourceSettlement, list, transactionType, amountDescription)
}

func (m *Matcher) resolve(source model.SourceType, list []candidate, transactionType, wildcardValue string) (*candidate, bool) {
	ntt := normalize.Key(transactionType)
	nval := normalize.Key(wildcardValue)

	var best []candidate
	bestScore := -1
	for _, c := range list {
		ttExact := c.transactionType != "" && normalize.Key(c.transactionType) == ntt
		ttFallback := c.transactionType == ""
		if !ttExact && !ttFallback {
			continue
		}
		valExact := !normalize.IsWildcard(c.wildcardDim) && normalize.Key(c.wildcardDim) == nval
		valWildcard := normalize.IsWildcard(c.wildcardDim)
		if !valExact && !valWildcard {
			continue
		}
		score := 0
		if ttExact {
			score += 2
		}
		if valExact {
			score += 1
		}
		if score > bestScore {
			bestScore = score
			best = []candidate{c}
		} else if score == bestScore {
			best = append(best, c)
		}
	}

	if len(best) == 0 {
		return nil, false
	}
	if len(best) == 1 {
		return &best[0], false
	}

	// Ambiguous: multiple config rows tie for the most specific match.
	// Deterministically choose the lowest source_line (first-in-file) so the
	// pipeline still produces a number, but record it so it surfaces in the
	// investigation instead of being silently swallowed. The lookup key is
	// keyed on the TIED CONFIG ROWS themselves (sorted source lines), not on
	// the triggering row's free-text values -- e.g. every ORDER row's
	// "sales_tax_collected" amount ties on the exact same two config rows
	// regardless of that row's own product description, and should collapse
	// to one ambiguity entry, not one per distinct description string.
	chosen := best[0]
	ids := []int{best[0].id}
	lines := []int{best[0].sourceLine}
	for _, cnd := range best[1:] {
		ids = append(ids, cnd.id)
		lines = append(lines, cnd.sourceLine)
		if cnd.sourceLine < chosen.sourceLine {
			chosen = cnd
		}
	}
	sort.Ints(lines)
	lookupKey := fmt.Sprintf("config_lines=%v", lines)
	m.Ambiguities = append(m.Ambiguities, Ambiguity{
		ConfigSource: source,
		LookupKey:    lookupKey,
		CandidateIDs: ids,
		ChosenID:     chosen.id,
	})
	return &chosen, true
}

// Fields returns the config row's public fields (id, record_ref template,
// positive/negative summary buckets) -- candidate is kept unexported so
// callers can't construct one directly, but ingest needs to read these off
// the match result.
func (c *candidate) Fields() (id int, recordRefTemplate, summaryPositive, summaryNegative string) {
	return c.id, c.recordRefTemplate, c.summaryFieldPositive, c.summaryFieldNegative
}

// Package model holds the shared types passed between the ingest, mapping,
// and reconcile packages.
package model

import "time"

// SourceType distinguishes which of the two Amazon reports a record came from.
type SourceType string

const (
	SourcePayment    SourceType = "payment"
	SourceSettlement SourceType = "settlement"
)

// PaymentConfig is one row of amazon_payment_configs_au_old.csv.
type PaymentConfig struct {
	ID                   int
	SourceLine           int
	TransactionType      string // "" = fallback bucket
	Description          string // "any" = wildcard
	AmountField          string
	RecordRefTemplate    string
	SummaryFieldPositive string
	SummaryFieldNegative string
}

// SettlementConfig is one row of amazon_settlement_configs_au.csv.
type SettlementConfig struct {
	ID                   int
	SourceLine           int
	TransactionType      string // "" = fallback bucket
	AmountType           string
	AmountDescription    string // "any" = wildcard
	RecordRefTemplate    string
	SummaryFieldPositive string
	SummaryFieldNegative string
}

// Component is one amount-component about to be ingested: for a settlement
// row this is the row itself; for a payments row this is one non-zero
// amount column exploded out of the wide row so both sources share the same
// "one row per amount component" grain.
type Component struct {
	SourceType SourceType
	SourceFile string
	SourceLine int
	RawPayload map[string]string

	TransactionType   string
	Description       string // payments only
	AmountType        string // settlements only
	AmountDescription string // settlements only
	AmountField       string // payments only

	AmountCents int64 // signed, exact (avoids float rounding on money)

	OrderID         string
	SKU             string
	SettlementID    string
	ShipmentID      string // settlements only
	MerchantOrderID string // settlements only
	TxnDate         time.Time
	HasTxnDate      bool
}

// MatchResult is what the mapping engine resolves a Component to.
type MatchResult struct {
	RecordRef           string
	MatchedConfigID     int
	MatchedConfigSource SourceType
	SummaryField        string // "" if this amount doesn't route to any bucket
	Ambiguous           bool
}

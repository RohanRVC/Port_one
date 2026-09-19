package mapping

import (
	"strings"
	"testing"
	"time"

	"amazon-recon/internal/model"
	"amazon-recon/internal/normalize"
)

func testMatcher() *Matcher {
	return &Matcher{
		paymentByExactDim:    map[string][]candidate{},
		settlementByExactDim: map[string][]candidate{},
	}
}

func (m *Matcher) addPayment(id, line int, tt, desc, field, ref, pos, neg string) {
	k := normalize.Key(field)
	m.paymentByExactDim[k] = append(m.paymentByExactDim[k], candidate{
		id: id, sourceLine: line, transactionType: tt, wildcardDim: desc,
		recordRefTemplate: ref, summaryFieldPositive: pos, summaryFieldNegative: neg,
	})
}

func (m *Matcher) addSettlement(id, line int, tt, amountType, desc, ref, pos, neg string) {
	k := normalize.Key(amountType)
	m.settlementByExactDim[k] = append(m.settlementByExactDim[k], candidate{
		id: id, sourceLine: line, transactionType: tt, wildcardDim: desc,
		recordRefTemplate: ref, summaryFieldPositive: pos, summaryFieldNegative: neg,
	})
}

func TestMatchPrecedence(t *testing.T) {
	m := testMatcher()
	m.addPayment(1, 2, "", "any", "total", "fallback", "", "")
	m.addPayment(2, 3, "ORDER", "any", "total", "order-any", "", "")
	m.addPayment(3, 4, "ORDER", "SOME_DESC", "total", "order-exact", "", "")

	cases := []struct {
		tt, desc string
		wantID   int
	}{
		{"Order", "some desc", 3},  // exact type + exact description
		{"Order", "other text", 2}, // exact type + wildcard
		{"Refund", "some desc", 1}, // no rule for the type: blank-type fallback
		{"order", "SOME-DESC", 3},  // case and separators don't matter
	}
	for _, c := range cases {
		got, amb := m.MatchPayment(c.tt, c.desc, "total")
		if got == nil || amb {
			t.Fatalf("MatchPayment(%q,%q): got %v ambiguous=%v", c.tt, c.desc, got, amb)
		}
		if got.id != c.wantID {
			t.Errorf("MatchPayment(%q,%q) matched id %d, want %d", c.tt, c.desc, got.id, c.wantID)
		}
	}
}

func TestMatchAmountFieldIsNeverWildcarded(t *testing.T) {
	m := testMatcher()
	m.addPayment(1, 2, "ORDER", "any", "product_sales", "ref", "a", "a")
	if got, _ := m.MatchPayment("ORDER", "x", "selling_fees"); got != nil {
		t.Errorf("selling_fees should not match a product_sales rule, got id %d", got.id)
	}
}

func TestMatchSettlementNormalizesSeparators(t *testing.T) {
	m := testMatcher()
	m.addSettlement(1, 2, "OTHER-TRANSACTION", "FBA_INVENTORY_REIMBURSEMENT", "REVERSAL_REIMBURSEMENT", "r", "p", "n")
	got, amb := m.MatchSettlement("other-transaction", "FBA Inventory Reimbursement", "REVERSAL_REIMBURSEMENT")
	if got == nil || amb || got.id != 1 {
		t.Fatalf("expected clean match on id 1, got %v ambiguous=%v", got, amb)
	}
}

func TestMatchAmbiguityPicksLowestLineAndIsRecorded(t *testing.T) {
	m := testMatcher()
	m.addPayment(10, 72, "ORDER", "any", "sales_tax_collected", "r", "sales_shipping", "sales_shipping")
	m.addPayment(9, 71, "ORDER", "any", "sales_tax_collected", "r", "sales_product_charges", "sales_product_charges")

	got, amb := m.MatchPayment("Order", "whatever", "sales_tax_collected")
	if got == nil || !amb {
		t.Fatalf("expected an ambiguous match, got %v ambiguous=%v", got, amb)
	}
	if got.id != 9 {
		t.Errorf("chose id %d, want 9 (lowest source_line)", got.id)
	}
	if len(m.Ambiguities) != 1 {
		t.Fatalf("recorded %d ambiguities, want 1", len(m.Ambiguities))
	}
	if key := m.Ambiguities[0].LookupKey; !strings.Contains(key, "71") || !strings.Contains(key, "72") {
		t.Errorf("lookup key %q should name both tied config lines", key)
	}
}

func TestMatchNoRule(t *testing.T) {
	m := testMatcher()
	m.addPayment(1, 2, "ORDER", "any", "total", "r", "", "")
	if got, _ := m.MatchPayment("Refund", "x", "total"); got != nil {
		t.Errorf("no rule for REFUND should give nil, got id %d", got.id)
	}
}

func TestBuildRecordRef(t *testing.T) {
	c := model.Component{
		OrderID:         "503-8856864-4518217",
		SKU:             "BIO-S000004059_AU",
		SettlementID:    "12395580393",
		ShipmentID:      "SHIP1",
		MerchantOrderID: "M1",
		Description:     "To account ending with: 334",
		TxnDate:         time.Date(2026, time.July, 17, 0, 0, 0, 0, time.UTC),
		HasTxnDate:      true,
	}
	cases := []struct{ tmpl, want string }{
		{"txn_ref+sku+date", "503-8856864-4518217+BIO-S000004059_AU+2026-07-17"},
		{"ADJUSTMENT_OTHER+settlement_id+date", "ADJUSTMENT_OTHER+12395580393+2026-07-17"},
		{"shipment_id+INBOUND_DEFECT_FEE+settlement_id+date", "SHIP1+INBOUND_DEFECT_FEE+12395580393+2026-07-17"},
		{"merchant_order_id+settlement_id+date", "M1+12395580393+2026-07-17"},
		{"TRANSFER+description+settlement_id+date", "TRANSFER+To account ending with: 334+12395580393+2026-07-17"},
		{"GENERAL ADJUSTMENT+sku+settlement_id+date", "GENERAL ADJUSTMENT+BIO-S000004059_AU+12395580393+2026-07-17"},
		// unrecognized token is kept as a literal
		{"ADJUSTMENT_OTHER+settlement_id+date+record_type+settlement_id", "ADJUSTMENT_OTHER+12395580393+2026-07-17+record_type+12395580393"},
	}
	for _, tc := range cases {
		if got := BuildRecordRef(tc.tmpl, c); got != tc.want {
			t.Errorf("BuildRecordRef(%q) = %q, want %q", tc.tmpl, got, tc.want)
		}
	}

	c.HasTxnDate = false
	if got := BuildRecordRef("txn_ref+sku+date", c); got != "503-8856864-4518217+BIO-S000004059_AU+" {
		t.Errorf("missing date should leave an empty segment, got %q", got)
	}
}

func TestAccumulatorKeepsSignsSeparate(t *testing.T) {
	a := NewAccumulator()
	a.Add(model.SourcePayment, "sales_other", 1000)
	a.Add(model.SourcePayment, "sales_other", -250)
	a.Add(model.SourcePayment, "sales_other", 50)
	a.Add(model.SourcePayment, "", 999999) // unrouted amounts are ignored

	got := a.deltas[bucketKey{model.SourcePayment, "sales_other"}]
	if got == nil {
		t.Fatal("no bucket recorded")
	}
	if got.positiveCents != 1050 || got.negativeCents != -250 || got.count != 3 {
		t.Errorf("got %+v, want positive=1050 negative=-250 count=3", *got)
	}
	if len(a.deltas) != 1 {
		t.Errorf("unrouted amount created a bucket: %d buckets", len(a.deltas))
	}
}

package normalize

import "testing"

func TestKey(t *testing.T) {
	cases := []struct{ in, want string }{
		{"Order", "ORDER"},
		{"ItemPrice", "ITEMPRICE"},
		{"FBA Inventory Reimbursement", "FBA_INVENTORY_REIMBURSEMENT"},
		{"FBA_INVENTORY_REIMBURSEMENT", "FBA_INVENTORY_REIMBURSEMENT"},
		{"other-transaction", "OTHER_TRANSACTION"},
		{"OTHER-TRANSACTION", "OTHER_TRANSACTION"},
		{"Base fee", "BASE_FEE"},
		{"  padded  value ", "PADDED_VALUE"},
		{"a - b__c", "A_B_C"},
		{"trailing_", "TRAILING"},
		{"", ""},
	}
	for _, c := range cases {
		if got := Key(c.in); got != c.want {
			t.Errorf("Key(%q) = %q, want %q", c.in, got, c.want)
		}
	}
}

func TestIsWildcard(t *testing.T) {
	for _, v := range []string{"any", "ANY", " Any "} {
		if !IsWildcard(v) {
			t.Errorf("IsWildcard(%q) = false", v)
		}
	}
	for _, v := range []string{"", "anything", "PRINCIPAL"} {
		if IsWildcard(v) {
			t.Errorf("IsWildcard(%q) = true", v)
		}
	}
}

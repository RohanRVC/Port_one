package report

import "testing"

func lineByRow(t *testing.T, row int) summaryLine {
	t.Helper()
	for _, l := range summaryLayout() {
		if l.row == row {
			return l
		}
	}
	t.Fatalf("no summary line at row %d", row)
	return summaryLine{}
}

func TestSummaryDualSignBucketsSplitBySign(t *testing.T) {
	totals := map[string]BucketTotal{
		"total_adjustment_other_buyer_recharge_amt": {PositiveCents: 500, NegativeCents: -200},
		"bank_account_transfer_round_off":           {PositiveCents: 70, NegativeCents: -30},
	}
	checks := []struct {
		row  int
		want int64
	}{
		{10, 500},  // Sales / Cross-account Debt Adjustment: positive share only
		{26, -200}, // Expenses / Cross-account Debt Adjustment: negative share only
		{13, 70},   // Sales / Micro Deposit (Failed)
		{28, -30},  // Expenses / Micro Deposit
	}
	for _, c := range checks {
		if got := lineByRow(t, c.row).value(totals); got != c.want {
			t.Errorf("row %d = %d, want %d", c.row, got, c.want)
		}
	}
}

func TestSummaryRefundLinesCombineBuckets(t *testing.T) {
	totals := map[string]BucketTotal{
		"refunded_expenses":                 {PositiveCents: 1000, NegativeCents: -300},
		"refunded_sales":                    {NegativeCents: -5000},
		"total_refund_expense_or_sales_amt": {PositiveCents: 40, NegativeCents: -90},
	}
	// Refund expenses = net(refunded_expenses) + negative share of the either/or bucket
	if got := lineByRow(t, 16).value(totals); got != 700-90 {
		t.Errorf("Refund expenses = %d, want %d", got, 700-90)
	}
	// Refunded sales = net(refunded_sales) + positive share of the either/or bucket
	if got := lineByRow(t, 17).value(totals); got != -5000+40 {
		t.Errorf("Refunded sales = %d, want %d", got, -5000+40)
	}
}

func TestSummaryLayoutRowsAreUnique(t *testing.T) {
	seen := map[int]bool{}
	for _, l := range summaryLayout() {
		if seen[l.row] {
			t.Errorf("row %d defined twice", l.row)
		}
		seen[l.row] = true
	}
	for _, rows := range [][]int{salesChildren, refundsChildren, expensesChildren} {
		for _, r := range rows {
			if !seen[r] {
				t.Errorf("section child row %d has no summary line", r)
			}
		}
	}
}

package report

import (
	"fmt"

	"github.com/xuri/excelize/v2"

	"amazon-recon/internal/model"
)

// selector picks which slice of a bucket's totals a given Summary sheet
// line displays. Most lines net a bucket's positive and negative
// contributions together; a few deliberately split a single bucket across
// two lines by sign -- see README "Dual-sign summary buckets".
type selector func(BucketTotal) int64

func netOf(bucket string) (string, selector) {
	return bucket, func(b BucketTotal) int64 { return b.Net() }
}
func positiveOf(bucket string) (string, selector) {
	return bucket, func(b BucketTotal) int64 { return b.PositiveCents }
}
func negativeOf(bucket string) (string, selector) {
	return bucket, func(b BucketTotal) int64 { return b.NegativeCents }
}

// summaryLine is one row on the Summary sheet: a label plus zero or more
// (bucket, selector) contributions summed together to produce that row's
// value (more than one contributor only for the Refunds section, where
// total_refund_expense_or_sales_amt's split adds into the same lines as
// refunded_sales / refunded_expenses -- see README).
type summaryLine struct {
	row          int
	label        string
	isSectionTop bool // true for Sales / Refunds / Expenses: value = sum of the section's own line items
	buckets      []string
	selectors    []selector
}

func line(row int, label string, contributions ...struct {
	bucket string
	sel    selector
}) summaryLine {
	l := summaryLine{row: row, label: label}
	for _, c := range contributions {
		l.buckets = append(l.buckets, c.bucket)
		l.selectors = append(l.selectors, c.sel)
	}
	return l
}

func c(bucket string, sel selector) struct {
	bucket string
	sel    selector
} {
	return struct {
		bucket string
		sel    selector
	}{bucket, sel}
}

// summaryLayout mirrors amazon_sample_output_report.xlsx's Summary sheet
// exactly: same row numbers, same labels, same section grouping. See
// README "Summary sheet: bucket-to-row mapping" for the evidence behind
// each assignment (every bucket name was cross-referenced against the
// template's row labels and against which config rows actually produce it).
var salesChildren = []int{5, 6, 7, 8, 9, 10, 11, 12, 13}
var refundsChildren = []int{16, 17}
var expensesChildren = []int{20, 21, 22, 23, 24, 25, 26, 27, 28}

func summaryLayout() []summaryLine {
	posAdj := func() (string, selector) { return positiveOf("total_adjustment_other_buyer_recharge_amt") }
	negAdj := func() (string, selector) { return negativeOf("total_adjustment_other_buyer_recharge_amt") }
	posMicro := func() (string, selector) { return positiveOf("bank_account_transfer_round_off") }
	negMicro := func() (string, selector) { return negativeOf("bank_account_transfer_round_off") }

	b1, s1 := posAdj()
	b2, s2 := negAdj()
	b3, s3 := posMicro()
	b4, s4 := negMicro()
	b5, s5 := netOf("refunded_expenses")
	b6, s6 := negativeOf("total_refund_expense_or_sales_amt")
	b7, s7 := netOf("refunded_sales")
	b8, s8 := positiveOf("total_refund_expense_or_sales_amt")

	return []summaryLine{
		line(4, "Sales"), // section subtotal, computed as sum of children at render time
		line(5, "Product Charges", c(netOf("sales_product_charges"))),
		line(6, "Tax", c(netOf("sales_tax"))),
		line(7, "Shipping", c(netOf("sales_shipping"))),
		line(8, "Amazon fees", c(netOf("sales_amazon_fees"))),
		line(9, "Inventory Reimbursements", c(netOf("sales_inventory_reimbursements"))),
		line(10, "Cross-account Debt Adjustment", c(b1, s1)),
		line(11, "Other", c(netOf("sales_other"))),
		line(12, "FBA Fees"), // no config bucket routes here for this dataset; stays 0
		line(13, "Micro Deposit (Failed)", c(b3, s3)),

		line(15, "Refunds"),
		line(16, "Refund expenses", c(b5, s5), c(b6, s6)),
		line(17, "Refunded sales", c(b7, s7), c(b8, s8)),

		line(19, "Expenses"),
		line(20, "Promo rebates", c(netOf("expenses_promotional_rebates"))),
		line(21, "FBA fees", c(netOf("expenses_fba_fees"))),
		line(22, "Cost of Advertising", c(netOf("expenses_cost_of_advertising"))),
		line(23, "Shipping Charges"), // no config bucket routes here for this dataset; stays 0
		line(24, "Amazon fees", c(netOf("expenses_amazon_fees"))),
		line(25, "Reversed Reimbursements", c(netOf("expenses_reversed_reimbursements"))),
		line(26, "Cross-account Debt Adjustment", c(b2, s2)),
		line(27, "Other", c(netOf("expenses_other"))),
		line(28, "Micro Deposit", c(b4, s4)),

		line(32, "Paid To Amazon", c(netOf("paid_to_amazon"))),
	}
}

func (l summaryLine) value(totals map[string]BucketTotal) int64 {
	var sum int64
	for i, bucket := range l.buckets {
		sum += l.selectors[i](totals[bucket])
	}
	return sum
}

// WriteSummarySheet renders the Summary sheet into f, matching
// amazon_sample_output_report.xlsx's shape exactly.
func WriteSummarySheet(f *excelize.File, totals Totals) error {
	const sheet = "Summary"
	if _, err := f.NewSheet(sheet); err != nil {
		return err
	}

	bold, _ := f.NewStyle(&excelize.Style{Font: &excelize.Font{Bold: true}})
	money, _ := f.NewStyle(&excelize.Style{NumFmt: 4})                                       // #,##0.00
	boldMoney, _ := f.NewStyle(&excelize.Style{NumFmt: 4, Font: &excelize.Font{Bold: true}}) // section subtotal rows

	f.SetCellValue(sheet, "C1", "Payments")
	f.SetCellValue(sheet, "D1", "Settlements")
	f.SetCellValue(sheet, "E1", "Payments - Settlements")
	f.SetCellStyle(sheet, "C1", "E1", bold)

	byRow := map[int]summaryLine{}
	for _, l := range summaryLayout() {
		byRow[l.row] = l
	}

	sectionSum := func(children []int, pay bool) int64 {
		var sum int64
		for _, r := range children {
			l := byRow[r]
			totalsForSource := totals[model.SourcePayment]
			if !pay {
				totalsForSource = totals[model.SourceSettlement]
			}
			sum += l.value(totalsForSource)
		}
		return sum
	}

	for _, l := range summaryLayout() {
		rowLabel := fmt.Sprintf("B%d", l.row)
		f.SetCellValue(sheet, rowLabel, l.label)

		var payCents, settleCents int64
		switch l.row {
		case 4:
			payCents, settleCents = sectionSum(salesChildren, true), sectionSum(salesChildren, false)
		case 15:
			payCents, settleCents = sectionSum(refundsChildren, true), sectionSum(refundsChildren, false)
		case 19:
			payCents, settleCents = sectionSum(expensesChildren, true), sectionSum(expensesChildren, false)
		default:
			payCents = l.value(totals[model.SourcePayment])
			settleCents = l.value(totals[model.SourceSettlement])
		}

		payDollars, settleDollars := toDollars(payCents), toDollars(settleCents)
		diff := payDollars - settleDollars

		cRef, dRef, eRef := fmt.Sprintf("C%d", l.row), fmt.Sprintf("D%d", l.row), fmt.Sprintf("E%d", l.row)
		f.SetCellValue(sheet, cRef, payDollars)
		f.SetCellValue(sheet, dRef, settleDollars)
		f.SetCellValue(sheet, eRef, diff)

		isSectionRow := l.row == 4 || l.row == 15 || l.row == 19
		if isSectionRow {
			f.SetCellStyle(sheet, rowLabel, rowLabel, bold)
			f.SetCellStyle(sheet, cRef, eRef, boldMoney)
		} else {
			f.SetCellStyle(sheet, cRef, eRef, money)
		}
	}

	f.SetColWidth(sheet, "B", "B", 32)
	f.SetColWidth(sheet, "C", "E", 20)
	return nil
}

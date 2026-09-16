package mapping

import (
	"strings"

	"amazon-recon/internal/model"
)

// BuildRecordRef substitutes the known placeholders in a '+'-joined
// record_ref template with the component's actual values. Any token that
// isn't a recognized placeholder is treated as a literal constant and used
// verbatim -- this is a deliberate, documented fallback (see README
// "record_ref construction") rather than an error, because both config
// files consistently mix literal constants and placeholders in the same
// template, and rejecting unknown tokens outright would make one malformed
// config row (e.g. settlement config line 138's stray "record_type" token)
// fail closed instead of degrading to a stable, still-comparable key.
func BuildRecordRef(template string, c model.Component) string {
	tokens := strings.Split(template, "+")
	out := make([]string, len(tokens))
	for i, tok := range tokens {
		switch tok {
		case "txn_ref":
			out[i] = c.OrderID
		case "sku":
			out[i] = c.SKU
		case "settlement_id":
			out[i] = c.SettlementID
		case "shipment_id":
			out[i] = c.ShipmentID
		case "merchant_order_id":
			out[i] = c.MerchantOrderID
		case "description":
			out[i] = c.Description
		case "date":
			if c.HasTxnDate {
				out[i] = c.TxnDate.Format("2006-01-02")
			} else {
				out[i] = ""
			}
		default:
			out[i] = tok // literal constant, used as authored
		}
	}
	return strings.Join(out, "+")
}

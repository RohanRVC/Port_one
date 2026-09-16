// Package normalize implements the case- and separator-insensitive matching
// rules the assignment calls for: real data values like "Order"/"ItemPrice"/
// "FBA Inventory Reimbursement" must line up with config values like "ORDER"/
// "ITEMPRICE"/"FBA_INVENTORY_REIMBURSEMENT" despite differing in case and in
// whether words are separated by spaces, hyphens, or underscores.
package normalize

import "strings"

// Key uppercases s and collapses any run of spaces, hyphens, underscores or
// tabs into a single underscore, trimming a trailing underscore. It is used
// on every value taking part in a config lookup (transaction_type,
// description, amount_field, amount_type, amount_description) before
// comparison. It is deliberately NOT applied to record_ref literal segments,
// since both config files already author those literals consistently.
func Key(s string) string {
	s = strings.ToUpper(strings.TrimSpace(s))
	var b strings.Builder
	b.Grow(len(s))
	prevSep := false
	for _, r := range s {
		switch r {
		case ' ', '-', '_', '\t':
			if !prevSep && b.Len() > 0 {
				b.WriteByte('_')
				prevSep = true
			}
		default:
			b.WriteRune(r)
			prevSep = false
		}
	}
	out := b.String()
	return strings.TrimSuffix(out, "_")
}

// Wildcard is the literal sentinel both config files use to mean "matches
// any value in this column".
const Wildcard = "any"

// IsWildcard reports whether a config column value is the wildcard marker.
func IsWildcard(configValue string) bool {
	return strings.EqualFold(strings.TrimSpace(configValue), Wildcard)
}

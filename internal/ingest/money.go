package ingest

import (
	"fmt"
	"strconv"
	"strings"
)

// ParseCents converts a decimal amount string (e.g. "-3.52", "0", "") into
// signed integer cents, so all downstream arithmetic is exact instead of
// accumulating floating-point rounding error across tens of thousands of
// rows -- exactly the "silent rounding error" the assignment brief warns
// against.
func ParseCents(s string) (int64, error) {
	s = strings.TrimSpace(s)
	if s == "" {
		return 0, nil
	}
	// A handful of rows (e.g. large TRANSFER amounts) use a thousands
	// separator, e.g. "-97,919.76"; every other row doesn't. Strip it
	// rather than treating it as malformed input.
	s = strings.ReplaceAll(s, ",", "")
	neg := false
	if strings.HasPrefix(s, "-") {
		neg = true
		s = s[1:]
	} else if strings.HasPrefix(s, "+") {
		s = s[1:]
	}
	whole := s
	frac := "00"
	if i := strings.IndexByte(s, '.'); i >= 0 {
		whole = s[:i]
		frac = s[i+1:]
		if len(frac) == 0 {
			frac = "00"
		} else if len(frac) == 1 {
			frac += "0"
		} else if len(frac) > 2 {
			// Truncate rather than round on any unexpected extra precision;
			// none of the source data has more than 2 decimal places.
			frac = frac[:2]
		}
	}
	if whole == "" {
		whole = "0"
	}
	wholeVal, err := strconv.ParseInt(whole, 10, 64)
	if err != nil {
		return 0, fmt.Errorf("bad amount %q: %w", s, err)
	}
	fracVal, err := strconv.ParseInt(frac, 10, 64)
	if err != nil {
		return 0, fmt.Errorf("bad amount %q: %w", s, err)
	}
	cents := wholeVal*100 + fracVal
	if neg {
		cents = -cents
	}
	return cents, nil
}

// FormatCents renders signed cents back into a decimal string suitable for
// binding to a NUMERIC(18,2) column, e.g. -352 -> "-3.52".
func FormatCents(cents int64) string {
	neg := cents < 0
	if neg {
		cents = -cents
	}
	s := fmt.Sprintf("%d.%02d", cents/100, cents%100)
	if neg {
		s = "-" + s
	}
	return s
}

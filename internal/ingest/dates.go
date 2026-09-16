package ingest

import (
	"fmt"
	"strconv"
	"strings"
	"time"
)

var months = map[string]time.Month{
	"january": time.January, "february": time.February, "march": time.March,
	"april": time.April, "may": time.May, "june": time.June,
	"july": time.July, "august": time.August, "september": time.September,
	"october": time.October, "november": time.November, "december": time.December,
}

// ParsePaymentsTimestamp parses the payments report's
// "29 June 2026 5:39:32 pm GMT+9" style timestamp and returns it converted
// to UTC. Both the "date/time" and "Transaction Release Date" columns use
// this exact format.
func ParsePaymentsTimestamp(s string) (time.Time, error) {
	s = strings.TrimSpace(s)
	parts := strings.Fields(s)
	if len(parts) != 6 {
		return time.Time{}, fmt.Errorf("unexpected timestamp shape %q", s)
	}
	day, err := strconv.Atoi(parts[0])
	if err != nil {
		return time.Time{}, fmt.Errorf("bad day in %q: %w", s, err)
	}
	month, ok := months[strings.ToLower(parts[1])]
	if !ok {
		return time.Time{}, fmt.Errorf("bad month in %q", s)
	}
	year, err := strconv.Atoi(parts[2])
	if err != nil {
		return time.Time{}, fmt.Errorf("bad year in %q: %w", s, err)
	}
	hh, mm, ss, err := parseHMS(parts[3])
	if err != nil {
		return time.Time{}, fmt.Errorf("bad time in %q: %w", s, err)
	}
	ampm := strings.ToLower(parts[4])
	switch ampm {
	case "pm":
		if hh != 12 {
			hh += 12
		}
	case "am":
		if hh == 12 {
			hh = 0
		}
	default:
		return time.Time{}, fmt.Errorf("bad am/pm in %q", s)
	}
	tzPart := parts[5] // "GMT+9", "GMT-5", etc.
	if !strings.HasPrefix(tzPart, "GMT") {
		return time.Time{}, fmt.Errorf("bad timezone in %q", s)
	}
	offsetHours, err := strconv.Atoi(strings.TrimPrefix(tzPart, "GMT"))
	if err != nil {
		return time.Time{}, fmt.Errorf("bad timezone offset in %q: %w", s, err)
	}
	local := time.Date(year, month, day, hh, mm, ss, 0, time.UTC)
	return local.Add(-time.Duration(offsetHours) * time.Hour), nil
}

func parseHMS(s string) (int, int, int, error) {
	parts := strings.Split(s, ":")
	if len(parts) != 3 {
		return 0, 0, 0, fmt.Errorf("expected H:M:S, got %q", s)
	}
	h, err := strconv.Atoi(parts[0])
	if err != nil {
		return 0, 0, 0, err
	}
	m, err := strconv.Atoi(parts[1])
	if err != nil {
		return 0, 0, 0, err
	}
	sec, err := strconv.Atoi(parts[2])
	if err != nil {
		return 0, 0, 0, err
	}
	return h, m, sec, nil
}

// ParseSettlementDate parses the settlement report's "posted-date" column,
// formatted dd.mm.yyyy, already in UTC.
func ParseSettlementDate(s string) (time.Time, error) {
	s = strings.TrimSpace(s)
	parts := strings.Split(s, ".")
	if len(parts) != 3 {
		return time.Time{}, fmt.Errorf("unexpected date shape %q", s)
	}
	d, err := strconv.Atoi(parts[0])
	if err != nil {
		return time.Time{}, err
	}
	mo, err := strconv.Atoi(parts[1])
	if err != nil {
		return time.Time{}, err
	}
	y, err := strconv.Atoi(parts[2])
	if err != nil {
		return time.Time{}, err
	}
	return time.Date(y, time.Month(mo), d, 0, 0, 0, 0, time.UTC), nil
}

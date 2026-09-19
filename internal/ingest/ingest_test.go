package ingest

import (
	"testing"
	"time"
)

func TestParseCents(t *testing.T) {
	cases := []struct {
		in   string
		want int64
	}{
		{"", 0},
		{"0", 0},
		{"24.59", 2459},
		{"-3.52", -352},
		{"1.5", 150},
		{"7.", 700},
		{".5", 50},
		{"+2.00", 200},
		{"-97,919.76", -9791976},
		{"212118.95", 21211895},
	}
	for _, c := range cases {
		got, err := ParseCents(c.in)
		if err != nil {
			t.Errorf("ParseCents(%q) error: %v", c.in, err)
			continue
		}
		if got != c.want {
			t.Errorf("ParseCents(%q) = %d, want %d", c.in, got, c.want)
		}
	}
	if _, err := ParseCents("12.ab"); err == nil {
		t.Error("ParseCents(12.ab) should fail")
	}
}

func TestFormatCents(t *testing.T) {
	cases := map[int64]string{0: "0.00", 5: "0.05", -352: "-3.52", 21211895: "212118.95", -9791976: "-97919.76"}
	for in, want := range cases {
		if got := FormatCents(in); got != want {
			t.Errorf("FormatCents(%d) = %q, want %q", in, got, want)
		}
	}
}

func TestParsePaymentsTimestamp(t *testing.T) {
	utc := func(y int, m time.Month, d, h, mi, s int) time.Time {
		return time.Date(y, m, d, h, mi, s, 0, time.UTC)
	}
	cases := []struct {
		in   string
		want time.Time
	}{
		// this pair was checked against the settlement file: order
		// 503-8856864-4518217 posted at 17.07.2026 21:10:51 UTC
		{"18 July 2026 6:10:51 am GMT+9", utc(2026, time.July, 17, 21, 10, 51)},
		{"29 June 2026 5:39:32 pm GMT+9", utc(2026, time.June, 29, 8, 39, 32)},
		{"1 July 2026 12:05:00 am GMT+9", utc(2026, time.June, 30, 15, 5, 0)},
		{"1 July 2026 12:30:00 pm GMT-5", utc(2026, time.July, 1, 17, 30, 0)},
	}
	for _, c := range cases {
		got, err := ParsePaymentsTimestamp(c.in)
		if err != nil {
			t.Errorf("ParsePaymentsTimestamp(%q) error: %v", c.in, err)
			continue
		}
		if !got.Equal(c.want) {
			t.Errorf("ParsePaymentsTimestamp(%q) = %v, want %v", c.in, got, c.want)
		}
	}
	for _, bad := range []string{"", "not a date", "18 Smarch 2026 6:10:51 am GMT+9", "18 July 2026 6:10:51 GMT+9"} {
		if _, err := ParsePaymentsTimestamp(bad); err == nil {
			t.Errorf("ParsePaymentsTimestamp(%q) should fail", bad)
		}
	}
}

func TestParseSettlementDate(t *testing.T) {
	got, err := ParseSettlementDate("17.07.2026")
	if err != nil {
		t.Fatal(err)
	}
	if want := time.Date(2026, time.July, 17, 0, 0, 0, 0, time.UTC); !got.Equal(want) {
		t.Errorf("got %v, want %v", got, want)
	}
	if _, err := ParseSettlementDate("2026-07-17"); err == nil {
		t.Error("ISO date should not parse as dd.mm.yyyy")
	}
}

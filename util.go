package gosh

import (
	"errors"
	"fmt"
	"regexp"
	"strconv"
	"strings"
	"time"
)

// Time determination beyond days resp. weeks is a more complex issue. Due to
// months of different lengths plus additional leap years and leap seconds,
// there is no clear duration of a month. At this point the monthly average of
// the Gregorian calendar was used.
// Souce: https://www.quora.com/What-is-the-average-number-of-days-in-a-month

const (
	timeDay   time.Duration = 24 * time.Hour
	timeWeek  time.Duration = 7 * timeDay
	timeMonth time.Duration = time.Duration(30.44 * float64(timeDay))
	timeYear  time.Duration = 12 * timeMonth
)

var (
	durations = map[string]time.Duration{
		"s":  time.Second,
		"m":  time.Minute,
		"h":  time.Hour,
		"d":  timeDay,
		"w":  timeWeek,
		"mo": timeMonth,
		"y":  timeYear,
	}
	durationsOrder = []string{"y", "mo", "w", "d", "h", "m", "s"}
	durationPretty = []string{"year", "month", "week", "day", "hour", "minute", "second"}

	durationPattern *regexp.Regexp = nil

	ErrNoMatch = errors.New("Input does not match pattern")
)

// getDurationPattern compiles a regular expression to parse our duration string.
func getDurationPattern() *regexp.Regexp {
	if durationPattern != nil {
		return durationPattern
	}

	var b strings.Builder

	b.WriteString(`\A`)
	for _, durElem := range durationsOrder {
		fmt.Fprintf(&b, `((?P<%s>\d+)%s)?`, durElem, durElem)
	}
	b.WriteString(`\z`)

	durationPattern = regexp.MustCompile(b.String())
	return durationPattern
}

// ParseDuration parses a (positive) duration string, similar to the
// `time.ParseDuration` method. A duration string is sequence of decimal
// numbers and a unit suffix. Valid time units are "s", "m", "h", "d", "w",
// "mo", "y".
func ParseDuration(s string) (d time.Duration, err error) {
	pattern := getDurationPattern()
	if s == "" || !pattern.MatchString(s) {
		err = ErrNoMatch
		return
	}

	parts := pattern.FindStringSubmatch(s)
	for i, elemKey := range pattern.SubexpNames() {
		if elemKey == "" || parts[i] == "" {
			continue
		}

		if elemVal, elemErr := strconv.Atoi(parts[i]); elemErr != nil {
			err = elemErr
			return
		} else {
			d += time.Duration(elemVal) * durations[elemKey]
		}
	}

	return
}

// PrettyDuration returns a human readable representation of a time.Duration.
func PrettyDuration(d time.Duration) string {
	var b strings.Builder

	for i, elemKey := range durationsOrder {
		elemVal := durations[elemKey]
		if elemVal > d {
			continue
		}

		amount := int64(d / elemVal)
		d = d % elemVal

		fmt.Fprintf(&b, "%d %s", amount, durationPretty[i])
		if amount > 1 {
			fmt.Fprintf(&b, "s")
		}
		fmt.Fprintf(&b, " ")
	}

	return strings.TrimRight(b.String(), " ")
}

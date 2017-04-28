package custom_types

import (
	"database/sql/driver"
	"fmt"
	"strings"
	"time"
	"github.com/pkg/errors"
	"strconv"
)


type Interval struct {
	interval time.Duration
}

func NewInterval(d time.Duration) Interval {
	isNeg := d < 0
	if isNeg {
		d *= -1
	}
	nanos := d.Nanoseconds()
	// if microseconds
	if nanos % time.Millisecond.Nanoseconds() != 0 {
		// find microseconds
		micros := nanos % time.Millisecond.Nanoseconds()
		mills := nanos / time.Millisecond.Nanoseconds()
		// find leading digit of microseconds, i.e. how many hundred-thousand nanoseconds
		lead := micros / (100*time.Microsecond.Nanoseconds())
		// round up if necessary
		if lead >= 5 {
			mills += 1
		}
		nanos = mills*1e6
	}
	if isNeg {
		nanos *= -1
	}
	return Interval{time.Duration(nanos)}

}

func (i Interval) LT(j Interval) bool {
	return i.interval < j.interval
}

func (i Interval) LE(j Interval) bool {
	return i.interval <= j.interval
}

func (i Interval) EQ(j Interval) bool {
	return i.interval == j.interval
}

func (i Interval) GT(j Interval) bool {
	return i.interval > j.interval
}

func (i Interval) GE(j Interval) bool {
	return i.interval >= j.interval
}

func (i *Interval) String() string {
	isNeg := i.interval < 0
	if isNeg {
		i.interval *= -1
	}
	hours := int(i.interval.Hours())
	minutes := int(i.interval.Minutes() - float64(hours)*60)
	seconds := i.interval.Seconds() - float64(minutes)*60 - float64(hours)*3600
	s := fmt.Sprintf("%d:%d:%.3f", hours, minutes, seconds)
	if isNeg {
		s = "-"+s
	}
	return s
}

func (i *Interval) Scan(value interface{}) error {
	intervalAsBytes, ok := value.([]byte)
	if !ok {
		return errors.Errorf("%s couldn't be cast to byte", value)
	}
	intervalAsString := string(intervalAsBytes)
	chunks := strings.Split(intervalAsString, ":")
	hoursAsString := chunks[0]
	isNeg := hoursAsString[0] == '-'
	hours, err := strconv.Atoi(hoursAsString[1:])
	if err != nil {
		return errors.Wrapf(err, "failed to convert %s to int hours", chunks[0])
	}

	minutes, err := strconv.Atoi(chunks[1])
	if err != nil {
		return errors.Wrapf(err, "failed to convert %s to int minutes", chunks[1])
	}
	seconds, err := strconv.ParseFloat(chunks[2], 64)
	if err != nil {
		return errors.Wrapf(err, "failed to convert %s to float seconds", chunks[2])
	}
	s := fmt.Sprintf("%dh%dm%.3fs", hours, minutes, seconds)
	if isNeg {
		s = "-"+s
	}
	i.interval, err = time.ParseDuration(s)
	if err != nil {
		return errors.Errorf("failed to parse duration from %s", s)
	}
	return nil
}

func (i Interval) Value() (driver.Value, error) {
	return []byte(i.String()), nil
}

// This file is generated by SQLBoiler (https://github.com/databrary/sqlboiler)
// and is meant to be re-generated in place and/or deleted at any time.
// EDIT AT YOUR OWN RISK

package public

import (
	"bytes"
	"testing"
)

func testVolumeOwnersViews(t *testing.T) {
	t.Parallel()

	query := VolumeOwnersViews(nil)

	if query.Query == nil {
		t.Error("expected a query, got nothing")
	}
}

var (
	volumeOwnersViewDBTypes = map[string]string{`Owners`: `ARRAYtext`, `Volume`: `integer`}
	_                       = bytes.MinRead
)

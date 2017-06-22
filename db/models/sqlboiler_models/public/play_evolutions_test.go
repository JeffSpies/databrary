// This file is generated by SQLBoiler (https://github.com/databrary/sqlboiler)
// and is meant to be re-generated in place and/or deleted at any time.
// EDIT AT YOUR OWN RISK

package public

import (
	"bytes"
	"github.com/databrary/sqlboiler/boil"
	"github.com/databrary/sqlboiler/randomize"
	"github.com/databrary/sqlboiler/strmangle"
	"github.com/pmezard/go-difflib/difflib"
	"os"
	"os/exec"
	"reflect"
	"sort"
	"strings"
	"testing"
)

func testPlayEvolutions(t *testing.T) {
	t.Parallel()

	query := PlayEvolutions(nil)

	if query.Query == nil {
		t.Error("expected a query, got nothing")
	}
}

func testPlayEvolutionsLive(t *testing.T) {
	all, err := PlayEvolutions(dbMain.liveDbConn).All()
	if err != nil {
		t.Fatalf("failed to get all PlayEvolutions err: ", err)
	}
	tx, err := dbMain.liveTestDbConn.Begin()
	if err != nil {
		t.Fatalf("failed to begin transaction: ", err)
	}
	for _, v := range all {
		err := v.Insert(tx)
		if err != nil {
			t.Fatalf("failed to failed to insert %s because of %s", v, err)
		}

	}
	err = tx.Commit()
	if err != nil {
		t.Fatalf("failed to commit transaction: ", err)
	}
	bf := &bytes.Buffer{}
	dumpCmd := exec.Command("psql", `-c "COPY (SELECT * FROM play_evolutions) TO STDOUT" -d `, dbMain.DbName)
	dumpCmd.Env = append(os.Environ(), dbMain.pgEnv()...)
	dumpCmd.Stdout = bf
	err = dumpCmd.Start()
	if err != nil {
		t.Fatalf("failed to start dump from live db because of %s", err)
	}
	dumpCmd.Wait()
	if err != nil {
		t.Fatalf("failed to wait dump from live db because of %s", err)
	}
	bg := &bytes.Buffer{}
	dumpCmd = exec.Command("psql", `-c "COPY (SELECT * FROM play_evolutions) TO STDOUT" -d `, dbMain.LiveTestDBName)
	dumpCmd.Env = append(os.Environ(), dbMain.pgEnv()...)
	dumpCmd.Stdout = bg
	err = dumpCmd.Start()
	if err != nil {
		t.Fatalf("failed to start dump from test db because of %s", err)
	}
	dumpCmd.Wait()
	if err != nil {
		t.Fatalf("failed to wait dump from test db because of %s", err)
	}
	bfslice := sort.StringSlice(difflib.SplitLines(bf.String()))
	gfslice := sort.StringSlice(difflib.SplitLines(bg.String()))
	bfslice.Sort()
	gfslice.Sort()
	diff := difflib.ContextDiff{
		A:        bfslice,
		B:        gfslice,
		FromFile: "databrary",
		ToFile:   "test",
		Context:  1,
	}
	result, _ := difflib.GetContextDiffString(diff)
	if len(result) > 0 {
		t.Fatalf("PlayEvolutionsLive failed but it's probably trivial: %s", strings.Replace(result, "\t", " ", -1))
	}

}

func testPlayEvolutionsDelete(t *testing.T) {
	t.Parallel()

	var err error
	seed := randomize.NewSeed()
	playEvolution := &PlayEvolution{}
	if err = randomize.Struct(seed, playEvolution, playEvolutionDBTypes, true); err != nil {
		t.Errorf("Unable to randomize PlayEvolution struct: %s", err)
	}

	tx := MustTx(boil.Begin())
	defer tx.Rollback()
	if err = playEvolution.Insert(tx); err != nil {
		t.Error(err)
	}

	if err = playEvolution.Delete(tx); err != nil {
		t.Error(err)
	}

	count, err := PlayEvolutions(tx).Count()
	if err != nil {
		t.Error(err)
	}

	if count != 0 {
		t.Error("want zero records, got:", count)
	}
}

func testPlayEvolutionsQueryDeleteAll(t *testing.T) {
	t.Parallel()

	var err error
	seed := randomize.NewSeed()
	playEvolution := &PlayEvolution{}
	if err = randomize.Struct(seed, playEvolution, playEvolutionDBTypes, true); err != nil {
		t.Errorf("Unable to randomize PlayEvolution struct: %s", err)
	}

	tx := MustTx(boil.Begin())
	defer tx.Rollback()
	if err = playEvolution.Insert(tx); err != nil {
		t.Error(err)
	}

	if err = PlayEvolutions(tx).DeleteAll(); err != nil {
		t.Error(err)
	}

	count, err := PlayEvolutions(tx).Count()
	if err != nil {
		t.Error(err)
	}

	if count != 0 {
		t.Error("want zero records, got:", count)
	}
}

func testPlayEvolutionsSliceDeleteAll(t *testing.T) {
	t.Parallel()

	var err error
	seed := randomize.NewSeed()
	playEvolution := &PlayEvolution{}
	if err = randomize.Struct(seed, playEvolution, playEvolutionDBTypes, true); err != nil {
		t.Errorf("Unable to randomize PlayEvolution struct: %s", err)
	}

	tx := MustTx(boil.Begin())
	defer tx.Rollback()
	if err = playEvolution.Insert(tx); err != nil {
		t.Error(err)
	}

	slice := PlayEvolutionSlice{playEvolution}

	if err = slice.DeleteAll(tx); err != nil {
		t.Error(err)
	}

	count, err := PlayEvolutions(tx).Count()
	if err != nil {
		t.Error(err)
	}

	if count != 0 {
		t.Error("want zero records, got:", count)
	}
}

func testPlayEvolutionsExists(t *testing.T) {
	t.Parallel()

	var err error
	seed := randomize.NewSeed()
	playEvolution := &PlayEvolution{}
	if err = randomize.Struct(seed, playEvolution, playEvolutionDBTypes, true); err != nil {
		t.Errorf("Unable to randomize PlayEvolution struct: %s", err)
	}

	tx := MustTx(boil.Begin())
	defer tx.Rollback()
	if err = playEvolution.Insert(tx); err != nil {
		t.Error(err)
	}

	e, err := PlayEvolutionExists(tx, playEvolution.ID)
	if err != nil {
		t.Errorf("Unable to check if PlayEvolution exists: %s", err)
	}
	if !e {
		t.Errorf("Expected PlayEvolutionExistsG to return true, but got false.")
	}
}

func testPlayEvolutionsFind(t *testing.T) {
	t.Parallel()

	var err error
	seed := randomize.NewSeed()
	playEvolution := &PlayEvolution{}
	if err = randomize.Struct(seed, playEvolution, playEvolutionDBTypes, true); err != nil {
		t.Errorf("Unable to randomize PlayEvolution struct: %s", err)
	}

	tx := MustTx(boil.Begin())
	defer tx.Rollback()
	if err = playEvolution.Insert(tx); err != nil {
		t.Error(err)
	}

	playEvolutionFound, err := FindPlayEvolution(tx, playEvolution.ID)
	if err != nil {
		t.Error(err)
	}

	if playEvolutionFound == nil {
		t.Error("want a record, got nil")
	}
}

func testPlayEvolutionsBind(t *testing.T) {
	t.Parallel()

	var err error
	seed := randomize.NewSeed()
	playEvolution := &PlayEvolution{}
	if err = randomize.Struct(seed, playEvolution, playEvolutionDBTypes, true); err != nil {
		t.Errorf("Unable to randomize PlayEvolution struct: %s", err)
	}

	tx := MustTx(boil.Begin())
	defer tx.Rollback()
	if err = playEvolution.Insert(tx); err != nil {
		t.Error(err)
	}

	if err = PlayEvolutions(tx).Bind(playEvolution); err != nil {
		t.Error(err)
	}
}

func testPlayEvolutionsOne(t *testing.T) {
	t.Parallel()

	var err error
	seed := randomize.NewSeed()
	playEvolution := &PlayEvolution{}
	if err = randomize.Struct(seed, playEvolution, playEvolutionDBTypes, true); err != nil {
		t.Errorf("Unable to randomize PlayEvolution struct: %s", err)
	}

	tx := MustTx(boil.Begin())
	defer tx.Rollback()
	if err = playEvolution.Insert(tx); err != nil {
		t.Error(err)
	}

	if x, err := PlayEvolutions(tx).One(); err != nil {
		t.Error(err)
	} else if x == nil {
		t.Error("expected to get a non nil record")
	}
}

func testPlayEvolutionsAll(t *testing.T) {
	t.Parallel()

	var err error
	seed := randomize.NewSeed()
	playEvolutionOne := &PlayEvolution{}
	playEvolutionTwo := &PlayEvolution{}
	if err = randomize.Struct(seed, playEvolutionOne, playEvolutionDBTypes, false, playEvolutionColumnsWithDefault...); err != nil {

		t.Errorf("Unable to randomize PlayEvolution struct: %s", err)
	}
	if err = randomize.Struct(seed, playEvolutionTwo, playEvolutionDBTypes, false, playEvolutionColumnsWithDefault...); err != nil {
		t.Errorf("Unable to randomize PlayEvolution struct: %s", err)
	}

	tx := MustTx(boil.Begin())
	defer tx.Rollback()
	if err = playEvolutionOne.Insert(tx); err != nil {
		t.Error(err)
	}
	if err = playEvolutionTwo.Insert(tx); err != nil {
		t.Error(err)
	}

	slice, err := PlayEvolutions(tx).All()
	if err != nil {
		t.Error(err)
	}

	if len(slice) != 2 {
		t.Error("want 2 records, got:", len(slice))
	}
}

func testPlayEvolutionsCount(t *testing.T) {
	t.Parallel()

	var err error
	seed := randomize.NewSeed()
	playEvolutionOne := &PlayEvolution{}
	playEvolutionTwo := &PlayEvolution{}
	if err = randomize.Struct(seed, playEvolutionOne, playEvolutionDBTypes, false, playEvolutionColumnsWithDefault...); err != nil {

		t.Errorf("Unable to randomize PlayEvolution struct: %s", err)
	}
	if err = randomize.Struct(seed, playEvolutionTwo, playEvolutionDBTypes, false, playEvolutionColumnsWithDefault...); err != nil {
		t.Errorf("Unable to randomize PlayEvolution struct: %s", err)
	}

	tx := MustTx(boil.Begin())
	defer tx.Rollback()
	if err = playEvolutionOne.Insert(tx); err != nil {
		t.Error(err)
	}
	if err = playEvolutionTwo.Insert(tx); err != nil {
		t.Error(err)
	}

	count, err := PlayEvolutions(tx).Count()
	if err != nil {
		t.Error(err)
	}

	if count != 2 {
		t.Error("want 2 records, got:", count)
	}
}

func playEvolutionBeforeInsertHook(e boil.Executor, o *PlayEvolution) error {
	*o = PlayEvolution{}
	return nil
}

func playEvolutionAfterInsertHook(e boil.Executor, o *PlayEvolution) error {
	*o = PlayEvolution{}
	return nil
}

func playEvolutionAfterSelectHook(e boil.Executor, o *PlayEvolution) error {
	*o = PlayEvolution{}
	return nil
}

func playEvolutionBeforeUpdateHook(e boil.Executor, o *PlayEvolution) error {
	*o = PlayEvolution{}
	return nil
}

func playEvolutionAfterUpdateHook(e boil.Executor, o *PlayEvolution) error {
	*o = PlayEvolution{}
	return nil
}

func playEvolutionBeforeDeleteHook(e boil.Executor, o *PlayEvolution) error {
	*o = PlayEvolution{}
	return nil
}

func playEvolutionAfterDeleteHook(e boil.Executor, o *PlayEvolution) error {
	*o = PlayEvolution{}
	return nil
}

func playEvolutionBeforeUpsertHook(e boil.Executor, o *PlayEvolution) error {
	*o = PlayEvolution{}
	return nil
}

func playEvolutionAfterUpsertHook(e boil.Executor, o *PlayEvolution) error {
	*o = PlayEvolution{}
	return nil
}

func testPlayEvolutionsHooks(t *testing.T) {
	t.Parallel()

	var err error
	seed := randomize.NewSeed()
	playEvolution := &PlayEvolution{}
	if err = randomize.Struct(seed, playEvolution, playEvolutionDBTypes, true); err != nil {
		t.Errorf("Unable to randomize PlayEvolution struct: %s", err)
	}

	empty := &PlayEvolution{}

	AddPlayEvolutionHook(boil.BeforeInsertHook, playEvolutionBeforeInsertHook)
	if err = playEvolution.doBeforeInsertHooks(nil); err != nil {
		t.Errorf("Unable to execute doBeforeInsertHooks: %s", err)
	}
	if !reflect.DeepEqual(playEvolution, empty) {
		t.Errorf("Expected BeforeInsertHook function to empty object, but got: %#v", playEvolution)
	}
	playEvolutionBeforeInsertHooks = []PlayEvolutionHook{}

	AddPlayEvolutionHook(boil.AfterInsertHook, playEvolutionAfterInsertHook)
	if err = playEvolution.doAfterInsertHooks(nil); err != nil {
		t.Errorf("Unable to execute doAfterInsertHooks: %s", err)
	}
	if !reflect.DeepEqual(playEvolution, empty) {
		t.Errorf("Expected AfterInsertHook function to empty object, but got: %#v", playEvolution)
	}
	playEvolutionAfterInsertHooks = []PlayEvolutionHook{}

	AddPlayEvolutionHook(boil.AfterSelectHook, playEvolutionAfterSelectHook)
	if err = playEvolution.doAfterSelectHooks(nil); err != nil {
		t.Errorf("Unable to execute doAfterSelectHooks: %s", err)
	}
	if !reflect.DeepEqual(playEvolution, empty) {
		t.Errorf("Expected AfterSelectHook function to empty object, but got: %#v", playEvolution)
	}
	playEvolutionAfterSelectHooks = []PlayEvolutionHook{}

	AddPlayEvolutionHook(boil.BeforeUpdateHook, playEvolutionBeforeUpdateHook)
	if err = playEvolution.doBeforeUpdateHooks(nil); err != nil {
		t.Errorf("Unable to execute doBeforeUpdateHooks: %s", err)
	}
	if !reflect.DeepEqual(playEvolution, empty) {
		t.Errorf("Expected BeforeUpdateHook function to empty object, but got: %#v", playEvolution)
	}
	playEvolutionBeforeUpdateHooks = []PlayEvolutionHook{}

	AddPlayEvolutionHook(boil.AfterUpdateHook, playEvolutionAfterUpdateHook)
	if err = playEvolution.doAfterUpdateHooks(nil); err != nil {
		t.Errorf("Unable to execute doAfterUpdateHooks: %s", err)
	}
	if !reflect.DeepEqual(playEvolution, empty) {
		t.Errorf("Expected AfterUpdateHook function to empty object, but got: %#v", playEvolution)
	}
	playEvolutionAfterUpdateHooks = []PlayEvolutionHook{}

	AddPlayEvolutionHook(boil.BeforeDeleteHook, playEvolutionBeforeDeleteHook)
	if err = playEvolution.doBeforeDeleteHooks(nil); err != nil {
		t.Errorf("Unable to execute doBeforeDeleteHooks: %s", err)
	}
	if !reflect.DeepEqual(playEvolution, empty) {
		t.Errorf("Expected BeforeDeleteHook function to empty object, but got: %#v", playEvolution)
	}
	playEvolutionBeforeDeleteHooks = []PlayEvolutionHook{}

	AddPlayEvolutionHook(boil.AfterDeleteHook, playEvolutionAfterDeleteHook)
	if err = playEvolution.doAfterDeleteHooks(nil); err != nil {
		t.Errorf("Unable to execute doAfterDeleteHooks: %s", err)
	}
	if !reflect.DeepEqual(playEvolution, empty) {
		t.Errorf("Expected AfterDeleteHook function to empty object, but got: %#v", playEvolution)
	}
	playEvolutionAfterDeleteHooks = []PlayEvolutionHook{}

	AddPlayEvolutionHook(boil.BeforeUpsertHook, playEvolutionBeforeUpsertHook)
	if err = playEvolution.doBeforeUpsertHooks(nil); err != nil {
		t.Errorf("Unable to execute doBeforeUpsertHooks: %s", err)
	}
	if !reflect.DeepEqual(playEvolution, empty) {
		t.Errorf("Expected BeforeUpsertHook function to empty object, but got: %#v", playEvolution)
	}
	playEvolutionBeforeUpsertHooks = []PlayEvolutionHook{}

	AddPlayEvolutionHook(boil.AfterUpsertHook, playEvolutionAfterUpsertHook)
	if err = playEvolution.doAfterUpsertHooks(nil); err != nil {
		t.Errorf("Unable to execute doAfterUpsertHooks: %s", err)
	}
	if !reflect.DeepEqual(playEvolution, empty) {
		t.Errorf("Expected AfterUpsertHook function to empty object, but got: %#v", playEvolution)
	}
	playEvolutionAfterUpsertHooks = []PlayEvolutionHook{}
}
func testPlayEvolutionsInsert(t *testing.T) {
	t.Parallel()

	var err error
	seed := randomize.NewSeed()
	playEvolution := &PlayEvolution{}
	if err = randomize.Struct(seed, playEvolution, playEvolutionDBTypes, true); err != nil {
		t.Errorf("Unable to randomize PlayEvolution struct: %s", err)
	}

	tx := MustTx(boil.Begin())
	defer tx.Rollback()
	if err = playEvolution.Insert(tx); err != nil {
		t.Error(err)
	}

	count, err := PlayEvolutions(tx).Count()
	if err != nil {
		t.Error(err)
	}

	if count != 1 {
		t.Error("want one record, got:", count)
	}
}

func testPlayEvolutionsInsertWhitelist(t *testing.T) {
	t.Parallel()

	var err error
	seed := randomize.NewSeed()
	playEvolution := &PlayEvolution{}
	if err = randomize.Struct(seed, playEvolution, playEvolutionDBTypes, true); err != nil {
		t.Errorf("Unable to randomize PlayEvolution struct: %s", err)
	}

	tx := MustTx(boil.Begin())
	defer tx.Rollback()
	if err = playEvolution.Insert(tx, playEvolutionColumns...); err != nil {
		t.Error(err)
	}

	count, err := PlayEvolutions(tx).Count()
	if err != nil {
		t.Error(err)
	}

	if count != 1 {
		t.Error("want one record, got:", count)
	}
}

func testPlayEvolutionsReload(t *testing.T) {
	t.Parallel()

	var err error
	seed := randomize.NewSeed()
	playEvolution := &PlayEvolution{}
	if err = randomize.Struct(seed, playEvolution, playEvolutionDBTypes, true); err != nil {
		t.Errorf("Unable to randomize PlayEvolution struct: %s", err)
	}

	tx := MustTx(boil.Begin())
	defer tx.Rollback()
	if err = playEvolution.Insert(tx); err != nil {
		t.Error(err)
	}

	if err = playEvolution.Reload(tx); err != nil {
		t.Error(err)
	}
}

func testPlayEvolutionsReloadAll(t *testing.T) {
	t.Parallel()

	var err error
	seed := randomize.NewSeed()
	playEvolution := &PlayEvolution{}
	if err = randomize.Struct(seed, playEvolution, playEvolutionDBTypes, true); err != nil {
		t.Errorf("Unable to randomize PlayEvolution struct: %s", err)
	}

	tx := MustTx(boil.Begin())
	defer tx.Rollback()
	if err = playEvolution.Insert(tx); err != nil {
		t.Error(err)
	}

	slice := PlayEvolutionSlice{playEvolution}

	if err = slice.ReloadAll(tx); err != nil {
		t.Error(err)
	}
}

func testPlayEvolutionsSelect(t *testing.T) {
	t.Parallel()

	var err error
	seed := randomize.NewSeed()
	playEvolution := &PlayEvolution{}
	if err = randomize.Struct(seed, playEvolution, playEvolutionDBTypes, true); err != nil {
		t.Errorf("Unable to randomize PlayEvolution struct: %s", err)
	}

	tx := MustTx(boil.Begin())
	defer tx.Rollback()
	if err = playEvolution.Insert(tx); err != nil {
		t.Error(err)
	}

	slice, err := PlayEvolutions(tx).All()
	if err != nil {
		t.Error(err)
	}

	if len(slice) != 1 {
		t.Error("want one record, got:", len(slice))
	}
}

var (
	playEvolutionDBTypes = map[string]string{`AppliedAt`: `timestamp without time zone`, `ApplyScript`: `text`, `Hash`: `character varying`, `ID`: `integer`, `LastProblem`: `text`, `RevertScript`: `text`, `State`: `character varying`}
	_                    = bytes.MinRead
)

func testPlayEvolutionsUpdate(t *testing.T) {
	t.Parallel()

	if len(playEvolutionColumns) == len(playEvolutionPrimaryKeyColumns) {
		t.Skip("Skipping table with only primary key columns")
	}

	var err error
	seed := randomize.NewSeed()
	playEvolution := &PlayEvolution{}
	if err = randomize.Struct(seed, playEvolution, playEvolutionDBTypes, true); err != nil {
		t.Errorf("Unable to randomize PlayEvolution struct: %s", err)
	}

	tx := MustTx(boil.Begin())
	defer tx.Rollback()
	if err = playEvolution.Insert(tx); err != nil {
		t.Error(err)
	}

	count, err := PlayEvolutions(tx).Count()
	if err != nil {
		t.Error(err)
	}

	if count != 1 {
		t.Error("want one record, got:", count)
	}

	blacklist := playEvolutionColumnsWithDefault

	if err = randomize.Struct(seed, playEvolution, playEvolutionDBTypes, true, blacklist...); err != nil {
		t.Errorf("Unable to randomize PlayEvolution struct: %s", err)
	}

	if err = playEvolution.Update(tx); err != nil {
		t.Error(err)
	}
}

func testPlayEvolutionsSliceUpdateAll(t *testing.T) {
	t.Parallel()

	if len(playEvolutionColumns) == len(playEvolutionPrimaryKeyColumns) {
		t.Skip("Skipping table with only primary key columns")
	}

	var err error
	seed := randomize.NewSeed()
	playEvolution := &PlayEvolution{}
	if err = randomize.Struct(seed, playEvolution, playEvolutionDBTypes, true); err != nil {
		t.Errorf("Unable to randomize PlayEvolution struct: %s", err)
	}

	tx := MustTx(boil.Begin())
	defer tx.Rollback()
	if err = playEvolution.Insert(tx); err != nil {
		t.Error(err)
	}

	count, err := PlayEvolutions(tx).Count()
	if err != nil {
		t.Error(err)
	}

	if count != 1 {
		t.Error("want one record, got:", count)
	}

	blacklist := playEvolutionPrimaryKeyColumns

	if err = randomize.Struct(seed, playEvolution, playEvolutionDBTypes, true, blacklist...); err != nil {
		t.Errorf("Unable to randomize PlayEvolution struct: %s", err)
	}

	// Remove Primary keys and unique columns from what we plan to update
	var fields []string
	if strmangle.StringSliceMatch(playEvolutionColumns, playEvolutionPrimaryKeyColumns) {
		fields = playEvolutionColumns
	} else {
		fields = strmangle.SetComplement(
			playEvolutionColumns,
			playEvolutionPrimaryKeyColumns,
		)
	}

	value := reflect.Indirect(reflect.ValueOf(playEvolution))
	updateMap := M{}
	for _, col := range fields {
		updateMap[col] = value.FieldByName(strmangle.TitleCase(col)).Interface()
	}

	slice := PlayEvolutionSlice{playEvolution}
	if err = slice.UpdateAll(tx, updateMap); err != nil {
		t.Error(err)
	}
}

func testPlayEvolutionsUpsert(t *testing.T) {
	t.Parallel()

	if len(playEvolutionColumns) == len(playEvolutionPrimaryKeyColumns) {
		t.Skip("Skipping table with only primary key columns")
	}

	var err error
	seed := randomize.NewSeed()
	playEvolution := &PlayEvolution{}
	if err = randomize.Struct(seed, playEvolution, playEvolutionDBTypes, true); err != nil {
		t.Errorf("Unable to randomize PlayEvolution struct: %s", err)
	}

	tx := MustTx(boil.Begin())
	defer tx.Rollback()
	if err = playEvolution.Upsert(tx, false, nil, nil); err != nil {
		t.Errorf("Unable to upsert PlayEvolution: %s", err)
	}

	count, err := PlayEvolutions(tx).Count()
	if err != nil {
		t.Error(err)
	}
	if count != 1 {
		t.Error("want one record, got:", count)
	}

	// Attempt the UPDATE side of an UPSERT
	blacklist := playEvolutionPrimaryKeyColumns

	if err = randomize.Struct(seed, playEvolution, playEvolutionDBTypes, false, blacklist...); err != nil {
		t.Errorf("Unable to randomize PlayEvolution struct: %s", err)
	}

	if err = playEvolution.Upsert(tx, true, nil, nil); err != nil {
		t.Errorf("Unable to upsert PlayEvolution: %s", err)
	}

	count, err = PlayEvolutions(tx).Count()
	if err != nil {
		t.Error(err)
	}
	if count != 1 {
		t.Error("want one record, got:", count)
	}
}

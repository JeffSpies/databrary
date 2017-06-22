// This file is generated by SQLBoiler (https://github.com/databrary/sqlboiler)
// and is meant to be re-generated in place and/or deleted at any time.
// EDIT AT YOUR OWN RISK

package audit

import (
	"bytes"
	"database/sql"
	"fmt"
	"github.com/databrary/databrary/db/models/custom_types"
	"github.com/databrary/sqlboiler/boil"
	"github.com/databrary/sqlboiler/queries"
	"github.com/databrary/sqlboiler/queries/qm"
	"github.com/databrary/sqlboiler/strmangle"
	"github.com/pkg/errors"
	"gopkg.in/nullbio/null.v6"
	"reflect"
	"strings"
	"sync"
	"time"
)

// Authorize is an object representing the database table.
type Authorize struct {
	AuditTime   time.Time               `db:"audit_time" json:"authorize_audit_time"`
	AuditUser   int                     `db:"audit_user" json:"authorize_audit_user"`
	AuditIP     custom_types.Inet       `db:"audit_ip" json:"authorize_audit_ip"`
	AuditAction custom_types.Action     `db:"audit_action" json:"authorize_audit_action"`
	Child       int                     `db:"child" json:"authorize_child"`
	Parent      int                     `db:"parent" json:"authorize_parent"`
	Site        custom_types.Permission `db:"site" json:"authorize_site"`
	Member      custom_types.Permission `db:"member" json:"authorize_member"`
	Expires     null.Time               `db:"expires" json:"authorize_expires,omitempty"`

	R *authorizeR `db:"-" json:"-"`
	L authorizeL  `db:"-" json:"-"`
}

// authorizeR is where relationships are stored.
type authorizeR struct {
}

// authorizeL is where Load methods for each relationship are stored.
type authorizeL struct{}

var (
	authorizeColumns               = []string{"audit_time", "audit_user", "audit_ip", "audit_action", "child", "parent", "site", "member", "expires"}
	authorizeColumnsWithoutDefault = []string{"audit_user", "audit_ip", "audit_action", "child", "parent", "site", "member", "expires"}
	authorizeColumnsWithDefault    = []string{"audit_time"}
	authorizeColumnsWithCustom     = []string{"audit_ip", "audit_action", "site", "member"}
)

type (
	// AuthorizeSlice is an alias for a slice of pointers to Authorize.
	// This should generally be used opposed to []Authorize.
	AuthorizeSlice []*Authorize
	// AuthorizeHook is the signature for custom Authorize hook methods
	AuthorizeHook func(boil.Executor, *Authorize) error

	authorizeQuery struct {
		*queries.Query
	}
)

// Cache for insert, update and upsert
var (
	authorizeType    = reflect.TypeOf(&Authorize{})
	authorizeMapping = queries.MakeStructMapping(authorizeType)

	authorizeInsertCacheMut sync.RWMutex
	authorizeInsertCache    = make(map[string]insertCache)
	authorizeUpdateCacheMut sync.RWMutex
	authorizeUpdateCache    = make(map[string]updateCache)
	authorizeUpsertCacheMut sync.RWMutex
	authorizeUpsertCache    = make(map[string]insertCache)
)

var (
	// Force time package dependency for automated UpdatedAt/CreatedAt.
	_ = time.Second
	// Force bytes in case of primary key column that uses []byte (for relationship compares)
	_ = bytes.MinRead
)
var authorizeBeforeInsertHooks []AuthorizeHook
var authorizeBeforeUpdateHooks []AuthorizeHook
var authorizeBeforeDeleteHooks []AuthorizeHook
var authorizeBeforeUpsertHooks []AuthorizeHook

var authorizeAfterInsertHooks []AuthorizeHook
var authorizeAfterSelectHooks []AuthorizeHook
var authorizeAfterUpdateHooks []AuthorizeHook
var authorizeAfterDeleteHooks []AuthorizeHook
var authorizeAfterUpsertHooks []AuthorizeHook

// doBeforeInsertHooks executes all "before insert" hooks.
func (o *Authorize) doBeforeInsertHooks(exec boil.Executor) (err error) {
	for _, hook := range authorizeBeforeInsertHooks {
		if err := hook(exec, o); err != nil {
			return err
		}
	}

	return nil
}

// doBeforeUpdateHooks executes all "before Update" hooks.
func (o *Authorize) doBeforeUpdateHooks(exec boil.Executor) (err error) {
	for _, hook := range authorizeBeforeUpdateHooks {
		if err := hook(exec, o); err != nil {
			return err
		}
	}

	return nil
}

// doBeforeDeleteHooks executes all "before Delete" hooks.
func (o *Authorize) doBeforeDeleteHooks(exec boil.Executor) (err error) {
	for _, hook := range authorizeBeforeDeleteHooks {
		if err := hook(exec, o); err != nil {
			return err
		}
	}

	return nil
}

// doBeforeUpsertHooks executes all "before Upsert" hooks.
func (o *Authorize) doBeforeUpsertHooks(exec boil.Executor) (err error) {
	for _, hook := range authorizeBeforeUpsertHooks {
		if err := hook(exec, o); err != nil {
			return err
		}
	}

	return nil
}

// doAfterInsertHooks executes all "after Insert" hooks.
func (o *Authorize) doAfterInsertHooks(exec boil.Executor) (err error) {
	for _, hook := range authorizeAfterInsertHooks {
		if err := hook(exec, o); err != nil {
			return err
		}
	}

	return nil
}

// doAfterSelectHooks executes all "after Select" hooks.
func (o *Authorize) doAfterSelectHooks(exec boil.Executor) (err error) {
	for _, hook := range authorizeAfterSelectHooks {
		if err := hook(exec, o); err != nil {
			return err
		}
	}

	return nil
}

// doAfterUpdateHooks executes all "after Update" hooks.
func (o *Authorize) doAfterUpdateHooks(exec boil.Executor) (err error) {
	for _, hook := range authorizeAfterUpdateHooks {
		if err := hook(exec, o); err != nil {
			return err
		}
	}

	return nil
}

// doAfterDeleteHooks executes all "after Delete" hooks.
func (o *Authorize) doAfterDeleteHooks(exec boil.Executor) (err error) {
	for _, hook := range authorizeAfterDeleteHooks {
		if err := hook(exec, o); err != nil {
			return err
		}
	}

	return nil
}

// doAfterUpsertHooks executes all "after Upsert" hooks.
func (o *Authorize) doAfterUpsertHooks(exec boil.Executor) (err error) {
	for _, hook := range authorizeAfterUpsertHooks {
		if err := hook(exec, o); err != nil {
			return err
		}
	}

	return nil
}

// AddAuthorizeHook registers your hook function for all future operations.
func AddAuthorizeHook(hookPoint boil.HookPoint, authorizeHook AuthorizeHook) {
	switch hookPoint {
	case boil.BeforeInsertHook:
		authorizeBeforeInsertHooks = append(authorizeBeforeInsertHooks, authorizeHook)
	case boil.BeforeUpdateHook:
		authorizeBeforeUpdateHooks = append(authorizeBeforeUpdateHooks, authorizeHook)
	case boil.BeforeDeleteHook:
		authorizeBeforeDeleteHooks = append(authorizeBeforeDeleteHooks, authorizeHook)
	case boil.BeforeUpsertHook:
		authorizeBeforeUpsertHooks = append(authorizeBeforeUpsertHooks, authorizeHook)
	case boil.AfterInsertHook:
		authorizeAfterInsertHooks = append(authorizeAfterInsertHooks, authorizeHook)
	case boil.AfterSelectHook:
		authorizeAfterSelectHooks = append(authorizeAfterSelectHooks, authorizeHook)
	case boil.AfterUpdateHook:
		authorizeAfterUpdateHooks = append(authorizeAfterUpdateHooks, authorizeHook)
	case boil.AfterDeleteHook:
		authorizeAfterDeleteHooks = append(authorizeAfterDeleteHooks, authorizeHook)
	case boil.AfterUpsertHook:
		authorizeAfterUpsertHooks = append(authorizeAfterUpsertHooks, authorizeHook)
	}
}

// OneP returns a single authorize record from the query, and panics on error.
func (q authorizeQuery) OneP() *Authorize {
	o, err := q.One()
	if err != nil {
		panic(boil.WrapErr(err))
	}

	return o
}

// One returns a single authorize record from the query.
func (q authorizeQuery) One() (*Authorize, error) {
	o := &Authorize{}

	queries.SetLimit(q.Query, 1)

	err := q.Bind(o)
	if err != nil {
		if errors.Cause(err) == sql.ErrNoRows {
			return nil, sql.ErrNoRows
		}
		return nil, errors.Wrap(err, "models: failed to execute a one query for authorize")
	}

	if err := o.doAfterSelectHooks(queries.GetExecutor(q.Query)); err != nil {
		return o, err
	}

	return o, nil
}

// AllP returns all Authorize records from the query, and panics on error.
func (q authorizeQuery) AllP() AuthorizeSlice {
	o, err := q.All()
	if err != nil {
		panic(boil.WrapErr(err))
	}

	return o
}

// All returns all Authorize records from the query.
func (q authorizeQuery) All() (AuthorizeSlice, error) {
	var o AuthorizeSlice

	err := q.Bind(&o)
	if err != nil {
		return nil, errors.Wrap(err, "models: failed to assign all query results to Authorize slice")
	}

	if len(authorizeAfterSelectHooks) != 0 {
		for _, obj := range o {
			if err := obj.doAfterSelectHooks(queries.GetExecutor(q.Query)); err != nil {
				return o, err
			}
		}
	}

	return o, nil
}

// CountP returns the count of all Authorize records in the query, and panics on error.
func (q authorizeQuery) CountP() int64 {
	c, err := q.Count()
	if err != nil {
		panic(boil.WrapErr(err))
	}

	return c
}

// Count returns the count of all Authorize records in the query.
func (q authorizeQuery) Count() (int64, error) {
	var count int64

	queries.SetSelect(q.Query, nil)
	queries.SetCount(q.Query)

	err := q.Query.QueryRow().Scan(&count)
	if err != nil {
		return 0, errors.Wrap(err, "models: failed to count authorize rows")
	}

	return count, nil
}

// Exists checks if the row exists in the table, and panics on error.
func (q authorizeQuery) ExistsP() bool {
	e, err := q.Exists()
	if err != nil {
		panic(boil.WrapErr(err))
	}

	return e
}

// Exists checks if the row exists in the table.
func (q authorizeQuery) Exists() (bool, error) {
	var count int64

	queries.SetCount(q.Query)
	queries.SetLimit(q.Query, 1)

	err := q.Query.QueryRow().Scan(&count)
	if err != nil {
		return false, errors.Wrap(err, "models: failed to check if authorize exists")
	}

	return count > 0, nil
}

// AuthorizesG retrieves all records.
func AuthorizesG(mods ...qm.QueryMod) authorizeQuery {
	return Authorizes(boil.GetDB(), mods...)
}

// Authorizes retrieves all the records using an executor.
func Authorizes(exec boil.Executor, mods ...qm.QueryMod) authorizeQuery {
	mods = append(mods, qm.From("\"audit\".\"authorize\""))
	return authorizeQuery{NewQuery(exec, mods...)}
}

// InsertG a single record. See Insert for whitelist behavior description.
func (o *Authorize) InsertG(whitelist ...string) error {
	return o.Insert(boil.GetDB(), whitelist...)
}

// InsertGP a single record, and panics on error. See Insert for whitelist
// behavior description.
func (o *Authorize) InsertGP(whitelist ...string) {
	if err := o.Insert(boil.GetDB(), whitelist...); err != nil {
		panic(boil.WrapErr(err))
	}
}

// InsertP a single record using an executor, and panics on error. See Insert
// for whitelist behavior description.
func (o *Authorize) InsertP(exec boil.Executor, whitelist ...string) {
	if err := o.Insert(exec, whitelist...); err != nil {
		panic(boil.WrapErr(err))
	}
}

// Insert a single record using an executor.
// Whitelist behavior: If a whitelist is provided, only those columns supplied are inserted
// No whitelist behavior: Without a whitelist, columns are inferred by the following rules:
// - All columns without a default value are included (i.e. name, age)
// - All columns with a default, but non-zero are included (i.e. health = 75)
func (o *Authorize) Insert(exec boil.Executor, whitelist ...string) error {
	if o == nil {
		return errors.New("models: no authorize provided for insertion")
	}

	var err error

	if err := o.doBeforeInsertHooks(exec); err != nil {
		return err
	}

	nzDefaults := queries.NonZeroDefaultSet(authorizeColumnsWithDefault, o)

	key := makeCacheKey(whitelist, nzDefaults)
	authorizeInsertCacheMut.RLock()
	cache, cached := authorizeInsertCache[key]
	authorizeInsertCacheMut.RUnlock()

	if !cached {
		wl, returnColumns := strmangle.InsertColumnSet(
			authorizeColumns,
			authorizeColumnsWithDefault,
			authorizeColumnsWithoutDefault,
			nzDefaults,
			whitelist,
		)

		cache.valueMapping, err = queries.BindMapping(authorizeType, authorizeMapping, wl)
		if err != nil {
			return err
		}
		cache.retMapping, err = queries.BindMapping(authorizeType, authorizeMapping, returnColumns)
		if err != nil {
			return err
		}
		if len(wl) != 0 {
			cache.query = fmt.Sprintf("INSERT INTO \"audit\".\"authorize\" (\"%s\") VALUES (%s)", strings.Join(wl, "\",\""), strmangle.Placeholders(dialect.IndexPlaceholders, len(wl), 1, 1))
		} else {
			cache.query = "INSERT INTO \"audit\".\"authorize\" DEFAULT VALUES"
		}

		if len(cache.retMapping) != 0 {
			cache.query += fmt.Sprintf(" RETURNING \"%s\"", strings.Join(returnColumns, "\",\""))
		}
	}

	value := reflect.Indirect(reflect.ValueOf(o))
	vals := queries.ValuesFromMapping(value, cache.valueMapping)

	if boil.DebugMode {
		fmt.Fprintln(boil.DebugWriter, cache.query)
		fmt.Fprintln(boil.DebugWriter, vals)
	}

	if len(cache.retMapping) != 0 {
		err = exec.QueryRow(cache.query, vals...).Scan(queries.PtrsFromMapping(value, cache.retMapping)...)
	} else {
		_, err = exec.Exec(cache.query, vals...)
	}

	if err != nil {
		return errors.Wrap(err, "models: unable to insert into authorize")
	}

	if !cached {
		authorizeInsertCacheMut.Lock()
		authorizeInsertCache[key] = cache
		authorizeInsertCacheMut.Unlock()
	}

	return o.doAfterInsertHooks(exec)
}

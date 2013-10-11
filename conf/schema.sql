-- This is currently the complete, authoritative schema, as it is easier to
-- understand all in one place.

-- Whenever you make changes to this file, you must also write a new evolution
-- in evolutions/default and check the result using "project/runsql check".
-- Note that this while this file is valid SQL, evolutions require semi-colons
-- to be doubled when they do not terminate statements.

-- A general convention is that hard-coded fixtures get non-positive ids.

----------------------------------------------------------- utilities

CREATE FUNCTION CREATE_ABSTRACT_PARENT ("parent" name, "children" name[]) RETURNS void LANGUAGE plpgsql AS $create$
DECLARE
	parent_table CONSTANT text := quote_ident(parent);
	kind_type CONSTANT text := quote_ident(parent || '_kind');
BEGIN
	EXECUTE $macro$
		CREATE TYPE $macro$ || kind_type || $macro$ AS ENUM ('$macro$ || array_to_string(children, $$','$$) || $macro$');
		CREATE TABLE $macro$ || parent_table || $macro$ (
			"id" serial NOT NULL Primary Key,
			"kind" $macro$ || kind_type || $macro$ NOT NULL
		);
		CREATE FUNCTION $macro$ || quote_ident(parent || '_trigger') || $macro$ () RETURNS trigger LANGUAGE plpgsql AS $$ BEGIN
			IF TG_OP = 'INSERT' THEN
				INSERT INTO $macro$ || parent_table || $macro$ (id, kind) VALUES (NEW.id, TG_TABLE_NAME::$macro$ || kind_type || $macro$);
			ELSIF TG_OP = 'DELETE' THEN
				DELETE FROM $macro$ || parent_table || $macro$ WHERE id = OLD.id AND kind = TG_TABLE_NAME::$macro$ || kind_type || $macro$;
			ELSIF TG_OP = 'UPDATE' THEN
				IF NEW.id = OLD.id THEN
					RETURN NEW;
				END IF;
				UPDATE $macro$ || parent_table || $macro$ SET id = NEW.id WHERE id = OLD.id AND kind = TG_TABLE_NAME::$macro$ || kind_type || $macro$;
			END IF;
			IF NOT FOUND THEN
				RAISE EXCEPTION 'inconsistency for %:% parent $macro$ || parent || $macro$', TG_TABLE_NAME::$macro$ || kind_type || $macro$, OLD.id;
			END IF;
			IF TG_OP = 'DELETE' THEN
				RETURN OLD;
			ELSE
				RETURN NEW;
			END IF;
		END;$$
	$macro$;
END; $create$;
COMMENT ON FUNCTION CREATE_ABSTRACT_PARENT (name, name[]) IS 'A "macro" to create an abstract parent table and trigger function.  This could be done with a single function using dynamic EXECUTE but this way is more efficient and not much more messy.';

CREATE FUNCTION cast_int ("input" text) RETURNS integer LANGUAGE plpgsql IMMUTABLE STRICT AS $$
DECLARE
	i integer;
BEGIN
	SELECT input::integer INTO i;
	RETURN i;
EXCEPTION WHEN invalid_text_representation THEN
	RETURN NULL;
END; $$;

CREATE FUNCTION singleton (int4) RETURNS int4range LANGUAGE sql IMMUTABLE STRICT AS
	$$ SELECT int4range($1, $1, '[]') $$;

----------------------------------------------------------- auditing

CREATE SCHEMA audit;

CREATE TYPE audit_action AS ENUM ('attempt', 'open', 'close', 'add', 'change', 'remove', 'superuser');
COMMENT ON TYPE audit_action IS 'The various activities for which we keep audit records (in audit or a derived table).  This is not kept in the audit schema due to jdbc type search limitations.';

CREATE FUNCTION audit.SET_PRIVILEGES (name) RETURNS void LANGUAGE plpgsql AS $set$ BEGIN
	EXECUTE $$REVOKE UPDATE, DELETE, TRUNCATE ON TABLE audit.$$ || quote_ident($1) || $$ FROM $$ || quote_ident(current_user);
END; $set$;
COMMENT ON FUNCTION audit.SET_PRIVILEGES (name) IS 'REVOKE UPDATE, DELETE, TRUNCATE ON TABLE audit.$1 FROM current_user.  Unfortunately you cannot remove default privileges per-schema, so we do this instead for each audit table.  The function is necessary to interpolate current_user.';

CREATE TABLE audit."audit" (
	"audit_time" timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
	"audit_user" int NOT NULL, -- References "account" ("party"),
	"audit_ip" inet NOT NULL,
	"audit_action" audit_action NOT NULL
) WITH (OIDS = FALSE);
COMMENT ON TABLE audit."audit" IS 'Logs of all activities on the site, including access and modifications to any data. Each table has an associated audit table inheriting from this one.';
SELECT audit.SET_PRIVILEGES ('audit');

CREATE FUNCTION audit.CREATE_TABLE (name) RETURNS void LANGUAGE plpgsql AS $create$
DECLARE
	table_name CONSTANT text := quote_ident($1);
BEGIN
	EXECUTE $$CREATE TABLE audit.$$ || table_name || $$ (LIKE public.$$ || table_name || $$) INHERITS (audit."audit") WITH (OIDS = FALSE)$$;
	PERFORM audit.SET_PRIVILEGES($1);
END; $create$;
COMMENT ON FUNCTION audit.CREATE_TABLE (name) IS 'Create an audit.$1 table mirroring public.$1.';

----------------------------------------------------------- users

CREATE TABLE "party" (
	"id" serial NOT NULL Primary Key,
	"name" text NOT NULL,
	"orcid" char(16)
);
COMMENT ON TABLE "party" IS 'Users, groups, organizations, and other logical identities';

-- special parties (SERIAL starts at 1):
INSERT INTO "party" VALUES (-1, 'Everybody'); -- NOBODY
INSERT INTO "party" VALUES (0, 'Databrary'); -- ROOT

SELECT audit.CREATE_TABLE ('party');


CREATE TABLE "account" (
	"id" integer NOT NULL Primary Key References "party",
	"email" varchar(256) NOT NULL, -- split out (multiple/user)?
	"password" varchar(60), -- standard unix-style hash, currently $2a$ bcrypt
	"openid" varchar(256) -- split out (multiple/user)?
);
COMMENT ON TABLE "account" IS 'Login information for parties associated with registered individuals.';

SELECT audit.CREATE_TABLE ('account');

----------------------------------------------------------- permissions

CREATE TYPE permission AS ENUM ('NONE',
	'VIEW', -- list view, but no access to protected data (PUBLIC access)
	'DOWNLOAD', -- full read access to shared data (BROWSE access)
	'CONTRIBUTE', -- create and edit data of own/target (FULL access)
	'ADMIN' -- perform administrative tasks on site/target such as changing permissions
);
COMMENT ON TYPE permission IS 'Levels of access parties can have to the site data.';

CREATE TYPE consent AS ENUM (
	-- 		permission required
	'PRIVATE', 	-- CONTRIBUTE	did not consent to any sharing
	'SHARED', 	-- DOWNLOAD	consented to share on databrary
	'EXCERPTS', 	-- DOWNLOAD	SHARED, but consented that excerpts may be PUBLIC
	'PUBLIC' 	-- VIEW		consented to share openly
);
COMMENT ON TYPE consent IS 'Levels of sharing that participants may consent to.';

CREATE TABLE "authorize" (
	"child" integer NOT NULL References "party" ON DELETE Cascade,
	"parent" integer NOT NULL References "party",
	"access" permission NOT NULL DEFAULT 'NONE',
	"delegate" permission NOT NULL DEFAULT 'NONE',
	"authorized" timestamp DEFAULT CURRENT_TIMESTAMP,
	"expires" timestamp,
	Primary Key ("parent", "child"),
	Check ("child" <> "parent" AND ("child" > 0 OR "parent" = -1))
);
COMMENT ON TABLE "authorize" IS 'Relationships and permissions granted between parties';
COMMENT ON COLUMN "authorize"."child" IS 'Party granted permissions';
COMMENT ON COLUMN "authorize"."parent" IS 'Party granting permissions';
COMMENT ON COLUMN "authorize"."access" IS 'Level of independent site access granted to child (effectively minimum level on path to ROOT)';
COMMENT ON COLUMN "authorize"."delegate" IS 'Permissions for which child may act as parent (not inherited)';

SELECT audit.CREATE_TABLE ('authorize');

-- To allow normal users to inherit from nobody:
INSERT INTO "authorize" ("child", "parent", "access", "delegate", "authorized") VALUES (0, -1, 'ADMIN', 'ADMIN', '2013-1-1');

CREATE VIEW "authorize_valid" AS
	SELECT * FROM authorize WHERE authorized < CURRENT_TIMESTAMP AND (expires IS NULL OR expires > CURRENT_TIMESTAMP);
COMMENT ON VIEW "authorize_valid" IS 'Active records from "authorize"';

CREATE FUNCTION "authorize_access_parents" (IN "child" integer, OUT "parent" integer, INOUT "access" permission = NULL) RETURNS SETOF RECORD LANGUAGE sql STABLE AS $$
	WITH RECURSIVE closure AS (
		SELECT $1 AS parent, enum_last(null::permission) AS access
		UNION
		SELECT p.parent, LEAST(p.access, c.access)
			FROM authorize_valid p, closure c
			WHERE p.child = c.parent AND ($2 IS NULL OR p.access >= $2)
	)
	SELECT * FROM closure
$$;
COMMENT ON FUNCTION "authorize_access_parents" (integer, permission) IS 'All ancestors (recursive) of a given child';

CREATE FUNCTION "authorize_access_check" ("child" integer, "parent" integer = 0, "access" permission = NULL) RETURNS permission LANGUAGE sql STABLE AS $$
	SELECT max(access) FROM authorize_access_parents($1, $3) WHERE parent = $2
$$;
COMMENT ON FUNCTION "authorize_access_check" (integer, integer, permission) IS 'Test if a given child inherits the given permission [any] from the given parent [root]';

CREATE FUNCTION "authorize_delegate_check" ("child" integer, "parent" integer, "delegate" permission = NULL) RETURNS permission LANGUAGE sql STABLE AS $$
	SELECT CASE WHEN $1 = $2 THEN enum_last(max(delegate)) ELSE max(delegate) END FROM authorize_valid WHERE child = $1 AND parent = $2
$$;
COMMENT ON FUNCTION "authorize_delegate_check" (integer, integer, permission) IS 'Test if a given child has the given permission [any] over the given parent';

----------------------------------------------------------- volumes

CREATE TABLE "volume" (
	"id" serial NOT NULL Primary Key,
	"name" text NOT NULL,
	"body" text
);
COMMENT ON TABLE "volume" IS 'Basic organizational unit for data.';

SELECT audit.CREATE_TABLE ('volume');
CREATE INDEX "volume_creation_idx" ON audit."volume" ("id") WHERE "audit_action" = 'add';
COMMENT ON INDEX audit."volume_creation_idx" IS 'Allow efficient retrieval of volume creation information, specifically date.';

CREATE FUNCTION "volume_creation" ("volume" integer) RETURNS timestamp LANGUAGE sql STABLE STRICT AS
	$$ SELECT max("audit_time") FROM audit."volume" WHERE "id" = $1 AND "audit_action" = 'add' $$;

CREATE TABLE "volume_access" (
	"volume" integer NOT NULL References "volume",
	"party" integer NOT NULL References "party",
	"access" permission NOT NULL DEFAULT 'NONE',
	"inherit" permission NOT NULL DEFAULT 'NONE' Check ("inherit" < 'ADMIN'),
	Check ("access" >= "inherit"),
	Primary Key ("volume", "party")
);
COMMENT ON TABLE "volume_access" IS 'Permissions over volumes assigned to users.';

SELECT audit.CREATE_TABLE ('volume_access');

CREATE FUNCTION "volume_access_check" ("volume" integer, "party" integer, "access" permission = NULL) RETURNS permission LANGUAGE sql STABLE AS $$
	WITH sa AS (
		SELECT party, access, inherit
		  FROM volume_access 
		 WHERE volume = $1 AND ($3 IS NULL OR access >= $3)
	)
	SELECT max(access) FROM (
		SELECT access 
		  FROM sa
		 WHERE party = $2
	UNION ALL
		SELECT LEAST(sa.inherit, aap.access) 
		  FROM sa JOIN authorize_access_parents($2, $3) aap ON party = parent 
	UNION ALL
		SELECT LEAST(sa.access, ad.delegate)
		  FROM sa JOIN authorize_valid ad ON party = parent 
		 WHERE child = $2
	) a WHERE $3 IS NULL OR access >= $3
$$;
COMMENT ON FUNCTION "volume_access_check" (integer, integer, permission) IS 'Test if a given party has the given permission [any] on the given volume, either directly, inherited through site access, or delegated.';

CREATE TABLE "volume_citation" (
	"volume" integer NOT NULL References "volume",
	"head" text NOT NULL,
	"url" text,
	"body" text
);
CREATE INDEX ON "volume_citation" ("volume");
COMMENT ON TABLE "volume_citation" IS 'Quick and dirty citation list.  Not intended to be permanent.  No PK: only updated in bulk on volume.';

CREATE TABLE "volume_funding" (
	"volume" integer NOT NULL References "volume",
	"funder" integer NOT NULL References "party",
	"grant" text
);
CREATE INDEX ON "volume_funding" ("volume");
COMMENT ON TABLE "volume_funding" IS 'Quick and dirty funding list.  No PK: only updated in bulk on volume.';

----------------------------------------------------------- time intervals

CREATE FUNCTION "interval_mi_epoch" (interval, interval) RETURNS double precision LANGUAGE sql IMMUTABLE STRICT AS 
	$$ SELECT date_part('epoch', interval_mi($1, $2)) $$;
CREATE TYPE segment AS RANGE (
	SUBTYPE = interval HOUR TO SECOND,
	SUBTYPE_DIFF = "interval_mi_epoch"
);
COMMENT ON TYPE "segment" IS 'Intervals of time, used primarily for representing clips of timeseries data.';

CREATE FUNCTION "segment" (interval) RETURNS segment LANGUAGE sql IMMUTABLE STRICT AS
	$$ SELECT segment('0', $1) $$;
COMMENT ON FUNCTION "segment" (interval) IS 'The segment [0,X) but strict in X.';
CREATE FUNCTION "duration" (segment) RETURNS interval HOUR TO SECOND LANGUAGE sql IMMUTABLE STRICT AS
	$$ SELECT CASE WHEN isempty($1) THEN '0' ELSE interval_mi(upper($1), lower($1)) END $$;
COMMENT ON FUNCTION "duration" (segment) IS 'Determine the length of a segment, or NULL if unbounded.';
CREATE FUNCTION "singleton" (interval HOUR TO SECOND) RETURNS segment LANGUAGE sql IMMUTABLE STRICT AS
	$$ SELECT segment($1, $1, '[]') $$;
CREATE FUNCTION "singleton" (segment) RETURNS interval LANGUAGE sql IMMUTABLE STRICT AS
	$$ SELECT lower($1) WHERE lower_inc($1) AND upper_inc($1) AND lower($1) = upper($1) $$;
COMMENT ON FUNCTION "singleton" (segment) IS 'Determine if a segment represents a single point and return it, or NULL if not.';

CREATE FUNCTION "segment_shift" (segment, interval) RETURNS segment LANGUAGE sql IMMUTABLE STRICT AS $$
	SELECT CASE WHEN isempty($1) THEN 'empty' ELSE
		segment(lower($1) + $2, upper($1) + $2,
			CASE WHEN lower_inc($1) THEN '[' ELSE '(' END || CASE WHEN upper_inc($1) THEN ']' ELSE ')' END)
	END
$$;
COMMENT ON FUNCTION "segment_shift" (segment, interval) IS 'Shift both end points of a segment by the specified interval.';


CREATE TABLE "object_segment" ( -- ABSTRACT
	"id" integer NOT NULL,
	"source" integer NOT NULL, -- References "source_table"
	"segment" segment NOT NULL Check (NOT isempty("segment")),
	Check (false) NO INHERIT
);
ALTER TABLE "object_segment" ALTER COLUMN "segment" SET STORAGE plain;
COMMENT ON TABLE "object_segment" IS 'Generic table for objects defined as a temporal sub-sequence of another object.  Inherit from this table to use the functions below.';

CREATE FUNCTION "object_segment_contains" ("object_segment", "object_segment") RETURNS boolean LANGUAGE sql IMMUTABLE STRICT AS
	$$ SELECT $1.id = $2.id OR $1.source = $2.source AND $1.segment @> $2.segment $$;
CREATE FUNCTION "object_segment_within" ("object_segment", "object_segment") RETURNS boolean LANGUAGE sql IMMUTABLE STRICT AS
	$$ SELECT $1.id = $2.id OR $1.source = $2.source AND $1.segment <@ $2.segment $$;
CREATE OPERATOR @> (PROCEDURE = "object_segment_contains", LEFTARG = "object_segment", RIGHTARG = "object_segment", COMMUTATOR = <@);
CREATE OPERATOR <@ (PROCEDURE = "object_segment_within", LEFTARG = "object_segment", RIGHTARG = "object_segment", COMMUTATOR = @>);

----------------------------------------------------------- containers

CREATE TABLE "container" (
	"id" serial NOT NULL Primary Key,
	"volume" integer NOT NULL References "volume",
	"top" boolean NOT NULL DEFAULT false,
	"name" text,
	"date" date
);
CREATE INDEX ON "container" ("volume");
CREATE UNIQUE INDEX "container_top_idx" ON "container" ("volume") WHERE "top";
COMMENT ON TABLE "container" IS 'Organizational unit within volume containing related files (with common annotations), often corresponding to an individual data session (single visit/acquisition/participant/group/day).';

SELECT audit.CREATE_TABLE ('container');

CREATE FUNCTION "container_top_create" () RETURNS trigger LANGUAGE plpgsql AS $$ BEGIN
	INSERT INTO container (volume, top) VALUES (NEW.id, true);
	RETURN null;
END; $$;
CREATE TRIGGER "container_top_create" AFTER INSERT ON "volume" FOR EACH ROW EXECUTE PROCEDURE "container_top_create" ();
COMMENT ON TRIGGER "container_top_create" ON "volume" IS 'Always create a top container for each volume.  Unfortunately nothing currently prevents them from being removed/changed.';


CREATE TABLE "slot" (
	"id" serial NOT NULL Primary Key,
	"source" integer NOT NULL References "container",
	"segment" segment NOT NULL DEFAULT '(,)',
	"consent" consent,
	Unique ("source", "segment"),
	Exclude USING gist (singleton("source") WITH =, "segment" WITH &&) WHERE ("consent" IS NOT NULL)
) INHERITS ("object_segment");
CREATE UNIQUE INDEX "slot_full_container_idx" ON "slot" ("source") WHERE "segment" = '(,)';
COMMENT ON TABLE "slot" IS 'Sections of containers selected for referencing, annotating, consenting, etc.';
COMMENT ON COLUMN "slot"."consent" IS 'Sharing/release permissions granted by participants on (portions of) contained data.  This could equally well be an annotation, but hopefully won''t add too much space here.';

SELECT audit.CREATE_TABLE ('slot');
COMMENT ON TABLE audit."slot" IS 'Partial auditing for slot table covering only consent changes.';

CREATE FUNCTION "slot_full_create" () RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE
	slot_id integer;
BEGIN
	INSERT INTO slot (source, segment) VALUES (NEW.id, '(,)') RETURNING id INTO STRICT slot_id;
	RETURN null;
END; $$;
CREATE TRIGGER "slot_full_create" AFTER INSERT ON "container" FOR EACH ROW EXECUTE PROCEDURE "slot_full_create" ();
COMMENT ON TRIGGER "slot_full_create" ON "container" IS 'Always create a "full"-range slot for each container.  Unfortunately nothing currently prevents them from being removed/changed.';


CREATE VIEW "slot_nesting" ("child", "parent", "consent") AS 
	SELECT c.id, p.id, p.consent FROM slot c JOIN slot p ON c <@ p;
COMMENT ON VIEW "slot_nesting" IS 'Transitive closure of slots containtained within other slots.';

CREATE FUNCTION "slot_consent" ("slot" integer) RETURNS consent LANGUAGE sql STABLE STRICT AS
	$$ SELECT consent FROM slot_nesting WHERE child = $1 AND consent IS NOT NULL $$;
COMMENT ON FUNCTION "slot_consent" (integer) IS 'Effective consent level on a given slot.';

----------------------------------------------------------- assets

CREATE TYPE classification AS ENUM (
	'IDENTIFIED', 	-- data containing HIPPA identifiers, requiring appropriate consent and DOWNLOAD permission
	'EXCERPT', 	-- IDENTIFIED data that has been selected as a releasable excerpt
	'DEIDENTIFIED', -- "raw" data which has been de-identified, requiring only DOWNLOAD permission
	'ANALYSIS', 	-- un/de-identified derived, generated, summarized, or aggregated data measures
	'PRODUCT',	-- research products such as results, summaries, commentaries, discussions, manuscripts, or articles
	'MATERIAL'	-- materials not derived from data, such as proposals, procedures, stimuli, manuals, (blank) forms, or documentation
);

CREATE TABLE "format" (
	"id" smallserial NOT NULL Primary Key,
	"mimetype" varchar(128) NOT NULL Unique,
	"extension" varchar(8),
	"name" text NOT NULL
);
COMMENT ON TABLE "format" IS 'Possible types for assets, sufficient for producing download headers.';

CREATE TABLE "timeseries_format" (
	Primary Key ("id"),
	Unique ("mimetype")
) INHERITS ("format");
COMMENT ON TABLE "timeseries_format" IS 'Special asset types that correspond to internal formats representing timeseries data.';

-- The privledged formats with special handling (image and video for now) have hard-coded IDs:
INSERT INTO "format" ("id", "mimetype", "extension", "name") VALUES (-700, 'image/jpeg', 'jpg', 'JPEG');
INSERT INTO "timeseries_format" ("id", "mimetype", "extension", "name") VALUES (-800, 'video/mp4', 'mp4', 'Databrary video');

-- The above video format will change to reflect internal storage, these are used for uploaded files:
INSERT INTO "format" ("mimetype", "extension", "name") VALUES ('text/plain', 'txt', 'Plain text');
INSERT INTO "format" ("mimetype", "extension", "name") VALUES ('text/csv', 'csv', 'Comma-separated values');
INSERT INTO "format" ("mimetype", "extension", "name") VALUES ('text/html', 'html', 'Hypertext markup');
INSERT INTO "format" ("mimetype", "extension", "name") VALUES ('text/rtf', 'rtf', 'Rich text format');
INSERT INTO "format" ("mimetype", "extension", "name") VALUES ('image/png', 'png', 'Portable network graphics');
INSERT INTO "format" ("mimetype", "extension", "name") VALUES ('application/pdf', 'pdf', 'Portable document');
INSERT INTO "format" ("mimetype", "extension", "name") VALUES ('application/msword', 'doc', 'Microsoft Word document');
INSERT INTO "format" ("mimetype", "extension", "name") VALUES ('application/vnd.oasis.opendocument.text', 'odf', 'OpenDocument text');
INSERT INTO "format" ("mimetype", "extension", "name") VALUES ('application/vnd.openxmlformats-officedocument.wordprocessingml.document', 'docx', 'Microsoft Word (Office Open XML) document');
INSERT INTO "format" ("mimetype", "extension", "name") VALUES ('application/vnd.ms-excel', 'xls', 'Microsoft Excel spreadsheet');
INSERT INTO "format" ("mimetype", "extension", "name") VALUES ('application/vnd.oasis.opendocument.spreadsheet', 'ods', 'OpenDocument spreadsheet');
INSERT INTO "format" ("mimetype", "extension", "name") VALUES ('application/vnd.openxmlformats-officedocument.spreadsheetml.sheet', 'xlsx', 'Microsoft Excel (Office Open XML) workbook');
INSERT INTO "format" ("mimetype", "extension", "name") VALUES ('application/vnd.ms-powerpoint', 'ppt', 'Microsoft PowerPoint presentation');
INSERT INTO "format" ("mimetype", "extension", "name") VALUES ('application/vnd.oasis.opendocument.presentation', 'odp', 'OpenDocument presentation');
INSERT INTO "format" ("mimetype", "extension", "name") VALUES ('application/vnd.openxmlformats-officedocument.presentationml.presentation', 'pptx', 'Microsoft PowerPoint (Office Open XML) presentation');
-- INSERT INTO "format" ("mimetype", "extension", "name") VALUES ('video/mp4', 'mp4', 'MPEG-4 Part 14');
-- INSERT INTO "format" ("mimetype", "extension", "name") VALUES ('video/webm', 'webm', 'WebM');

SELECT CREATE_ABSTRACT_PARENT ('asset', ARRAY['file', 'timeseries', 'clip']);
COMMENT ON TABLE "asset" IS 'Parent table for all uploaded data in storage.';

CREATE TABLE "file" (
	"id" integer NOT NULL DEFAULT nextval('asset_id_seq') Primary Key References "asset" Deferrable Initially Deferred,
	"format" smallint NOT NULL References "format",
	"classification" classification NOT NULL
);
CREATE TRIGGER "asset" BEFORE INSERT OR UPDATE OR DELETE ON "file" FOR EACH ROW EXECUTE PROCEDURE "asset_trigger" ();
COMMENT ON TABLE "file" IS 'Assets in storage along with their "constant" metadata.';

SELECT audit.CREATE_TABLE ('file');

CREATE TABLE "timeseries" (
	"id" integer NOT NULL DEFAULT nextval('asset_id_seq') Primary Key References "asset" Deferrable Initially Deferred,
	"format" smallint NOT NULL References "timeseries_format",
	"duration" interval HOUR TO SECOND NOT NULL Check ("duration" > interval '0')
) INHERITS ("file");
CREATE TRIGGER "asset" BEFORE INSERT OR UPDATE OR DELETE ON "timeseries" FOR EACH ROW EXECUTE PROCEDURE "asset_trigger" ();
COMMENT ON TABLE "timeseries" IS 'File assets representing interpretable and sub-selectable timeseries data (e.g., videos).';

CREATE VIEW audit."timeseries" AS
	SELECT *, NULL::interval AS "duration" FROM audit."file";
COMMENT ON VIEW audit."timeseries" IS 'Timeseries are audited together with files.  This view provides glue to make that transparent.';
CREATE FUNCTION audit."timeseries_file" () RETURNS trigger LANGUAGE plpgsql AS $$ BEGIN
	INSERT INTO audit."file" (audit_time, audit_user, audit_ip, audit_action, id, format, classification) VALUES (NEW.audit_time, NEW.audit_user, NEW.audit_ip, NEW.audit_action, NEW.id, NEW.format, NEW.classification);
	RETURN NEW;
END; $$;
COMMENT ON FUNCTION audit."timeseries_file" () IS 'Trigger function for INSTEAD OF INSERT ON audit.timeseries to propagate to audit.file.';
CREATE TRIGGER "file" INSTEAD OF INSERT ON audit."timeseries" FOR EACH ROW EXECUTE PROCEDURE audit."timeseries_file" ();


CREATE TABLE "clip" (
	"id" integer NOT NULL DEFAULT nextval('asset_id_seq') Primary Key References "asset" Deferrable Initially Deferred,
	"source" integer NOT NULL References "timeseries",
	"segment" segment NOT NULL Check (lower("segment") >= '0'::interval AND NOT upper_inf("segment")), -- segment <@ [0,source.duration]
	Unique ("source", "segment")
) INHERITS ("object_segment");
CREATE TRIGGER "asset" BEFORE INSERT OR UPDATE OR DELETE ON "clip" FOR EACH ROW EXECUTE PROCEDURE "asset_trigger" ();
CREATE INDEX ON "clip" ("source");
COMMENT ON TABLE "clip" IS 'Sections of timeseries assets selected for use.  When placed into containers, they are treated independently of their source timeseries.';


CREATE TABLE "container_asset" (
	"asset" integer NOT NULL References "asset" Primary Key,
	"container" integer NOT NULL References "container",
	"position" interval HOUR TO SECOND,
	"name" text NOT NULL,
	"body" text
);
CREATE INDEX ON "container_asset" ("container");
COMMENT ON TABLE "container_asset" IS 'Asset linkages into containers along with "dynamic" metadata.';
COMMENT ON COLUMN "container_asset"."position" IS 'Start point or position of this asset within the container, such that this asset occurs or starts position time after the beginning of the container session.  NULL positions are treated as universal (existing at all times).';

SELECT audit.CREATE_TABLE ('container_asset');


CREATE VIEW "asset_duration" ("id", "duration") AS
	SELECT id, NULL FROM ONLY file UNION ALL
	SELECT id, duration FROM timeseries UNION ALL
	SELECT id, duration(segment) FROM clip;
COMMENT ON VIEW "asset_duration" IS 'All assets along with their temporal durations, NULL for non-timeseries.';


CREATE TABLE "toplevel_asset" (
	"slot" integer NOT NULL References "slot",
	"asset" integer NOT NULL References "asset",
	"excerpt" boolean NOT NULL DEFAULT false,
	Primary Key ("slot", "asset")
);
COMMENT ON TABLE "toplevel_asset" IS 'Slot assets which are promoted to the top volume level for display.';
COMMENT ON COLUMN "toplevel_asset"."excerpt" IS 'Asset segments that may be released publically if so permitted.';

SELECT audit.CREATE_TABLE ('toplevel_asset');

----------------------------------------------------------- comments

CREATE TABLE "comment" (
	"id" serial NOT NULL Primary Key,
	"who" integer NOT NULL References "account",
	"slot" integer NOT NULL References "slot",
	"time" timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
	"text" text NOT NULL
);
CREATE INDEX ON "comment" ("slot");
COMMENT ON TABLE "comment" IS 'Free-text comments on objects (unaudited, immutable).';

----------------------------------------------------------- tags

CREATE TABLE "tag" (
	"id" serial NOT NULL Primary Key,
	"name" varchar(32) NOT NULL Unique
);
COMMENT ON TABLE "tag" IS 'Tag/keywords that can be applied to objects.';

CREATE TABLE "tag_use" (
	"tag" integer NOT NULL References "tag",
	"who" integer NOT NULL References "account",
	"slot" integer NOT NULL References "slot",
	"up" boolean NOT NULL DEFAULT true,
	Primary Key ("tag", "who", "slot")
);
CREATE INDEX ON "tag_use" ("slot");
COMMENT ON TABLE "tag_use" IS 'Applications of tags to objects along with their weight (+-1).';

CREATE VIEW "tag_weight" ("tag", "slot", "weight") AS
	SELECT tag, slot, SUM(CASE WHEN up THEN 1::int ELSE -1::int END)::int FROM tag_use GROUP BY tag, slot;

----------------------------------------------------------- records

CREATE TABLE "record_category" (
	"id" smallserial Primary Key,
	"name" varchar(64) NOT NULL Unique
);
COMMENT ON TABLE "record_category" IS 'Types of records that are relevant for data organization.';
INSERT INTO "record_category" ("id", "name") VALUES (-500, 'participant');

CREATE TABLE "record" (
	"id" serial NOT NULL Primary Key,
	"volume" integer NOT NULL References "volume",
	"category" smallint References "record_category" ON DELETE SET NULL
);
COMMENT ON TABLE "record" IS 'Sets of metadata measurements organized into or applying to a single cohesive unit.  These belong to the object(s) they''re attached to, which are expected to be within a single volume.';

CREATE TYPE data_type AS ENUM ('text', 'number', 'date');
COMMENT ON TYPE data_type IS 'Types of measurement data corresponding to measure_* tables.';

CREATE TABLE "metric" (
	"id" serial Primary Key,
	"name" varchar(64) NOT NULL,
	"classification" classification NOT NULL DEFAULT 'DEIDENTIFIED',
	"type" data_type NOT NULL,
	"values" text[] -- options for text enumerations, not enforced (could be pulled out to separate kind/table)
);
COMMENT ON TABLE "metric" IS 'Types of measurements for data stored in measure_$type tables.  Rough prototype.';
INSERT INTO "metric" ("id", "name", "type") VALUES (-900, 'ident', 'text');
INSERT INTO "metric" ("id", "name", "classification", "type") VALUES (-590, 'birthdate', 'IDENTIFIED', 'date');
INSERT INTO "metric" ("id", "name", "type", "values") VALUES (-580, 'gender', 'text', ARRAY['female','male']);
INSERT INTO "metric" ("id", "name", "type", "values") VALUES (-550, 'race', 'text', ARRAY['American Indian or Alaska Native','Asian','Native Hawaiian or Other Pacific Islander','Black or African American','White','Multiple']);
INSERT INTO "metric" ("id", "name", "type", "values") VALUES (-540, 'ethnicity', 'text', ARRAY['Not Hispanic or Latino','Hispanic or Latino']);

CREATE TABLE "record_template" (
	"category" smallint References "record_category" ON DELETE CASCADE,
	"metric" integer References "metric",
	Primary Key ("category", "metric")
);
COMMENT ON TABLE "record_template" IS 'Default set of measures defining a given record category.';
INSERT INTO "record_template" ("category", "metric") VALUES (-500, -900);
INSERT INTO "record_template" ("category", "metric") VALUES (-500, -590);
INSERT INTO "record_template" ("category", "metric") VALUES (-500, -580);
INSERT INTO "record_template" ("category", "metric") VALUES (-500, -550);
INSERT INTO "record_template" ("category", "metric") VALUES (-500, -540);

CREATE TABLE "measure" ( -- ABSTRACT
	"record" integer NOT NULL References "record" ON DELETE CASCADE,
	"metric" integer NOT NULL References "metric", -- WHERE kind = table_name
	Primary Key ("record", "metric"),
	Check (false) NO INHERIT
);
COMMENT ON TABLE "measure" IS 'Abstract parent of all measure tables containing data values.  Rough prototype.';

CREATE TABLE "measure_text" (
	"record" integer NOT NULL References "record" ON DELETE CASCADE,
	"metric" integer NOT NULL References "metric", -- WHERE kind = "text"
	"datum" text NOT NULL,
	Primary Key ("record", "metric")
) INHERITS ("measure");

CREATE TABLE "measure_number" (
	"record" integer NOT NULL References "record" ON DELETE CASCADE,
	"metric" integer NOT NULL References "metric", -- WHERE kind = "number"
	"datum" numeric NOT NULL,
	Primary Key ("record", "metric")
) INHERITS ("measure");

CREATE TABLE "measure_date" (
	"record" integer NOT NULL References "record" ON DELETE CASCADE,
	"metric" integer NOT NULL References "metric", -- WHERE kind = "date"
	"datum" date NOT NULL,
	Primary Key ("record", "metric")
) INHERITS ("measure");

CREATE VIEW "measure_view" AS
	SELECT record, metric, datum FROM measure_text UNION ALL
	SELECT record, metric, text(datum) FROM measure_number UNION ALL
	SELECT record, metric, text(datum) FROM measure_date;
COMMENT ON VIEW "measure_view" IS 'Data from all measure tables, coerced to text.';

CREATE VIEW "measure_all" ("record", "metric", "datum_text", "datum_number", "datum_date") AS
	SELECT record, metric, datum, NULL::numeric, NULL::date FROM measure_text UNION ALL
	SELECT record, metric, NULL, datum, NULL FROM measure_number UNION ALL
	SELECT record, metric, NULL, NULL, datum FROM measure_date;
COMMENT ON VIEW "measure_all" IS 'Data from all measure tables, coerced to text.';


CREATE TABLE "slot_record" (
	"slot" integer NOT NULL References "slot",
	"record" integer NOT NULL References "record",
	Primary Key ("slot", "record")
);
CREATE INDEX ON "slot_record" ("record");
COMMENT ON TABLE "slot_record" IS 'Attachment of records to slots.';


CREATE FUNCTION "record_consent" ("record" integer) RETURNS consent LANGUAGE sql STABLE STRICT AS
	$$ SELECT MIN(consent) FROM slot_record JOIN slot ON slot = slot.id WHERE record = $1 $$;
COMMENT ON FUNCTION "record_consent" (integer) IS 'Effective (minimal) consent level granted on the specified record.  This should really consider containing slots, too, though for now this is sufficient because the only identified measure is on participants, which should coincide with consents.';

CREATE FUNCTION "record_daterange" ("record" integer) RETURNS daterange LANGUAGE sql STABLE STRICT AS $$
	SELECT daterange(min(date), max(date), '[]') 
	  FROM slot_record
	  JOIN slot ON slot = slot.id
	  JOIN container ON slot.source = container.id
	 WHERE record = $1
$$;
COMMENT ON FUNCTION "record_daterange" (integer) IS 'Range of container dates covered by the given record.';

----------------------------------------------------------- tokens

CREATE FUNCTION "random_string" ("length" smallint, "charset" text = '()-0123456789@ABCDEFGHIJKLMNOPQRSTUVWXYZ_abcdefghijklmnopqrstuvwxyz~') RETURNS varchar LANGUAGE sql VOLATILE STRICT AS
	$$ SELECT string_agg(substr($2, (length($2)*random()+0.5)::smallint, 1), '') FROM generate_series(1,$1) $$;
COMMENT ON FUNCTION "random_string" (smallint, text) IS 'Generate a random string of the given length drawn from the given list of characters.  This uses the postgres random function, which is not cryptographically secure.';

CREATE TABLE "token" (
	"token" char(64) Primary Key NOT NULL,
	"expires" timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP + interval '1 week'
);
COMMENT ON TABLE "token" IS 'Generic tokens issued to automatically perform actions such as logins or authorizations.';

CREATE TABLE "login_token" (
	"token" char(64) Primary Key NOT NULL DEFAULT "random_string"(64::smallint), -- could generate pk violations
	"expires" timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP + interval '1 week',
	"account" integer NOT NULL References "account",
	"password" boolean NOT NULL DEFAULT false
) INHERITS ("token");
CREATE UNIQUE INDEX "login_token_account_idx" ON "login_token" ("account") WHERE "password";
COMMENT ON TABLE "login_token" IS 'Tokens issued to automatically login/register users or reset passwords.';

----------------------------------------------------------- bootstrap/test data

INSERT INTO party (id, name, orcid) VALUES (1, 'Dylan Simon', '0000000227931679');
INSERT INTO party (id, name) VALUES (2, 'Mike Continues');
INSERT INTO party (id, name) VALUES (3, 'Lisa Steiger');
INSERT INTO party (id, name) VALUES (4, 'Andrea Byrne');
INSERT INTO party (id, name) VALUES (5, 'Karen Adolph');
INSERT INTO party (id, name) VALUES (6, 'Rick Gilmore');
SELECT setval('party_id_seq', 6);

INSERT INTO account (id, email, openid) VALUES (1, 'dylan@databrary.org', 'http://dylex.net/');
INSERT INTO account (id, email, openid) VALUES (2, 'mike@databrary.org', NULL);
INSERT INTO account (id, email, openid) VALUES (3, 'lisa@databrary.org', NULL);
INSERT INTO account (id, email, openid) VALUES (4, 'andrea@databrary.org', NULL);

INSERT INTO authorize (child, parent, access, delegate, authorized) VALUES (1, 0, 'ADMIN', 'ADMIN', '2013-3-1');
INSERT INTO authorize (child, parent, access, delegate, authorized) VALUES (2, 0, 'ADMIN', 'ADMIN', '2013-8-1');
INSERT INTO authorize (child, parent, access, delegate, authorized) VALUES (3, 0, 'CONTRIBUTE', 'NONE', '2013-4-1');
INSERT INTO authorize (child, parent, access, delegate, authorized) VALUES (4, 0, 'CONTRIBUTE', 'NONE', '2013-9-1');

INSERT INTO volume (id, name, body) VALUES (1, 'Databrary', 'Databrary is an open data library for developmental science. Share video, audio, and related metadata. Discover more, faster.
Most developmental scientists rely on video recordings to capture the complexity and richness of behavior. However, researchers rarely share video data, and this has impeded scientific progress. By creating the cyber-infrastructure and community to enable open video sharing, the Databrary project aims to facilitate deeper, richer, and broader understanding of behavior.
The Databrary project is dedicated to transforming the culture of developmental science by building a community of researchers committed to open video data sharing, training a new generation of developmental scientists and empowering them with an unprecedented set of tools for discovery, and raising the profile of behavioral science by bolstering interest in and support for scientific research among the general public.');
SELECT setval('volume_id_seq', 1);

INSERT INTO volume_access (volume, party, access, inherit) VALUES (1, -1, 'DOWNLOAD', 'DOWNLOAD');
INSERT INTO volume_access (volume, party, access, inherit) VALUES (1, 1, 'ADMIN', 'NONE');
INSERT INTO volume_access (volume, party, access, inherit) VALUES (1, 2, 'ADMIN', 'NONE');

INSERT INTO timeseries (id, format, classification, duration) VALUES (1, -800, 'MATERIAL', interval '40');
SELECT setval('asset_id_seq', 1);

INSERT INTO container_asset (container, asset, position, name) VALUES (1, 1, '0', 'counting');


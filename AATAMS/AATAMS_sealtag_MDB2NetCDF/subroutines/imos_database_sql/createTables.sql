-- DROP SCHEMA aatams_sattag CASCADE;

BEGIN;
CREATE SCHEMA aatams_sattag;
COMMIT;

BEGIN;
CREATE TABLE aatams_sattag.ctd_device_mdb_workflow
(
  pkid bigserial NOT NULL,
  device_id character(20) NOT NULL,
  ptt integer,
  body integer,
  device_wmo_ref character(15) NOT NULL,
  metadata character varying(255),
  pi character varying(120),
  sattag_program character varying(20),
  abstract character varying(500),
  tag_type character varying(50),
  common_name character varying(50),
  species character varying(100),
  nickname character varying(100),
  release_site character varying(250),
  opendap_url character varying(250),
  CONSTRAINT ctd_device_mdb_workflow_pkey PRIMARY KEY (pkid),
  CONSTRAINT ctd_device_mdb_workflow_device_id_key UNIQUE (device_id)
)
WITH (
  OIDS=FALSE
);



CREATE TABLE aatams_sattag.ctd_profile_mdb_workflow
(
  pkid bigserial NOT NULL,
  ctd_device_mdb_workflow_fk bigint NOT NULL,
  device_wmo_ref character(15) NOT NULL,
  "timestamp" timestamp without time zone NOT NULL,
  lon double precision,
  lat double precision,
  filename character(150),
  created timestamp without time zone NOT NULL DEFAULT ('now'::text)::timestamp without time zone,
  geom geometry,
  source_filename character varying(35),
  CONSTRAINT ctd_profile_mdb_workflow_pkey PRIMARY KEY (pkid),
  CONSTRAINT ctd_profile_mdb_workflow_fkey FOREIGN KEY (ctd_device_mdb_workflow_fk)
      REFERENCES aatams_sattag.ctd_device_mdb_workflow (pkid) MATCH SIMPLE
      ON UPDATE CASCADE ON DELETE CASCADE,
  CONSTRAINT enforce_dims_trajectory CHECK (ndims(geom) = 2),
  CONSTRAINT enforce_srid_trajectory CHECK (srid(geom) = 4326)
)
WITH (
  OIDS=FALSE
);
COMMIT;



BEGIN;
CREATE UNIQUE INDEX ctd_profile_unique_mdb_workflow
  ON aatams_sattag.ctd_profile_mdb_workflow
  USING btree
  (ctd_device_mdb_workflow_fk, "timestamp");
COMMIT;



BEGIN;
 CREATE OR REPLACE VIEW aatams_sattag.ctd_profile_mdb_workflow_vw AS 
 SELECT a.pkid, a."timestamp", a.lon, a.lat, a.filename, a.created, a.geom, b.device_id, b.ptt, b.body, b.device_wmo_ref, b.metadata, b.pi, b.sattag_program, b.abstract, b.tag_type, b.common_name, b.species, b.nickname, b.release_site
   FROM aatams_sattag.ctd_profile_mdb_workflow a, aatams_sattag.ctd_device_mdb_workflow b
  WHERE a.ctd_device_mdb_workflow_fk = b.pkid
  ORDER BY a.pkid;

--CREATE OR REPLACE VIEW aatams_sattag.ctd_profile_mdb_workflow_vw_recent AS 
 --SELECT a.pkid, a."timestamp", a.lon, a.lat, a.filename, a.created, a.geom, b.device_id, b.ptt, b.body, b.device_wmo_ref, b.metadata, b.pi, b.sattag_program, b.abstract, b.tag_type, b.common_name, b.species, b.nickname, b.release_site
 --  FROM aatams_sattag.ctd_profile_mdb_workflow a, aatams_sattag.ctd_device_mdb_workflow b, ( SELECT DISTINCT a.device_wmo_ref, max(a."timestamp") AS last_date
 --          FROM aatams_sattag.ctd_profile_mdb_workflow a
 --         GROUP BY a.device_wmo_ref
 --         ORDER BY a.device_wmo_ref, max(a."timestamp")) profile
 -- WHERE profile.device_wmo_ref = b.device_wmo_ref AND a.device_wmo_ref = b.device_wmo_ref AND date_part('epoch'::text, profile.last_date - a."timestamp") < 604800::double precision
 -- ORDER BY a."timestamp";

 CREATE OR REPLACE VIEW aatams_sattag.ctd_profile_mdb_workflow_vw_recent AS 
 SELECT devicetable.pkid AS device_pkid, devicetable.device_id, devicetable.ptt, devicetable.body, devicetable.device_wmo_ref, devicetable.metadata, devicetable.pi, devicetable.sattag_program, devicetable.abstract, devicetable.tag_type, devicetable.common_name, devicetable.species, devicetable.nickname, devicetable.release_site, profiletable.pkid, profiletable.ctd_device_mdb_workflow_fk, profiletable."timestamp", profiletable.lon, profiletable.lat, profiletable.filename, profiletable.created, profiletable.geom, profiletable.source_filename
   FROM aatams_sattag.ctd_profile_mdb_workflow profiletable, aatams_sattag.ctd_device_mdb_workflow devicetable, ( SELECT DISTINCT profiletable.ctd_device_mdb_workflow_fk, max(profiletable."timestamp") AS last_date
           FROM aatams_sattag.ctd_profile_mdb_workflow profiletable
          GROUP BY profiletable.ctd_device_mdb_workflow_fk
          ORDER BY profiletable.ctd_device_mdb_workflow_fk, max(profiletable."timestamp")) profile
  WHERE devicetable.pkid = profiletable.ctd_device_mdb_workflow_fk AND devicetable.pkid = profile.ctd_device_mdb_workflow_fk AND date_part('epoch'::text, profile.last_date - profiletable."timestamp") < 604800::double precision
  ORDER BY devicetable.device_id;
COMMIT;

BEGIN;
ALTER TABLE aatams_sattag.ctd_device_mdb_workflow OWNER TO gis_writer;
GRANT ALL ON TABLE aatams_sattag.ctd_device_mdb_workflow TO gis_writer;
GRANT ALL ON TABLE aatams_sattag.ctd_device_mdb_workflow TO aatams;
GRANT ALL ON TABLE aatams_sattag.ctd_device_mdb_workflow TO aatams_group;

ALTER TABLE aatams_sattag.ctd_profile_mdb_workflow OWNER TO gis_writer;
GRANT ALL ON TABLE aatams_sattag.ctd_profile_mdb_workflow TO gis_writer;
GRANT ALL ON TABLE aatams_sattag.ctd_profile_mdb_workflow TO aatams_group;
GRANT ALL ON TABLE aatams_sattag.ctd_profile_mdb_workflow TO aatams;

ALTER TABLE aatams_sattag.ctd_profile_mdb_workflow_vw_recent OWNER TO gis_writer;
GRANT ALL ON TABLE aatams_sattag.ctd_profile_mdb_workflow_vw_recent TO gis_writer;
GRANT SELECT ON TABLE aatams_sattag.ctd_profile_mdb_workflow_vw_recent TO gisread;

ALTER TABLE aatams_sattag.ctd_profile_mdb_workflow_vw OWNER TO gis_writer;
GRANT ALL ON TABLE aatams_sattag.ctd_profile_mdb_workflow_vw TO gis_writer;
GRANT SELECT ON TABLE aatams_sattag.ctd_profile_mdb_workflow_vw TO gisread;
COMMIT;



INSERT INTO geometry_columns(f_table_catalog, f_table_schema, f_table_name, f_geometry_column, coord_dimension, srid, "type") 
SELECT '', 'aatams_sattag', 'ctd_profile_mdb_workflow', 'geom', ST_CoordDim(geom), ST_SRID(geom), GeometryType(geom) FROM aatams_sattag.ctd_profile_mdb_workflow LIMIT 1;

INSERT INTO geometry_columns(f_table_catalog, f_table_schema, f_table_name, f_geometry_column, coord_dimension, srid, "type") 
SELECT '', 'aatams_sattag', 'ctd_profile_mdb_workflow_vw', 'geom', ST_CoordDim(geom), ST_SRID(geom), GeometryType(geom) FROM aatams_sattag.ctd_profile_mdb_workflow_vw LIMIT 1;

INSERT INTO geometry_columns(f_table_catalog, f_table_schema, f_table_name, f_geometry_column, coord_dimension, srid, "type") 
SELECT '', 'aatams_sattag', 'ctd_profile_mdb_workflow_vw_recent', 'geom', ST_CoordDim(geom), ST_SRID(geom), GeometryType(geom) FROM aatams_sattag.ctd_profile_mdb_workflow_vw_recent LIMIT 1;

-- Sequence: aatams_sattag.ctd_profile_mdb_workflow_pkid_seq

-- DROP SEQUENCE aatams_sattag.ctd_profile_mdb_workflow_pkid_seq;
CREATE SEQUENCE aatams_sattag.ctd_profile_mdb_workflow_pkid_seq
  INCREMENT 1
  MINVALUE 1
  MAXVALUE 9223372036854775807
  START 79776
  CACHE 1;
ALTER TABLE aatams_sattag.ctd_profile_mdb_workflow_pkid_seq OWNER TO gis_writer;

-- DROP SEQUENCE aatams_sattag.ctd_device_mdb_workflow_pkid_seq;

CREATE SEQUENCE aatams_sattag.ctd_device_mdb_workflow_pkid_seq
  INCREMENT 1
  MINVALUE 1
  MAXVALUE 9223372036854775807
  START 156
  CACHE 1;
  
ALTER TABLE aatams_sattag.ctd_device_mdb_workflow_pkid_seq OWNER TO gis_writer;

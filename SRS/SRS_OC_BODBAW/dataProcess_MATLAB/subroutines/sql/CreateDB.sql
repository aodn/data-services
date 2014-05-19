DROP TABLE bio_optical.deployments CASCADE;
DROP SEQUENCE bio_optical.deployments_pkid_seq;

CREATE TABLE bio_optical.deployments
(
  pkid integer NOT NULL,
  data_type character varying(40),
  deployment_id character varying(40),
  metadata_uuid character varying(40),
  abstract character varying(1000),
  filepath character varying(40),
  filename character varying(160),
  opendap_url character varying(160),
  time_coverage_start timestamp with time zone,
  time_coverage_end timestamp with time zone,
  geom geometry,
  CONSTRAINT pkid PRIMARY KEY (pkid)
)
WITH (
  OIDS=FALSE
);
ALTER TABLE bio_optical.deployments OWNER TO gisadmin;
GRANT ALL ON TABLE bio_optical.deployments TO gisadmin;
GRANT SELECT ON TABLE bio_optical.deployments TO gisread;


CREATE SEQUENCE bio_optical.deployments_pkid_seq
  INCREMENT 1
  MINVALUE 1
  MAXVALUE 9223372036854775807
  START 1
  CACHE 1;
ALTER TABLE bio_optical.deployments_pkid_seq OWNER TO gisadmin;


-- Table: anmn_mv

-- DROP TABLE anmn_mv;

CREATE TABLE anmn.anmn_mv
(
  id bigint,
  platform_code bpchar,
  site_code bpchar,
  deployment_code bpchar,
  instrument bpchar,
  instrument_serial_number bpchar,
  institution bpchar,
  principal_investigator bpchar,
  instrument_type bpchar,
  opendap_url character varying(1000),
  download_url text,
  geospatial_lat_min double precision,
  geospatial_lon_min double precision,
  geospatial_lat_max double precision,
  geospatial_lon_max double precision,
  geospatial_vertical_min double precision,
  geospatial_vertical_max double precision,
  geometry geometry,
  time_coverage_start timestamp without time zone,
  time_coverage_end timestamp without time zone,
  time_deployment_start timestamp without time zone,
  time_deployment_end timestamp without time zone,
  date_created timestamp without time zone,
  last_modified_date timestamp without time zone,
  first_harvested_date timestamp with time zone
)
WITH (
  OIDS=FALSE
);
ALTER TABLE anmn.anmn_mv OWNER TO report;
GRANT ALL ON TABLE anmn.anmn_mv TO report;
GRANT ALL ON TABLE anmn.anmn_mv TO postgres;
GRANT SELECT ON TABLE anmn.anmn_mv TO public;

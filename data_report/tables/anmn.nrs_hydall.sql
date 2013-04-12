
-- DROP TABLE anmn.nrs_hydall;

CREATE TABLE anmn.nrs_hydall
(
  pkid serial NOT NULL,
  sample_time timestamp with time zone NOT NULL,
  site_code character(6) NOT NULL,
  sample_lat double precision,
  sample_lon double precision,
  sample_depth real NOT NULL,
  salinity double precision,
  salinity_qc integer,
  oxygen double precision,
  oxygen_qc integer,
  silicate double precision,
  silicate_qc integer,
  nitrate_nitrite double precision,
  nitrate_nitrite_qc integer,
  phosphate double precision,
  phosphate_qc integer,
  ammonium double precision,
  ammonium_qc integer,
  sample_comment character varying(255),
  first_indexed timestamp with time zone NOT NULL,
  last_indexed timestamp with time zone NOT NULL,
  CONSTRAINT nrs_hydall_pkey PRIMARY KEY (pkid)
) 
WITH (
  OIDS = FALSE
);

ALTER TABLE anmn.nrs_hydall OWNER TO report;
COMMENT ON COLUMN anmn.nrs_hydall.sample_time IS 'Time of sample collection';
COMMENT ON TABLE anmn.nrs_hydall
  IS 'Data harvested from NRS water-sampling nutrients data in Excel spreadsheets.';

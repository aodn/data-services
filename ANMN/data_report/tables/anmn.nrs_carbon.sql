
-- DROP TABLE anmn.nrs_carbon;

CREATE TABLE anmn.nrs_carbon
(
  pkid serial NOT NULL,
  sample_time timestamp with time zone NOT NULL,
  site_code character(6) NOT NULL,
  sample_lat double precision,
  sample_lon double precision,
  sample_depth real NOT NULL,
  tco2 double precision,
  tco2_qc integer,
  talkalinity double precision,
  talkalinity_qc integer,
  sample_comment character varying(255),
  first_indexed timestamp with time zone NOT NULL,
  last_indexed timestamp with time zone NOT NULL,
  CONSTRAINT nrs_carbon_pkey PRIMARY KEY (pkid)
) 
WITH (
  OIDS = FALSE
);

ALTER TABLE anmn.nrs_carbon OWNER TO report;
COMMENT ON COLUMN anmn.nrs_carbon.sample_time IS 'Time of sample collection';
COMMENT ON TABLE anmn.nrs_carbon
  IS 'Data harvested from NRS water-sampling carbon data in Excel spreadsheets.';

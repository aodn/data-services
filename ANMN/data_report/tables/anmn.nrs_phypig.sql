
-- DROP TABLE anmn.nrs_phypig;

CREATE TABLE anmn.nrs_phypig
(
  pkid serial NOT NULL,
  sample_time timestamp with time zone NOT NULL,
  site_code character(6) NOT NULL,
  sample_lat double precision,
  sample_lon double precision,
  sample_depth real NOT NULL,
  sample_qc integer,
  sample_comment character varying(255),
  time_comment character varying(255),
  location_comment character varying(255),
  first_indexed timestamp with time zone NOT NULL,
  last_indexed timestamp with time zone NOT NULL,
  CONSTRAINT nrs_phypig_pkey PRIMARY KEY (pkid)
) 
WITH (
  OIDS = FALSE
);

ALTER TABLE anmn.nrs_phypig OWNER TO report;
COMMENT ON COLUMN anmn.nrs_phypig.sample_time IS 'Time of sample collection';
COMMENT ON TABLE anmn.nrs_phypig
  IS 'Metadata harvested from NRS water-sampling data (Phytoplankton HPLC pigments) in Excel spreadsheets.';

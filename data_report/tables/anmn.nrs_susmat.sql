
-- DROP TABLE anmn.nrs_susmat

CREATE TABLE anmn.nrs_susmat
(
  pkid serial NOT NULL,
  sample_time timestamp with time zone NOT NULL,
  site_code character(6) NOT NULL,
  sample_lat double precision NOT NULL,
  sample_lon double precision NOT NULL,
  sample_depth real NOT NULL,
  sample_qc integer,
  sample_comment character varying(255),
  tss double precision,
  inorganic_fraction double precision,
  organic_fraction double precision,
  secchi_depth double precision,
  secchi_comment character varying(255)
) 
WITH (
  OIDS = FALSE
)
;
ALTER TABLE anmn.nrs_susmat OWNER TO report;
COMMENT ON COLUMN anmn.nrs_susmat.sample_time IS 'Time of sample collection';
COMMENT ON TABLE anmn.nrs_susmat
  IS 'Data harvested from NRS water-sampling suspended matter data in Excel spreadsheets.';

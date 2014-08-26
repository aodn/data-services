
-- DROP TABLE anmn.nrs_ctdpro;

CREATE TABLE anmn.nrs_ctdpro
(
  pkid serial NOT NULL,
  sample_time timestamp with time zone NOT NULL,
  site_code character(6) NOT NULL,
  file_version int,
  processing_time timestamp with time zone,
  first_indexed timestamp with time zone NOT NULL,
  last_indexed timestamp with time zone NOT NULL,
  CONSTRAINT nrs_ctdpro_pkey PRIMARY KEY (pkid)
) 
WITH (
  OIDS = FALSE
);

ALTER TABLE anmn.nrs_ctdpro OWNER TO report;
COMMENT ON COLUMN anmn.nrs_ctdpro.sample_time IS 'CTD cast start time.';
COMMENT ON TABLE anmn.nrs_ctdpro
  IS 'CTD profiles from NRS water sampling program.';


-- DROP TABLE anmn.nrs_logsht;

CREATE TABLE anmn.nrs_logsht
(
  pkid serial NOT NULL,
  sample_time timestamp with time zone NOT NULL,
  site_code character(6) NOT NULL,
  file_version int,
  first_indexed timestamp with time zone NOT NULL,
  last_indexed timestamp with time zone NOT NULL,
  CONSTRAINT nrs_logsht_pkey PRIMARY KEY (pkid)
) 
WITH (
  OIDS = FALSE
);

ALTER TABLE anmn.nrs_logsht OWNER TO report;
COMMENT ON COLUMN anmn.nrs_logsht.sample_time IS 'Field trip start time.';
COMMENT ON TABLE anmn.nrs_logsht
  IS 'Field trip logsheets for NRS water sampling program.';

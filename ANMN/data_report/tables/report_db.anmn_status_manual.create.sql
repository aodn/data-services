-- Table: anmn_status_manual

-- DROP TABLE anmn_status_manual;

CREATE TABLE anmn_status_manual
(
  pkid serial NOT NULL,
  site_code character varying(10),
  platform_code character varying(30),
  deployment_code character varying(30),
  status_date date,
  status_type text,
  status_comment text,
  updated date,
  CONSTRAINT anmn_status_manual_pkey PRIMARY KEY (pkid)
)
WITH (
  OIDS=FALSE
);
ALTER TABLE anmn_status_manual OWNER TO report;
GRANT ALL ON TABLE anmn_status_manual TO report;
GRANT ALL ON TABLE anmn_status_manual TO inventory_group;

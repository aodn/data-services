-- Table: report.anmn_datacategories_manual

BEGIN;


-- delete previous table

-- DROP TABLE report.anmn_datacategories_manual;


-- create new table

CREATE TABLE report.anmn_datacategories_manual
(
  pkid serial NOT NULL,
  instr_model bpchar NOT NULL,
  data_category character varying(20),
  CONSTRAINT anmn_datacategories_manual_pkey PRIMARY KEY (pkid)
)
WITH (
  OIDS=FALSE
);
ALTER TABLE report.anmn_datacategories_manual OWNER TO report;


-- insert previous deployments
INSERT INTO report.anmn_datacategories_manual(instr_model, data_category)
VALUES  ('Aquatec Aqualogger 520','Temperature'),
	('NORTEK ADCP','Velocity'),
	('RDI ADCP','Velocity'),
	('SEABIRD SBE37SM','CTD'),
	('SEABIRD SBE39','Temperature'),
	('Teledyne RD Workhorse ADCP','Velocity'),
	('WETLABS WQM','Biogeochem');


COMMIT;

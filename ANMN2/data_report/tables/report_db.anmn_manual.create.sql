-- Table: report.anmn_manual

BEGIN;


-- delete previous table

-- DROP TABLE report.anmn_manual;


-- create new table

CREATE TABLE report.anmn_manual
(
  pkid serial NOT NULL,
  platform_code character varying(20) NOT NULL,
  deployment_code character varying(30),
  responsible_persons character varying(50),
  responsible_organisation character varying(20),
  planned_deployment_start date NOT NULL,
  planned_deployment_end date NOT NULL,
  deployment_start date,
  deployment_end date,
  CONSTRAINT anmn_manual_pkey PRIMARY KEY (pkid)
)
WITH (
  OIDS=FALSE
);
ALTER TABLE report.anmn_manual OWNER TO report;


-- insert previous deployments
INSERT INTO report.anmn_manual(platform_code, deployment_code, responsible_persons,responsible_organisation, planned_deployment_start, planned_deployment_end, deployment_start, deployment_end)  VALUES
	('PH100','PH100-1101','Moninya Roughan / Brad Morris','SIMS / OFS','2010-12-28','2011-01-28','2010-12-28','2011-01-28'),
	('PH100','PH100-1102','Moninya Roughan / Brad Morris','SIMS / OFS','2011-01-23','2011-03-04','2011-01-23','2011-03-04'),
	('PH100','PH100-1103','Moninya Roughan / Brad Morris','SIMS / OFS','2011-02-22','2011-03-31','2011-02-22','2011-03-31'),
	('PH100','PH100-1104','Moninya Roughan / Brad Morris','SIMS / OFS','2011-03-27','2011-05-15','2011-03-27','2011-05-15'),
	('PH100','PH100-1105','Moninya Roughan / Brad Morris','SIMS / OFS','2011-05-02','2011-06-23','2011-05-02','2011-06-23'),
	('PH100','PH100-1106','Moninya Roughan / Brad Morris','SIMS / OFS','2011-06-16','2011-09-02','2011-06-16','2011-09-02'),

--	('KIM050','KIM050-1202','Craig Steinberg','AIMS','2012-02-01','2012-07-20','2012-02-01',NULL),
--	('KIM100','KIM100-1202','Craig Steinberg','AIMS','2012-02-01','2012-07-20','2012-02-01',NULL),
--	('KIM200','KIM200-1202','Craig Steinberg','AIMS','2012-02-02','2012-07-20','2012-02-02',NULL),
--	('KIM400','KIM400-1202','Craig Steinberg','AIMS','2012-02-03','2012-07-20','2012-02-03',NULL);

-- insert planned deployments for 2012-2013
INSERT INTO report.anmn_manual(platform_code, responsible_persons,responsible_organisation, planned_deployment_start, planned_deployment_end)  VALUES
        ('CH070','Moninya Roughan / Brad Morris','SIMS / UNSW','2012-07-15','2012-09-15'),
        ('CH070','Moninya Roughan / Brad Morris','SIMS / UNSW','2012-09-15','2012-11-15'),
	('CH070','Moninya Roughan / Brad Morris','SIMS / UNSW','2012-11-15','2013-01-15'),
	('CH070','Moninya Roughan / Brad Morris','SIMS / UNSW','2013-01-15','2013-03-15'),
	('CH070','Moninya Roughan / Brad Morris','SIMS / UNSW','2013-03-15','2013-05-15'),
	('CH070','Moninya Roughan / Brad Morris','SIMS / UNSW','2013-05-15','2013-06-15'),

	('CH100','Moninya Roughan / Brad Morris','SIMS / UNSW','2012-07-15','2012-09-15'),
	('CH100','Moninya Roughan / Brad Morris','SIMS / UNSW','2012-09-15','2012-11-15'),
	('CH100','Moninya Roughan / Brad Morris','SIMS / UNSW','2012-11-15','2013-01-15'),
	('CH100','Moninya Roughan / Brad Morris','SIMS / UNSW','2013-01-15','2013-03-15'),
	('CH100','Moninya Roughan / Brad Morris','SIMS / UNSW','2013-03-15','2013-05-15'),
	('CH100','Moninya Roughan / Brad Morris','SIMS / UNSW','2013-05-15','2013-06-15'),

	('SYD100','Moninya Roughan / Brad Morris','SIMS / OFS','2012-07-15','2012-10-15'),
	('SYD100','Moninya Roughan / Brad Morris','SIMS / OFS','2012-10-15','2013-01-15'),
	('SYD100','Moninya Roughan / Brad Morris','SIMS / OFS','2013-01-15','2013-04-15'),
	('SYD100','Moninya Roughan / Brad Morris','SIMS / OFS','2013-04-15','2013-06-15'),

	('SYD140','Moninya Roughan / Brad Morris','SIMS / OFS','2012-08-15','2012-11-15'),
	('SYD140','Moninya Roughan / Brad Morris','SIMS / OFS','2012-11-15','2013-02-15'),
	('SYD140','Moninya Roughan / Brad Morris','SIMS / OFS','2013-02-15','2013-05-15'),
	('SYD140','Moninya Roughan / Brad Morris','SIMS / OFS','2013-05-15','2013-06-15'),

	('PH100','Moninya Roughan / Brad Morris','SIMS / OFS','2012-06-15','2012-09-15'),
	('PH100','Moninya Roughan / Brad Morris','SIMS / OFS','2012-09-15','2012-12-15'),
	('PH100','Moninya Roughan / Brad Morris','SIMS / OFS','2012-12-15','2013-03-15'),
	('PH100','Moninya Roughan / Brad Morris','SIMS / OFS','2013-03-15','2013-05-15'),
	('PH100','Moninya Roughan / Brad Morris','SIMS / OFS','2013-05-15','2013-06-15'),

        ('BMP090','Moninya Roughan / Brad Morris','SIMS / UNSW','2012-07-15','2012-09-15'),
        ('BMP090','Moninya Roughan / Brad Morris','SIMS / UNSW','2012-09-15','2012-11-15'),
	('BMP090','Moninya Roughan / Brad Morris','SIMS / UNSW','2012-11-15','2013-01-15'),
	('BMP090','Moninya Roughan / Brad Morris','SIMS / UNSW','2013-01-15','2013-03-15'),
	('BMP090','Moninya Roughan / Brad Morris','SIMS / UNSW','2013-03-15','2013-05-15'),
	('BMP090','Moninya Roughan / Brad Morris','SIMS / UNSW','2013-05-15','2013-06-15'),

	('BMP120','Moninya Roughan / Brad Morris','SIMS / UNSW','2012-07-15','2012-09-15'),
	('BMP120','Moninya Roughan / Brad Morris','SIMS / UNSW','2012-09-15','2012-11-15'),
	('BMP120','Moninya Roughan / Brad Morris','SIMS / UNSW','2012-11-15','2013-01-15'),
	('BMP120','Moninya Roughan / Brad Morris','SIMS / UNSW','2013-01-15','2013-03-15'),
	('BMP120','Moninya Roughan / Brad Morris','SIMS / UNSW','2013-03-15','2013-05-15'),
	('BMP120','Moninya Roughan / Brad Morris','SIMS / UNSW','2013-05-15','2013-06-15');


COMMIT;

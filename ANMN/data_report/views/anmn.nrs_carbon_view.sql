
DROP VIEW IF EXISTS anmn.nrs_carbon_view;

CREATE OR REPLACE VIEW anmn.nrs_carbon_view AS
  SELECT 
    site_code,
    sample_date,
    count(*) AS n_sample,
    sum(sample_ok::int) AS n_ok,
    (avg(n_params_ok)/0.02)::int AS percent_ok,
    date(min(first_indexed) at time zone 'UTC') AS first_indexed,
    date(max(last_indexed) at time zone 'UTC') AS last_indexed
  FROM (SELECT
          site_code,
    	  date(sample_time at time zone 'UTC') AS sample_date,
    	  tco2_qc != 4 AND tco2_qc != 9 AND talkalinity_qc != 4 AND talkalinity_qc != 9 AS sample_ok,
	  (tco2_qc != 4 AND tco2_qc != 9)::int + (talkalinity_qc != 4 AND talkalinity_qc != 9)::int AS n_params_ok,
	  first_indexed,
	  last_indexed
  	FROM anmn.nrs_carbon) AS carbon_prep
  GROUP BY site_code, sample_date
  ORDER BY site_code, sample_date;


GRANT ALL ON TABLE anmn.nrs_carbon_view TO report;

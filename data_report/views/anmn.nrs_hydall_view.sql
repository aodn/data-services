
DROP VIEW IF EXISTS anmn.nrs_hydall_view;

CREATE OR REPLACE VIEW anmn.nrs_hydall_view AS
  SELECT 
    site_code,
    sample_date,
    count(*) AS n_sample,
    sum(sample_ok::int) AS n_ok,
    (avg(n_params_ok)/0.05)::int AS percent_ok,
    date(min(first_indexed) at time zone 'UTC') AS first_indexed,
    date(max(last_indexed) at time zone 'UTC') AS last_indexed
  FROM (SELECT
          site_code,
    	  date(sample_time at time zone 'UTC') AS sample_date,
    	  least(salinity_qc, silicate_qc, nitrate_nitrite_qc, phosphate_qc, ammonium_qc) < 3 AS sample_ok,
	  (salinity_qc<3)::int + (silicate_qc<3)::int + (nitrate_nitrite_qc<3)::int + 
	  		       	 (phosphate_qc<3)::int + (ammonium_qc<3)::int  AS n_params_ok,
	  first_indexed,
	  last_indexed
  	FROM anmn.nrs_hydall) AS hydall_prep
  GROUP BY site_code, sample_date
  ORDER BY site_code, sample_date;

GRANT ALL ON TABLE anmn.nrs_hydall_view TO report;

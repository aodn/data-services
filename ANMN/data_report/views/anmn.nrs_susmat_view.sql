
DROP VIEW IF EXISTS anmn.nrs_susmat_view;

CREATE OR REPLACE VIEW anmn.nrs_susmat_view AS
  SELECT
    site_code,
    sample_date,
    count(*) AS n_sample,
    sum(sample_ok::int) AS n_ok,
    avg(sample_ok::int)::int*100 AS percent_ok,
    date(min(first_indexed) at time zone 'UTC') AS first_indexed,
    date(max(last_indexed) at time zone 'UTC') AS last_indexed
  FROM (SELECT
          site_code,
          date(sample_time at time zone 'UTC') AS sample_date,
	  sample_qc < 3 AS sample_ok,
	  first_indexed,
	  last_indexed
  	FROM anmn.nrs_susmat) AS susmat_prep
  GROUP BY site_code, sample_date
  ORDER BY site_code, sample_date;

GRANT ALL ON TABLE anmn.nrs_susmat_view TO report;


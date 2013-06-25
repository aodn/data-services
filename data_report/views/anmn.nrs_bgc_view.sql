
-- DROP VIEW anmn.nrs_bgc

CREATE OR REPLACE VIEW anmn.nrs_bgc_view AS
  SELECT 
    product,
    site_code,
    date(sample_time) AS sample_date,
    count(*) AS n_samples,
    sum((sample_qc=0)::int) AS n_nonqc,
    sum((sample_qc=1 OR sample_qc=2)::int) AS n_good,
    sum((sample_qc=3 OR sample_qc=4)::int) AS n_bad,
    sum((sample_qc=9)::int) AS n_missing
  FROM (SELECT * FROM anmn.nrs_hydall_view
        UNION
        SELECT * FROM anmn.nrs_susmat_view) AS all_products
  GROUP BY product, site_code, sample_date
  ORDER BY product, site_code, sample_date;

GRANT ALL ON TABLE anmn.nrs_bgc_view TO report;

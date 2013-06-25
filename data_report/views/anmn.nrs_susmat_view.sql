
-- DROP VIEW anmn.nrs_susmat

CREATE OR REPLACE VIEW anmn.nrs_susmat_view AS
  SELECT
    'SUSMAT'::text AS product,
    site_code,
    sample_time at time zone 'UTC' AS sample_time,
    sample_depth,
--    count(*) AS n_sample,
    min(sample_qc) AS sample_qc,
    max(sample_qc) AS worst_qc,
    max(sample_comment)::text AS sample_comment,
    min(first_indexed) at time zone 'UTC' AS first_indexed,
    max(last_indexed) at time zone 'UTC' AS last_indexed
  FROM anmn.nrs_susmat
  GROUP BY site_code,sample_time,sample_depth
  ORDER BY site_code,sample_time,sample_depth;

GRANT ALL ON TABLE anmn.nrs_susmat_view TO report;


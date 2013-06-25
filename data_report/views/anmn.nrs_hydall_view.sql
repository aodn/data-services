
-- DROP VIEW anmn.nrs_hydall

CREATE OR REPLACE VIEW anmn.nrs_hydall_view AS
  SELECT
    'HYDALL'::text AS product,
    site_code,
    sample_time at time zone 'UTC' AS sample_time,
    sample_depth,
    least(salinity_qc, silicate_qc, nitrate_nitrite_qc, phosphate_qc, ammonium_qc) AS sample_qc,
    greatest(salinity_qc, silicate_qc, nitrate_nitrite_qc, phosphate_qc, ammonium_qc) AS worst_qc,
    sample_comment::text,
    first_indexed at time zone 'UTC' AS first_indexed,
    last_indexed at time zone 'UTC' AS last_indexed
  FROM anmn.nrs_hydall
  ORDER BY site_code,sample_time,sample_depth;

GRANT ALL ON TABLE anmn.nrs_hydall_view TO report;

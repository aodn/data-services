
DROP VIEW IF EXISTS anmn.nrs_ctdpro_view;

CREATE OR REPLACE VIEW anmn.nrs_ctdpro_view AS
  SELECT
    NULL::character(6) AS site_code,
    NULL::date AS sample_date,
    NULL::bigint AS n_sample,
    NULL::bigint AS n_ok,
    NULL::integer AS percent_ok,
    NULL::date AS first_indexed,
    NULL::date AS last_indexed
  GROUP BY site_code, sample_date
  ORDER BY site_code, sample_date;

GRANT ALL ON TABLE anmn.nrs_ctdpro_view TO report;

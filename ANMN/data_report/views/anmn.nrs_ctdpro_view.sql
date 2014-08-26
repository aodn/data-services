
DROP VIEW IF EXISTS anmn.nrs_ctdpro_view;

CREATE OR REPLACE VIEW anmn.nrs_ctdpro_view AS
  SELECT
    site_code,
    date(sample_time at time zone 'UTC')  AS sample_date,
    count(*) AS n_sample,
    NULL::bigint AS n_ok,
    NULL::integer AS percent_ok,
    date(min(first_indexed) at time zone 'UTC') AS first_indexed,
    date(max(last_indexed) at time zone 'UTC') AS last_indexed
  FROM anmn.nrs_ctdpro
  GROUP BY site_code, sample_date
  ORDER BY site_code, sample_date;

GRANT ALL ON TABLE anmn.nrs_ctdpro_view TO report;

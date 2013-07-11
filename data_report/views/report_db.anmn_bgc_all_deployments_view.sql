
DROP VIEW IF EXISTS report.anmn_bgc_all_deployments_view;

CREATE OR REPLACE VIEW report.anmn_bgc_all_deployments_view AS

  WITH all_dates AS (
       SELECT DISTINCT *
       FROM (SELECT site_code, sample_date FROM anmn.nrs_logsht_view UNION
--       	     SELECT site_code, sample_date FROM anmn.nrs_ctdpro_view UNION
       	     SELECT site_code, sample_date FROM anmn.nrs_hydall_view UNION
       	     SELECT site_code, sample_date FROM anmn.nrs_susmat_view UNION
       	     SELECT site_code, sample_date FROM anmn.nrs_carbon_view UNION
       	     SELECT site_code, sample_date FROM anmn.nrs_phypig_view) AS all_dates
       )

  SELECT 
    site_code,
    site_name,
    sample_date,
    n_logsht,
    NULL::int       AS ns_ctdpro,
    hydall.n_sample AS ns_hydall,
    susmat.n_sample AS ns_susmat,
    carbon.n_sample AS ns_carbon,
    phypig.n_sample AS ns_phypig,
    NULL::int	    AS ns_zoo,
    NULL::int	    AS ns_phyto,

    NULL::int   AS nok_ctdpro,
    hydall.n_ok AS nok_hydall,
    susmat.n_ok AS nok_susmat,
    carbon.n_ok AS nok_carbon,
    phypig.n_ok AS nok_phypig,
    NULL::int   AS nok_zoo,
    NULL::int   AS nok_phyto,

    NULL::text AS status_ctdpro,
    hydall.n_ok::text||'/'||hydall.n_sample::text AS status_hydall,
    susmat.n_ok::text||'/'||susmat.n_sample::text AS status_susmat,
    carbon.n_ok::text||'/'||carbon.n_sample::text AS status_carbon,
    phypig.n_ok::text||'/'||phypig.n_sample::text AS status_phypig,
    NULL::text AS status_zoo,
    NULL::text AS status_phyto

  FROM all_dates LEFT JOIN anmn.nrs_logsht_view logsht  USING (site_code, sample_date)
--       		 LEFT JOIN anmn.nrs_ctdpro_view ctdpro  USING (site_code, sample_date)
       		 LEFT JOIN anmn.nrs_hydall_view hydall  USING (site_code, sample_date)
       		 LEFT JOIN anmn.nrs_susmat_view susmat  USING (site_code, sample_date)
       		 LEFT JOIN anmn.nrs_carbon_view carbon  USING (site_code, sample_date)
       		 LEFT JOIN anmn.nrs_phypig_view phypig  USING (site_code, sample_date)
		 LEFT JOIN report.anmn_sites_view USING (site_code)

  ORDER BY site_code, sample_date;

GRANT ALL ON TABLE report.anmn_bgc_all_deployments_view TO report;


DROP VIEW IF EXISTS report.anmn_bgc_all_deployments_view;

CREATE OR REPLACE VIEW report.anmn_bgc_all_deployments_view AS

  SELECT 
    site_code,
    site_name || ' (' || site_code || ')' AS site_name_code,
    sample_date,
    n_logsht,
    ctdpro.n_sample AS ns_ctdpro,
    hydall.n_sample AS ns_hydall,
    susmat.n_sample AS ns_susmat,
    carbon.n_sample AS ns_carbon,
    phypig.n_sample AS ns_phypig,
    zoo.n_sample    AS ns_zoo,
    NULL::int	    AS ns_phyto,

    NULL::int   AS nok_ctdpro,
    hydall.n_ok AS nok_hydall,
    susmat.n_ok AS nok_susmat,
    carbon.n_ok AS nok_carbon,
    phypig.n_ok AS nok_phypig,
    zoo.n_ok    AS nok_zoo,
    NULL::int   AS nok_phyto,

    ctdpro.n_sample::text AS status_ctdpro,
    hydall.n_ok::text||'/'||hydall.n_sample::text AS status_hydall,
    susmat.n_ok::text||'/'||susmat.n_sample::text AS status_susmat,
    carbon.n_ok::text||'/'||carbon.n_sample::text AS status_carbon,
    phypig.n_ok::text||'/'||phypig.n_sample::text AS status_phypig,
    zoo.n_ok::text||'/'||zoo.n_sample::text AS status_zoo,
    NULL::text AS status_phyto

  FROM anmn.nrs_logsht_view logsht FULL JOIN
       anmn.nrs_ctdpro_view ctdpro USING (site_code, sample_date)  FULL JOIN
       anmn.nrs_hydall_view hydall USING (site_code, sample_date)  FULL JOIN
       anmn.nrs_susmat_view susmat USING (site_code, sample_date)  FULL JOIN
       anmn.nrs_carbon_view carbon USING (site_code, sample_date)  FULL JOIN
       anmn.nrs_phypig_view phypig USING (site_code, sample_date)  FULL JOIN
       anmn.nrs_zoo_view    zoo    USING (site_code, sample_date)  JOIN 
       report.anmn_sites_view USING (site_code)

  ORDER BY site_code, sample_date;

GRANT ALL ON TABLE report.anmn_bgc_all_deployments_view TO report;

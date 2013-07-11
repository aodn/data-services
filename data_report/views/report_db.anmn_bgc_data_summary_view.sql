
DROP VIEW IF EXISTS report.anmn_bgc_data_summary_view;

CREATE OR REPLACE VIEW report.anmn_bgc_data_summary_view AS
   SELECT
     site_code,
     site_name,
     product,
     min(sample_date) AS first_sample,
     max(sample_date) AS last_sample,
     (count(*) / ((max(sample_date) - min(sample_date))::float / 365))::int AS trip_per_year,
     count(*) AS ntrip_total,
     sum((n_ok = n_sample)::int) AS ntrip_full_data,
     sum((n_ok > 0 AND n_ok < n_sample)::int) AS ntrip_partial_data,
     sum((n_ok = 0)::int) AS ntrip_no_data,
     (sum(n_ok) / sum(n_sample) * 100)::int AS percent_ok,
     max(last_indexed) AS last_harvested,
     max(first_indexed) AS last_data_update
   FROM (SELECT *, 'Nutrients' AS product FROM anmn.nrs_hydall_view UNION
	 SELECT *, 'Suspended matter' AS product FROM anmn.nrs_susmat_view UNION
	 SELECT *, 'Carbon' AS product FROM anmn.nrs_carbon_view UNION
	 SELECT *, 'Pigments' AS product FROM anmn.nrs_phypig_view  UNION
    	 SELECT site_code, sample_date, NULL, NULL, NULL, first_indexed, last_indexed, 'Field logsheets' as product FROM anmn.nrs_logsht_view
        ) AS all_products
    	LEFT JOIN report.anmn_sites_view USING (site_code)
   GROUP BY site_code, site_name, product
   ORDER BY site_name, product;


GRANT ALL ON TABLE report.anmn_bgc_data_summary_view TO report;

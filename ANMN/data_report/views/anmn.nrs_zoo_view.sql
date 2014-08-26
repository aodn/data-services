
DROP VIEW IF EXISTS anmn.nrs_zoo_view;

CREATE OR REPLACE VIEW anmn.nrs_zoo_view AS
  SELECT
    site_code,
    sample_date,
    count(*) AS n_sample,
    sum(ok::int) AS n_ok,
    (sum(ok::int)*100./count(*))::int AS percent_ok,
    NULL::date AS first_indexed,
    NULL::date AS last_indexed
  FROM ( (SELECT 
	    'NRS' || substr(nrs_code,1,3) AS site_code,
	    date(sample_date) AS sample_date,
	    mg_per_m3>0 AS ok
	  FROM cpr.csiro_harvest_nrs_biomass
	 )
    	  UNION ALL
         (SELECT 
	    'NRS' || substr(nrs_code,1,3) AS site_code,
	    date(sample_date) AS sample_date,
	    bool_or(taxon_per_m3>0) AS ok
	  FROM cpr.csiro_harvest_nrs_zooplankton
	  GROUP BY nrs_code, sample_date
	 )
       ) as zoo_all	
  GROUP BY site_code, sample_date
  ORDER BY site_code, sample_date;

GRANT ALL ON TABLE anmn.nrs_zoo_view TO report;

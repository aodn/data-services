SELECT sub_facility, site_name, deployment_code,  
			bool_or(date_first_processed <> date_last_processed) AS reprocessed,
      bool_or(date_first_upload = date_last_upload) AS new_upload, 
			bool_or(date_first_public = date_last_public) AS new_public,
			max(date_last_public)
FROM anmn_deployments_view
WHERE date_first_public > '2012-12-18' 
GROUP BY sub_facility, site_name, deployment_code
ORDER BY sub_facility, site_name, deployment_code;
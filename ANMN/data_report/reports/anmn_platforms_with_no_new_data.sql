-- view for ANMN data report

SELECT sub_facility, site, platform_code, 
	min(days_since_deployment_end) AS days_since_last_deployment_end, 
	min(days_since_uploaded) AS days_since_last_upload
FROM report.anmn_regions_view
GROUP BY sub_facility, site, platform_code
HAVING min(days_since_uploaded) > 10
ORDER BY sub_facility, site, platform_code, days_since_last_upload

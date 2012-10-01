SELECT sub_facility, site, platform_code, deployment_code, 
       date(min(time_coverage_start)) AS time_coverage_start, 
       date(max(time_coverage_end)) AS time_coverage_end,
       date(max(date_public)) AS date_on_portal,
       count(platform_code) AS number_of_files
FROM report.anmn_regions_view
WHERE time_since_public < interval '1 months'
GROUP BY sub_facility, site, platform_code, deployment_code
ORDER BY sub_facility, site, platform_code, deployment_code;

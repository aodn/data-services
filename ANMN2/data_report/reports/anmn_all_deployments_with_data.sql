SELECT sub_facility, site, platform_code, deployment_code,
       date(min(time_coverage_start)) AS time_coverage_start, 
       date(max(time_coverage_end)) AS time_coverage_end,
       date_trunc('day', avg(processing_interval)) AS "Mean processing time",
       date_trunc('day', avg(publication_interval)) AS "Mean time to publish"
FROM report.anmn_regions_view
GROUP BY sub_facility, site, platform_code, deployment_code
ORDER BY sub_facility, site, platform_code, deployment_code;

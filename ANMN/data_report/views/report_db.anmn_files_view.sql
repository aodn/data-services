-- View: anmn_files_view

-- DROP VIEW anmn_files_view;

CREATE OR REPLACE VIEW anmn_files_view AS 
 SELECT DISTINCT 
	substring(url from 'IMOS/ANMN/([A-Z]+)/') AS sub_facility, 
	site_code, 
	platform_code, 
	deployment_code, 
	substring(url from '([^_]+)_END') AS deployment_product,
 	substring(url from '[^/]+nc') AS file_name,
	status,
	toolbox_version,
	substring(file_version from 'Level ([012]+)') AS file_version, 
 	institution,
	substring(url from '(Temperature|CTD_timeseries|CTD_profiles|Biogeochem_timeseries|Biogeochem_profiles|Velocity|Wave|CO2|Meteorology)') AS data_category,
	source, 
	instrument, 
	instrument_serial_number,
	instrument_nominal_depth,
	geospatial_vertical_min, 
	geospatial_vertical_max, 
	time_coverage_start AT TIME ZONE 'UTC' AS time_coverage_start, 
	time_coverage_end AT TIME ZONE 'UTC' AS time_coverage_end, 
	time_deployment_start AT TIME ZONE 'UTC' AS time_deployment_start,
	time_deployment_end AT TIME ZONE 'UTC' AS time_deployment_end,
	greatest(time_deployment_start, time_coverage_start) AT TIME ZONE 'UTC' AS good_data_start,
	least(time_deployment_end, time_coverage_end)  AT TIME ZONE 'UTC' AS good_data_end,
	time_coverage_end - time_coverage_start AS coverage_duration,
	time_deployment_end - time_deployment_start AS deployment_duration,
	greatest(interval '0',least(time_deployment_end,time_coverage_end)-greatest(time_deployment_start,time_coverage_start)) AS good_data_duration,
	date(date_created AT TIME ZONE 'UTC') AS date_processed,
	date(last_modified AT TIME ZONE 'UTC') AS date_uploaded,
	date(first_indexed AT TIME ZONE 'UTC') AS date_public,
        date_part('day', last_modified - time_deployment_end) AS processing_duration,
        date_part('day', first_indexed - last_modified) AS publication_duration,
        date_part('day', now() - time_deployment_end) AS days_since_deployment_end,
        date_part('day', now() - last_modified) AS days_since_uploaded,
        date_part('day', now() - first_indexed) AS days_since_public
   FROM anmn.anmn_mv
--  WHERE platform_code IS NOT NULL
  ORDER BY sub_facility, deployment_code, data_category;

ALTER TABLE anmn_files_view OWNER TO report;
GRANT ALL ON TABLE anmn_files_view TO report;
GRANT SELECT, REFERENCES ON TABLE anmn_files_view TO gisread;
GRANT ALL ON TABLE anmn_files_view TO gisadmin;

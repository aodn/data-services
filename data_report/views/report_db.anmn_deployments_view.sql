-- View: anmn_deployments_view

-- DROP VIEW anmn_deployments_view;

CREATE OR REPLACE VIEW anmn_deployments_view AS
  SELECT 
       sub_facility, site_code, site_name, data_category, deployment_code,  
       sum((file_version='0')::int) AS num_fv00,
       sum((file_version='1')::int) AS num_fv01,
       min(geospatial_vertical_min) AS min_depth,
       max(geospatial_vertical_max) AS max_depth,
       date(min(time_deployment_start)) AS deployment_start,
       date(max(time_deployment_end)) AS deployment_end,
       date(min(good_data_start)) AS good_data_start, 
       date(max(good_data_end)) AS good_data_end, 
       date_part('day', max(time_deployment_end) - min(time_deployment_start)) AS deployed_days,
       date_part('day', max(good_data_end) - min(good_data_start)) AS good_data_days,
       min(date_processed) AS date_first_processed,
       max(date_processed) AS date_last_processed,
       min(date_uploaded) AS date_first_upload,
       max(date_uploaded) AS date_last_upload,
       min(date_public) AS date_first_public,
       max(date_public) AS date_last_public,
       min(processing_duration) AS processing_duration,
       min(publication_duration) AS publication_duration,
       min(days_since_deployment_end) AS days_since_deployment_end,
       max(days_since_uploaded) AS days_since_uploaded,
       max(days_since_public) AS days_since_public
  FROM anmn_files_view NATURAL LEFT JOIN anmn_sites_view
  WHERE status IS NULL
  GROUP BY sub_facility, site_code, site_name, data_category, deployment_code
  ORDER BY sub_facility, site_code, data_category, deployment_code;

ALTER TABLE anmn_deployments_view OWNER TO report;
GRANT ALL ON TABLE anmn_deployments_view  TO report;
GRANT SELECT, REFERENCES ON TABLE anmn_deployments_view  TO gisread;
GRANT ALL ON TABLE anmn_deployments_view  TO gisadmin;


-- This table has one row for each group of files belonging to the same site, deployment and data category.
-- Columns:
-- sub_facility
-- site_code
-- data_category
-- deployment_code
-- num_files = number of files in group
-- min_depth = minimum actual depth recorded in group
-- max_depth = maximum actual depth recorded in group
-- deployment_start = earliest time_deployment_start (UTC date)
-- deployment_end = latest time_deployment_end (UTC date)
-- good_data_start = first date (UTC) after deployment start for which at least one file in the group has data
-- good_data_end = last date (UTC) before deployment end for which at least one file has data
-- deployed_days = number of days from deployment start to end
-- good_data_days = number of days within deployment period for which at least one file in group has data
-- processing_duration = shortest time (days) taken from deployment end to file upload
-- publication_duration = shortest time (days) taken from upload to file being publicly available
-- days_since_uploaded = days elapsed since the first file in this group was uploaded
-- days_since_public = days elapsed since the first file in this group was made public

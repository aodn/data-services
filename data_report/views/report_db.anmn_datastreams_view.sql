-- View: anmn_datastreams_view

-- DROP VIEW anmn_datastreams_view;

CREATE OR REPLACE VIEW anmn_datastreams_view AS
  WITH group_by_dataCategory AS (
       SELECT sub_facility, site_code, data_category, 
       	      count(*) AS num_deployments,
       	      max(num_fv00) AS max_fv00_per_deployment, 
       	      max(num_fv01) AS max_fv01_per_deployment, 
       	      min(min_depth) AS min_depth, 
       	      max(max_depth) AS max_depth, 
       	      min(deployment_start) AS first_deployment_start, 
       	      max(deployment_end) AS last_deployment_end, 
       	      min(good_data_start) AS good_data_start, 
       	      max(good_data_end) AS good_data_end,
       	      max(date_last_processed) AS latest_processing, 
       	      max(date_last_upload) AS latest_upload,
	      max(date_last_public) AS latest_public,
	      max(deployment_end) - min(deployment_start) AS deployments_span_days,
       	      sum(good_data_days) AS total_good_data_days
       FROM anmn_deployments_view
       GROUP BY sub_facility, site_code, data_category
       ORDER BY sub_facility, site_code, data_category
  )
  SELECT *,
  	 deployments_span_days - total_good_data_days AS total_gap_days,
	 (total_good_data_days / deployments_span_days * 100)::int AS percent_coverage
  FROM group_by_dataCategory NATURAL LEFT JOIN anmn_sites_view
  ORDER BY sub_facility, site_code, data_category;

ALTER TABLE anmn_datastreams_view OWNER TO report;
GRANT ALL ON TABLE anmn_datastreams_view  TO report;
GRANT SELECT, REFERENCES ON TABLE anmn_datastreams_view  TO gisread;
GRANT ALL ON TABLE anmn_datastreams_view  TO gisadmin;

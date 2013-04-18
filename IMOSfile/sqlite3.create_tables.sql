
DROP TABLE IF EXISTS staging;

CREATE TABLE staging
(  
  source_path character varying,
  filename character varying,
  extension character varying,
  dest_path character varying,
  facility character varying,
  sub_facility character varying,
  data_code character varying,
  data_category character varying,
  site_code character varying,
  platform_code character varying,
  file_version character varying,
  product_code character varying,
  deployment_code character varying,
  instrument character varying,
  instrument_depth real,
  filename_errors character varying,
  start_time timestamp with time zone,
  end_time timestamp with time zone,
  creation_time timestamp with time zone
);


DROP TABLE IF EXISTS opendap;

CREATE TABLE opendap
(  
  source_path character varying,
  filename character varying,
  extension character varying,
  dest_path character varying,
  facility character varying,
  sub_facility character varying,
  data_code character varying,
  data_category character varying,
  site_code character varying,
  platform_code character varying,
  file_version character varying,
  product_code character varying,
  deployment_code character varying,
  instrument character varying,
  instrument_depth real,
  filename_errors character varying,
  start_time timestamp with time zone,
  end_time timestamp with time zone,
  creation_time timestamp with time zone
);


DROP VIEW IF EXISTS move_view;

CREATE VIEW move_view AS
  SELECT staging.source_path,
         staging.filename,
         staging.dest_path,
         staging.creation_time,
         opendap.filename AS old_file,
         opendap.source_path AS old_path,
         opendap.creation_time AS old_creation_time
  FROM staging LEFT JOIN opendap USING (product_code, file_version);

-- DROP TABLE staging

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


-- DROP TABLE opendap

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

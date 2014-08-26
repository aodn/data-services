-- views to find and archive duplicate files on opendap

-- WARNING: filenames ending in _PARTn are not accounted for!

CREATE VIEW odap_grp AS
  SELECT product_code, 
  	 file_version, 
	 count(*) AS n_files, 
	 min(creation_time) AS first_created, 
	 max(creation_time) AS last_created
  FROM opendap
  GROUP BY product_code, file_version;


CREATE VIEW duplicates AS
  SELECT source_path,
  	 filename,
         replace(dest_path, 't3/IMOS/opendap', 't4/IMOS/archive') AS archive_path,
	 creation_time,
	 sub_facility,
	 product_code,
	 file_version
  FROM odap_grp LEFT JOIN opendap  USING (product_code, file_version)
  WHERE n_files > 1  AND  creation_time != last_created;

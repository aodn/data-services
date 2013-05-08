
DROP VIEW IF EXISTS good_to_go;

CREATE VIEW good_to_go AS
  SELECT source_path,
  	 filename,
	 dest_path,
	 creation_time,
	 sub_facility,
	 product_code,
	 file_version,
	 n_files,
	 nullif(first_created, last_created) AS first_created
  FROM (SELECT 
          product_code,
          file_version,
          count(*) AS n_files,
	  min(creation_time) AS first_created,
          max(creation_time) AS last_created
        FROM staging
        WHERE filename_errors IS NULL  AND
	      dest_path IS NOT NULL    AND
	      extension = 'nc'
        GROUP BY product_code, file_version
       ) AS grouped 
       JOIN staging 
       USING (product_code, file_version)
  WHERE creation_time == last_created;


DROP VIEW IF EXISTS move_view;

CREATE VIEW move_view AS
  SELECT good_to_go.*,
         opendap.filename AS old_file,
         opendap.source_path AS old_path,
         opendap.creation_time AS old_creation_time
  FROM good_to_go LEFT JOIN opendap USING (product_code, file_version);
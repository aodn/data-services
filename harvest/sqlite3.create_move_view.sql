
DROP VIEW IF EXISTS staging_nc_good;

CREATE VIEW staging_nc_good AS
  SELECT *,
  	 product_code || file_version || data_category || coalesce(dataset_part,'') AS dataset_id
  FROM staging
  WHERE filename_errors IS NULL  AND
        dest_path IS NOT NULL    AND
        extension = 'nc';


DROP VIEW IF EXISTS staging_nc_grouped;

CREATE VIEW staging_nc_grouped AS
  SELECT dataset_id,
         count(*) AS n_files,
	 min(creation_time) AS first_created,
         max(creation_time) AS last_created
  FROM staging_nc_good
  GROUP BY dataset_id;


DROP VIEW IF EXISTS good_to_go;

CREATE VIEW good_to_go AS
  SELECT source_path,
  	 filename,
	 dest_path,
	 creation_time,
	 sub_facility,
	 product_code,
	 file_version,
	 dataset_id,
	 n_files,
	 nullif(first_created, last_created) AS first_created
  FROM staging_nc_grouped LEFT JOIN staging_nc_good USING (dataset_id)
  WHERE creation_time == last_created;


DROP VIEW IF EXISTS move_view;

CREATE VIEW move_view AS
  SELECT good_to_go.*,
         op.filename AS old_file,
         op.source_path AS old_path,
         op.creation_time AS old_creation_time
  FROM good_to_go LEFT JOIN opendap op
         ON (dataset_id = op.product_code || op.file_version || op.data_category || coalesce(op.dataset_part,''));

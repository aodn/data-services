
SELECT 
  min(staging.filename) AS first_file,
  staging.dest_path
FROM staging LEFT JOIN opendap USING (filename)
WHERE opendap.source_path IS NOT NULL
GROUP BY staging.dest_path;

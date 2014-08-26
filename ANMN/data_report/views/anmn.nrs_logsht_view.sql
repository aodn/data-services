
DROP VIEW IF EXISTS anmn.nrs_logsht_view;

CREATE OR REPLACE VIEW anmn.nrs_logsht_view AS
  SELECT
    site_code,
    sample_date,
    count(*) AS n_logsht,
    date(min(first_indexed) at time zone 'UTC') AS first_indexed,
    date(max(last_indexed) at time zone 'UTC') AS last_indexed
  FROM (SELECT
          site_code,
	  date(sample_time at time zone 'UTC')  AS sample_date, 
	  min(first_indexed) AS first_indexed,
	  max(last_indexed) AS last_indexed
	FROM anmn.nrs_logsht
	WHERE file_version IS NOT NULL
	GROUP BY site_code, sample_time  
       ) AS logsht_prep
  GROUP BY site_code, sample_date
  ORDER BY site_code, sample_date;

GRANT ALL ON TABLE anmn.nrs_logsht_view TO report;

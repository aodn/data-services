-- View: anmn_acoustics_view

-- DROP VIEW anmn_acoustics_view;

CREATE OR REPLACE VIEW anmn_acoustics_view AS 
WITH group_by_logger AS (
  SELECT
    substring(deployment_name from E'\\D+') AS site_name,
    substring(deployment_name from '2[-0-9]+') AS deployment_years,
    logger_id,
    date(min(time_deployment_start)) AS deployment_start,
    date(max(time_deployment_end)) AS deployment_end,
    bool_or(frequency=6) AS ok_6,
    bool_or(frequency=22) AS ok_22,
    bool_or(is_primary AND data_path IS NOT NULL) AS on_ADV
  FROM anmn.acoustic_deployments
  WHERE set_success != 'Failure'
  GROUP BY site_name, deployment_years, logger_id
)
SELECT site_name, deployment_years, 
  min(deployment_start) AS deployment_start, 
  max(deployment_end) AS deployment_end,
  count(*) AS num_loggers_deployed,
  greatest( bool_or(ok_6)::int, sum((ok_6 AND ok_22)::int) ) AS num_ok,
  bool_or(on_ADV) AS on_ADV
FROM group_by_logger
GROUP BY site_name, deployment_years
ORDER BY site_name, deployment_years;

ALTER TABLE anmn_acoustics_view OWNER TO report;
GRANT ALL ON TABLE anmn_acoustics_view TO report;
GRANT SELECT, REFERENCES ON TABLE anmn_acoustics_view TO gisread;
GRANT ALL ON TABLE anmn_acoustics_view TO gisadmin;

SELECT 
  substring(deployment_name from E'\\D+') AS site_name,
  substring(deployment_name from '2[-0-9]+') AS deployment_year,
  date(min(time_deployment_start)) AS deployment_start,
  date(max(time_deployment_end)) AS deployment_end,
  bool_or(data_path IS NOT NULL) AS data_public
FROM anmn.acoustic_deployments
WHERE frequency=6 AND set_success != 'Failure'
GROUP BY site_name, deployment_year
ORDER BY site_name, deployment_year

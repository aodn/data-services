SELECT platform_code, 
       deployment_code,
       date(time_deployment_start) AS planned_deployment_start, 
       date(time_deployment_end) AS planned_deployment_end,
       date(time_deployment_start) AS deployment_start, 
       date(time_deployment_end) AS deployment_end
  FROM anmn.anmn_nsw_mv
--  WHERE deployment_code LIKE 'PH100-1%'
  GROUP BY platform_code, deployment_code, date(time_deployment_start), date(time_deployment_end)
  ORDER BY deployment_code;

-- View: anmn_sites_view

DROP VIEW anmn_sites_view;

CREATE OR REPLACE VIEW anmn_sites_view AS 
 SELECT anmn_platforms_manual.site_code, anmn_platforms_manual.site_name, avg(anmn_platforms_manual.lat) AS site_lat, avg(anmn_platforms_manual.lon) AS site_lon, avg(anmn_platforms_manual.depth)::integer AS site_depth, min(anmn_platforms_manual.first_deployed) AS site_first_deployed, max(anmn_platforms_manual.discontinued) AS site_discontinued, bool_or(anmn_platforms_manual.active) AS site_active
   FROM anmn_platforms_manual
  GROUP BY anmn_platforms_manual.site_code, anmn_platforms_manual.site_name
  ORDER BY anmn_platforms_manual.site_code;

ALTER TABLE anmn_sites_view OWNER TO report;
GRANT ALL ON TABLE anmn_sites_view TO report;
GRANT ALL ON TABLE anmn_sites_view TO inventory_group;


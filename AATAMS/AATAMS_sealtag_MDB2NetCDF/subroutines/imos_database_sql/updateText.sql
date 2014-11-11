--- UPDATE table to remove blank spaces
BEGIN;
-- remove blank and replace by _
	UPDATE aatams_sattag.ctd_device_mdb_workflow SET release_site = regexp_replace(replace((SELECT ctd_device_mdb_workflow.release_site), ' '::text, '_'::text), E'[ \t\n\r]*', '', 'g') ;
	UPDATE aatams_sattag.ctd_device_mdb_workflow SET species      = regexp_replace(replace((SELECT ctd_device_mdb_workflow.species), ' '::text, '_'::text), E'[ \t\n\r]*', '', 'g') ;
	UPDATE aatams_sattag.ctd_device_mdb_workflow SET pi           = regexp_replace(replace((SELECT ctd_device_mdb_workflow.pi), ' '::text, '_'::text), E'[ \t\n\r]*', '', 'g') ;
	UPDATE aatams_sattag.ctd_device_mdb_workflow SET tag_type = regexp_replace(replace((SELECT ctd_device_mdb_workflow.tag_type), ' '::text, '_'::text), E'[ \t\n\r]*', '', 'g') ;
	UPDATE aatams_sattag.ctd_device_mdb_workflow SET common_name = regexp_replace(replace((SELECT ctd_device_mdb_workflow.common_name), ' '::text, '_'::text), E'[ \t\n\r]*', '', 'g') ;
	UPDATE aatams_sattag.ctd_device_mdb_workflow SET nickname = regexp_replace(replace((SELECT ctd_device_mdb_workflow.nickname), ' '::text, '_'::text), E'[ \t\n\r]*', '', 'g') ;

	-- replace _ by blank
	UPDATE aatams_sattag.ctd_device_mdb_workflow SET release_site = regexp_replace(ctd_device_mdb_workflow.release_site, E'_', ' ', 'g') ;
	UPDATE aatams_sattag.ctd_device_mdb_workflow SET species = regexp_replace(ctd_device_mdb_workflow.species, E'_', ' ', 'g') ;
	UPDATE aatams_sattag.ctd_device_mdb_workflow SET pi = regexp_replace(ctd_device_mdb_workflow.pi, E'_', ' ', 'g') ;
	UPDATE aatams_sattag.ctd_device_mdb_workflow SET tag_type = regexp_replace(ctd_device_mdb_workflow.tag_type, E'_', ' ', 'g') ;
	UPDATE aatams_sattag.ctd_device_mdb_workflow SET common_name = regexp_replace(ctd_device_mdb_workflow.common_name, E'_', ' ', 'g') ;
	UPDATE aatams_sattag.ctd_device_mdb_workflow SET nickname = regexp_replace(ctd_device_mdb_workflow.nickname, E'_', ' ', 'g') ;
COMMIT;
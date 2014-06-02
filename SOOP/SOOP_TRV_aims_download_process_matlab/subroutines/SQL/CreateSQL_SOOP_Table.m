function CreateSQL_SOOP_Table()
WIP=pwd;

Filename_DB=strcat(WIP,filesep,'DB_CreateTABLE.sql'); %%SQL COMMANDS to paste on PGadmin
fid_DB = fopen(Filename_DB, 'w+');

fprintf(fid_DB,'--BEGIN;\n');
fprintf(fid_DB,'CREATE TABLE soop.soop_platforms  (\n');
fprintf(fid_DB,'"platform_code" character varying(100),\n');
fprintf(fid_DB,'"pkid" serial NOT NULL,\n');
fprintf(fid_DB,'CONSTRAINT faimms_sites_pkey PRIMARY KEY (pkid) \n )');
fprintf(fid_DB,'WITH ( \n OIDS=FALSE\n)');
fprintf(fid_DB,';\n');
fprintf(fid_DB,'ALTER TABLE soop.soop_platforms OWNER TO soop;\n');
fprintf(fid_DB,'GRANT ALL ON TABLE soop.soop_platforms TO soop;\n');
fprintf(fid_DB,'GRANT SELECT ON TABLE soop.soop_platforms TO gisread;\n');
fprintf(fid_DB,'GRANT ALL ON TABLE soop.soop_platforms TO gisadmin;\n');
fprintf(fid_DB,'--COMMIT;\n \n');


fprintf(fid_DB,'--BEGIN;\n');
fprintf(fid_DB,'CREATE TABLE soop.soop_parameters(\n');
fprintf(fid_DB,'"pkid" serial NOT NULL PRIMARY KEY,\n');
fprintf(fid_DB,'"fk_soop_platforms" integer,\n');
fprintf(fid_DB,'"channelid" integer,\n');
fprintf(fid_DB,'"sensor_name" character varying(1000),\n');
fprintf(fid_DB,'"metadata_uuid" character varying(255),\n');
fprintf(fid_DB,'"time_coverage_start" timestamp without time zone,\n');
fprintf(fid_DB,'"time_coverage_end" timestamp without time zone,\n');
fprintf(fid_DB,'"folder_datafabric" character varying(1000),\n');
fprintf(fid_DB,'"geom" geometry,\n');
fprintf(fid_DB,'CONSTRAINT fk_soop_platforms_exists FOREIGN KEY (fk_soop_platforms)\n');
fprintf(fid_DB,'REFERENCES soop.soop_platforms (pkid) \n');
fprintf(fid_DB,'ON DELETE CASCADE \n ');
fprintf(fid_DB,'ON UPDATE CASCADE \n )');
fprintf(fid_DB,';\n');
fprintf(fid_DB,'ALTER TABLE soop.soop_parameters OWNER TO soop;\n');
fprintf(fid_DB,'GRANT ALL ON TABLE soop.soop_parameters TO soop;\n');
fprintf(fid_DB,'GRANT SELECT ON TABLE soop.soop_parameters TO gisread;\n');
fprintf(fid_DB,'GRANT ALL ON TABLE soop.soop_parameters TO gisadmin;\n');
fprintf(fid_DB,'SELECT AddGeometryColumn(\''soop\'', \''soop_platforms\'', \''geom\'', 4326, \''LINESTRING\'', 2 );\n'); %% AddGeometryColumn(varchar scheme,varchar table_name, varchar column_name, integer srid, varchar type, integer dimension);
fprintf(fid_DB,'--COMMIT;\n \n');
fclose(fid_DB);

end

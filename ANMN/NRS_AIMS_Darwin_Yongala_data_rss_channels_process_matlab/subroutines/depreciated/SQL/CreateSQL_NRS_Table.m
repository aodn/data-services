function CreateSQL_NRS_Table()
global dataWIP;

Filename_DB=fullfile(dataWIP,'DB_Create_NRS_TABLE.sql'); %%SQL COMMANDS to paste on PGadmin
fid_DB = fopen(Filename_DB, 'w+');

fprintf(fid_DB,'--BEGIN;\n');
fprintf(fid_DB,'CREATE TABLE anmn.nrs_platforms  (\n');
fprintf(fid_DB,'"platform_code" character varying(100),\n');
fprintf(fid_DB,'"lon" double precision,\n');
fprintf(fid_DB,'"lat" double precision,\n');
fprintf(fid_DB,'"pkid" serial NOT NULL PRIMARY KEY) \n  ');
fprintf(fid_DB,'WITH ( \n OIDS=FALSE \n)');
fprintf(fid_DB,';\n');
fprintf(fid_DB,'ALTER TABLE anmn.nrs_platforms OWNER TO anmn;\n');
fprintf(fid_DB,'GRANT ALL ON TABLE anmn.nrs_platforms TO anmn;\n');
fprintf(fid_DB,'GRANT SELECT ON TABLE anmn.nrs_platforms TO gisread;\n');
fprintf(fid_DB,'GRANT ALL ON TABLE anmn.nrs_platforms TO gisadmin;\n');
fprintf(fid_DB,'SELECT AddGeometryColumn(\''nrs\'', \''nrs_platforms\'', \''geom\'', 4326, \''POINT\'', 2 );\n'); %% AddGeometryColumn(varchar scheme,varchar table_name, varchar column_name, integer srid, varchar type, integer dimension);
fprintf(fid_DB,'COMMIT; \n \n');



fprintf(fid_DB,'--BEGIN;\n');
fprintf(fid_DB,'CREATE TABLE anmn.nrs_parameters(\n');
fprintf(fid_DB,'"pkid" serial NOT NULL PRIMARY KEY,\n');
fprintf(fid_DB,'"fk_nrs_platforms" integer,\n');
fprintf(fid_DB,'"channelid" integer,\n');
fprintf(fid_DB,'"sensor_name" character varying(1000),\n');
fprintf(fid_DB,'"parameter" character varying(1000),\n');
fprintf(fid_DB,'"depth_sensor" character varying(1000),\n');
fprintf(fid_DB,'"metadata_uuid" character varying(255),\n');
fprintf(fid_DB,'"time_coverage_start" timestamp without time zone,\n');
fprintf(fid_DB,'"time_coverage_end" timestamp without time zone,\n');
fprintf(fid_DB,'"folder_datafabric" character varying(1000),\n');
fprintf(fid_DB,'CONSTRAINT fk_nrs_platforms_exists FOREIGN KEY (fk_nrs_platforms)\n');
fprintf(fid_DB,'REFERENCES anmn.nrs_platforms (pkid) \n');
fprintf(fid_DB,'ON DELETE CASCADE \n ');
fprintf(fid_DB,'ON UPDATE CASCADE \n )');
fprintf(fid_DB,';\n');
fprintf(fid_DB,'ALTER TABLE anmn.nrs_parameters OWNER TO anmn;\n');
fprintf(fid_DB,'GRANT ALL ON TABLE anmn.nrs_parameters TO anmn;\n');
fprintf(fid_DB,'GRANT SELECT ON TABLE anmn.nrs_parameters TO gisread;\n');
fprintf(fid_DB,'GRANT ALL ON TABLE anmn.nrs_parameters TO gisadmin;\n');
fprintf(fid_DB,'COMMIT;\n \n');
fclose(fid_DB);
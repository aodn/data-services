function CreateSQL_FAIMMS_Table()
%% CreateSQL_FAIMMS_Table 
% Creates the tables used by geoserver
%
% Inputs:
%
% Outputs in 'dataWIP'/ :
%  DB_CreateTABLE..    - PSQL script to load for geoserver
%
% See also: FAIMMS_processLevel,Insert_DB_FAIMMS
% 
% Author: Laurent Besnard, IMOS/eMII
% email: laurent.besnard@utas.edu.au
% Website: http://imos.org.au/  http://froggyscripts.blogspot.com
% Aug 2012; Last revision: 24-Aug-2012
global dataWIP;

Filename_DB=fullfile(dataWIP,'DB_CreateTABLE.sql'); %%SQL COMMANDS to paste on PGadmin
fid_DB = fopen(Filename_DB, 'w+');
fprintf(fid_DB,'BEGIN;\n');
fprintf(fid_DB,'CREATE TABLE faimms.faimms_sites  (\n');
fprintf(fid_DB,'"site_code" character varying(100),\n');
fprintf(fid_DB,'"lon" double precision,\n');
fprintf(fid_DB,'"lat" double precision,\n');
fprintf(fid_DB,'"pkid" serial NOT NULL PRIMARY KEY) \n  ');
fprintf(fid_DB,'WITH ( \n OIDS=FALSE \n)');
fprintf(fid_DB,';\n');
fprintf(fid_DB,'ALTER TABLE faimms.faimms_sites OWNER TO faimms;\n');
fprintf(fid_DB,'GRANT ALL ON TABLE faimms.faimms_sites TO faimms;\n');
fprintf(fid_DB,'GRANT SELECT ON TABLE faimms.faimms_sites TO gisread;\n');
fprintf(fid_DB,'GRANT ALL ON TABLE faimms.faimms_sites TO gisadmin;\n');
fprintf(fid_DB,'SELECT AddGeometryColumn(\''faimms\'', \''faimms_sites\'', \''geom\'', 4326, \''POINT\'', 2 );\n'); %% AddGeometryColumn(varchar scheme,varchar table_name, varchar column_name, integer srid, varchar type, integer dimension);
fprintf(fid_DB,'COMMIT; \n \n');


fprintf(fid_DB,'BEGIN;\n');
fprintf(fid_DB,'CREATE TABLE faimms.faimms_platforms  (\n');
fprintf(fid_DB,'"pkid" serial NOT NULL PRIMARY KEY,\n');
fprintf(fid_DB,'"fk_faimms_sites" integer,\n');
fprintf(fid_DB,'"platform_code" character varying(100),\n');
fprintf(fid_DB,'"lon" double precision,\n');
fprintf(fid_DB,'"lat" double precision,\n');
fprintf(fid_DB,'CONSTRAINT fk_faimms_sites_exists FOREIGN KEY (fk_faimms_sites)\n');
fprintf(fid_DB,'REFERENCES faimms.faimms_sites (pkid) \n');
fprintf(fid_DB,'ON DELETE CASCADE \n ');
fprintf(fid_DB,'ON UPDATE CASCADE \n )');
fprintf(fid_DB,'\n');
fprintf(fid_DB,'WITH ( \n OIDS=FALSE\n)');
fprintf(fid_DB,';\n');
fprintf(fid_DB,'ALTER TABLE faimms.faimms_platforms OWNER TO faimms;\n');
fprintf(fid_DB,'GRANT ALL ON TABLE faimms.faimms_platforms TO faimms;\n');
fprintf(fid_DB,'GRANT SELECT ON TABLE faimms.faimms_platforms TO gisread;\n');
fprintf(fid_DB,'GRANT ALL ON TABLE faimms.faimms_platforms TO gisadmin;\n');
fprintf(fid_DB,'SELECT AddGeometryColumn(\''faimms\'', \''faimms_platforms\'', \''geom\'', 4326, \''POINT\'', 2 );\n'); %% AddGeometryColumn(varchar scheme,varchar table_name, varchar column_name, integer srid, varchar type, integer dimension);
fprintf(fid_DB,'COMMIT;\n \n');



fprintf(fid_DB,'BEGIN;\n');
fprintf(fid_DB,'CREATE TABLE faimms.faimms_parameters(\n');
fprintf(fid_DB,'"pkid" serial NOT NULL PRIMARY KEY,\n');
fprintf(fid_DB,'"fk_faimms_platforms" integer,\n');
fprintf(fid_DB,'"channelid" integer,\n');
fprintf(fid_DB,'"sensor_name" character varying(1000),\n');
fprintf(fid_DB,'"parameter" character varying(1000),\n');
fprintf(fid_DB,'"depth_sensor" double precision,\n');
fprintf(fid_DB,'"metadata_uuid" character varying(255),\n');
fprintf(fid_DB,'"qaqc_boolean" integer,\n');
fprintf(fid_DB,'"no_qaqc_boolean" integer,\n');
fprintf(fid_DB,'"time_coverage_start" timestamp without time zone,\n');
fprintf(fid_DB,'"time_coverage_end" timestamp without time zone,\n');
fprintf(fid_DB,'"folder_datafabric" character varying(1000),\n');
fprintf(fid_DB,'CONSTRAINT fk_faimms_platforms_exists FOREIGN KEY (fk_faimms_platforms)\n');
fprintf(fid_DB,'REFERENCES faimms.faimms_platforms (pkid) \n');
fprintf(fid_DB,'ON DELETE CASCADE \n ');
fprintf(fid_DB,'ON UPDATE CASCADE \n )');
fprintf(fid_DB,';\n');
fprintf(fid_DB,'ALTER TABLE faimms.faimms_parameters OWNER TO faimms;\n');
fprintf(fid_DB,'GRANT ALL ON TABLE faimms.faimms_parameters TO faimms;\n');
fprintf(fid_DB,'GRANT SELECT ON TABLE faimms.faimms_parameters TO gisread;\n');
fprintf(fid_DB,'GRANT ALL ON TABLE faimms.faimms_parameters TO gisadmin;\n');
fprintf(fid_DB,'COMMIT;\n \n');
fclose(fid_DB);

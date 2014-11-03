function CreateSQLTable(DATA_FOLDER)
%CreateSQLTable create the tables headers for the two AUV SQL scripts
%
% Inputs:
%   DATA_FOLDER       - str pointing to the folder where the user wants to
%                       save the SQL file.
%
% Outputs:
%
% Author: Laurent Besnard <laurent.besnard@utas,edu,au>
%
%
% Copyright (c) 2010, eMarine Information Infrastructure (eMII) and Integrated 
% Marine Observing System (IMOS).
% All rights reserved.
% 
% Redistribution and use in source and binary forms, with or without 
% modification, are permitted provided that the following conditions are met:
% 
%     * Redistributions of source code must retain the above copyright notice, 
%       this list of conditions and the following disclaimer.
%     * Redistributions in binary form must reproduce the above copyright 
%       notice, this list of conditions and the following disclaimer in the 
%       documentation and/or other materials provided with the distribution.
%     * Neither the name of the eMII/IMOS nor the names of its contributors 
%       may be used to endorse or promote products derived from this software 
%       without specific prior written permission.
% 
% THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" 
% AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE 
% IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE 
% ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE 
% LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR 
% CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF 
% SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS 
% INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN 
% CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) 
% ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE 
% POSSIBILITY OF SUCH DAMAGE.
%
format long
DATA_FOLDER=readConfig('processedDataOutput.path', 'config.txt','=');

Filename_DB_DATA=strcat(DATA_FOLDER,filesep,'DB_Create_TABLE_DATA.sql'); %%SQL COMMANDS to paste on PGadmin
Filename_DB_METADATA=strcat(DATA_FOLDER,filesep,'DB_Create_TABLE_METADATA.sql');%%SQL COMMANDS to paste on PGadmin


fid7 =fopen(Filename_DB_DATA, 'w+');
fprintf(fid7,'CREATE TABLE auv.auv_images  (\n');
fprintf(fid7,'"pkid" serial NOT NULL,\n');
fprintf(fid7,'"fk_auv_tracks" integer,\n');
fprintf(fid7,'"image_filename" character varying(60),\n');
fprintf(fid7,'"longitude" double precision,\n');
fprintf(fid7,'"latitude" double precision,\n');
fprintf(fid7,'"image_width" double precision,\n');
fprintf(fid7,'"depth_sensor" double precision,\n');
fprintf(fid7,'"altitude_sensor" double precision,\n');
fprintf(fid7,'"depth" double precision,\n');
fprintf(fid7,'"sea_water_temperature" double precision,\n');
fprintf(fid7,'"sea_water_salinity" double precision,\n');
fprintf(fid7,'"chlorophyll_concentration_in_sea_water" double precision,\n');
fprintf(fid7,'"backscattering_ratio" double precision,\n');
fprintf(fid7,'"colored_dissolved_organic_matter" double precision,\n');
fprintf(fid7,'"time" timestamp without time zone,\n');
fprintf(fid7,'"cluster_tag" integer,\n');
fprintf(fid7,'"geom" geometry,\n');
fprintf(fid7,'CONSTRAINT auv_images_pkey PRIMARY KEY (pkid),\n');
fprintf(fid7,'CONSTRAINT fk_auv_tracks_exists FOREIGN KEY (fk_auv_tracks) \n ');
fprintf(fid7,'REFERENCES auv.auv_tracks (pkid) \n ');
fprintf(fid7,'ON DELETE CASCADE \n ');
fprintf(fid7,'ON UPDATE CASCADE,\n');
fprintf(fid7,'CONSTRAINT enforce_dims_geom CHECK (ndims(geom) = 2),\n');
fprintf(fid7,'CONSTRAINT enforce_geotype_geom CHECK (geometrytype(geom) = ''POLYGON''::text OR geom IS NULL),\n');
fprintf(fid7,'CONSTRAINT enforce_srid_geom CHECK (srid(geom) = 4326)\n');
fprintf(fid7,');\n');
fprintf(fid7,'ALTER TABLE auv.auv_images OWNER TO auv;\n');
fprintf(fid7,'GRANT ALL ON TABLE auv.auv_images TO auv;\n');
fprintf(fid7,'GRANT SELECT ON TABLE auv.auv_images TO gisread;\n');
fprintf(fid7,'GRANT ALL ON TABLE auv.auv_images TO gisadmin;\n');
fprintf(fid7,'CREATE INDEX auv_images_fk_idx \n ON auv.auv_images \n USING btree  (fk_auv_tracks, pkid); \n ');
fprintf(fid7,'CREATE INDEX auv_images_time_idx \n ON auv.auv_images \nUSING btree \n  ("time"); \n');




fid6 = fopen(Filename_DB_METADATA, 'w+');
fprintf(fid6,'CREATE TABLE auv.auv_tracks  (\n');
fprintf(fid6,'"pkid" serial NOT NULL,\n');
fprintf(fid6,'"facility_code" varchar(5),\n');
fprintf(fid6,'"campaign_code" character varying(60),\n');
fprintf(fid6,'"site_code" character varying(255),\n');
fprintf(fid6,'"image_folder" character varying(255),\n');
fprintf(fid6,'"abstract" character varying(255),\n');
fprintf(fid6,'"platform_code" varchar(15),\n');
fprintf(fid6,'"dive_number" integer,\n');
fprintf(fid6,'"dive_code_name" varchar(255),\n');
fprintf(fid6,'"pattern" character varying(30),\n');
fprintf(fid6,'"number_of_images" integer,\n');
fprintf(fid6,'"distance" double precision,\n');
fprintf(fid6,'"dive_notes" character varying(1000),\n');
fprintf(fid6,'"dive_report" character varying(255),\n');
fprintf(fid6,'"kml" character varying(255),\n');
fprintf(fid6,'"metadata_uuid" character varying(255),\n');
fprintf(fid6,'"geospatial_lat_min" double precision,\n');
fprintf(fid6,'"geospatial_lon_min" double precision,\n');
fprintf(fid6,'"geospatial_lat_max" double precision,\n');
fprintf(fid6,'"geospatial_lon_max" double precision,\n');
fprintf(fid6,'"geospatial_vertical_min" double precision,\n');
fprintf(fid6,'"geospatial_vertical_max" double precision,\n');
fprintf(fid6,'"time_coverage_start" timestamp without time zone,\n');
fprintf(fid6,'"time_coverage_end" timestamp without time zone, \n');
fprintf(fid6,'"geom" geometry,\n');
fprintf(fid6,'CONSTRAINT auv_tracks_pkey PRIMARY KEY (pkid),\n');
fprintf(fid6,'CONSTRAINT enforce_dims_geom CHECK (ndims(geom) = 2),\n');
fprintf(fid6,'CONSTRAINT enforce_geotype_geom CHECK (geometrytype(geom) = ''LINESTRING''::text OR geom IS NULL),\n');
fprintf(fid6,'CONSTRAINT enforce_srid_geom CHECK (srid(geom) = 4326)\n )\n');
fprintf(fid6,'WITH ( \n OIDS=FALSE \n)');
fprintf(fid6,';\n');
fprintf(fid6,'ALTER TABLE auv.auv_tracks OWNER TO auv;\n');
fprintf(fid6,'GRANT ALL ON TABLE auv.auv_tracks TO auv;\n');
fprintf(fid6,'GRANT SELECT ON TABLE auv.auv_tracks TO gisread;\n');
fprintf(fid6,'GRANT ALL ON TABLE auv.auv_tracks TO gisadmin;\n');

% fprintf(fid6,'SELECT AddGeometryColumn(\''auv\'', \''auv_tracks\'', \''geom\'', 4326, \''LINESTRING\'', 2 );\n'); %% AddGeometryColumn(varchar scheme,varchar table_name, varchar column_name, integer srid, varchar type, integer dimension);






fclose(fid6);
fclose(fid7);
end

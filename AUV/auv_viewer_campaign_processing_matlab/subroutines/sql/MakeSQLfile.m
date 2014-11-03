function MakeSQLfile(metadata, sample_data)
%MakeSQLfile creates two SQL script files to load into postgreSQL. one
%called DB_TABLE_DATA_<CAMPAIGN>.sql containing all the images coordinates
%with their respective engineering and scientific data. The geom column
%refers to the 4 corners of each image; & DB_TABLE_METADATA_<CAMPAIGN>.sql
%containing the metadata of each dive. The geom column refers to the track.
%
%
% Inputs:
%   DATA_FOLDER       - str pointing to the folder where the user wants to
%                       save the SQL file.
%   sample_data       - structure containing images info, scientific&engineering data .
%   metadata          - structure containing some metadata of the dive.
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
metadataUUID_file=readConfig('metadataUUID.file', 'config.txt','=');

Filename_DB_DATA=strcat(DATA_FOLDER,filesep,metadata.Campaign,filesep,'DB_TABLE_DATA_',metadata.Campaign,'.sql'); %%SQL COMMANDS to paste on PGadmin
fid7 =fopen(Filename_DB_DATA, 'a+');

Filename_DB_METADATA=strcat(DATA_FOLDER,filesep,metadata.Campaign,filesep,'DB_TABLE_METADATA_',metadata.Campaign,'.sql');%%SQL COMMANDS to paste on PGadmin
fid6 = fopen(Filename_DB_METADATA, 'a+');

facility_code='AUV';
platform_code='SIRIUS';


campaign_code=metadata.Campaign;
site_code=metadata.Dive;


metadata_uuid=getUUID([campaign_code filesep site_code], [DATA_FOLDER filesep metadataUUID_file],',');
% metadata_uuid= char(java.util.UUID.randomUUID);

if exist('metadata','var')
    pattern=metadata.cdm_data_type;
    abstract=metadata.abstract;
    distance=metadata.Distance; 
    number_of_images=length(sample_data);
else
    pattern=' ';
    abstract=' ';
    distance=' ';
    number_of_images=' ';
end


dive_report=strcat('http://data.aodn.org.au/IMOS/public/AUV/',metadata.Campaign,'/all_reports/',metadata.Dive,'_report.pdf');
kml=strcat('http://data.aodn.org.au/IMOS/public/AUV/',metadata.Campaign,'/',metadata.Dive,'/',metadata.KML);




fprintf(fid6,'INSERT INTO auv.auv_tracks (dive_number,dive_code_name,metadata_uuid,facility_code,campaign_code, site_code,distance,number_of_images,image_folder,abstract, platform_code, pattern, dive_report, kml, geospatial_lat_min, geospatial_lon_min, geospatial_lat_max, geospatial_lon_max, geospatial_vertical_min, geospatial_vertical_max, time_coverage_start, time_coverage_end, geom)\n');
fprintf(fid6,'VALUES (%d,\''%s\'' ,\''%s\'' , \''%s\'', \''%s\'',\''%s\'', %f,%d,\''%s\'',\''%s\'',\''%s\'', \''%s\'' ,\''%s\'',\''%s\'', %s, %s, %s, %s, %s, %s, \''%s\'', \''%s\'',LineFromText(\''LINESTRING(',metadata.dive_number,metadata.dive_code_name,metadata_uuid, facility_code, campaign_code, site_code,distance, number_of_images,metadata.TIFFdir,abstract, platform_code, pattern,  dive_report, kml, metadata.geospatial_lat_min, metadata.geospatial_lon_min, metadata.geospatial_lat_max, metadata.geospatial_lon_max, metadata.geospatial_vertical_min, metadata.geospatial_vertical_max, metadata.date_start,metadata.date_end);
for k=1:length(sample_data)-2
    fprintf(fid6, '%3.7f %2.7f, %3.7f %2.7f, ',sample_data(k).lon_center,sample_data(k).lat_center,sample_data(k+1).lon_center,sample_data(k+1).lat_center );
end
fprintf(fid6, '%3.7f %2.7f)\'',4326));\n',  sample_data(length(sample_data)).lon_center,sample_data(length(sample_data)).lat_center );
clear k;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%% This matlab code writes down the PostgreSQL code to paste into
%%%%%%%%%%% pgAdmin to create the TABLE of all different values attached to
%%%%%%%%%%% the AUV images
%%%%%%%%%%% It uses for this purpose the data collected by
%%%%%%%%%%% another Matlab script from which all data have been saved into
%%%%%%%%%%% a DAT file. this table will only give basic informations.
%%%%%%%%%%% Laurent.Besnard@utas.edu.au Project officer/IMOS-eMII.Apr 2010
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

value_pkid=strcat('(Select pkid from auv.auv_tracks where site_code ='' ',char(site_code),''') ' );

for k=1:length(sample_data)
    fprintf(fid7,'INSERT INTO auv.auv_images (fk_auv_tracks,image_filename,longitude,latitude,image_width,depth_sensor,altitude_sensor,depth,sea_water_temperature,sea_water_salinity,chlorophyll_concentration_in_sea_water,backscattering_ratio,colored_dissolved_organic_matter,time, cluster_tag,geom)\n');
    fprintf(fid7,'VALUES (');
    fprintf(fid7,' %s , \''%s\'', %3.7f, %2.7f, %f, %f, %f, %f, %f, %f, %f, %f, %f, \''%s\'',%d,PolyFromText(\''POLYGON((',value_pkid,sample_data(k).Image,sample_data(k).lon_center,sample_data(k).lat_center,sample_data(k).Image_Width,sample_data(k).Depth,sample_data(k).Altitude,sample_data(k).Bathy,sample_data(k).TEMP,sample_data(k).PSAL,sample_data(k).CPHL,sample_data(k).OPBS,sample_data(k).CDOM,sample_data(k).Date4SQL,sample_data(k).cluster);
    fprintf(fid7, '%3.7f %2.7f, %3.7f %2.7f, %3.7f %2.7f , %3.7f %2.7f ,%3.7f %2.7f))\'',4326));\n',sample_data(k).upLlon,sample_data(k).upLlat,sample_data(k).upRlon,sample_data(k).upRlat,sample_data(k).lowRlon,sample_data(k).lowRlat,sample_data(k).lowLlon,sample_data(k).lowLlat,sample_data(k).upLlon,sample_data(k).upLlat );
end
clear k;
fclose(fid6);
fclose(fid7);

%% replace NaN by 'NaN' with sed (much easier) so it can be handled by geoserver
systemCmd = sprintf('sed -i "s/NaN,/\\''NaN\\'',/g" %s;',Filename_DB_DATA);
[~,~]=system(systemCmd) ;

clearvars -except -regexp Campaign WIP Dives Number_Dives fid7 Filename_DB_Dive Filename_DB_General fid6;

end

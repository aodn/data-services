function createCSV_talend(metadata,sample_data)
%createCSV_talend creates two CSV script files to load into TALEND for postgreSQL. one
%called DB_TABLE_DATA_<CAMPAIGN>.sql containing all the images coordinates
%with their respective engineering and scientific data. The geom column
%refers to the 4 corners of each image; & DB_TABLE_METADATA_<CAMPAIGN>.sql
%containing the metadata of each dive. The geom column refers to the track.
%
%
% Inputs:
%   DATA_FOLDER       - str pointing to the folder where the user wants to
%                       save the SQL file.
%   sample_data       - structure containing images info,scientific&engineering data .
%   metadata          - structure containing some metadata of the dive.
%
% Outputs:
%
% Author: Laurent Besnard <laurent.besnard@utas,edu,au>
%
%
% Copyright (c) 2010,eMarine Information Infrastructure (eMII) and Integrated
% Marine Observing System (IMOS).
% All rights reserved.
%
% Redistribution and use in source and binary forms,with or without
% modification,are permitted provided that the following conditions are met:
%
%     * Redistributions of source code must retain the above copyright notice,
%       this list of conditions and the following disclaimer.
%     * Redistributions in binary form must reproduce the above copyright
%       notice,this list of conditions and the following disclaimer in the
%       documentation and/or other materials provided with the distribution.
%     * Neither the name of the eMII/IMOS nor the names of its contributors
%       may be used to endorse or promote products derived from this software
%       without specific prior written permission.
%
% THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
% AND ANY EXPRESS OR IMPLIED WARRANTIES,INCLUDING,BUT NOT LIMITED TO,THE
% IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
% ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
% LIABLE FOR ANY DIRECT,INDIRECT,INCIDENTAL,SPECIAL,EXEMPLARY,OR
% CONSEQUENTIAL DAMAGES (INCLUDING,BUT NOT LIMITED TO,PROCUREMENT OF
% SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,DATA,OR PROFITS; OR BUSINESS
% INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,WHETHER IN
% CONTRACT,STRICT LIABILITY,OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
% ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE,EVEN IF ADVISED OF THE
% POSSIBILITY OF SUCH DAMAGE.
%

DATA_FOLDER       = getenv('processed_data_output_path');
metadataUUID_file = getenv('metadata_uuid_file');

Filename_METADATA = strcat(DATA_FOLDER,filesep,metadata.Campaign,filesep,'TABLE_METADATA_',metadata.Campaign,'_',metadata.Dive,'.csv');
fid6 = fopen(Filename_METADATA,'w+');
fprintf(fid6,'dive_number,dive_name,dive_metadata_uuid,facility_code,campaign_code,dive_code,distance_covered_in_m,number_of_images,image_path,abstract,platform_code,pattern,dive_report_path,kml_path,geospatial_lat_min,geospatial_lon_min,geospatial_lat_max,geospatial_lon_max,geospatial_vertical_min,geospatial_vertical_max,time_coverage_start,time_coverage_end\n');

Filename_DATA = strcat(DATA_FOLDER,filesep,metadata.Campaign,filesep,'TABLE_DATA_',metadata.Campaign,'_',metadata.Dive,'.csv');
fid7          = fopen(Filename_DATA,'w+');

facility_code = 'AUV';
platform_code = 'SIRIUS';

campaign_code = metadata.Campaign;
site_code     = metadata.Dive;

metadata_uuid = getUUID([campaign_code filesep site_code],[DATA_FOLDER filesep metadataUUID_file],',');

if exist('metadata','var')
    pattern          = metadata.cdm_data_type;
    abstract         = metadata.abstract;
    distance         = metadata.Distance;
    number_of_images = length(sample_data);
else
    pattern          =' ';
    abstract         =' ';
    distance         =' ';
    number_of_images =' ';
end


dive_report =strcat('http://data.aodn.org.au/IMOS/public/AUV/',metadata.Campaign,'/all_reports/',metadata.Dive,'_report.pdf');
kml         =strcat('http://data.aodn.org.au/IMOS/public/AUV/',metadata.Campaign,'/',metadata.Dive,'/',metadata.KML);


%% track data
%put "" between abstract value (10th entry) in case the abstract contains
%a comma
fprintf(fid6,' %d,%s,%s,%s,%s,%s,%f,%d,%s,"%s",%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s\n',metadata.dive_number,metadata.dive_code_name,...
                                                                                    metadata_uuid,facility_code,campaign_code,...
                                                                                    site_code,distance,...
                                                                                    number_of_images,metadata.TIFFdir,...
                                                                                    abstract,platform_code,...
                                                                                    pattern,dive_report,kml,...
                                                                                    metadata.geospatial_lat_min,metadata.geospatial_lon_min,...
                                                                                    metadata.geospatial_lat_max,metadata.geospatial_lon_max,...
                                                                                    metadata.geospatial_vertical_min,metadata.geospatial_vertical_max,...
                                                                                    metadata.date_start,metadata.date_end);
fclose(fid6);



%% individual images data
fprintf(fid7,'campaign_code,dive_code,image_filename,longitude,latitude,image_width,depth_sensor,altitude_sensor,depth,sea_water_temperature,sea_water_salinity,chlorophyll_concentration_in_sea_water,backscattering_ratio,colored_dissolved_organic_matter,time,cluster_tag,up_left_lon,up_left_lat,up_right_lon,up_right_lat,low_right_lon,low_right_lat,low_left_lon,low_left_lat\n');

for k=1:length(sample_data)
    fprintf(fid7,'%s,%s,%s,%3.8f,%2.8f,%f,%f,%f,%f,%f,%f,%f,%f,%f,%s,%d,',metadata.Campaign,metadata.Dive,sample_data(k).Image,sample_data(k).lon_center,sample_data(k).lat_center,sample_data(k).Image_Width,sample_data(k).Depth,sample_data(k).Altitude,sample_data(k).Bathy,sample_data(k).TEMP,sample_data(k).PSAL,sample_data(k).CPHL,sample_data(k).OPBS,sample_data(k).CDOM,sample_data(k).Date4SQL,sample_data(k).cluster);
    fprintf(fid7,'%3.8f,%2.8f,%3.8f,%2.8f,%3.8f,%2.8f,%3.8f,%2.8f\n',sample_data(k).upLlon,sample_data(k).upLlat,sample_data(k).upRlon,sample_data(k).upRlat,sample_data(k).lowRlon,sample_data(k).lowRlat,sample_data(k).lowLlon,sample_data(k).lowLlat);
end
clear k;
fclose(fid7);

%% replace NaN by 'NaN' with sed (much easier) so it can be handled by geoserver
% systemCmd = sprintf('sed -i "s/NaN,/\NaN\,/g" %s;',Filename_DATA);
% [~,~]=system(systemCmd) ;


end

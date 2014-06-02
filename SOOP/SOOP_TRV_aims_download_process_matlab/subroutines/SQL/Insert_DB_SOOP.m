function Insert_DB_SOOP(channelId,siteName,platformName,sensors,parameterType,fromDate,thruDate,metadata_uuid,PreviousDownloadedFile)
% Insert_DB_SOOP writes 1 psql scripts in WIP to load into pgadmin, or psql (psql -h DatabaseServer
% -U user -W password -d maplayers -p port < file.sql )
%
% The tables should be loaded at each run of this script into the
% Database after having previously dropped the old ones in reverse order
% (because of foreign keys).
%
% Inputs:
%   channelId       -Cell array of online channels (270)
%   siteName        -Cell array of site_codes (Lizard Island)
%   platformName        -Cell array of platform_codes (Weather Station
%                    Platform)
%   FolderName      -Cell array of one part of the folder structure of a
%                    NetCDF file
%   long            -Cell array of longitudes of each parameter
%   lat             -Cell array of latitudes of each parameter
%   sensors         -Cell array of sensors (water temperature)
%   parameterType   -Cell array of parameters (temperature)
%   fromDate        -Cell array of first date available of each channel
%   thruDate        -Cell array of last date available of each channel
%   metadata_uuid   -Cell array UUID for the MEST of each channel
%   depth           -Cell array of the depth of each sensor
%
%
% Outputs in 'soop_DownloadFolder'/ :
%   DB_Insert_soop_TABLE.sql   - PSQL scripts for all different sites
%   DB_CreateTABLE.sql         - PSQL scripts for all different platforms
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

WIP=pwd;
format long

%% recreates cell arrays with only non empty values
PreviousDownloadedFilebis=PreviousDownloadedFile(~cellfun('isempty',PreviousDownloadedFile));
% siteNamebis=siteName(~cellfun('isempty',siteName));
platformNamebis=platformName(~cellfun('isempty',platformName));
sensorsbis=sensors(~cellfun('isempty',sensors));
parameterTypebis=parameterType(~cellfun('isempty',parameterType));
fromDatebis=fromDate(~cellfun('isempty',fromDate));
thruDatebis=thruDate(~cellfun('isempty',thruDate));
metadata_uuidbis=metadata_uuid(~cellfun('isempty',metadata_uuid));
Number_channels_available=size(platformNamebis,1);

%% Finds the platforms which have a different name, and creates a equivalent index between the different parameters and a platform
% platformName_singular =cell(2,1);
% platformName_singular{1}=str2mat(platformNamebis{1});
% j=1;

% for i=1:Number_channels_available-1
%     if ~isempty(platformNamebis{i})
%         if  max(strcmpi(platformName_singular,platformNamebis{i+1}))==1
%         else j=j+1;
%             
%             platformName_singular{j}=str2mat(platformNamebis{i+1});
%         end
%         
%     end
% end
% platformName_singular=platformName_singular';
[platformName_singular, ~]=unique( platformNamebis);

index_equivalent_platformName_parameter=zeros(Number_channels_available,1);
for j=1:Number_channels_available
    [~, bb]=ismember(platformNamebis(j), ( platformName_singular ) );
    index_equivalent_platformName_parameter(j)=bb;
end

% http_7days=strcat('http://data.aims.gov.au/gbroosdata/services/chart/rtds/qaqc/',num2str(code_platformName),'/level0/raw/raw/last7days/750/500/page');
% http_last6mth=strcat('http://data.aims.gov.au/gbroosdata/services/chart/rtds/qaqc/',num2str(code_platformName),'/level0/raw/raw/last6mth/750/500/page');


%% PSQl table for the sites
Filename_DB=strcat(WIP,filesep,'DB_Insert_SOOP_TABLE.sql'); %%SQL COMMANDS to paste on PGadmin
fid_DB = fopen(Filename_DB, 'w+');

%% PSQl table for the platformNames
fprintf(fid_DB,'BEGIN;\n');
fprintf(fid_DB,'delete FROM  soop.soop_platforms CASCADE;\n');
fprintf(fid_DB,'ALTER SEQUENCE  soop.soop_platforms_pkid_seq\n');
fprintf(fid_DB,'INCREMENT 1\n');
fprintf(fid_DB,'MINVALUE 1\n');
fprintf(fid_DB,'START 1\n');
fprintf(fid_DB,'RESTART\n');
fprintf(fid_DB,'CACHE 1;\n');

N_platformName=size (platformName_singular,1);
for k=1:N_platformName
    fprintf(fid_DB,'INSERT INTO soop.soop_platforms(platform_code)\n');
    fprintf(fid_DB,'VALUES (\''%s\'');\n',char(platformName_singular(k)));
    
end
fprintf(fid_DB,'COMMIT;\n');

%% PSQl table for the parameters
fprintf(fid_DB,'BEGIN;\n');
fprintf(fid_DB,'delete FROM  soop.soop_parameters CASCADE;\n');
fprintf(fid_DB,'ALTER SEQUENCE  soop.soop_parameters_pkid_seq\n');
fprintf(fid_DB,'INCREMENT 1\n');
fprintf(fid_DB,'MINVALUE 1\n');
fprintf(fid_DB,'START 1\n');
fprintf(fid_DB,'RESTART\n');
fprintf(fid_DB,'CACHE 1;\n');

Folder=cell(Number_channels_available,1);
for k=1:Number_channels_available
    [year,~,~,~,~,~]=datevec(fromDatebis{k},'yyyy-mm-ddTHH:MM:SS');
    value_pkid=strcat('(Select pkid from soop.soop_platforms where pkid =',num2str(index_equivalent_platformName_parameter(k)),') ' );
    Folder{k}=strcat('QAQC/SOOP_TMV',filesep,platformNamebis{k},filesep,num2str(year),filesep,parameterTypebis{k},filesep,PreviousDownloadedFilebis{k});
    filename=char(strcat(pwd,filesep,'sorted',filesep,cellstr(Folder{k})));
    ncid = netcdf.open(filename,'NC_NOWRITE');
    
    lat=netcdf.getVar(ncid,netcdf.inqVarID(ncid,'latitude'),'double');
    lon=netcdf.getVar(ncid,netcdf.inqVarID(ncid,'longitude'),'double');
    lat_qc=netcdf.getVar(ncid,netcdf.inqVarID(ncid,'latitude_quality_control'),'double');
    lon_qc=netcdf.getVar(ncid,netcdf.inqVarID(ncid,'longitude_quality_control'),'double');
    
    netcdf.close(ncid)
    
    for i=1:length(lat_qc)
        I_lat = find(lat_qc<3);
        I_lon= find(lon_qc<3) ;
        Index_good=find (I_lat==I_lon);
    end
    
    fprintf(fid_DB,'INSERT INTO soop.soop_parameters (fk_soop_platforms,channelid,sensor_name,time_coverage_start,time_coverage_end,folder_datafabric,metadata_uuid,geom)\n');
    fprintf(fid_DB,'VALUES (  %s, \''%s\'', \''%s\'',\''%s\'' , \''%s\'' ,  \''%s\'',\''%s\'',LineFromText(\''LINESTRING (',value_pkid,num2str(channelId(k)),num2str(sensorsbis{k}),fromDatebis{k},thruDatebis{k},filename,metadata_uuidbis{k});
    
    for t=1:length(Index_good)-2
        fprintf(fid_DB, '%s %s, %s %s, \n',num2str(lon(Index_good(t)),'%3.7f'),num2str(lat(Index_good(t)),'%2.7f'),num2str(lon(Index_good(t+1)),'%3.7f'),num2str(lat(Index_good(t+1)),'%2.7f') );
    end
    fprintf(fid_DB, '%s %s)\'',4326));\n',  num2str(lon(Index_good(end)),'%3.7f'),num2str(lat(Index_good(end)),'%2.7f'));
end

fprintf(fid_DB,'COMMIT;');
fclose(fid_DB);
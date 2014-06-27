function Insert_DB_NRS_test(channelInfo,alreadyDownloaded)
% Insert_DB_NRS writes 1 psql scripts in NRS_DownloadFolder to load into pgadmin, or psql (psql -h DatabaseServer
% -U user -W password -d maplayers -p port < file.sql ) in the following order :
%   1.DB_TABLE_sites.sql
%   2.DB_TABLE_platforms.sql
%   3.DB_TABLE_parameters.sql
%
% All three tables should be loaded at each run of this script into the
% Database after having previously dropped the old ones in reverse order
% (because of foreign keys).
%
% Inputs:
%   channelId       -Cell array of online channels (270)
%   siteName        -Cell array of site_codes (Lizard Island)
%   siteType        -Cell array of platform_codes (Weather Station
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
% Outputs in 'NRS_DownloadFolder'/ :
%   DB_TABLE_sites.sql         - PSQL scripts for all different sites
%   DB_TABLE_platforms         - PSQL scripts for all different platforms
%   DB_TABLE_parameters.sql    - PSQL scripts for all different parameters
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
global NRS_DownloadFolder;
global DATE_PROGRAM_LAUNCHED

channelId=sort(str2double(channelInfo.channelId));
%% recreates cell arrays with only non empty values
siteNamebis=channelInfo.siteName(channelId);
longbis=channelInfo.long(channelId);
latbis=channelInfo.lat(channelId);
FolderNamebis=alreadyDownloaded.folderLongnameDepth(channelId);
sensorsbis=alreadyDownloaded.sensorsLongname(channelId);
parameterTypebis=channelInfo.parameterType(channelId);
fromDatebis=channelInfo.fromDate(channelId);
thruDatebis=channelInfo.thruDate(channelId);
metadata_uuidbis=channelInfo.metadata_uuid(channelId);
depthbis=str2double(channelInfo.depth(channelId));
Number_channels_available=size(channelId,1);

%% Finds the platforms which have a different name, and creates a equivalent index between the different parameters and a platform
[siteName_singular, Ip]=unique( siteNamebis);
long_eq=str2double(longbis(Ip));
lat_eq=str2double(latbis(Ip));

index_equivalent_siteName_parameter=zeros(Number_channels_available,1);
for j=1:Number_channels_available
    [~, bb]=ismember(siteNamebis(j), ( siteName_singular ) );
    index_equivalent_siteName_parameter(j)=bb;
end

% http_7days=strcat('http://data.aims.gov.au/gbroosdata/services/chart/rtds/qaqc/',num2str(code_siteName),'/level0/raw/raw/last7days/750/500/page');
% http_last6mth=strcat('http://data.aims.gov.au/gbroosdata/services/chart/rtds/qaqc/',num2str(code_siteName),'/level0/raw/raw/last6mth/750/500/page');
% any_date=http://data.aims.gov.au/gbroosdata/services/chart/rtds/',num2str(code_siteName),'/level0/raw/raw/2010-12-07T12:00:00/2010-12-14T12:00:00/1600/800/page/1
%% PSQl table for the sites
Filename_DB=fullfile(NRS_DownloadFolder,strcat('DB_Insert_NRS_TABLE',DATE_PROGRAM_LAUNCHED,'.sql')); %%SQL COMMANDS to paste on PGadmin
fid_DB = fopen(Filename_DB, 'w+');

%% PSQl table for the siteNames
fprintf(fid_DB,'BEGIN;\n');
fprintf(fid_DB,'delete FROM  anmn.nrs_platforms CASCADE;\n');
fprintf(fid_DB,'ALTER SEQUENCE  anmn.nrs_platforms_pkid_seq\n');
fprintf(fid_DB,'INCREMENT 1\n');
fprintf(fid_DB,'MINVALUE 1\n');
fprintf(fid_DB,'START 1\n');
fprintf(fid_DB,'RESTART\n');
fprintf(fid_DB,'CACHE 1;\n');

N_siteName=size (siteName_singular,1);
for k=1:N_siteName
    fprintf(fid_DB,'INSERT INTO anmn.nrs_platforms(platform_code,lon,lat,geom)\n');
    fprintf(fid_DB,'VALUES (\''%s\'', %3.7f,  %2.7f,PointFromText(\''POINT(%3.7f %2.7f)\'' ,4326));\n',char(siteName_singular(k)),long_eq(k),lat_eq(k),long_eq(k),lat_eq(k) );
end
fprintf(fid_DB,'COMMIT;\n \n' );

%% PSQl table for the parameters
fprintf(fid_DB,'BEGIN;\n');
fprintf(fid_DB,'delete FROM  anmn.nrs_parameters CASCADE;\n');
fprintf(fid_DB,'ALTER SEQUENCE  anmn.nrs_parameters_pkid_seq\n');
fprintf(fid_DB,'INCREMENT 1\n');
fprintf(fid_DB,'MINVALUE 1\n');
fprintf(fid_DB,'START 1\n');
fprintf(fid_DB,'RESTART\n');
fprintf(fid_DB,'CACHE 1;\n');

Folder=cell(Number_channels_available,1);
for k=1:Number_channels_available
%     [year,~,~,~,~,~]=datevec(thruDatebis{k},'yyyy-mm-ddTHH:MM:SS');
    value_pkid=strcat('(Select pkid from anmn.nrs_platforms where pkid =',num2str(index_equivalent_siteName_parameter(k)),') ' );
    
    if strcmp(siteNamebis{k},'Yongala')
        site='NRSYON';
    elseif strcmp(siteNamebis{k},'Darwin')
        site='NRSDAR';
    else
        site='UNKNOWN';
    end
    if depthbis(k)==0
%         Folder{k}=strcat('ANMN/NRS/REAL_TIME/',site,filesep,parameterTypebis{k},filesep,sensorsbis{k},'_channel_',num2str(channelId(k)));
          Folder{k}=strcat('ANMN/NRS/REAL_TIME/',site,filesep,parameterTypebis{k},filesep,sensorsbis{k},'_channel_',num2str(channelId(k)));

    else
%         Folder{k}=strcat('ANMN/NRS/REAL_TIME/',site,filesep,parameterTypebis{k},filesep,sensorsbis{k},'@',num2str(depthbis(k),'% 2.1f'),'m_channel_',num2str(channelId(k)));
%         Folder{k}=strcat('ANMN/NRS/REAL_TIME/',site,filesep,parameterTypebis{k},filesep,sensorsbis{k},'@',num2str(depthbis(k),'% 2.1f'),'m_channel_',num2str(channelId(k)));
    Folder{k}=strcat('ANMN/NRS/REAL_TIME/',site,filesep,parameterTypebis{k},filesep,FolderNamebis{k},'_channel_',num2str(channelId(k)));

%         Folder{k}=strcat('ANMN/NRS/REAL_TIME/',site,filesep,parameterTypebis{k},filesep,sensorsbis{k},'@',depthbis(k),'m_channel_',num2str(channelId(k)));
    end
    fprintf(fid_DB,'INSERT INTO anmn.nrs_parameters (fk_nrs_platforms,channelid,sensor_name,parameter,depth_sensor,time_coverage_start,time_coverage_end,folder_datafabric,metadata_uuid)\n');
    fprintf(fid_DB,'VALUES (  %s, %s, \''%s\'', \''%s\'' ,%f, \''%s\'' , \''%s\'' ,  \''%s\'',\''%s\'' );\n',value_pkid,num2str(channelId(k)),sensorsbis{k},parameterTypebis{k},depthbis(k),fromDatebis{k},thruDatebis{k},Folder{k},metadata_uuidbis{k});
end

fprintf(fid_DB,'COMMIT;');
fclose(fid_DB);

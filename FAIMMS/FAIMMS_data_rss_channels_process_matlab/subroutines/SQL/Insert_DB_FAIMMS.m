function Insert_DB_FAIMMS(channelInfo,alreadyDownloaded)
%% Insert_DB_FAIMMS 
% writes 1 psql scripts in dataWIP to load into pgadmin, or psql (psql -h DatabaseServer
% -U user -W password -d maplayers -p port < file.sql )
%
% All three tables should be loaded at each run of this script into the
% Database after having previously dropped the old ones in reverse order
% (because of foreign keys). This function should be improved in order not
% to drop the entire table. This requires a java library to connect to the
% database and query each channel to know the pkid and foreign keys.
%
% Inputs:
%       channelInfo        : structure of current RSS feed
%       alreadyDownloaded  : structure of last RSS feed plus last files
%          downloaded
%
% Outputs in 'dataWIP'/ :
%  DB_Insert_FAIMMS_TABLE..    - PSQL script to load for geoserver
%
% See also: FAIMMS_processLevel,CreateSQL_FAIMMS_Table
% 
% Author: Laurent Besnard, IMOS/eMII
% email: laurent.besnard@utas.edu.au
% Website: http://imos.org.au/  http://froggyscripts.blogspot.com
% Aug 2012; Last revision: 24-Aug-2012

global dataWIP;
global DATE_PROGRAM_LAUNCHED

channelId=sort(str2double(channelInfo.channelId));

platform_bis=cell(size(channelInfo.siteName,1),1);
for i=1:size(channelInfo.siteName,1)
    if ~isempty(channelInfo.siteName{i})
        platform_bis{i}=strcat(channelInfo.siteName{i},'-',channelInfo.siteType{i});
    end
end

%% recreates cell arrays with only non empty values
platform_doubled = platform_bis(channelId); %delete empty cells
siteNamebis=channelInfo.siteName(channelId);
FolderNamebis=alreadyDownloaded.folderLongnameDepth(channelId);
siteTypebis=channelInfo.siteType(channelId);
longbis=channelInfo.long(channelId);
latbis=channelInfo.lat(channelId);
sensorsbis=alreadyDownloaded.sensorsLongname(channelId);
parameterTypebis=channelInfo.parameterType(channelId);
fromDatebis=channelInfo.fromDate(channelId);
thruDatebis=channelInfo.thruDate(channelId);
metadata_uuidbis=channelInfo.metadata_uuid(channelId);
depthbis=str2double(channelInfo.depth(channelId));
Number_channels_available=size(channelId,1);

%% Finds the platforms which have a different name, and creates a equivalent index between the different parameters and a platform
[platform_singular, Ip]=unique( ( platform_doubled));
long_eq=str2double(longbis(Ip));
lat_eq=str2double(latbis(Ip));

index_equivalent_platform_parameter=zeros(Number_channels_available,1);
for j=1:Number_channels_available
    [~, bb]=ismember(platform_doubled(j),  platform_singular );
    index_equivalent_platform_parameter(j)=bb;
end

N_platform=size (platform_singular,1);
platform_code=cell(N_platform,1);
site_code=cell(N_platform,1);
for k=1:N_platform
    index=strfind( platform_singular{k},'-');
    site_code{k}=platform_singular{k}(1:index-1);
    platform_code{k}=platform_singular{k}(index+1:end);
end


%% Finds the sites which have a different name, and creates a equivalent index between the different platforms and sites
[site_singular, Is]=unique(site_code);
long_site_eq=(long_eq(Is));
lat_site_eq=(lat_eq(Is));
N_site=size(site_singular,1);

index_equivalent_site_platform=zeros(N_platform,1);
for j=1:N_platform
    [~, bb]=ismember(cellstr(site_code{j}), ( site_singular ) );
    index_equivalent_site_platform(j)=bb;
end


% http_7days=strcat('http://data.aims.gov.au/gbroosdata/services/chart/rtds/qaqc/',num2str(code_platform),'/level0/raw/raw/last7days/750/500/page');
% http_last6mth=strcat('http://data.aims.gov.au/gbroosdata/services/chart/rtds/qaqc/',num2str(code_platform),'/level0/raw/raw/last6mth/750/500/page');


%% PSQl table for the sites
Filename_DB=fullfile(dataWIP,strcat('DB_Insert_FAIMMS_TABLE',DATE_PROGRAM_LAUNCHED,'.sql')); %%SQL COMMANDS to paste on PGadmin
fid_DB = fopen(Filename_DB, 'w+');
fprintf(fid_DB,'BEGIN;\n');
fprintf(fid_DB,'delete FROM  faimms.faimms_sites CASCADE;\n');
fprintf(fid_DB,'ALTER SEQUENCE  faimms.faimms_sites_pkid_seq\n');
fprintf(fid_DB,'INCREMENT 1\n');
fprintf(fid_DB,'MINVALUE 1\n');
fprintf(fid_DB,'START 1\n');
fprintf(fid_DB,'RESTART\n');
fprintf(fid_DB,'CACHE 1;\n');

for k=1:N_site
    fprintf(fid_DB,'INSERT INTO faimms.faimms_sites (site_code,lon,lat,geom)\n');
    fprintf(fid_DB,'VALUES (''%s\'', %3.7f,  %2.7f,PointFromText(\''POINT(%3.7f %2.7f)\'' ,4326));\n',site_singular{k},long_site_eq(k),lat_site_eq(k),long_site_eq(k),lat_site_eq(k) );
end
fprintf(fid_DB,'COMMIT;\n');




%% PSQl table for the platforms
fprintf(fid_DB,'BEGIN;\n');
fprintf(fid_DB,'delete FROM  faimms.faimms_platforms CASCADE;\n');
fprintf(fid_DB,'ALTER SEQUENCE  faimms.faimms_platforms_pkid_seq\n');
fprintf(fid_DB,'INCREMENT 1\n');
fprintf(fid_DB,'MINVALUE 1\n');
fprintf(fid_DB,'START 1\n');
fprintf(fid_DB,'RESTART\n');
fprintf(fid_DB,'CACHE 1;\n');

for k=1:N_platform
    value_pkid=strcat('(Select pkid from faimms.faimms_sites where site_code ='' ', (site_code{k}),''') ' );
    fprintf(fid_DB,'INSERT INTO faimms.faimms_platforms (fk_faimms_sites,platform_code,lon,lat,geom)\n');
    fprintf(fid_DB,'VALUES (%s,\''%s\'', %3.7f,  %2.7f,PointFromText(\''POINT(%3.7f %2.7f)\'' ,4326));\n',value_pkid,platform_code{k},long_eq(k),lat_eq(k),long_eq(k),lat_eq(k) );
end
fprintf(fid_DB,'COMMIT;\n');


%% PSQl table for the parameters
fprintf(fid_DB,'BEGIN;\n');
fprintf(fid_DB,'delete FROM  faimms.faimms_parameters CASCADE;\n');
fprintf(fid_DB,'ALTER SEQUENCE  faimms.faimms_parameters_pkid_seq\n');
fprintf(fid_DB,'INCREMENT 1\n');
fprintf(fid_DB,'MINVALUE 1\n');
fprintf(fid_DB,'START 1\n');
fprintf(fid_DB,'RESTART\n');
fprintf(fid_DB,'CACHE 1;\n');

Folder=cell(Number_channels_available,1);
for k=1:Number_channels_available
    value_pkid=strcat('(Select pkid from faimms.faimms_platforms where pkid ='' ',num2str(index_equivalent_platform_parameter(k)),''') ' );
    Folder{k}=strcat(siteNamebis{k},filesep,siteTypebis{k},filesep,parameterTypebis{k},filesep,FolderNamebis{k},'_channel_',num2str(channelId(k)));
    fprintf(fid_DB,'INSERT INTO faimms.faimms_parameters (fk_faimms_platforms,channelid,sensor_name,parameter,depth_sensor,time_coverage_start,time_coverage_end,folder_datafabric,metadata_uuid)\n');
    fprintf(fid_DB,'VALUES (  %s, %s, \''%s\'', \''%s\'' ,%f, \''%s\'' , \''%s\'' ,  \''%s\'',\''%s\'');\n',value_pkid,num2str(channelId(k)),sensorsbis{k},parameterTypebis{k},depthbis(k),fromDatebis{k},thruDatebis{k},Folder{k},metadata_uuidbis{k});
end

fprintf(fid_DB,'COMMIT;');
fclose(fid_DB);
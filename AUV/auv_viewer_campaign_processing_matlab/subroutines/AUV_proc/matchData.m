function [metadata sample_data]=matchData(header_data,AUV_Folder,Campaign,Dive)
%matchData loads the informations harvested by getImageinfo and tries to
%match the images with engineering and scientific data -  Depth Altitude
%Bathy TEMP PSAL CPHL OPBS CDOM - according to the closest time as the frequency
%of the different outputs are not similar. The CSV
%contained in the track directory contains the image filename, the time and
%engineering data. The two NC files contain Scientific Data
%
% Inputs:
%   header_data  - structure of images metadata harvested from getImageinfo.m .
%   AUV_Folder  - str pointing to the main AUV folder address ( could be
%                 local or on the DF -slow- through a mount.davfs
%   Campaign    - str containing the Campaign name.
%   Dive        - str containing the Dive name.
%
% Outputs:
%   sample_data       - structure containing images info, scientific&engineering data.
%   metadata          - structure containing some metadata of the dive.
%
% Author: Laurent Besnard <laurent.besnard@utas,edu,au>
% Oct 2010; Last revision: 31-Oct-2012


format long
warning('off','MATLAB:dispatcher:InexactCaseMatch')

%% Find the files and directories
divePath= (strcat(AUV_Folder,filesep,Campaign,filesep,Dive));
Hydro_dir=dir([divePath filesep 'h*']);
hydroPath=[divePath filesep Hydro_dir.name];

Track_dir=dir([divePath filesep 'track*']);
trackPath=[divePath filesep Track_dir.name];

TIFF_dir=dir([divePath filesep 'i2*gtif']);
tiffPath=[divePath filesep TIFF_dir.name];

Files_Hydro_dir=dir([hydroPath filesep '*.nc']); % structure 1 and 2 matche the files

File_track_csv=dir([trackPath filesep '*.csv']);
File_track_kml=dir([trackPath filesep '*.kml']);

%% check missing files
if ~size(Hydro_dir,1)
    fprintf('%s - WARNING: Missing folder "hydro_netcdf"  for %s.\n',datestr(now), [Campaign '-' Dive]);
    %     fprintf('%s - EXIT FUNCTION\n',datestr(now));
    
    metadata    =struct;
    sample_data =struct;
    return
end

if ~size(Files_Hydro_dir,1)
    fprintf('%s - WARNING: Missing files in "hydro_netcdf"  for %s\n',datestr(now), [Campaign '-' Dive]);
    %     fprintf('%s - EXIT FUNCTION\n',datestr(now));
    
    metadata    =struct;
    sample_data =struct;
    return
end

if ~size(Track_dir,1)
    fprintf('%s - WARNING: Missing folder "track_files"  for %s\n',datestr(now), [Campaign '-' Dive]);
    %     fprintf('%s - EXIT FUNCTION\n',datestr(now));
    
    metadata    =struct;
    sample_data =struct;
    return
end

if ~size(File_track_csv,1)
    fprintf('%s - WARNING: Missing files in "track_files"  for %s\n',datestr(now), [Campaign '-' Dive]);
    %     fprintf('%s - EXIT FUNCTION\n',datestr(now));
    
    metadata    =struct;
    sample_data =struct;
    return
end

if ~size(File_track_kml,1)
    fprintf('%s - WARNING: Missing files in "track_files"  for %s\n',datestr(now), [Campaign '-' Dive]);
    %     fprintf('%s - EXIT FUNCTION\n',datestr(now));
    
    metadata    =struct;
    sample_data =struct;
    return
end

if ~size(TIFF_dir,1)
    fprintf('%s - WARNING: Missing folder "i...gtif"  for %s\n',datestr(now), [Campaign '-' Dive]);
    %     fprintf('%s - EXIT FUNCTION\n',datestr(now));
    
    metadata    =struct;
    sample_data =struct;
    return
end

%% location of the data files
Filename_CSV_Coordinates    =strcat(AUV_Folder,filesep,Campaign,filesep,Dive,filesep,Track_dir.name,filesep,File_track_csv.name);       %CSV file in the track dire
Filename_B_Load             =strcat(AUV_Folder,filesep,Campaign,filesep,Dive,filesep,Hydro_dir.name,filesep,Files_Hydro_dir(1,1).name); %first NC file
Filename_ST_Load            =strcat(AUV_Folder,filesep,Campaign,filesep,Dive,filesep,Hydro_dir.name,filesep,Files_Hydro_dir(2,1).name); %second NC file

%% extract coordinates from header_data input
LON_TOP_LEFT    =[header_data.upLlon];                                             %Load of the structure create by geotiffinfo.m
LAT_TOP_LEFT    =[header_data.upLlat];
LON_TOP_RIGHT   =[header_data.upRlon];
LAT_TOP_RIGHT   =[header_data.upRlat];
ResolutionX     =[header_data.Width];

%% compute the distance in meters of the track overtook by the robot
dist=0;
Divedistance=0;
for k=1:length(header_data)-1
    dist = 1000*Dist2km(header_data(k).lon_center,header_data(k).lat_center,header_data(k+1).lon_center,header_data(k+1).lat_center);
    if isempty(dist)
        kk=k;
        continue
    end
    Divedistance=dist+Divedistance; %in meters
end


%% Compute the Pixel Size
Image_Width=Dist2km(LON_TOP_LEFT,LAT_TOP_LEFT,LON_TOP_RIGHT,LAT_TOP_RIGHT)*1000; % Width of images in meter
Pixel_Size= Image_Width.*1.0 ./ ResolutionX;                                % size of one pixel in meter

% Image_name=[];
%%  get the image filename and remove the extention as the CSV doesn't contain the extention
Image_name=strtok({header_data.image}','.');
clear k
Image_name=Image_name';
nrows=length(header_data);


%% Import depth,altitude... and time from LatLon CSV file
fid2 = fopen(Filename_CSV_Coordinates,'r');
% C_text2 = textscan(fid2, '%s', 17, 'delimiter', ',');                       %C_text{1}{2} C_text{1}{1} to get values;
% C_data2 = textscan(fid2, '%n %n %n %n %n %f %f %f %f %f %f %f %f %f %f %s %s ','CollectOutput', 1,'treatAsEmpty', {'NA', 'na'}, 'Delimiter', ',');
try
    [~, C_data2] = csvload(Filename_CSV_Coordinates);
catch
    fprintf('%s - ERROR: %s is corrupted\n',datestr(now),[Track_dir.name filesep File_track_csv.name]);
    metadata    =struct;
    sample_data =struct;
    return
end

fclose(fid2);

%% get file name from file fid2 , to get the filename and remove the ext
Filename_latlon_pre={C_data2{1,2}{:,1}}';%(1,2:end-1) remove the "
[Filename_latlon ~] = strtok(Filename_latlon_pre,'.');
clear Filename_latlon_pre;

% for t=1:length(C_data2)
% Filename_latlon_pre={C_data2{t,2}{:,1}}';%(1,2:end-1) remove the "
% [Filename_latlon(t) extention] = strtok(Filename_latlon_pre,'.');
% end
%
% for t=1:length(C_data2)
%
% Year_latlon(t)=C_data2{t,1}(1);
% Month_latlon(t)=C_data2{t,1}(2);
% Day_latlon(t)=C_data2{t,1}(3);
% Hour_latlon(t)=C_data2{t,1}(4);
% Minute_latlon(t)=C_data2{t,1}(5);
% Sec_latlon(t)=C_data2{t,1}(6);
% Depth_latlon(t)=C_data2{t,1}(9);
% Altitude_latlon(t)=C_data2{t,1}(15);
% end
%
% Filename_latlon=Filename_latlon';
% Year_latlon=Year_latlon';
% Month_latlon=Month_latlon';
% Day_latlon=Day_latlon';
% Hour_latlon=Hour_latlon';
% Minute_latlon=Minute_latlon';
% Sec_latlon=Sec_latlon';
% Depth_latlon=Depth_latlon';
% Altitude_latlon=Altitude_latlon';

%Load of the spreadsheet
DATA_latlon=C_data2{1,1};
Year_latlon=DATA_latlon(:,1);
Month_latlon=DATA_latlon(:,2);
Day_latlon=DATA_latlon(:,3);
Hour_latlon=DATA_latlon(:,4);
Minute_latlon=DATA_latlon(:,5);
Sec_latlon=DATA_latlon(:,6);
Depth_latlon=DATA_latlon(:,9);
Altitude_latlon=DATA_latlon(:,15);

%cluster tag - Only available in new versions of csv file
if size (C_data2,2)==3
    Cluster_Tag=C_data2{:,3};
elseif size (C_data2,2)==2
    % Image labels denote the class or cluster assigned to an image.  A zero (0) indicates
    % no label data was available for that image.
    % so if we have an old version of a csv file where cluster tag does not
    % exist, we replace the values by 0
    Cluster_Tag=zeros(nrows,1);
end


clear C_data2 C_text2 DATA_latlon;


%% Find image name into both CSV to find an equivalent index
index_equivalent2=int16(find(ismember( Filename_latlon(:), Image_name(:))==1)');

Year=Year_latlon(index_equivalent2);
Month=Month_latlon(index_equivalent2);
Day=Day_latlon(index_equivalent2);
Hour=Hour_latlon(index_equivalent2);
Minute=Minute_latlon(index_equivalent2);
Sec=Sec_latlon(index_equivalent2);
Depth=Depth_latlon(index_equivalent2);
Altitude=Altitude_latlon(index_equivalent2);
Bathy=Altitude+Depth;                                                       %in (m)
clear Year_latlon Month_latlon Day_latlon Hour_latlon Minute_latlon Sec_latlon Depth_latlon Altitude_latlon index_equivalent2;
N_lonlat = datenum(Year, Month, Day, Hour, Minute, Sec);
DATE_DB=datestr([Year, Month, Day, Hour, Minute, Sec],'yyyymmddTHHMMSSZ');%Transform the date into a single number in the DATA BASE GIS format, letter Z means UTC


%% match CT (csv) =ST (netcdf) & LON LAT CSV in time with the images for the temp salinity
fid3 = Filename_ST_Load;
ncid3 = netcdf.open(fid3,'NC_NOWRITE');

%NC ATTRIBUTES
gattname0 = netcdf.inqAttName(ncid3,netcdf.getConstant('NC_GLOBAL'),0);
site_code = netcdf.getAtt(ncid3,netcdf.getConstant('NC_GLOBAL'),gattname0); % -> AUV

gattname3 = netcdf.inqAttName(ncid3,netcdf.getConstant('NC_GLOBAL'),3);
title= netcdf.getAtt(ncid3,netcdf.getConstant('NC_GLOBAL'),gattname3); % -> AUV

gattname5 = netcdf.inqAttName(ncid3,netcdf.getConstant('NC_GLOBAL'),5);
date_created= netcdf.getAtt(ncid3,netcdf.getConstant('NC_GLOBAL'),gattname5); % -> AUV

gattname6 = netcdf.inqAttName(ncid3,netcdf.getConstant('NC_GLOBAL'),6);
abstract = netcdf.getAtt(ncid3,netcdf.getConstant('NC_GLOBAL'),gattname6);

gattname14 = netcdf.inqAttName(ncid3,netcdf.getConstant('NC_GLOBAL'),14);
platform_code = netcdf.getAtt(ncid3,netcdf.getConstant('NC_GLOBAL'),gattname14);

gattname16 = netcdf.inqAttName(ncid3,netcdf.getConstant('NC_GLOBAL'),16);
cdm_data_type = netcdf.getAtt(ncid3,netcdf.getConstant('NC_GLOBAL'),gattname16);

gattname17 = netcdf.inqAttName(ncid3,netcdf.getConstant('NC_GLOBAL'),17);
geospatial_lat_min = netcdf.getAtt(ncid3,netcdf.getConstant('NC_GLOBAL'),gattname17);

gattname18 = netcdf.inqAttName(ncid3,netcdf.getConstant('NC_GLOBAL'),18);
geospatial_lat_max = netcdf.getAtt(ncid3,netcdf.getConstant('NC_GLOBAL'),gattname18);

gattname19 = netcdf.inqAttName(ncid3,netcdf.getConstant('NC_GLOBAL'),19);
geospatial_lon_min = netcdf.getAtt(ncid3,netcdf.getConstant('NC_GLOBAL'),gattname19);

gattname20 = netcdf.inqAttName(ncid3,netcdf.getConstant('NC_GLOBAL'),20);
geospatial_lon_max = netcdf.getAtt(ncid3,netcdf.getConstant('NC_GLOBAL'),gattname20);

% gattname21 = netcdf.inqAttName(ncid3,netcdf.getConstant('NC_GLOBAL'),21);
% geospatial_vertical_min = netcdf.getAtt(ncid3,netcdf.getConstant('NC_GLOBAL'),gattname21);
geospatial_vertical_min=min(Depth);

gattname22 = netcdf.inqAttName(ncid3,netcdf.getConstant('NC_GLOBAL'),22);
geospatial_vertical_max = netcdf.getAtt(ncid3,netcdf.getConstant('NC_GLOBAL'),gattname22);

format bank

try
    [TIME_fid3,~]=getVarNetCDF('TIME',ncid3);   
catch corrupted_ST_file
    fprintf('%s - ERROR - corrupted TIME Var in NetCDF file %s . Dive cannot be processed\n',datestr(now),Filename_ST_Load)
    metadata    =struct;
    sample_data =struct;
    return
end

try
    [PSAL_fid3,~]=getVarNetCDF('PSAL',ncid3);
catch
    fprintf('%s - WARNING - corrupted PSAL Var in NetCDF file %s \n',datestr(now),Filename_ST_Load)
    PSAL_fid3=NaN(length(TIME_fid3),1);
end

try
    [TEMP_fid3,~]=getVarNetCDF('TEMP',ncid3);
catch
    fprintf('%s - WARNING - corrupted TEMP Var in NetCDF file %s \n',datestr(now),Filename_ST_Load)
    TEMP_fid3=NaN(length(TIME_fid3),1);
end


if (length(N_lonlat) < nrows)
    fprintf('%s - WARNING %d images missing somewhere\n',datestr(now),abs(nrows-length(N_lonlat)))
    nrows=length(N_lonlat);
end


index_equivalent3=zeros(nrows,1);
for j=1:nrows
    if isempty(find (TIME_fid3 < N_lonlat(j) ))
        index_equivalent3(j)=min(find (TIME_fid3 > N_lonlat(j) ));
    else
        index_equivalent3(j)=max(find (TIME_fid3 < N_lonlat(j) ));
    end
end

index_equivalent3=int16(index_equivalent3');

TEMP=TEMP_fid3(index_equivalent3);
PSAL=PSAL_fid3(index_equivalent3);

clear j TEMP_fid3 PSAL_fid3 index_equivalent3;




%% match ECO (csv) = B (netcdf) & LON LAT CSV in time with the images for the temp salinity since the images are not taken at the same time than in situ data
fid4 = Filename_B_Load;
ncid4 = netcdf.open(fid4,'NC_NOWRITE');

format bank

try
    [TIME_fid4,~]=getVarNetCDF('TIME',ncid4);
catch corrupted_ST_file
    
    fprintf('%s - ERROR - corrupted NetCDF file %s . Dive cannot be processed\n',datestr(now),Filename_B_Load)
    metadata    =struct;
    sample_data =struct;
    return
end

%
try
    [CDOM_fid4,~]=getVarNetCDF('CDOM',ncid4);
catch
    fprintf('%s - WARNING - corrupted CDOM Var in NetCDF file %s \n',datestr(now),Filename_ST_Load)
    CDOM_fid4=NaN(length(TIME_fid3),1);
end
%
try
    [CPHL_fid4,~]=getVarNetCDF('CPHL',ncid4);
catch
    fprintf('%s - WARNING - corrupted CPHL Var in NetCDF file %s \n',datestr(now),Filename_ST_Load)
    CPHL_fid4=NaN(length(TIME_fid3),1);
end
%
try
    [OPBS_fid4,~]=getVarNetCDF('OPBS',ncid4);
catch
    fprintf('%s - WARNING - corrupted OPBS Var in NetCDF file %s \n',datestr(now),Filename_ST_Load)
    OPBS_fid4=NaN(length(TIME_fid3),1);
end



% format bank

index_equivalent4=zeros(nrows,1);
for k=1:nrows
    index_equivalent4(k)=max(find (TIME_fid4 < N_lonlat(k) ));%#ok
end
index_equivalent4=int16(index_equivalent4');

CDOM=CDOM_fid4(index_equivalent4);
CPHL=CPHL_fid4(index_equivalent4);
OPBS=OPBS_fid4(index_equivalent4);

clear k index_equivalent4 CDOM_fid4 CPHL_fid4 OPBS_fid4 TIME_fid4 ;

dive_name_seperate=textscan(Dive,'r%d %d %s %s %s %s %s %s','delimiter', '_');

%% Find where the dive number is written on the diving name
for t=3:length(dive_name_seperate)
    if  isfinite(str2double(dive_name_seperate{t}))
        INDEX_DiveNumber = t;
        INDEX_DiveNumber = str2double(dive_name_seperate{INDEX_DiveNumber});
    end
end

%% second way in case the dive number is for example '18a' and not '18'
if ~exist('INDEX_DiveNumber','var')
    for t=3:length(dive_name_seperate)
        a=regexp(dive_name_seperate{t},'\d+','match');
        if ~isempty(a)
            if  isfinite(str2double(a{1}))
                INDEX_DiveNumber=str2double(a{1});
                break
            end
        end
    end
end

%% third way, we makle the dive number up
if ~exist('INDEX_DiveNumber','var')
    INDEX_DiveNumber=0;
end

%% create a dive code name readable by the user
A=' ';
for t=3:length(dive_name_seperate)
    if t==3
        A=strcat(char(dive_name_seperate{t}));
    elseif t ~= INDEX_DiveNumber && ~isempty(dive_name_seperate{t})
        A=strcat(A,{' '},char(dive_name_seperate{t}));
    end
end


%% fill the metadata structure
metadata=struct;
metadata.Campaign                =Campaign;
metadata.Dive                    =Dive;
metadata.dive_number             =INDEX_DiveNumber;
metadata.dive_code_name          =char(A);
metadata.site_code               =site_code;
metadata.title                   =title;
metadata.date_start              =DATE_DB(1,:);
metadata.date_end                =DATE_DB(end,:);
metadata.abstract                =abstract;
metadata.platform_code           =platform_code;
metadata.cdm_data_type           =cdm_data_type;
metadata.geospatial_lat_min      =geospatial_lat_min;
metadata.geospatial_lat_max      =geospatial_lat_max;
metadata.geospatial_lon_min      =geospatial_lon_min;
metadata.geospatial_lon_max      =geospatial_lon_max;
metadata.geospatial_vertical_min =geospatial_vertical_min;
metadata.geospatial_vertical_max =geospatial_vertical_max;
metadata.CSV                     =strcat(Track_dir.name,filesep,File_track_csv.name);
metadata.KML                     =strcat(Track_dir.name,filesep,File_track_kml.name);
metadata.B                       =strcat(Hydro_dir.name,filesep,Files_Hydro_dir(1,1).name);
metadata.ST                      =strcat(Hydro_dir.name,filesep,Files_Hydro_dir(2,1).name);
metadata.TIFFdir                 =strcat(TIFF_dir.name);
metadata.NumberPictures          =length(header_data);
metadata.Distance                =Divedistance;


%% fill the sample_data structure
sample_data(nrows,1)=struct('Image',[],'Year',[],'Month',[],'Day',[],...
    'Hour',[],'Minute',[],'Sec',[],'Date4SQL',[],'Pixel_Size',[],'Image_Width',[],...
    'Depth',[],'Altitude',[],'Bathy',[],...
    'TEMP',[],'PSAL',[],'CPHL',[],'OPBS',[],...
    'CDOM',[],'upLlat',[],'upLlon',[],'upRlat',[],...
    'upRlon',[],'lowRlat',[],'lowRlon',[],'lowLlat',[],...
    'lowLlon',[],'lon_center',[],'lat_center',[],'cluster',[]);

for j=1:nrows
    sample_data(j,1).Image      =Image_name{j};
    sample_data(j,1).Year       =Year(j);
    sample_data(j,1).Month      =Month(j);
    sample_data(j,1).Day        =Day(j);
    sample_data(j,1).Hour       =Hour(j);
    sample_data(j,1).Minute     =Minute(j);
    sample_data(j,1).Sec        =Sec(j);
    sample_data(j,1).Date4SQL   =DATE_DB(j,:);
    sample_data(j,1).Pixel_Size =Pixel_Size(j);
    sample_data(j,1).Image_Width=Image_Width(j);
    sample_data(j,1).Depth      =Depth(j);
    sample_data(j,1).Altitude   =Altitude(j);
    sample_data(j,1).Bathy      =Bathy(j);
    sample_data(j,1).TEMP       =TEMP(j);
    sample_data(j,1).PSAL       =PSAL(j);
    sample_data(j,1).CPHL       =CPHL(j);
    sample_data(j,1).OPBS       =OPBS(j);
    sample_data(j,1).CDOM       =CDOM(j);
    sample_data(j,1).upLlat     =header_data(j,1).upLlat;
    sample_data(j,1).upLlon     =header_data(j,1).upLlon;
    sample_data(j,1).upRlat     =header_data(j,1).upRlat;
    sample_data(j,1).upRlon     =header_data(j,1).upRlon;
    sample_data(j,1).lowRlat    =header_data(j,1).lowRlat;
    sample_data(j,1).lowRlon    =header_data(j,1).lowRlon;
    sample_data(j,1).lowLlat    =header_data(j,1).lowLlat;
    sample_data(j,1).lowLlon    =header_data(j,1).lowLlon;
    sample_data(j,1).lon_center =header_data(j,1).lon_center;
    sample_data(j,1).lat_center =header_data(j,1).lat_center;
    sample_data(j,1).cluster    =Cluster_Tag(j);
    
end

netcdf.close(ncid3)
netcdf.close(ncid4)
end
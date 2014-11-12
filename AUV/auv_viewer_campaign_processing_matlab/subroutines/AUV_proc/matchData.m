function [metadata sample_data]=matchData(header_data,Campaign,Dive)
%matchData loads the informations harvested by getImageinfo and tries to
%match the images with engineering and scientific data -  Depth Altitude
%Bathy TEMP PSAL CPHL OPBS CDOM - according to the closest time as the frequency
%of the different outputs are not similar. The CSV
%contained in the track directory contains the image filename, the time and
%engineering data. The two NC files contain Scientific Data
%
% Inputs:
%   header_data  - structure of images metadata harvested from getImageinfo.m .
%   releasedCampaignPath  - str pointing to the main AUV folder address ( could be
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
releasedCampaignPath     = readConfig('releasedCampaign.path', 'config.txt','=');

% format long
% warning('off','MATLAB    :dispatcher:InexactCaseMatch')

%% Find the files and directories
divePath                 = strcat(releasedCampaignPath,filesep,Campaign,filesep,Dive);
Hydro_dir                = dir([divePath filesep 'h*']);

Track_dir                = dir([divePath filesep 'track*']);
trackPath                = [divePath filesep Track_dir.name];

TIFF_dir                 = dir([divePath filesep 'i2*gtif']);

File_track_csv           = dir([trackPath filesep '*.csv']);
File_track_kml           = dir([trackPath filesep '*.kml']);
if ~size(File_track_kml,1)
    fprintf('%s - WARNING: Missing files in "track_files"  for %s\n',datestr(now), [Campaign '-' Dive]);   
end

%% conditions not to process dive : no images, and no .csv file
if ~size(Track_dir,1)
    fprintf('%s - WARNING: Missing folder "track_files". Dive %s not processed\n',datestr(now), [Campaign '-' Dive]);
    
    metadata    = struct;
    sample_data = struct;
    return
end


if ~size(TIFF_dir,1)
    fprintf('%s - WARNING: Missing folder "i...gtif"  Dive %s not processed\n',datestr(now), [Campaign '-' Dive]);
    
    metadata    = struct;
    sample_data = struct;
    return
end


[Image_Width, Pixel_Size , Divedistance] = computeImageSize(header_data) ;
[track_csv]                              = readCSV_track (Campaign,Dive,header_data);

if  isempty(fieldnames(track_csv))
    fprintf('%s - WARNING: No Track CSV file. Cant process the dive\n',datestr(now), [Campaign '-' Dive]);
    metadata    = struct;
    sample_data = struct;
    
    return
end

[metadata_ST , sample_data_ST]           = matchST_data(header_data,track_csv,Campaign,Dive);
[metadata_B  , sample_data_B]            = matchB_data(header_data,track_csv,Campaign,Dive);
[dive_code_name,diveNumber]              = findDiveCode (Dive);


%% ouput of the main function

%% get the image filename and remove the extention as the CSV doesn't contain the extention
Image_name              = strtok({header_data.image}','.');
Image_name              = Image_name';
nrows                   = length(header_data);

datestrCSV              = datestr([track_csv.Year, track_csv.Month, track_csv.Day, track_csv.Hour, track_csv.Minute, track_csv.Sec],'yyyymmddTHHMMSSZ');%Transform the date into a single number in the DATA BASE GIS format, letter Z means UTC
geospatial_vertical_min = min(track_csv.Depth);
geospatial_vertical_max = max(track_csv.Depth);
geospatial_lat_min      = min([header_data.lat_center]);
geospatial_lat_max      = max([header_data.lat_center]);
geospatial_lon_min      = min([header_data.lon_center]);
geospatial_lon_max      = max([header_data.lon_center]);
cdm_data_type           = 'trajectory';

%% fill the metadata structure
metadata                         = struct;
metadata.Campaign                = Campaign;
metadata.Dive                    = Dive;
metadata.dive_number             = diveNumber;
metadata.dive_code_name          = dive_code_name;

metadata.site_code               = metadata_ST.site_code;
metadata.title                   = metadata_ST.title;
metadata.abstract                = metadata_ST.abstract;
metadata.platform_code           = metadata_ST.platform_code;

metadata.date_start              = datestrCSV(1,:);
metadata.date_end                = datestrCSV(end,:);

metadata.cdm_data_type           = cdm_data_type;
metadata.geospatial_lat_min      = geospatial_lat_min;
metadata.geospatial_lat_max      = geospatial_lat_max;
metadata.geospatial_lon_min      = geospatial_lon_min;
metadata.geospatial_lon_max      = geospatial_lon_max;
metadata.geospatial_vertical_min = geospatial_vertical_min;
metadata.geospatial_vertical_max = geospatial_vertical_max;
metadata.CSV                     = strcat(Track_dir.name,filesep,File_track_csv.name);
metadata.KML                     = strcat(Track_dir.name,filesep,File_track_kml.name);
metadata.B                       = strcat(Hydro_dir.name,filesep,metadata_B.filename);
metadata.ST                      = strcat(Hydro_dir.name,filesep,metadata_ST.filename);
metadata.TIFFdir                 = strcat(TIFF_dir.name);
metadata.NumberPictures          = length(header_data);
metadata.Distance                = Divedistance;


%% fill the sample_data structure
sample_data(nrows,1)=struct('Image',[],'Year',[],'Month',[],'Day',[],...
    'Hour',[],'Minute',[],'Sec',[],'Date4SQL',[],'Pixel_Size',[],'Image_Width',[],...
    'Depth',[],'Altitude',[],'Bathy',[],...
    'TEMP',[],'PSAL',[],'CPHL',[],'OPBS',[],...
    'CDOM',[],'upLlat',[],'upLlon',[],'upRlat',[],...
    'upRlon',[],'lowRlat',[],'lowRlon',[],'lowLlat',[],...
    'lowLlon',[],'lon_center',[],'lat_center',[],'cluster',[]);

for j=1:nrows
    sample_data(j,1).Image       =Image_name{j};
    sample_data(j,1).Date4SQL    =datestrCSV(j,:);
    sample_data(j,1).Pixel_Size  =Pixel_Size(j);
    sample_data(j,1).Image_Width =Image_Width(j);
    
    sample_data(j,1).Year        =track_csv.Year(j);
    sample_data(j,1).Month       =track_csv.Month(j);
    sample_data(j,1).Day         =track_csv.Day(j);
    sample_data(j,1).Hour        =track_csv.Hour(j);
    sample_data(j,1).Minute      =track_csv.Minute(j);
    sample_data(j,1).Sec         =track_csv.Sec(j);
    sample_data(j,1).cluster     =track_csv.Cluster_Tag(j);
    sample_data(j,1).Depth       =track_csv.Depth(j);
    sample_data(j,1).Altitude    =track_csv.Altitude(j);
    sample_data(j,1).Bathy       =track_csv.Bathy(j);
    
    sample_data(j,1).TEMP        =sample_data_ST.TEMP(j);
    sample_data(j,1).PSAL        =sample_data_ST.PSAL(j);
    sample_data(j,1).CPHL        =sample_data_B.CPHL(j);
    sample_data(j,1).OPBS        =sample_data_B.OPBS(j);
    sample_data(j,1).CDOM        =sample_data_B.CDOM(j);
    
    sample_data(j,1).upLlat      =header_data(j,1).upLlat;
    sample_data(j,1).upLlon      =header_data(j,1).upLlon;
    sample_data(j,1).upRlat      =header_data(j,1).upRlat;
    sample_data(j,1).upRlon      =header_data(j,1).upRlon;
    sample_data(j,1).lowRlat     =header_data(j,1).lowRlat;
    sample_data(j,1).lowRlon     =header_data(j,1).lowRlon;
    sample_data(j,1).lowLlat     =header_data(j,1).lowLlat;
    sample_data(j,1).lowLlon     =header_data(j,1).lowLlon;
    sample_data(j,1).lon_center  =header_data(j,1).lon_center;
    sample_data(j,1).lat_center  =header_data(j,1).lat_center;
    
    
end

end
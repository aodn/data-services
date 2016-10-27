function [FileNameCSV,FileNameNC,folderHierarchy]=createAC9_HS6Filename(DATA,METADATA)
%% createAC9_HS6Filename
% this function creates the IMOS compliant filename according to the
% metadata found in the METADATA structure
% Syntax:  [FileNameCSV,FileNameNC,folderHierarchy]=createAC9_HS6Filename(DATA,METADATA)
%
% Inputs: DATA - structure created by AC9_HS6_CSV_reader
%         METADATA - structure created by AC9_HS6_CSV_reader
%
%
% Outputs:
%    FileNameCSV   - filename for the CSV file
%    FileNameNC    - filename for the NetCDF file
%    folderHierarchy- folder structure hierarchy to be copied to the IMOS
%    cloud storage
%
% Example:
%    [FileNameCSV,FileNameNC,folderHierarchy]=createAC9_HS6Filename(DATA,METADATA)
%
% Other m-files
% required:
% Other files required: config.txt
% Subfunctions: none
% MAT-files required: none
%
% See also: AC9_HS6_CSV_reader,CreateBioOptical_AC9_HS6_NetCDF
%
% Author: Laurent Besnard, IMOS/eMII
% email: laurent.besnard@utas.edu.au
% Website: http://imos.org.au/  http://froggyscripts.blogspot.com
% Aug 2011; Last revision: 28-Nov-2012

[Y, M, D, H, ~, ~]=datevec(now);
CREATION_DATE=datestr(datenum([Y, M, D, H, 0, 0]),'yyyymmddTHHMMSSZ');

FacilitySuffixe=readConfig('netcdf.facility_suffixe', 'config.txt','=');
DataType=readConfig('netcdf.data_type', 'config.txt','=');   %<Data-Code> IMOS filenaming convention

%% load variables _Column
VariableNames_Column=[DATA.VarName_Column{:}]';
VariableNames_Column=strrep(VariableNames_Column,' ','_');

TimeIdx= strcmpi(VariableNames_Column, 'time');
% LatIdx= strcmpi(VariableNames_Column, 'latitude');
% LonIdx= strcmpi(VariableNames_Column, 'longitude');
% DepthIdx= strcmpi(VariableNames_Column, 'depth');
% StationIdx= strcmpi(VariableNames_Column, 'station_code');

% VariableNames_Column{TimeIdx}='TIME';%rename in upper case
% VariableNames_Column{LatIdx}='LATITUDE';%rename in upper case
% VariableNames_Column{LonIdx}='LONGITUDE';%rename in upper case
% VariableNames_Column{DepthIdx}='DEPTH';%rename in upper case

TIME=datenum({DATA.Values_Column{:,TimeIdx}},'yyyy-mm-ddTHH:MM:SS');
% LAT=str2double(DATA.Values_Column{:,LatIdx});
% LON=str2double(DATA.Values_Column{:,LonIdx});
% STATION=(DATA.Values_Column{:,StationIdx});

%% load variables _Column
VariableNames_Column=[DATA.VarName_Column{:}]';
VariableNames_Column=strrep(VariableNames_Column,' ','_');

VariableNames_Row=[DATA.VarName_Row{:}]';
VariableNames_Row=strrep(VariableNames_Row,' ','_');

WavelengthIdx= strcmpi(VariableNames_Row, 'Wavelength');
VariableNames_Row{WavelengthIdx}='WAVELENGTH';%rename in upper case
% MainVariableIdx= ~strcmpi(VariableNames_Column, 'Wavelength');
% MainVariableName=DATA.VarName_Column{MainVariableIdx};

% WAVELENGTH=({DATA.Values_Column{:,WavelengthIdx}}');
% IndexAllColumnVariables=1:length(DATA.VarName_Column);
% IndexOfMainVar=[IndexAllColumnVariables(MainVariableIdx)];
% MainVAR=cell(size(DATA.Values_Column,1),size(DATA.Values_Column,IndexOfMainVar)-1);
% MainVAR=DATA.Values_Column(:,IndexOfMainVar:end); % we start at 2 because this where the main var starts



%% Create a NEW netCDF file.
if sum(strcmpi(VariableNames_Column, 'ad'))==1
    RefName= 'AC9_HS6-non-algal-detritus';
elseif sum(strcmpi(VariableNames_Column, 'ag'))==1
    RefName= 'AC9_HS6-CDOM';
elseif sum(strcmpi(VariableNames_Column, 'aph'))==1
    RefName= 'AC9_HS6-phytoplankton';
end



GATTANAME=strrep([METADATA.gAttName{:}]',' ','_'); % replace blanck by _ in case the CSV template is badly done
cruise_id=strrep(METADATA.gAttVal{ strcmpi(GATTANAME, 'cruise_id')}, '/', '-');

% find instrument name
attSource=METADATA.gAttVal{ strcmpi(GATTANAME, 'source')};
if ~isempty(cell2mat(strfind(attSource,'AC-9'))) && ~isempty(cell2mat(strfind(attSource,'Filtered')))
    Instrument='AC-9-absorption-CDOM';
    dataType='absorption';
    
elseif ~isempty(cell2mat(strfind(attSource,'AC-9'))) && ~isempty(cell2mat(strfind(attSource,'Total')))
    Instrument='AC-9-absorption-total';
    dataType='absorption';
    
elseif ~isempty(cell2mat(strfind(attSource,'HS-6')))
    Instrument='HS-6';
    dataType='backscattering';
    
else
    Instrument='Unknown';
    dataType='Unknown';
end

StationIdx= strcmpi(VariableNames_Column, 'station_code');
STATION=({DATA.Values_Column{:,StationIdx}}');

if length(unique(STATION)) == 1
    %this means that we only have one station per file, therefor the free
    %part in the NetCDF filename will be set as [cruiseID]-[stationCode]
    IMOS_NAME_freePartCode=strcat(cruise_id,'-',STATION{1},'-',Instrument);
else
    IMOS_NAME_freePartCode=strcat(cruise_id,'-',Instrument);
end

FileNameNC=strcat(FacilitySuffixe,'_',DataType,'_',datestr(min(TIME),'yyyymmddTHHMMSSZ'),'_',IMOS_NAME_freePartCode,'_END-',datestr(max(TIME),'yyyymmddTHHMMSSZ'),'_C-',CREATION_DATE,'.nc');
FileNameCSV=strcat(FacilitySuffixe,'_',DataType,'_',datestr(min(TIME),'yyyymmddTHHMMSSZ'),'_',IMOS_NAME_freePartCode,'_END-',datestr(max(TIME),'yyyymmddTHHMMSSZ'),'.csv');


folderHierarchy=strrep(strcat(datestr(min(TIME),'yyyy'),'_cruise-',char(cruise_id),filesep,dataType),' ','-');
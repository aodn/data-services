function [FileNameCSV,FileNameNC,folderHierarchy]=createAbsorptionFilename(DATA,METADATA)
%% createAbsorptionFilename
% this function creates the IMOS compliant filename according to the 
% metadata found in the METADATA structure
% Syntax:  [FileNameCSV,FileNameNC,folderHierarchy]=createAbsorptionFilename(DATA,METADATA)
%
% Inputs: DATA - structure created by Absorption_CSV_reader
%         METADATA - structure created by Absorption_CSV_reader
%   
%
% Outputs:
%    FileNameCSV   - filename for the CSV file
%    FileNameNC    - filename for the NetCDF file
%    folderHierarchy- folder structure hierarchy to be copied to the IMOS
%    cloud storage
%
% Example: 
%    [FileNameCSV,FileNameNC,folderHierarchy]=createAbsorptionFilename(DATA,METADATA)
%
% Other m-files
% required:
% Other files required: config.txt
% Subfunctions: none
% MAT-files required: none
%
% See also: Absorption_CSV_reader,CreateBioOptical_Absorption_NetCDF
% 
% Author: Laurent Besnard, IMOS/eMII
% email: laurent.besnard@utas.edu.au
% Website: http://imos.org.au/  http://froggyscripts.blogspot.com
% Aug 2011; Last revision: 28-Nov-2012

[Y, M, D, H, ~, ~]=datevec(now);
CREATION_DATE=datestr(datenum([Y, M, D, H, 0, 0]),'yyyymmddTHHMMSSZ');

FacilitySuffixe=readConfig('netcdf.facility_suffixe', 'config.txt','=');
DataType=readConfig('netcdf.data_type', 'config.txt','=');   %<Data-Code> IMOS filenaming convention

%% load variables _Row
VariableNames_Row=[DATA.VarName_Row{:}]';
VariableNames_Row=strrep(VariableNames_Row,' ','_');

TimeIdx= strcmpi(VariableNames_Row, 'time');
% LatIdx= strcmpi(VariableNames_Row, 'latitude');
% LonIdx= strcmpi(VariableNames_Row, 'longitude');
% DepthIdx= strcmpi(VariableNames_Row, 'depth');
% StationIdx= strcmpi(VariableNames_Row, 'station_code');

% VariableNames_Row{TimeIdx}='TIME';%rename in upper case
% VariableNames_Row{LatIdx}='LATITUDE';%rename in upper case
% VariableNames_Row{LonIdx}='LONGITUDE';%rename in upper case
% VariableNames_Row{DepthIdx}='DEPTH';%rename in upper case

TIME=datenum(DATA.Values_Row{:,TimeIdx},'yyyy-mm-ddTHH:MM:SS');
% LAT=str2double(DATA.Values_Row{:,LatIdx});
% LON=str2double(DATA.Values_Row{:,LonIdx});
% STATION=(DATA.Values_Row{:,StationIdx});

%% load variables _Column
VariableNames_Column=[DATA.VarName_Column{:}]';
VariableNames_Column=strrep(VariableNames_Column,' ','_');

WavelengthIdx= strcmpi(VariableNames_Column, 'Wavelength');
VariableNames_Column{WavelengthIdx}='WAVELENGTH';%rename in upper case
% MainVariableIdx= ~strcmpi(VariableNames_Column, 'Wavelength');
% MainVariableName=DATA.VarName_Column{MainVariableIdx};

% WAVELENGTH=({DATA.Values_Column{:,WavelengthIdx}}');
% IndexAllColumnVariables=1:length(DATA.VarName_Column);
% IndexOfMainVar=[IndexAllColumnVariables(MainVariableIdx)];
% MainVAR=cell(size(DATA.Values_Column,1),size(DATA.Values_Column,IndexOfMainVar)-1);
% MainVAR=DATA.Values_Column(:,IndexOfMainVar:end); % we start at 2 because this where the main var starts



%% Create a NEW netCDF file.
if sum(strcmpi(VariableNames_Column, 'ad'))==1
    RefName= 'absorption-non-algal-detritus';
elseif sum(strcmpi(VariableNames_Column, 'ag'))==1
    RefName= 'absorption-CDOM';
elseif sum(strcmpi(VariableNames_Column, 'aph'))==1
    RefName= 'absorption-phytoplankton';
elseif sum(strcmpi(VariableNames_Column, 'ap'))==1
    RefName= 'absorption-phytoplankton-non-algal-detritus';
end



GATTANAME=strrep([METADATA.gAttName{:}]',' ','_'); % replace blanck by _ in case the CSV template is badly done
cruise_id=METADATA.gAttVal{ strcmpi(GATTANAME, 'cruise_id')};
FileNameNC=strcat(FacilitySuffixe,'_',DataType,'_',datestr(min(TIME),'yyyymmddTHHMMSSZ'),'_',cruise_id,'-',RefName,'_END-',datestr(max(TIME),'yyyymmddTHHMMSSZ'),'_C-',CREATION_DATE,'.nc');
FileNameCSV=strcat(FacilitySuffixe,'_',DataType,'_',datestr(min(TIME),'yyyymmddTHHMMSSZ'),'_',cruise_id,'-',RefName,'_END-',datestr(max(TIME),'yyyymmddTHHMMSSZ'),'.csv');

folderHierarchy=strrep(strcat(datestr(min(TIME),'yyyy'),'_cruise-',char(cruise_id),filesep,'absorption'),' ','-');
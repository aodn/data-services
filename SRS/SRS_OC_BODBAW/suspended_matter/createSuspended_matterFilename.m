function [FileNameCSV,FileNameNC,folderHierarchy]=createSuspended_matterFilename(DATA,METADATA)
%% createSuspended_matterFilename
% this function creates the IMOS compliant filename according to the 
% metadata found in the METADATA structure
% Syntax:  [FileNameCSV,FileNameNC,folderHierarchy]=createSuspended_matterFilename(DATA,METADATA)
%
% Inputs: DATA - structure created by Pigment_CSV_reader
%         METADATA - structure created by Pigment_CSV_reader
%   
%
% Outputs:
%    FileNameCSV   - filename for the CSV file
%    FileNameNC    - filename for the NetCDF file
%    folderHierarchy- folder structure hierarchy to be copied to the IMOS
%    cloud storage
%
% Example: 
%    [FileNameCSV,FileNameNC,folderHierarchy]=createSuspended_matterFilename(DATA,METADATA)
%
% Other m-files
% required:
% Other files required: config.txt
% Subfunctions: none
% MAT-files required: none
%
% See also: Pigment_CSV_reader,CreateBioOptical_Pigment_NetCDF
% 
% Author: Laurent Besnard, IMOS/eMII
% email: laurent.besnard@utas.edu.au
% Website: http://imos.org.au/  http://froggyscripts.blogspot.com
% Aug 2011; Last revision: 28-Nov-2012

[Y, M, D, H, ~, ~]=datevec(now);
CREATION_DATE=datestr(datenum([Y, M, D, H, 0, 0]),'yyyymmddTHHMMSSZ');

FacilitySuffixe=readConfig('netcdf.facility_suffixe', 'config.txt','=');
DataType=readConfig('netcdf.data_type', 'config.txt','=');   %<Data-Code> IMOS filenaming convention

% %% load variables 
VariableNames=[DATA.VarName{:}]';
VariableNames=strrep(VariableNames,' ','_');
 
TimeIdx= strcmpi(VariableNames, 'time');
TIME=datenum({DATA.Values{:,TimeIdx}}','yyyy-mm-ddTHH:MM:SS');


GATTANAME=strrep([METADATA.gAttName{:}]',' ','_'); % replace blanck by _ in case the CSV template is badly done
cruise_id=strrep(METADATA.gAttVal{ strcmpi(GATTANAME, 'cruise_id')}, '/', '-');
FileNameNC=strcat(FacilitySuffixe,'_',DataType,'_',datestr(min(TIME),'yyyymmddTHHMMSSZ'),'_',cruise_id,'-suspended_matter','_END-',datestr(max(TIME),'yyyymmddTHHMMSSZ'),'_C-',CREATION_DATE,'.nc');
FileNameCSV=strcat(FacilitySuffixe,'_',DataType,'_',datestr(min(TIME),'yyyymmddTHHMMSSZ'),'_',cruise_id,'-suspended_matter','_END-',datestr(max(TIME),'yyyymmddTHHMMSSZ'),'.csv');

folderHierarchy=strrep(strcat(datestr(min(TIME),'yyyy'),'_cruise-',char(cruise_id),filesep,'suspended_matter'),' ','-');
end
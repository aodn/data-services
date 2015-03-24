function [long_name,lastDate,filenameNew] = NetCDF_getinfo (filepath,filename)
%% NetCDF_getinfo 
% gets the long name of the main variable found in each NetCDF file. 
% This value will be used to create the folder where the file will be stored
%
% Inputs:
%   filename    -filename to test
%   filepath    -the path of the filename
% Outputs:
%   long_name       
%   lastDate 
%   filenameNew
%
% See also:downloadChannelNRS,NRS_processLevel
% 
% Author: Laurent Besnard, IMOS/eMII
% email: laurent.besnard@utas.edu.au
% Website: http://imos.org.au/  http://froggyscripts.blogspot.com
% Aug 2012; Last revision: 01-Oct-2012


nc = netcdf.open(strcat(filepath,filename),'NC_WRITE');

%% list all the Variables
[VARNAME,~]=listVarNC(nc);

idxLON= strcmpi(VARNAME,'longitude')==1; %idx to remove from sub_array_of_variables
idxTIME= strcmpi(VARNAME,'time')==1; %idx to remove from sub_array_of_variables
idxDEPTH= strcmpi(VARNAME,'depth')==1; %idx to remove from sub_array_of_variables
idxLAT= strcmpi(VARNAME,'latitude')==1; %idx to remove from sub_array_of_variables

array_of_all_variables=1:length(VARNAME);
sub_array_of_variables=array_of_all_variables(setdiff(1:length(array_of_all_variables),[array_of_all_variables(idxTIME),array_of_all_variables(idxLAT),...
    array_of_all_variables(idxLON),array_of_all_variables(idxDEPTH)]));

% get the long name of the main variable
for ii=sub_array_of_variables
    if  isempty(strfind(char(VARNAME(ii)),'_quality_control'))
        long_name = netcdf.getAtt(nc,netcdf.inqVarID(nc,VARNAME{ii}),'long_name');
        long_name=strrep(long_name, ' ', '_');
    end
end

if ~exist('long_name','var') 
    %this mean that the main variable is actually DEPTH. new 'feature' from
    %AIMS, so we assume that long_name='DEPTH' .2014.02.04
    long_name = 'DEPTH';
end

%% we grab the date dimension
idxTIME= strcmpi(VARNAME,'TIME')==1;
TimeVarName=VARNAME{idxTIME};

% we grab the date dimension
date_id=netcdf.inqDimID(nc,TimeVarName);
[~, dimlen] = netcdf.inqDim(nc,date_id);

if dimlen >0
    [~,~,firstDateNum,lastDateNum]= getTimeOffsetNC(nc);
    lastDate=datestr(lastDateNum,'yyyy-mm-ddTHH:MM:SSZ');%date in RSS feed are queried in UTC      
    
    % we write the time (which is in UTC) in good UTC format in the NcFile
    filenameNew=filename;
    filenameNew=regexprep(filenameNew, '\d[\dT]+Z', datestr(firstDateNum,'yyyymmddTHHMMSSZ'),'once'); % if there is a + , it is incoherent.
    filenameNew=regexprep(filenameNew, '_END-[\dT]+Z', strcat('_END-',datestr(lastDateNum,'yyyymmddTHHMMSSZ')),1); % if there is a + , it is incoherent.    
    

    netcdf.close(nc);
    if ~strcmp(filenameNew,filename)
        movefile(strcat(filepath,filename),strcat(filepath,filenameNew));
    end
else
    netcdf.close(nc);
    indexEnd=strfind( filename,'END-')+length('END-');
    lastDate=datestr(datevec(filename(indexEnd:indexEnd+14),'yyyymmddTHHMMSS'),'yyyy-mm-ddTHH:MM:SS');
    filenameNew=filename;
end
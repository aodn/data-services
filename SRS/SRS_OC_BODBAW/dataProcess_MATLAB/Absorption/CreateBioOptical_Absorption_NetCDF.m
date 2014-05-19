function CreateBioOptical_Absorption_NetCDF(DATA,METADATA,FileNameNC,folderHierarchy)
%% CreateBioOptical_Absorption_NetCDF
% this function creates the IMOS NetCDF file for absorption data
% Syntax:  CreateBioOptical_Absorption_NetCDF(DATA,METADATA,FileName,folderHierarchy)
%
% Inputs: DATA - structure created by Absorption_CSV_reader
%         METADATA - structure created by Absorption_CSV_reader
%         FileName - filename created by createAbsorptionFilename
%         folderHierarchy - folder structure hierarchy created by createAbsorptionFilename
% Outputs:
%
%
% Example:
%    CreateBioOptical_Absorption_NetCDF(DATA,METADATA,FileName,folderHierarchy)
%
% Other m-files
% required:
% Other files required:config.txt
% Subfunctions: none
% MAT-files required: none
%
% See also: Absorption_CSV_reader,createAbsorptionFilename
%
% Author: Laurent Besnard, IMOS/eMII
% email: laurent.besnard@utas.edu.au
% Website: http://imos.org.au/  http://froggyscripts.blogspot.com
% Aug 2011; Last revision: 28-Nov-2012

DataFileFolder=readConfig('data_absorption.path', 'config.txt','=');

%% load variables _Row
VariableNames_Row=[DATA.VarName_Row{:}]';
VariableNames_Row=strrep(VariableNames_Row,' ','_');

TimeIdx= strcmpi(VariableNames_Row, 'time');
LatIdx= strcmpi(VariableNames_Row, 'latitude');
LonIdx= strcmpi(VariableNames_Row, 'longitude');
DepthIdx= strcmpi(VariableNames_Row, 'depth');
StationIdx= strcmpi(VariableNames_Row, 'station_code');

VariableNames_Row{TimeIdx}='TIME';%rename in upper case
VariableNames_Row{LatIdx}='LATITUDE';%rename in upper case
VariableNames_Row{LonIdx}='LONGITUDE';%rename in upper case
VariableNames_Row{DepthIdx}='DEPTH';%rename in upper case

TIME=datenum(DATA.Values_Row{:,TimeIdx},'yyyy-mm-ddTHH:MM:SS');
LAT=str2double(DATA.Values_Row{:,LatIdx});
LON=str2double(DATA.Values_Row{:,LonIdx});
STATION=(DATA.Values_Row{:,StationIdx});

%% load variables _Column
VariableNames_Column=[DATA.VarName_Column{:}]';
VariableNames_Column=strrep(VariableNames_Column,' ','_');

WavelengthIdx= strcmpi(VariableNames_Column, 'Wavelength');
VariableNames_Column{WavelengthIdx}='WAVELENGTH';%rename in upper case
MainVariableIdx= ~strcmpi(VariableNames_Column, 'Wavelength');
MainVariableName=DATA.VarName_Column{MainVariableIdx};

WAVELENGTH=({DATA.Values_Column{:,WavelengthIdx}}');
IndexAllColumnVariables=1:length(DATA.VarName_Column);
IndexOfMainVar=[IndexAllColumnVariables(MainVariableIdx)];
MainVAR=cell(size(DATA.Values_Column,1),size(DATA.Values_Column,IndexOfMainVar)-1);
MainVAR=DATA.Values_Column(:,IndexOfMainVar:end); % we start at 2 because this where the main var starts



mkpath(strcat(DataFileFolder,filesep,'NetCDF',filesep,folderHierarchy,filesep))

if exist(fullfile(DataFileFolder,filesep,'NetCDF',filesep,folderHierarchy,filesep,char(FileNameNC)),'file')==2
    fprintf('%s - WARNING: NetCDF file already exists\n',datestr(now))
    return
end


ncid = netcdf.create(fullfile(DataFileFolder,'NetCDF',filesep,folderHierarchy,filesep,char(FileNameNC)),'NC_NOCLOBBER');
for uu=1:length(METADATA.gAttName)
    netcdf.putAtt(ncid,netcdf.getConstant('GLOBAL'),char(METADATA.gAttName{uu}),char(METADATA.gAttVal{uu}));
end

%% change these following attributes into numbers and not char
AttNames=[METADATA.gAttName{:}]';
GeoDepthMinIdx= strcmpi(AttNames, 'geospatial_vertical_min');
GeoDepthMaxIdx= strcmpi(AttNames, 'geospatial_vertical_max');
TimeZoneIdx= strcmpi(AttNames, 'local_time_zone');

netcdf.putAtt(ncid,netcdf.getConstant('GLOBAL'),char(METADATA.gAttName{GeoDepthMinIdx}),str2double(char(METADATA.gAttVal{GeoDepthMinIdx})));
netcdf.putAtt(ncid,netcdf.getConstant('GLOBAL'),char(METADATA.gAttName{GeoDepthMaxIdx}),str2double(char(METADATA.gAttVal{GeoDepthMaxIdx})));
netcdf.putAtt(ncid,netcdf.getConstant('GLOBAL'),char(METADATA.gAttName{TimeZoneIdx}),str2double(char(METADATA.gAttVal{TimeZoneIdx})));


%% Creation of global attributes
gattname{1}='Conventions';
gattval{1}='CF-1.5, IMOS-1.2';

gattname{2}='date_created';
gattval{2}=datestr(now,'yyyy-mm-ddTHH:MM:SSZ') ;

gattname{3}='date_modified';
gattval{3}=datestr(now,'yyyy-mm-ddTHH:MM:SSZ') ;

gattname{4}='netcdf_version';
gattval{4}='3.6';

gattname{5}='geospatial_lat_min';
gattval{5}=(min(LAT));

gattname{6}='geospatial_lat_max';
gattval{6}=(max(LAT));

gattname{7}='geospatial_lon_min';
gattval{7}=(min(LON));

gattname{8}='geospatial_lon_max';
gattval{8}=(max(LON));

gattname{9}='time_coverage_start';
gattval{9}=datestr(min(TIME),'yyyy-mm-ddTHH:MM:SSZ') ;

gattname{10}='time_coverage_end';
gattval{10}=datestr(max(TIME),'yyyy-mm-ddTHH:MM:SSZ') ;

gattname{11}='featureType';
gattval{11}='timeSeries';
gattname{12}='netcdf_author';
gattval{12}='Besnard, Laurent';

gattname{13}='netcdf_author_email';
gattval{13}='laurent.besnard@utas.edu.au';


for uu=1:length(gattname)
    netcdf.putAtt(ncid,netcdf.getConstant('GLOBAL'),gattname{uu}, gattval{uu});
end

%%  Creation of the DIMENSION
Observation_Name='obs';
Station_Name='station';
Profile_Name='profile';
Wavelength_Name='wavelength';

dimlen_Observation_Dim=length(TIME);
dimlen_Station_Dim=length(uunique(STATION));
dimlen_Profile_Dim=length(uunique(TIME));
dimlen_Wavelength_Dim=length(WAVELENGTH);


OBS_dimid = netcdf.defDim(ncid,Observation_Name,dimlen_Observation_Dim);
Station_Dimid = netcdf.defDim(ncid,Station_Name,dimlen_Station_Dim);
Profile_Dimid = netcdf.defDim(ncid,Profile_Name,dimlen_Profile_Dim);
Station_stringdimID = netcdf.defDim(ncid, 'name_strlen', 19);
Wavelength_dimid = netcdf.defDim(ncid,Wavelength_Name,dimlen_Wavelength_Dim);


nc_char = netcdf.getConstant('NC_CHAR');
%
% if length(uunique(TIME))~=dimlen_Station_Dim
%     % A station (profile) is not attached to a single tine only. In that
%     % scenario, the variable time depends on observation and not on
%     % profile. This is used later to create the variable
%     TimeIsObservation=1;
% else
%     TimeIsObservation=0;
% end

%% create Vector Indexes of Non LAT, LON, DEPTH, TIME and STATION variables
IndexAllRowVariables=1:length(VariableNames_Row);


IndexOfNonPositionVariables=IndexAllRowVariables(setdiff(1:length(IndexAllRowVariables),...
    [IndexAllRowVariables(TimeIdx),...
    IndexAllRowVariables(LatIdx),...
    IndexAllRowVariables(LonIdx),...
    IndexAllRowVariables(StationIdx)]));%in that case, this is Depth


IndexOfPositionVariables=[IndexAllRowVariables(LatIdx),...
    IndexAllRowVariables(LonIdx)];

%% creation of the time variable
TIME_ID=netcdf.defVar(ncid,VariableNames_Row{IndexAllRowVariables(TimeIdx)},'double',[Profile_Dimid]);


%% creation of the positions variables
for ii=IndexOfPositionVariables
    VAR_PositionVariables_ID{ii} = netcdf.defVar(ncid,VariableNames_Row{ii},'float',[Station_Dimid]);
end
% VAR_PositionVariables_ID=VAR_PositionVariables_ID(~cellfun('isempty',VAR_PositionVariables_ID));

Station_VAR_ID=netcdf.defVar(ncid,'station_name',nc_char,[Station_stringdimID,Station_Dimid]);
Profile_VAR_ID=netcdf.defVar(ncid,'profile','short',[Profile_Dimid]);
StationIDX_VAR_ID=netcdf.defVar(ncid,'station_index','short',[Profile_Dimid]);
RowSize_VAR_ID=netcdf.defVar(ncid,'rowSize','short',[Profile_Dimid]);

WAVELENGHT_VAR_ID=netcdf.defVar(ncid,'wavelength','float',[Wavelength_dimid]);

%% creation of the rest of Row variables , in that case, this is depth
for ii=IndexOfNonPositionVariables
    VAR_NonPositionVariables_ID{ii} = netcdf.defVar(ncid,VariableNames_Row{ii},'float',[OBS_dimid]);
end

%% creation of the main variable, ag ad or aph
for ii=IndexOfMainVar
    VAR_MainVariable_ID{ii}=netcdf.defVar(ncid,char(MainVariableName),'float',[Wavelength_dimid,OBS_dimid]);
end
netcdf.endDef(ncid)


%% Creation of the ROW VARIABLE ATTRIBUTES
netcdf.reDef(ncid)
for ii=IndexOfNonPositionVariables
    %     DATA.VarName_Row{ii}
    if ~isempty(char(DATA.Long_Name_Row{ii}))
        netcdf.putAtt(ncid,VAR_NonPositionVariables_ID{ii},'long_name',char(DATA.Long_Name_Row{ii}));
    end
    
    if ~isempty(char(DATA.Standard_Name_Row{ii}))
        netcdf.putAtt(ncid,VAR_NonPositionVariables_ID{ii},'standard_name',char(DATA.Standard_Name_Row{ii}));
    end
    
    if ~isempty(char(DATA.Units_Row{ii}))
        netcdf.putAtt(ncid,VAR_NonPositionVariables_ID{ii},'units',char(DATA.Units_Row{ii}));
    end
    
    if ~isempty(char(DATA.FillValue_Row{ii}))
        netcdf.putAtt(ncid,VAR_NonPositionVariables_ID{ii},'_FillValue',single(str2double(char(DATA.FillValue_Row{ii}))));
    end
    
    if ~isempty(char(DATA.Comments_Row{ii}))
        netcdf.putAtt(ncid,VAR_NonPositionVariables_ID{ii},'comment',char(DATA.Comments_Row{ii}));
    end
    %     netcdf.putAtt(ncid,VAR_NonPositionVariables_ID{ii},'coordinates',...
    %         char(strcat(VariableNames_Row(TimeIdx),[{' '}],VariableNames_Row(LonIdx),[{' '}],VariableNames_Row(LatIdx),[{' '}],VariableNames_Row(DepthIdx))));
    
end



for ii=IndexOfPositionVariables
    %     DATA.VarName_Row{ii}
    if ~isempty(char(DATA.Long_Name_Row{ii}))
        netcdf.putAtt(ncid,VAR_PositionVariables_ID{ii},'long_name',char(DATA.Long_Name_Row{ii}));
    end
    
    if ~isempty(char(DATA.Standard_Name_Row{ii}))
        netcdf.putAtt(ncid,VAR_PositionVariables_ID{ii},'standard_name',char(DATA.Standard_Name_Row{ii}));
    end
    
    if ~isempty(char(DATA.Units_Row{ii}))
        netcdf.putAtt(ncid,VAR_PositionVariables_ID{ii},'units',char(DATA.Units_Row{ii}));
    end
    
    if ~isempty(char(DATA.FillValue_Row{ii}))
        netcdf.putAtt(ncid,VAR_PositionVariables_ID{ii},'_FillValue',single(str2double(char(DATA.FillValue_Row{ii}))));
    end
    
    if ~isempty(char(DATA.Comments_Row{ii}))
        netcdf.putAtt(ncid,VAR_PositionVariables_ID{ii},'comment',char(DATA.Comments_Row{ii}));
    end
end


%% Creation of the Column VARIABLE ATTRIBUTES
for ii=IndexOfMainVar
    %     DATA.VarName_Column{ii}
    if ~isempty(char(DATA.Long_Name_Column{ii}))
        netcdf.putAtt(ncid,VAR_MainVariable_ID{ii},'long_name',char(DATA.Long_Name_Column{ii}));
    end
    
    if ~isempty(char(DATA.Standard_Name_Column{ii}))
        netcdf.putAtt(ncid,VAR_MainVariable_ID{ii},'standard_name',char(DATA.Standard_Name_Column{ii}));
    end
    
    if ~isempty(char(DATA.Units_Column{ii}))
        netcdf.putAtt(ncid,VAR_MainVariable_ID{ii},'units',char(DATA.Units_Column{ii}));
    end
    
    if ~isempty(char(DATA.FillValue_Column{ii}))
        netcdf.putAtt(ncid,VAR_MainVariable_ID{ii},'_FillValue',single(str2double(char(DATA.FillValue_Column{ii}))));
    end
    
    if ~isempty(char(DATA.Comments_Row{ii}))
        netcdf.putAtt(ncid,VAR_MainVariable_ID{ii},'comment',char(DATA.Comments_Row{ii}));
    end
    
    %     netcdf.putAtt(ncid,VAR_MainVariable_ID{ii},'coordinates',...
    %         char(strcat(VariableNames_Row(TimeIdx),[{' '}],VariableNames_Row(LonIdx),[{' '}],VariableNames_Row(LatIdx),[{' '}],VariableNames_Row(DepthIdx),[{' '}],VariableNames_Column(WavelengthIdx))));
    
end

%% Contigious ragged array representation of Stations netcdf 1.5
netcdf.putAtt(ncid,Station_VAR_ID,'long_name','station name');
netcdf.putAtt(ncid,Station_VAR_ID,'cf_role','timeseries_id');

netcdf.putAtt(ncid,Profile_VAR_ID,'cf_role','profile_id');
netcdf.putAtt(ncid,Profile_VAR_ID,'long_name','profile_index');

netcdf.putAtt(ncid,StationIDX_VAR_ID,'long_name','which station this profile is for')
netcdf.putAtt(ncid,StationIDX_VAR_ID,'instance_dimension','station')

netcdf.putAtt(ncid,RowSize_VAR_ID,'long_name','number of observation for this profile');
netcdf.putAtt(ncid,RowSize_VAR_ID,'sample_dimension','obs')

%wavelength
netcdf.putAtt(ncid,WAVELENGHT_VAR_ID,'long_name',char(DATA.Long_Name_Column{WavelengthIdx}))
netcdf.putAtt(ncid,WAVELENGHT_VAR_ID,'_FillValue',single(str2double(char(DATA.FillValue_Column{WavelengthIdx}))))
netcdf.putAtt(ncid,WAVELENGHT_VAR_ID,'units',char(DATA.Units_Column{WavelengthIdx}))
netcdf.putAtt(ncid,WAVELENGHT_VAR_ID,'standard_name',char(DATA.Standard_Name_Column {WavelengthIdx}))


%time
netcdf.putAtt(ncid,TIME_ID,'standard_name','time');
netcdf.putAtt(ncid,TIME_ID,'long_name','time');
netcdf.putAtt(ncid,TIME_ID,'units','days since 1970-01-01T00:00:00 UTC');
netcdf.putAtt(ncid,TIME_ID,'axis','T');

%lon
LON_ID= VAR_PositionVariables_ID{strcmpi(VariableNames_Row, 'longitude')};
netcdf.putAtt(ncid,LON_ID,'long_name','longitude');
netcdf.putAtt(ncid,LON_ID,'standard_name','longitude');
netcdf.putAtt(ncid,LON_ID,'units','degrees_east');
netcdf.putAtt(ncid,LON_ID,'axis','X');
netcdf.putAtt(ncid,LON_ID,'valid_min',single(-180));
netcdf.putAtt(ncid,LON_ID,'valid_max',single(180));
netcdf.putAtt(ncid,LON_ID,'_FillValue',single(9999));
netcdf.putAtt(ncid,LON_ID,'reference_datum','geographical coordinates, WGS84 projection');

%lat
LAT_ID= VAR_PositionVariables_ID{strcmpi(VariableNames_Row, 'latitude')};
netcdf.putAtt(ncid,LAT_ID,'long_name','latitude');
netcdf.putAtt(ncid,LAT_ID,'standard_name','latitude');
netcdf.putAtt(ncid,LAT_ID,'units','degrees_north');
netcdf.putAtt(ncid,LAT_ID,'axis','Y');
netcdf.putAtt(ncid,LAT_ID,'valid_min',single(-90));
netcdf.putAtt(ncid,LAT_ID,'valid_max',single(90));
netcdf.putAtt(ncid,LAT_ID,'_FillValue',single(9999));
netcdf.putAtt(ncid,LAT_ID,'reference_datum','geographical coordinates, WGS84 projection');

%depth
DEPTH_ID= VAR_NonPositionVariables_ID{strcmpi(VariableNames_Row, 'depth')};
netcdf.putAtt(ncid,DEPTH_ID,'positive','down');
netcdf.putAtt(ncid,DEPTH_ID,'axis','Z');




netcdf.endDef(ncid)

%%%%%%%%%%%%%%%% DATA writing

%% write TIME
TimeForNetCDF=(TIME -datenum('1970-01-01','yyyy-mm-dd')); %num of day
netcdf.putVar(ncid,TIME_ID,uunique(TimeForNetCDF));


%% write LAT LON
LatValues=LAT;
LonValues=LON;

A={STATION{:}};
[UniqueStation,BB]=uunique(A);

netcdf.putVar(ncid,LAT_ID,LatValues(BB));
netcdf.putVar(ncid,LON_ID,LonValues(BB));

%% write station name data
ListStationsID=uunique(UniqueStation);
for ii=1:length(ListStationsID)
    netcdf.putVar(ncid,Station_VAR_ID,[0,ii-1],[length(ListStationsID{ii}),1],ListStationsID{ii});
end


%% compute the number of observations per profile
[UniqueTimeValues,m1 ]=uunique(TIME);  % is equal to a profile
[~, index]=ismember(UniqueTimeValues(:),TIME);
index2=[];
index2(1)=0;
index2(2:length(index))=index(1:length(index)-1);
NumObsPerProfile=index-index2';

netcdf.putVar(ncid,RowSize_VAR_ID,NumObsPerProfile);

%% compute which station each profile is for
Station2Profile=A(m1);
[~, IdxStationForProfile] = ismember(Station2Profile,UniqueStation);
IdxStationForProfile=IdxStationForProfile';

netcdf.putVar(ncid,StationIDX_VAR_ID,IdxStationForProfile);

%% Profile id index
netcdf.putVar(ncid,Profile_VAR_ID,[1:length(m1)]);


%% write standards variables
for ii=IndexOfNonPositionVariables
    netcdf.putVar(ncid,VAR_NonPositionVariables_ID{ii},str2double(DATA.Values_Row{:,ii}));
end

%% write main variable
for ii=IndexOfMainVar
    netcdf.putVar(ncid,VAR_MainVariable_ID{ii},str2double(MainVAR));
    %  netcdf.putVar(ncid,VAR_MainVariable_ID{ii},[0,0],[dimlen_Observation_Dim,dimlen_Wavelength_Dim],str2double(MainVAR))
    % netcdf.putVar(ncid,VAR_MainVariable_ID{ii},[0,0],[dimlen_Wavelength_Dim,dimlen_Observation_Dim],str2double(MainVAR)')
end

%% write wavelength variable
netcdf.putVar(ncid,WAVELENGHT_VAR_ID,str2double(WAVELENGTH));


%% delete
netcdf.close(ncid);
fprintf('%s - SUCCESS: file has been created\n',datestr(now))

end

function [b,m]=uunique(A)
[~, m1]=unique(A,'first');
b=A(sort(m1));
m=sort(m1);
end
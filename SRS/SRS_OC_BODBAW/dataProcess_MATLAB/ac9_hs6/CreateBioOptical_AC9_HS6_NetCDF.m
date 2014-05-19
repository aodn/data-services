function CreateBioOptical_AC9_HS6_NetCDF(DATA,METADATA,FileNameNC,folderHierarchy)
%% CreateBioOptical_AC9_HS6_NetCDF
% this function creates the IMOS NetCDF file for AC9_HS6 data
% Syntax:  CreateBioOptical_AC9_HS6_NetCDF(DATA,METADATA,FileName,folderHierarchy)
%
% Inputs: DATA - structure created by AC9_HS6_CSV_reader
%         METADATA - structure created by AC9_HS6_CSV_reader
%         FileName - filename created by createAC9_HS6Filename
%         folderHierarchy - folder structure hierarchy created by createAC9_HS6Filename
% Outputs:
%
%
% Example:
%    CreateBioOptical_AC9_HS6_NetCDF(DATA,METADATA,FileName,folderHierarchy)
%
% Other m-files
% required:
% Other files required:config.txt
% Subfunctions: none
% MAT-files required: none
%
% See also: AC9_HS6_CSV_reader,createAC9_HS6Filename
%
% Author: Laurent Besnard, IMOS/eMII
% email: laurent.besnard@utas.edu.au
% Website: http://imos.org.au/  http://froggyscripts.blogspot.com
% Aug 2011; Last revision: 28-Nov-2012

DataFileFolder=readConfig('data_ac9_hs6.path', 'config.txt','=');

%% load variables _Column
VariableNames_Column=[DATA.VarName_Column{:}]';
VariableNames_Column=strrep(VariableNames_Column,' ','_');

TimeIdx= strcmpi(VariableNames_Column, 'time');
LatIdx= strcmpi(VariableNames_Column, 'latitude');
LonIdx= strcmpi(VariableNames_Column, 'longitude');
DepthIdx= strcmpi(VariableNames_Column, 'depth');
StationIdx= strcmpi(VariableNames_Column, 'station_code');

VariableNames_Column{TimeIdx}='TIME';%rename in upper case
VariableNames_Column{LatIdx}='LATITUDE';%rename in upper case
VariableNames_Column{LonIdx}='LONGITUDE';%rename in upper case
VariableNames_Column{DepthIdx}='DEPTH';%rename in upper case

TIME=datenum({DATA.Values_Column{:,TimeIdx}},'yyyy-mm-ddTHH:MM:SS');
LAT=str2double({DATA.Values_Column{:,LatIdx}});
LON=str2double({DATA.Values_Column{:,LonIdx}});
STATION=strrep({DATA.Values_Column{:,StationIdx}},' ','');%remove blank space from strings for the station name
DEPTH=str2double({DATA.Values_Column{:,DepthIdx}});

%% load variables _Row
VariableNames_Row=[DATA.VarName_Row{:}]';
VariableNames_Row=strrep(VariableNames_Row,' ','_');

WavelengthIdx= strcmpi(VariableNames_Row, 'Wavelength');
VariableNames_Row{WavelengthIdx}='WAVELENGTH';%rename in upper case

IndexAllColumnVariables=1:length(VariableNames_Column);

IndexOfMainVariables=IndexAllColumnVariables(setdiff(1:length(IndexAllColumnVariables),...
    [IndexAllColumnVariables(TimeIdx),...
    IndexAllColumnVariables(LatIdx),...
    IndexAllColumnVariables(LonIdx),...
    IndexAllColumnVariables(DepthIdx),...
    IndexAllColumnVariables(StationIdx)]));%in that case, this is Depth

% VariableNames_Column=VariableNames_Column(IndexOfMainVariables)

% MainVariableIdx= ~strcmpi(VariableNames_Row, 'Wavelength');
% MainVariableName=VariableNames_Column(IndexOfMainVariables);

WAVELENGTH=str2double(DATA.Values_Row{:,2}');
IndexAllRowVariables=1:length(DATA.VarName_Row);
% IndexOfMainVar=[IndexAllRowVariables(MainVariableIdx)];
% MainVAR=cell(size(DATA.Values_Row,1),size(DATA.Values_Row,IndexOfMainVar)-1);

MainVAR=DATA.Values_Column(:,6:end); % we start at 2 because this where the main var starts



mkpath(strcat(DataFileFolder,filesep,'NetCDF',filesep,folderHierarchy,filesep))

if exist(fullfile(DataFileFolder,filesep,'NetCDF',filesep,folderHierarchy,filesep,char(FileNameNC)),'file')==2
    fprintf('%s - WARNING: NetCDF file already exists\n',datestr(now))
    return
end


ncid = netcdf.create(fullfile(DataFileFolder,'NetCDF',filesep,folderHierarchy,filesep,char(FileNameNC)),'NC_NOCLOBBER');
for uu=1:length(METADATA.gAttName)
    if ~isempty(char(METADATA.gAttName{uu}))
        netcdf.putAtt(ncid,netcdf.getConstant('GLOBAL'),char(METADATA.gAttName{uu}),char(METADATA.gAttVal{uu}));
    end
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
dimlen_Wavelength_Dim=length(unique(WAVELENGTH));

%a profile is defined by a time and station, we can have 2 profiles at the
%same time but at a different location.
%in order to find this, we're creating an string array of 'time-station'
%and looking for the uunique of this
strArray_time_station=strcat(DATA.Values_Column{:,TimeIdx},'_', STATION);
dimlen_Profile_Dim=length(uunique(strArray_time_station));


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
IndexAllRowVariables=1:length(VariableNames_Column);

% 
% IndexOfMainVariables=IndexAllRowVariables(setdiff(1:length(IndexAllRowVariables),...
%     [IndexAllRowVariables(TimeIdx),...
%     IndexAllRowVariables(LatIdx),...
%     IndexAllRowVariables(LonIdx),...
%     IndexAllRowVariables(StationIdx)]));%in that case, this is Depth

IndexOfDepthVariable=[IndexAllRowVariables(DepthIdx)];
IndexOfPositionVariables=[IndexAllRowVariables(LatIdx),...
    IndexAllRowVariables(LonIdx)];

%% creation of the time variable
TIME_ID=netcdf.defVar(ncid,VariableNames_Column{IndexAllRowVariables(TimeIdx)},'double',[Profile_Dimid]);


%% creation of the positions variables
for ii=IndexOfPositionVariables
    VAR_PositionVariables_ID{ii} = netcdf.defVar(ncid,VariableNames_Column{ii},'float',[Station_Dimid]);
end
% VAR_PositionVariables_ID=VAR_PositionVariables_ID(~cellfun('isempty',VAR_PositionVariables_ID));

Station_VAR_ID=netcdf.defVar(ncid,'station_name',nc_char,[Station_stringdimID,Station_Dimid]);
Profile_VAR_ID=netcdf.defVar(ncid,'profile','short',[Profile_Dimid]);
StationIDX_VAR_ID=netcdf.defVar(ncid,'station_index','short',[Profile_Dimid]);
RowSize_VAR_ID=netcdf.defVar(ncid,'rowSize','short',[Profile_Dimid]);

WAVELENGHT_VAR_ID=netcdf.defVar(ncid,'wavelength','float',[Wavelength_dimid]);

%% creation of the rest of Row variables , in that case, this is depth
for ii=IndexOfDepthVariable
    VAR_NonPositionVariables_ID{ii} = netcdf.defVar(ncid,VariableNames_Column{ii},'float',[OBS_dimid]);
end

%% creation of the main variables
for ii=IndexOfMainVariables
    VAR_MainVariable_ID{ii}=netcdf.defVar(ncid,char(VariableNames_Column(ii)),'float',[Wavelength_dimid,OBS_dimid]);
end
netcdf.endDef(ncid)


%% Creation of the Column VARIABLE ATTRIBUTES
netcdf.reDef(ncid)
for ii=IndexOfDepthVariable
    %     DATA.VarName_Column{ii}
    if ~isempty(char(DATA.Long_Name_Column{ii}))
        netcdf.putAtt(ncid,VAR_NonPositionVariables_ID{ii},'long_name',char(DATA.Long_Name_Column{ii}));
    end
    
    if ~isempty(char(DATA.Standard_Name_Column{ii}))
        netcdf.putAtt(ncid,VAR_NonPositionVariables_ID{ii},'standard_name',char(DATA.Standard_Name_Column{ii}));
    end
    
    if ~isempty(char(DATA.Units_Column{ii}))
        netcdf.putAtt(ncid,VAR_NonPositionVariables_ID{ii},'units',char(DATA.Units_Column{ii}));
    end
    
    if ~isempty(char(DATA.FillValue_Column{ii}))
        netcdf.putAtt(ncid,VAR_NonPositionVariables_ID{ii},'_FillValue',single(str2double(char(DATA.FillValue_Column{ii}))));
    end
    
    if ~isempty(char(DATA.Comments_Column{ii}))
        netcdf.putAtt(ncid,VAR_NonPositionVariables_ID{ii},'comment',char(DATA.Comments_Column{ii}));
    end
    %     netcdf.putAtt(ncid,VAR_NonPositionVariables_ID{ii},'coordinates',...
    %         char(strcat(VariableNames_Column(TimeIdx),[{' '}],VariableNames_Column(LonIdx),[{' '}],VariableNames_Column(LatIdx),[{' '}],VariableNames_Column(DepthIdx))));
    
end



for ii=IndexOfPositionVariables
    %     DATA.VarName_Column{ii}
    if ~isempty(char(DATA.Long_Name_Column{ii}))
        netcdf.putAtt(ncid,VAR_PositionVariables_ID{ii},'long_name',char(DATA.Long_Name_Column{ii}));
    end
    
    if ~isempty(char(DATA.Standard_Name_Column{ii}))
        netcdf.putAtt(ncid,VAR_PositionVariables_ID{ii},'standard_name',char(DATA.Standard_Name_Column{ii}));
    end
    
    if ~isempty(char(DATA.Units_Column{ii}))
        netcdf.putAtt(ncid,VAR_PositionVariables_ID{ii},'units',char(DATA.Units_Column{ii}));
    end
    
    if ~isempty(char(DATA.FillValue_Column{ii}))
        netcdf.putAtt(ncid,VAR_PositionVariables_ID{ii},'_FillValue',single(str2double(char(DATA.FillValue_Column{ii}))));
    end
    
    if ~isempty(char(DATA.Comments_Column{ii}))
        netcdf.putAtt(ncid,VAR_PositionVariables_ID{ii},'comment',char(DATA.Comments_Column{ii}));
    end
end


%% Creation of the Column VARIABLE ATTRIBUTES
for ii=IndexOfMainVariables
    %     DATA.VarName_Row{ii}
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
    
    if ~isempty(char(DATA.Comments_Column{ii}))
        netcdf.putAtt(ncid,VAR_MainVariable_ID{ii},'comment',char(DATA.Comments_Column{ii}));
    end
    
    %     netcdf.putAtt(ncid,VAR_MainVariable_ID{ii},'coordinates',...
    %         char(strcat(VariableNames_Column(TimeIdx),[{' '}],VariableNames_Column(LonIdx),[{' '}],VariableNames_Column(LatIdx),[{' '}],VariableNames_Column(DepthIdx),[{' '}],VariableNames_Row(WavelengthIdx))));
    
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
netcdf.putAtt(ncid,WAVELENGHT_VAR_ID,'long_name',char(DATA.Long_Name_Row{WavelengthIdx}))
netcdf.putAtt(ncid,WAVELENGHT_VAR_ID,'_FillValue',single(str2double(char(DATA.FillValue_Row{WavelengthIdx}))))
netcdf.putAtt(ncid,WAVELENGHT_VAR_ID,'units',char(DATA.Units_Row{WavelengthIdx}))
netcdf.putAtt(ncid,WAVELENGHT_VAR_ID,'standard_name',char(DATA.Standard_Name_Row {WavelengthIdx}))


%time
netcdf.putAtt(ncid,TIME_ID,'standard_name','time');
netcdf.putAtt(ncid,TIME_ID,'long_name','time');
netcdf.putAtt(ncid,TIME_ID,'units','days since 1970-01-01T00:00:00 UTC');
netcdf.putAtt(ncid,TIME_ID,'axis','T');

%lon
LON_ID= VAR_PositionVariables_ID{strcmpi(VariableNames_Column, 'longitude')};
netcdf.putAtt(ncid,LON_ID,'long_name','longitude');
netcdf.putAtt(ncid,LON_ID,'standard_name','longitude');
netcdf.putAtt(ncid,LON_ID,'units','degrees_east');
netcdf.putAtt(ncid,LON_ID,'axis','X');
netcdf.putAtt(ncid,LON_ID,'valid_min',single(-180));
netcdf.putAtt(ncid,LON_ID,'valid_max',single(180));
netcdf.putAtt(ncid,LON_ID,'_FillValue',single(9999));
netcdf.putAtt(ncid,LON_ID,'reference_datum','geographical coordinates, WGS84 projection');

%lat
LAT_ID= VAR_PositionVariables_ID{strcmpi(VariableNames_Column, 'latitude')};
netcdf.putAtt(ncid,LAT_ID,'long_name','latitude');
netcdf.putAtt(ncid,LAT_ID,'standard_name','latitude');
netcdf.putAtt(ncid,LAT_ID,'units','degrees_north');
netcdf.putAtt(ncid,LAT_ID,'axis','Y');
netcdf.putAtt(ncid,LAT_ID,'valid_min',single(-90));
netcdf.putAtt(ncid,LAT_ID,'valid_max',single(90));
netcdf.putAtt(ncid,LAT_ID,'_FillValue',single(9999));
netcdf.putAtt(ncid,LAT_ID,'reference_datum','geographical coordinates, WGS84 projection');

%depth
DEPTH_ID= VAR_NonPositionVariables_ID{strcmpi(VariableNames_Column, 'depth')};
netcdf.putAtt(ncid,DEPTH_ID,'positive','down');
netcdf.putAtt(ncid,DEPTH_ID,'axis','Z');




netcdf.endDef(ncid)

%%%%%%%%%%%%%%%% DATA writing

%% write TIME
[UniqueTimeStationValues,UniqueTimeStation_m_index,UniqueTimeStation_n_index]=unique_no_sort(strArray_time_station);
TimeForNetCDF=(datenum(TIME) -datenum('1970-01-01','yyyy-mm-dd')); %num of day
netcdf.putVar(ncid,TIME_ID,(TimeForNetCDF(UniqueTimeStation_m_index)));

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
% [UniqueTimeValues,m1 ]=uunique(TIME);  % is equal to a profile
% [~, index]=ismember(UniqueTimeValues(:),TIME);
% index2=[];
% index2(1)=0;
% index2(2:length(index))=index(1:length(index)-1);
% NumObsPerProfile=index-index2';
NumObsPerProfile=accumarray(UniqueTimeStation_n_index, 1);

netcdf.putVar(ncid,RowSize_VAR_ID,NumObsPerProfile);

%% compute which station each profile is for
Station2Profile=A(UniqueTimeStation_m_index);
[~, IdxStationForProfile] = ismember(Station2Profile,UniqueStation);
IdxStationForProfile=IdxStationForProfile';

netcdf.putVar(ncid,StationIDX_VAR_ID,IdxStationForProfile);

%% Profile id index
netcdf.putVar(ncid,Profile_VAR_ID,[1:length(UniqueTimeStation_m_index)]);


%% write Depth variables
for ii=IndexOfDepthVariable
    netcdf.putVar(ncid,VAR_NonPositionVariables_ID{ii},DEPTH);
end

%% write wavelength variable
netcdf.putVar(ncid,WAVELENGHT_VAR_ID,unique(WAVELENGTH));

%% write main variable

mainVarNames=[DATA.VarName_Column{IndexOfMainVariables}];
[~,~,indexWavelengthToPutVarIn]=unique(WAVELENGTH);
for ii=1:length(DATA.Values_Row{1})
    
        ncVarIndex=IndexOfMainVariables( strcmp(DATA.Values_Row{1}{ii},mainVarNames));
%         wavelengthAssociatedToThisVar=DATA.Values_Row{2}{ii};
        wavelengthValueIndex=indexWavelengthToPutVarIn(ii);
        mainVarValuesAssociatedToThisVarAndWavelength=str2double(MainVAR(:,ii));
        
netcdf.putVar(ncid,VAR_MainVariable_ID{ncVarIndex},[wavelengthValueIndex-1,0],[1,dimlen_Observation_Dim],mainVarValuesAssociatedToThisVarAndWavelength)

end



%% delete
netcdf.close(ncid);
fprintf('%s - SUCCESS: file has been created\n',datestr(now))

end

function [b,m]=uunique(A)
[~, m1]=unique(A,'first');
b=A(sort(m1));
m=sort(m1);
end
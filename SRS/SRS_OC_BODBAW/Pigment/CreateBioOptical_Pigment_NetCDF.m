function CreateBioOptical_Pigment_NetCDF(DATA,METADATA,FileNameNC,folderHierarchy)
%% CreateBioOptical_Pigment_NetCDF
% this function creates the IMOS NetCDF file for pigment data
% Syntax:  CreateBioOptical_Pigment_NetCDF(DATA,METADATA,FileNameNC,folderHierarchy)
%
% Inputs: DATA - structure created by Pigment_CSV_reader
%         METADATA - structure created by Pigment_CSV_reader
%         FileNameNC - filename created by createPigmentFilename
%         folderHierarchy - folder structure hierarchy created by createPigmentFilename
% Outputs:
%
%
% Example:
%    CreateBioOptical_Pigment_NetCDF(DATA,METADATA,FileNameNC,folderHierarchy)
%
% Other m-files
% required:
% Other files required:config.txt
% Subfunctions: none
% MAT-files required: none
%
% See also: Pigment_CSV_reader,createPigmentFilename
%
% Author: Laurent Besnard, IMOS/eMII
% email: laurent.besnard@utas.edu.au
% Website: http://imos.org.au/  http://froggyscripts.blogspot.com
% Aug 2011; Last revision: 28-Nov-2012

DataFileFolder=readConfig('data_pigment.path', 'config.txt','=');

%% load variables
VariableNames=[DATA.VarName{:}]';
VariableNames=strrep(VariableNames,' ','_');

TimeIdx= strcmpi(VariableNames, 'time');
LatIdx= strcmpi(VariableNames, 'latitude');
LonIdx= strcmpi(VariableNames, 'longitude');
DepthIdx= strcmpi(VariableNames, 'depth');
StationIdx= strcmpi(VariableNames, 'station_code');

VariableNames{TimeIdx}='TIME';%rename in upper case
VariableNames{LatIdx}='LATITUDE';%rename in upper case
VariableNames{LonIdx}='LONGITUDE';%rename in upper case
VariableNames{DepthIdx}='DEPTH';%rename in upper case

TIME=datenum({DATA.Values{:,TimeIdx}}','yyyy-mm-ddTHH:MM:SS');
LAT=str2double({DATA.Values{:,LatIdx}}');
LON=str2double({DATA.Values{:,LonIdx}}');
STATION=strrep(({DATA.Values{:,StationIdx}}'),' ','');%remove blank space from strings for the station name

mkpath(strcat(DataFileFolder,filesep,'NetCDF',filesep,folderHierarchy,filesep))

if exist(fullfile(DataFileFolder,filesep,'NetCDF',filesep,folderHierarchy,filesep,char(FileNameNC)),'file')==2
    fprintf('%s - WARNING: NetCDF file already exists\n',datestr(now))
    return
end


ncid = netcdf.create(fullfile(DataFileFolder,filesep,'NetCDF',filesep,folderHierarchy,filesep,char(FileNameNC)),'NC_NOCLOBBER');
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

dimlen_Observation_Dim=length(TIME);
dimlen_Station_Dim=length(uunique(STATION));

%a profile is defined by a time and station, we can have 2 profiles at the
%same time but at a different location.
%in order to find this, we're creating an string array of 'time-station'
%and looking for the uunique of this
strArray_time_station=strcat({DATA.Values{:,TimeIdx}}','_', STATION);
dimlen_Profile_Dim=length(uunique(strArray_time_station));

OBS_dimid = netcdf.defDim(ncid,Observation_Name,dimlen_Observation_Dim);
Station_Dimid = netcdf.defDim(ncid,Station_Name,dimlen_Station_Dim);
Profile_Dimid = netcdf.defDim(ncid,Profile_Name,dimlen_Profile_Dim);
Station_stringdimID = netcdf.defDim(ncid, 'name_strlen', 19);
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
IndexAllVariables=1:length(VariableNames);

IndexOfNonPositionVariables=IndexAllVariables(setdiff(1:length(IndexAllVariables),...
    [IndexAllVariables(TimeIdx),...
    IndexAllVariables(LatIdx),...
    IndexAllVariables(LonIdx),...
    IndexAllVariables(StationIdx)]));


IndexOfPositionVariables=[IndexAllVariables(LatIdx),...
    IndexAllVariables(LonIdx)];

%% creation of the time variable
TIME_ID=netcdf.defVar(ncid,VariableNames{IndexAllVariables(TimeIdx)},'double',[Profile_Dimid]);


%% creation of the positions variables
for ii=IndexOfPositionVariables
    VAR_PositionVariables_ID{ii} = netcdf.defVar(ncid,VariableNames{ii},'float',[Station_Dimid]);
end
% VAR_PositionVariables_ID=VAR_PositionVariables_ID(~cellfun('isempty',VAR_PositionVariables_ID));

Station_VAR_ID=netcdf.defVar(ncid,'station_name',nc_char,[Station_stringdimID,Station_Dimid]);
Profile_VAR_ID=netcdf.defVar(ncid,'profile','short',[Profile_Dimid]);
StationIDX_VAR_ID=netcdf.defVar(ncid,'station_index','short',[Profile_Dimid]);
RowSize_VAR_ID=netcdf.defVar(ncid,'rowSize','short',[Profile_Dimid]);

%% creation of the rest of variables
for ii=IndexOfNonPositionVariables
    VAR_NonPositionVariables_ID{ii} = netcdf.defVar(ncid,VariableNames{ii},'float',[OBS_dimid]);
end
% VAR_NonPositionVariables_ID=VAR_NonPositionVariables_ID(~cellfun('isempty',VAR_NonPositionVariables_ID));
netcdf.endDef(ncid)


%% Creation of the VARIABLE ATTRIBUTES
netcdf.reDef(ncid)
for ii=IndexOfNonPositionVariables
    %     DATA.VarName{ii}
    if ~isempty(char(DATA.Long_Name{ii}))
        netcdf.putAtt(ncid,VAR_NonPositionVariables_ID{ii},'long_name',char(DATA.Long_Name{ii}));
    end
    
    if ~isempty(char(DATA.Standard_Name{ii}))
        netcdf.putAtt(ncid,VAR_NonPositionVariables_ID{ii},'standard_name',char(DATA.Standard_Name{ii}));
    end
    
    if ~isempty(char(DATA.Units{ii}))
        netcdf.putAtt(ncid,VAR_NonPositionVariables_ID{ii},'units',char(DATA.Units{ii}));
    end
    
    if ~isempty(char(DATA.FillValue{ii}))
        netcdf.putAtt(ncid,VAR_NonPositionVariables_ID{ii},'_FillValue',single(str2double(char(DATA.FillValue{ii}))));
    end
    
    if ~isempty(char(DATA.Comments{ii}))
        netcdf.putAtt(ncid,VAR_NonPositionVariables_ID{ii},'comment',char(DATA.Comments{ii}));
    end
    
    %     netcdf.putAtt(ncid,VAR_NonPositionVariables_ID{ii},'coordinates',...
    %         char(strcat(VariableNames(TimeIdx),[{' '}],VariableNames(LonIdx),[{' '}],VariableNames(LatIdx),[{' '}],VariableNames(DepthIdx))));
    
end



for ii=IndexOfPositionVariables
    %     DATA.VarName{ii}
    if ~isempty(char(DATA.Long_Name{ii}))
        netcdf.putAtt(ncid,VAR_PositionVariables_ID{ii},'long_name',char(DATA.Long_Name{ii}));
    end
    
    if ~isempty(char(DATA.Standard_Name{ii}))
        netcdf.putAtt(ncid,VAR_PositionVariables_ID{ii},'standard_name',char(DATA.Standard_Name{ii}));
    end
    
    if ~isempty(char(DATA.Units{ii}))
        netcdf.putAtt(ncid,VAR_PositionVariables_ID{ii},'units',char(DATA.Units{ii}));
    end
    
    if ~isempty(char(DATA.FillValue{ii}))
        netcdf.putAtt(ncid,VAR_PositionVariables_ID{ii},'_FillValue',single(str2double(char(DATA.FillValue{ii}))));
    end
    
    if ~isempty(char(DATA.Comments{ii}))
        netcdf.putAtt(ncid,VAR_PositionVariables_ID{ii},'comment',char(DATA.Comments{ii}));
    end
    
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

%time
netcdf.putAtt(ncid,TIME_ID,'standard_name','time');
netcdf.putAtt(ncid,TIME_ID,'long_name','time');
netcdf.putAtt(ncid,TIME_ID,'units','days since 1970-01-01T00:00:00 UTC');
netcdf.putAtt(ncid,TIME_ID,'axis','T');

%lon
LON_ID= VAR_PositionVariables_ID{strcmpi(VariableNames, 'longitude')};
netcdf.putAtt(ncid,LON_ID,'long_name','longitude');
netcdf.putAtt(ncid,LON_ID,'standard_name','longitude');
netcdf.putAtt(ncid,LON_ID,'units','degrees_east');
netcdf.putAtt(ncid,LON_ID,'axis','X');
netcdf.putAtt(ncid,LON_ID,'valid_min',single(-180));
netcdf.putAtt(ncid,LON_ID,'valid_max',single(180));
netcdf.putAtt(ncid,LON_ID,'_FillValue',single(9999));
netcdf.putAtt(ncid,LON_ID,'reference_datum','geographical coordinates, WGS84 projection');

%lat
LAT_ID= VAR_PositionVariables_ID{strcmpi(VariableNames, 'latitude')};
netcdf.putAtt(ncid,LAT_ID,'long_name','latitude');
netcdf.putAtt(ncid,LAT_ID,'standard_name','latitude');
netcdf.putAtt(ncid,LAT_ID,'units','degrees_north');
netcdf.putAtt(ncid,LAT_ID,'axis','Y');
netcdf.putAtt(ncid,LAT_ID,'valid_min',single(-90));
netcdf.putAtt(ncid,LAT_ID,'valid_max',single(90));
netcdf.putAtt(ncid,LAT_ID,'_FillValue',single(9999));
netcdf.putAtt(ncid,LAT_ID,'reference_datum','geographical coordinates, WGS84 projection');

%depth
DEPTH_ID= VAR_NonPositionVariables_ID{strcmpi(VariableNames, 'depth')};
netcdf.putAtt(ncid,DEPTH_ID,'positive','down');
netcdf.putAtt(ncid,DEPTH_ID,'axis','Z');

netcdf.endDef(ncid)

%%%%%%%%%%%%%%%% DATA writing

%% write TIME
[UniqueTimeStationValues,UniqueTimeStation_m_index,UniqueTimeStation_n_index]=unique_no_sort(strArray_time_station);
TimeForNetCDF=(datenum({DATA.Values{:,TimeIdx}},'yyyy-mm-ddTHH:MM:SS') -datenum('1970-01-01','yyyy-mm-dd')); %num of day
netcdf.putVar(ncid,TIME_ID,(TimeForNetCDF(UniqueTimeStation_m_index)));


%% write LAT LON
LatValues=str2double({DATA.Values{:,LatIdx}});
LonValues=str2double({DATA.Values{:,LonIdx}});

A= {STATION{:}};
[UniqueStation,BB]=uunique(A);

netcdf.putVar(ncid,LAT_ID,LatValues(BB));%% whatever the time is, each station has always the same location
netcdf.putVar(ncid,LON_ID,LonValues(BB));

%% write station name data
% ListStationsID=uunique(({DATA.Values{:,StationIdx}}));
ListStationsID=UniqueStation;
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
% UniqueTimeStation_m_index
% [UniqueTimeValues,m1 ]=uunique(TIME);  % is equal to a profile
% [~, index]=ismember(datenum(UniqueTimeStationValues(:),'yyyy-mm-ddTHH:MM:SS'),TIME);
% index2=[];
% index2(1)=0;
% index2(2:length(index))=index(1:length(index)-1);
NumObsPerProfile=accumarray(UniqueTimeStation_n_index', 1);

% sum(UniqueTimeStation_n_index==unique(UniqueTimeStation_n_index))
% UniqueTimeStation_m_index
% A =  accumarray(UniqueTimeStation_n_index, 1);
netcdf.putVar(ncid,RowSize_VAR_ID,NumObsPerProfile);

%% compute for which station each profile is for
Station2Profile=A(UniqueTimeStation_m_index);
[~, IdxStationForProfile] = ismember(Station2Profile,UniqueStation);
IdxStationForProfile=IdxStationForProfile';

netcdf.putVar(ncid,StationIDX_VAR_ID,IdxStationForProfile);

%% Profile id index
netcdf.putVar(ncid,Profile_VAR_ID,[1:length(UniqueTimeStation_m_index)]);


%% write standards variables
for ii=IndexOfNonPositionVariables
    netcdf.putVar(ncid,VAR_NonPositionVariables_ID{ii},str2double({DATA.Values{:,ii}}));
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
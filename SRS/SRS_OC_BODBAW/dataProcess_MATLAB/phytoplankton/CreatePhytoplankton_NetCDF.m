function [FileName]=CreatePhytoplankton_NetCDF(DATA,METADATA)
global DataFileFolder
global FacilitySuffixe
global DataType

%% load variables
VariableNames=[DATA.VarName{:}]';
VariableNames=strrep(VariableNames,' ','_');

TimeIdx= strcmpi(VariableNames, 'time');
LatIdx= strcmpi(VariableNames, 'latitude');
LonIdx= strcmpi(VariableNames, 'longitude');
DepthIdx= strcmpi(VariableNames, 'depth');
StationIdx= strcmpi(VariableNames, 'station_code');

PigmentNumberIdx=strcmpi(VariableNames,'Pigment_number_');
SampleTypeIdx=strcmpi(VariableNames,'Sample_type');
SampleQCflagIdx=strcmpi(VariableNames,'Sample_QC_Flag');
SampleQCcommentIdx=strcmpi(VariableNames,'Sample_QC_comment');
TimeQCcommentIdx=strcmpi(VariableNames,'Time_QC_comment');
LocationQCcommentIdx=strcmpi(VariableNames,'Location_QC_comment');


VariableNames{TimeIdx}='TIME';%rename in upper case
VariableNames{LatIdx}='LATITUDE';%rename in upper case
VariableNames{LonIdx}='LONGITUDE';%rename in upper case
VariableNames{DepthIdx}='DEPTH';%rename in upper case

VariableNames{PigmentNumberIdx}='pigment_number';
VariableNames{SampleTypeIdx}='sample_type';
VariableNames{SampleQCflagIdx}='obs_quality_control';
VariableNames{SampleQCcommentIdx}='sample_quality_control';
VariableNames{TimeQCcommentIdx}='time_sample_quality_control';
VariableNames{LocationQCcommentIdx}='location_sample_quality_control';

% tic;
% TIME=datenum({DATA.Values{:,TimeIdx}}','yyyy-mm-ddTHH:MM:SS');
% LAT=str2double({DATA.Values{:,LatIdx}}');
% LON=str2double({DATA.Values{:,LonIdx}}');
% STATION=({DATA.Values{:,StationIdx}}');
% toc;

% tic;
LAT=str2double(DATA.Values(:,LatIdx));
LON=str2double(DATA.Values(:,LonIdx));
STATION=DATA.Values(:,StationIdx);
TIME=datenum(DATA.Values(:,TimeIdx),'yyyy-mm-ddTHH:MM:SS');
% toc;

%% Create a NEW netCDF file.
GATTANAME=[METADATA.gAttName{:}]';
cruise_id=METADATA.gAttVal{ strcmpi(GATTANAME, 'cruise_id')};

% find instrument name
attSource=METADATA.gAttVal{ strcmpi(GATTANAME, 'source')};
Instrument='FV01_PHYPIG';

if length(unique(STATION)) == 1
    %this means that we only have one station per file, therefor the free
    %part in the NetCDF filename will be set as [cruiseID]-[stationCode]
    IMOS_NAME_freePartCode=strcat(STATION{1},'_',Instrument);
else
    IMOS_NAME_freePartCode=strcat(Instrument);
end

FileName=strcat(FacilitySuffixe,'_',DataType,'_',datestr(min(TIME),'yyyymmddTHHMMSSZ'),'_',IMOS_NAME_freePartCode,'_END-',datestr(max(TIME),'yyyymmddTHHMMSSZ'),'_C-',datestr(now,'yyyymmddTHHMMSSZ'),'.nc');

if ~exist(fullfile(DataFileFolder,'NetCDF/'),'dir')
    mkdir(fullfile(DataFileFolder,'NetCDF/'))
end

if exist(fullfile(DataFileFolder,'NetCDF/',char(FileName)),'file')
    disp('NetCDF file already exists')
    return
end

% ncid = netcdf.create(fullfile(DataFileFolder,'NetCDF/',char(FileName)),'NETCDF4');
ncid = netcdf.create(fullfile(DataFileFolder,'NetCDF/',char(FileName)),'NC_NOCLOBBER');

for uu=1:length(METADATA.gAttName)
    %     uu
    netcdf.putAtt(ncid,netcdf.getConstant('GLOBAL'),char(METADATA.gAttName{uu}),char(METADATA.gAttVal{uu}));
end

%% change these following attributes into numbers and not char
AttNames=[METADATA.gAttName{:}]';
GeoDepthMinIdx= strcmpi(AttNames, 'geospatial_vertical_min');
GeoDepthMaxIdx= strcmpi(AttNames, 'geospatial_vertical_max');
% TimeZoneIdx= strcmpi(AttNames, 'local_time_zone');

netcdf.putAtt(ncid,netcdf.getConstant('GLOBAL'),char(METADATA.gAttName{GeoDepthMinIdx}),str2double(char(METADATA.gAttVal{GeoDepthMinIdx})));
netcdf.putAtt(ncid,netcdf.getConstant('GLOBAL'),char(METADATA.gAttName{GeoDepthMaxIdx}),str2double(char(METADATA.gAttVal{GeoDepthMaxIdx})));
% netcdf.putAtt(ncid,netcdf.getConstant('GLOBAL'),char(METADATA.gAttName{TimeZoneIdx}),str2double(char(METADATA.gAttVal{TimeZoneIdx})));


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

% gattname{12}='IMOS_Conventions';
% gattval{12}=' IMOS-1.2';
%
% gattname{13}='IMOS_Biological_Data_Format';
% gattval{13}=' 1.0';

for uu=1:length(gattname)
    netcdf.putAtt(ncid,netcdf.getConstant('GLOBAL'),gattname{uu}, gattval{uu});
end

%%  Creation of the DIMENSION
Observation_Name='obs';
Station_Name='station';
Profile_Name='profile';

dimlen_Observation_Dim=length(TIME);
dimlen_Station_Dim=length(uunique(STATION));
dimlen_Profile_Dim=length(uunique(TIME));


OBS_Dimid = netcdf.defDim(ncid,Observation_Name,dimlen_Observation_Dim);
Station_Dimid = netcdf.defDim(ncid,Station_Name,dimlen_Station_Dim);
Profile_Dimid = netcdf.defDim(ncid,Profile_Name,dimlen_Profile_Dim);
Station_stringdimID = netcdf.defDim(ncid, 'name_strlen', 40);

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
    IndexAllVariables(StationIdx),...
    IndexAllVariables(DepthIdx),...
    IndexAllVariables(PigmentNumberIdx),...
    IndexAllVariables(SampleTypeIdx),...
    IndexAllVariables(SampleQCflagIdx),...
    IndexAllVariables(SampleQCcommentIdx),...
    IndexAllVariables(TimeQCcommentIdx),...
    IndexAllVariables(LocationQCcommentIdx)]));


IndexOfPositionVariables=[IndexAllVariables(LatIdx),...
    IndexAllVariables(LonIdx)];

IndexOfcommentsQCVariables=[IndexAllVariables(TimeQCcommentIdx),...
    IndexAllVariables(LocationQCcommentIdx),...
    IndexAllVariables(SampleQCcommentIdx),...
    IndexAllVariables(SampleQCflagIdx)];

IndexOfSampleVariables=[IndexAllVariables(PigmentNumberIdx),...
    IndexAllVariables(SampleTypeIdx)];

%% creation of the time variable
TIME_ID=netcdf.defVar(ncid,VariableNames{IndexAllVariables(TimeIdx)},'double',[Profile_Dimid]);


%% creation of the positions variables
LatValues=str2double({DATA.Values{:,LatIdx}});
LonValues=str2double({DATA.Values{:,LonIdx}});
% LAT=str2double(DATA.Values(:,LatIdx));


A={STATION{:}};
[UniqueStation,BB]=uunique(A);
if length(UniqueStation)==1 && length(unique(LatValues))>1
    %we are in the case of more than 1 latitude and longitude per
    %station,which is not really the definition of a station!
    
    for ii=IndexOfPositionVariables
        VAR_PositionVariables_ID{ii} = netcdf.defVar(ncid,VariableNames{ii},'float',[OBS_Dimid]);
    end
else
    
    for ii=IndexOfPositionVariables
        VAR_PositionVariables_ID{ii} = netcdf.defVar(ncid,VariableNames{ii},'float',[Station_Dimid]);
    end
end
% VAR_PositionVariables_ID=VAR_PositionVariables_ID(~cellfun('isempty',VAR_PositionVariables_ID));

Station_VAR_ID=netcdf.defVar(ncid,'station_name',nc_char,[Station_stringdimID,Station_Dimid]);
Profile_VAR_ID=netcdf.defVar(ncid,'profile','short',[Profile_Dimid]);
StationIDX_VAR_ID=netcdf.defVar(ncid,'station_index','short',[Profile_Dimid]);
RowSize_VAR_ID=netcdf.defVar(ncid,'rowSize','short',[Profile_Dimid]);

%% creation of Depth variable
Depth_VAR_ID=netcdf.defVar(ncid,'DEPTH','short',[OBS_Dimid]);

%% creation of the rest of variables
for ii=IndexOfNonPositionVariables
    VAR_NonPositionVariables_ID{ii} = netcdf.defVar(ncid,VariableNames{ii},'float',[OBS_Dimid]);
end
% VAR_NonPositionVariables_ID=VAR_NonPositionVariables_ID(~cellfun('isempty',VAR_NonPositionVariables_ID));

%% creation 'comments' variables
for ii=IndexOfSampleVariables
    VAR_SampleVariables_ID{ii}=netcdf.defVar(ncid,VariableNames{ii},nc_char,[Station_stringdimID,OBS_Dimid]);
    % PigmentNumber_VAR_ID=netcdf.defVar(ncid,'pigment_number',nc_char,[Station_stringdimID,OBS_Dimid]);
    % SampleType_VAR_ID=netcdf.defVar(ncid,'sample_type',nc_char,[Station_stringdimID,OBS_Dimid]);
end

%% creation of QC variables
for ii=IndexOfcommentsQCVariables
    VAR_QCVariables_ID{ii}=netcdf.defVar(ncid,VariableNames{ii},'byte',OBS_Dimid);
end

% obs_QC_VAR_ID=netcdf.defVar(ncid,'obs_quality_control','byte',OBS_Dimid);
% time_QC_VAR_ID=netcdf.defVar(ncid,'time_sample_quality_control','byte',OBS_Dimid);
% location_QC_VAR_ID=netcdf.defVar(ncid,'location_sample_quality_control','byte',OBS_Dimid);


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

for ii=IndexAllVariables(DepthIdx)
    if ~isempty(char(DATA.Long_Name{ii}))
        netcdf.putAtt(ncid,Depth_VAR_ID,'long_name',char(DATA.Long_Name{ii}));
    end
    
    if ~isempty(char(DATA.Standard_Name{ii}))
        netcdf.putAtt(ncid,Depth_VAR_ID,'standard_name',char(DATA.Standard_Name{ii}));
    end
    
    if ~isempty(char(DATA.Units{ii}))
        netcdf.putAtt(ncid,Depth_VAR_ID,'units',char(DATA.Units{ii}));
    end
    
    if ~isempty(char(DATA.FillValue{ii}))
        netcdf.putAtt(ncid,Depth_VAR_ID,'_FillValue',single(str2double(char(DATA.FillValue{ii}))));
    end
    
    if ~isempty(char(DATA.Comments{ii}))
        netcdf.putAtt(ncid,Depth_VAR_ID,'comment',char(DATA.Comments{ii}));
    end
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
% DEPTH_ID= VAR_NonPositionVariables_ID{strcmpi(VariableNames, 'depth')};
netcdf.putAtt(ncid,Depth_VAR_ID,'positive','down');
netcdf.putAtt(ncid,Depth_VAR_ID,'axis','Z');
water_column_FillValue=-500;
netcdf.putAtt(ncid,Depth_VAR_ID,'water_column_FillValue',single(water_column_FillValue));

%comments qc variables
for ii=IndexOfcommentsQCVariables
    %     DATA.VarName{ii}
    if ~isempty(char(DATA.Long_Name{ii}))
        netcdf.putAtt(ncid,VAR_QCVariables_ID{ii},'long_name',char(DATA.Long_Name{ii}));
    end
    
    if ~isempty(char(DATA.Standard_Name{ii}))
        netcdf.putAtt(ncid,VAR_QCVariables_ID{ii},'standard_name',char(DATA.Standard_Name{ii}));
    end
    
    if ~isempty(char(DATA.Units{ii}))
        netcdf.putAtt(ncid,VAR_QCVariables_ID{ii},'units',char(DATA.Units{ii}));
    end
    
    if ~isempty(char(DATA.FillValue{ii}))
        netcdf.putAtt(ncid,VAR_QCVariables_ID{ii},'_FillValue',single(str2double(char(DATA.FillValue{ii}))));
    end
    
    if ~isempty(char(DATA.Comments{ii}))
        netcdf.putAtt(ncid,VAR_QCVariables_ID{ii},'comment',char(DATA.Comments{ii}));
    end
    
end

% sample type variables
for ii=IndexOfSampleVariables
    %     DATA.VarName{ii}
    if ~isempty(char(DATA.Long_Name{ii}))
        netcdf.putAtt(ncid,VAR_SampleVariables_ID{ii},'long_name',char(DATA.Long_Name{ii}));
    end
    
    if ~isempty(char(DATA.Standard_Name{ii}))
        netcdf.putAtt(ncid,VAR_SampleVariables_ID{ii},'standard_name',char(DATA.Standard_Name{ii}));
    end
    
    if ~isempty(char(DATA.Units{ii}))
        netcdf.putAtt(ncid,VAR_SampleVariables_ID{ii},'units',char(DATA.Units{ii}));
    end
    
    if ~isempty(char(DATA.FillValue{ii}))
        netcdf.putAtt(ncid,VAR_SampleVariables_ID{ii},'_FillValue',single(str2double(char(DATA.FillValue{ii}))));
    end
    
    if ~isempty(char(DATA.Comments{ii}))
        netcdf.putAtt(ncid,VAR_SampleVariables_ID{ii},'comment',char(DATA.Comments{ii}));
    end
    
end

%observation QC
obsQC_ID= VAR_QCVariables_ID{strcmpi(VariableNames, 'obs_quality_control')};
netcdf.putAtt(ncid,obsQC_ID,'long_name','observation_quality_control');
netcdf.putAtt(ncid,obsQC_ID,'quality_control_convention','IMOS standard set using the IODE flags');
netcdf.putAtt(ncid,obsQC_ID,'flag_values','0.0, 1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 9.0');
netcdf.putAtt(ncid,obsQC_ID,'flag_meanings','no_qc_performed good_data probably_good_data bad_data_that_are_potentially_correctable bad_data value_changed not_used not_used interpolated_values missing_values');

%time qc
timeQC_ID= VAR_QCVariables_ID{strcmpi(VariableNames, 'time_sample_quality_control')};
netcdf.putAtt(ncid,timeQC_ID,'quality_control_convention','IMOS NRS phytoplankton convention');
netcdf.putAtt(ncid,timeQC_ID,'flag_values','1.0 2.0 3.0 4.0 5.0 6.0');
netcdf.putAtt(ncid,timeQC_ID,'flag_meanings','no_comments default_time_used station_end_time_used station_start_time_used WC_time_used WQM_time_used');
% timeComments=({DATA.Values{:,TimeQCcommentIdx}}');
timeComments=DATA.Values(:,TimeQCcommentIdx);


%location qc
locationQC_ID= VAR_QCVariables_ID{strcmpi(VariableNames, 'location_sample_quality_control')};
netcdf.putAtt(ncid,locationQC_ID,'quality_control_convention','IMOS NRS phytoplankton convention');
netcdf.putAtt(ncid,locationQC_ID,'flag_values','1.0 2.0');
netcdf.putAtt(ncid,locationQC_ID,'flag_meanings','no_comments default_location_used');
% locationComments=({DATA.Values{:,LocationQCcommentIdx}}');
locationComments=DATA.Values(:,LocationQCcommentIdx);

%sample comment qc
sampleQC_ID= VAR_QCVariables_ID{strcmpi(VariableNames, 'sample_quality_control')};
netcdf.putAtt(ncid,sampleQC_ID,'quality_control_convention','IMOS NRS phytoplankton convention');
netcdf.putAtt(ncid,sampleQC_ID,'flag_values','1.0 2.0 3.0 4.0 5.0');
netcdf.putAtt(ncid,sampleQC_ID,'flag_meanings','no_comments delay_before_analysis delay_before_filtering volume_not_recorded volumes_in_mix_unequal');
% sampleComments=({DATA.Values{:,SampleQCcommentIdx}}');
sampleComments=DATA.Values(:,SampleQCcommentIdx);


netcdf.endDef(ncid)

%%%%%%%%%%%%%%%% DATA writing

%% write TIME
TimeForNetCDF=(datenum({DATA.Values{:,TimeIdx}},'yyyy-mm-ddTHH:MM:SS') -datenum('1970-01-01','yyyy-mm-dd')); %num of day
netcdf.putVar(ncid,TIME_ID,uunique(TimeForNetCDF));


%% write LAT LON
% LatValues=str2double({DATA.Values{:,LatIdx}});
% LonValues=str2double({DATA.Values{:,LonIdx}});

% A={STATION{:}};
% [UniqueStation,BB]=uunique(A);

if length(UniqueStation)==1 && length(unique(LatValues))>1
    netcdf.putVar(ncid,LAT_ID,LatValues);
    netcdf.putVar(ncid,LON_ID,LonValues);
else
    netcdf.putVar(ncid,LAT_ID,LatValues(BB));
    netcdf.putVar(ncid,LON_ID,LonValues(BB));
end

%% write station name data
ListStationsID=uunique(({DATA.Values{:,StationIdx}}));
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
    netcdf.putVar(ncid,VAR_NonPositionVariables_ID{ii},str2double({DATA.Values{:,ii}}));
end


%% depth
DEPTH=({DATA.Values{:,DepthIdx}});
wc_depthIdx=strcmpi(DEPTH,'WC');
DEPTH=str2double(DEPTH);
DEPTH(wc_depthIdx)=water_column_FillValue;
netcdf.putVar(ncid,Depth_VAR_ID,DEPTH);

%% sample variable
% PigmentNumberIdx
% SampleTypeIdx
% pigmentValue=({DATA.Values{:,PigmentNumberIdx}})
% netcdf.putVar(ncid,VAR_SampleVariables_ID{ii},[0,tt-1],[3,1],DATA.Values{:,ii});
for ii=IndexOfSampleVariables
    varValues=({DATA.Values{:,ii}});
    for tt=1:length(varValues)
        netcdf.putVar(ncid,VAR_SampleVariables_ID{ii},[0,tt-1],[length(varValues{tt}),1],varValues{tt});
    end
    clear varValues
end


%% commentsQCVariables

for ii=IndexOfcommentsQCVariables
    %     VariableNames{ii}
    %     VAR_QCVariables_ID{ii}
    if strcmpi(VariableNames{ii},'time_sample_quality_control')
        varValues=strrep(timeComments,' ','_');
        varValuesNC(1:length(varValues))=1;
        varValuesNC(strcmpi(varValues,'default_time_used'))=2;
        varValuesNC(strcmpi(varValues,'station_end_time_used'))=3;       
        varValuesNC(strcmpi(varValues,'station_start_time_used'))=4;       
        varValuesNC(strcmpi(varValues,'WC_time_used'))=5;      
        varValuesNC(strcmpi(varValues,'WQM_time_used'))=6;
        netcdf.putVar(ncid,VAR_QCVariables_ID{ii},varValuesNC);
        clear varValues varValuesNC
    end
    if strcmpi(VariableNames{ii},'location_sample_quality_control')
        varValues=strrep(locationComments,' ','_');
        varValuesNC(1:length(varValues))=1;
        varValuesNC(strcmpi(varValues,'default_location_used'))=2;
        netcdf.putVar(ncid,VAR_QCVariables_ID{ii},varValuesNC);
        clear varValues varValuesNC
    end
    if strcmpi(VariableNames{ii},'sample_quality_control')
        varValues=strrep(sampleComments,' ','_');
        varValuesNC(1:length(varValues))=1;
        varValuesNC(strcmpi(varValues,'delay_before_analysis'))=2;
        varValuesNC(strcmpi(varValues,'delay_before_filtering'))=3;
        varValuesNC(strcmpi(varValues,'volume_not_recorded'))=4;
        varValuesNC(strcmpi(varValues,'volumes_in_mix_unequal'))=5;
        netcdf.putVar(ncid, VAR_QCVariables_ID{ii},varValuesNC);
        clear varValues varValuesNC

        
        
    end
    if strcmpi(VariableNames{ii},'obs_quality_control')
        varValuesNC=str2double({DATA.Values{:,ii}});
        netcdf.putVar(ncid, VAR_QCVariables_ID{ii},single(varValuesNC));
    end
    
end


%% delete
netcdf.close(ncid);
end

function [b,m]=uunique(A)
[~, m1]=unique(A,'first');
b=A(sort(m1));
m=sort(m1);
end
function AATAMS_seals_aggregation_profiles(tagName)

dataWIP_Path       = getenv('data_wip_path');

tagPath = strcat(dataWIP_Path,filesep,'NETCDF',filesep,tagName);

listfiles = dir(strcat(tagPath,filesep,'profiles',filesep,'*.nc'));
nbfiles   = length(listfiles);

for j =1:nbfiles
    timestamp(1,j) = datenum(listfiles(j).name(24:38),'yyyymmddTHHMMSS');
end

%Read all the NetCDF files for one seal
t_fin = 0;
time1 = 0;
for j = 1:nbfiles
    ncid_Input = netcdf.open(strcat(tagPath,filesep,'profiles',filesep,listfiles(j).name),'NC_NOWRITE');
    temp_varid = netcdf.inqVarID(ncid_Input,'TIME');
    temp       = netcdf.getVar(ncid_Input,temp_varid);
    time1      = temp(:);

    %Variable LATITUDE and LONGITUDE
    temp_varid = netcdf.inqVarID(ncid_Input,'LATITUDE');
    temp       = netcdf.getVar(ncid_Input,temp_varid);
    lat1       = temp(:);

    temp_varid = netcdf.inqVarID(ncid_Input,'LONGITUDE');
    temp       = netcdf.getVar(ncid_Input,temp_varid);
    lon1       = temp(:);

    %Variable TEMPERATURE, Pressure and SALINITY
    temp_varid = netcdf.inqVarID(ncid_Input,'TEMP');
    temp       = netcdf.getVar(ncid_Input,temp_varid);
    TEMPE1     = temp(:);
    temp_varid = netcdf.inqVarID(ncid_Input,'PSAL');
    temp       = netcdf.getVar(ncid_Input,temp_varid);
    PSAL1      = temp(:);
    temp_varid = netcdf.inqVarID(ncid_Input,'PRES');
    temp       = netcdf.getVar(ncid_Input,temp_varid);
    PRES1      = temp(:);
    %Variable WMO_ID
    temp_varid = netcdf.inqVarID(ncid_Input,'WMO_ID');
    temp       = netcdf.getVar(ncid_Input,temp_varid);
    SEAL_ID1   = temp(:);

    netcdf.close(ncid_Input)

    dimfile                   = length(TEMPE1);
    t_deb                     = t_fin+1;
    t_fin                     = t_deb+dimfile-1;
    time(j)                   = time1;
    lat(j)                    = lat1;
    lon(j)                    = lon1;
    SEAL_ID(j,:)              = SEAL_ID1;
    TEMPE(t_deb:t_fin)        = TEMPE1;
    PSAL(t_deb:t_fin)         = PSAL1;
    PRES(t_deb:t_fin)         = PRES1;
    indexprofile(t_deb:t_fin) = j;
    %Clear the temporary variable
    clear TEMPE1 lat1 lon1 time1 PSAL1 PRES1  SEAL_ID1
end

dimobs               = length(TEMPE);
dimprofile           = nbfiles;
%% Creation of the aggregated NETCDF FILE
aggregatedFileOutput = strcat(dataWIP_Path,filesep, 'IMOS_AATAMS-SATTAG_TSP_',datestr(min(timestamp),'yyyymmddTHHMMSSZ'),'_',SEAL_ID(1,:),'_END-',datestr(max(timestamp),'yyyymmddTHHMMSSZ'),'_FV00.nc');
ncid_Output          = netcdf.create(aggregatedFileOutput,'NC_CLOBBER');

%% Creation of the GLOBAL ATTRIBUTES
netcdf.putAtt(ncid_Output,netcdf.getConstant('GLOBAL'),'project','Integrated Marine Observing System (IMOS)');
netcdf.putAtt(ncid_Output,netcdf.getConstant('GLOBAL'),'conventions','IMOS-1.2');
netcdf.putAtt(ncid_Output,netcdf.getConstant('GLOBAL'),'date_created',datestr(datenum(clock)-10/24,'yyyy-mm-ddTHH:MM:SSZ'));
netcdf.putAtt(ncid_Output,netcdf.getConstant('GLOBAL'),'title','Temperature, Salinity and Depth profiles in near real time');
netcdf.putAtt(ncid_Output,netcdf.getConstant('GLOBAL'),'institution','AATAMS');
netcdf.putAtt(ncid_Output,netcdf.getConstant('GLOBAL'),'site','CTD Satellite Relay Data Logger');

netcdf.putAtt(ncid_Output,netcdf.getConstant('GLOBAL'),'abstract',getenv('gattval_abstract'));
netcdf.putAtt(ncid_Output,netcdf.getConstant('GLOBAL'),'source','SMRU CTD Satellite relay Data Logger on marine mammals');

netcdf.putAtt(ncid_Output,netcdf.getConstant('GLOBAL'),'keywords',getenv('gattval_keywords'));
netcdf.putAtt(ncid_Output,netcdf.getConstant('GLOBAL'),'references','http://imos.org.au/aatams.html');
netcdf.putAtt(ncid_Output,netcdf.getConstant('GLOBAL'),'platform_code',SEAL_ID(1,:));
netcdf.putAtt(ncid_Output,netcdf.getConstant('GLOBAL'),'netcdf_version','3.6');
netcdf.putAtt(ncid_Output,netcdf.getConstant('GLOBAL'),'naming_authority','IMOS');
netcdf.putAtt(ncid_Output,netcdf.getConstant('GLOBAL'),'quality_control_set','1');
netcdf.putAtt(ncid_Output,netcdf.getConstant('GLOBAL'),'cdm_data_type','Trajectory');
%WHERE
netcdf.putAtt(ncid_Output,netcdf.getConstant('GLOBAL'),'geospatial_lat_min',min(lat));
netcdf.putAtt(ncid_Output,netcdf.getConstant('GLOBAL'),'geospatial_lat_max',max(lat));
netcdf.putAtt(ncid_Output,netcdf.getConstant('GLOBAL'),'geospatial_lat_units','degrees_north');
netcdf.putAtt(ncid_Output,netcdf.getConstant('GLOBAL'),'geospatial_lon_min',min(lon));
netcdf.putAtt(ncid_Output,netcdf.getConstant('GLOBAL'),'geospatial_lon_max',max(lon));
netcdf.putAtt(ncid_Output,netcdf.getConstant('GLOBAL'),'geospatial_lon_units','degrees_east');
netcdf.putAtt(ncid_Output,netcdf.getConstant('GLOBAL'),'geospatial_vertical_min',min(PRES));
netcdf.putAtt(ncid_Output,netcdf.getConstant('GLOBAL'),'geospatial_vertical_max',max(PRES));
netcdf.putAtt(ncid_Output,netcdf.getConstant('GLOBAL'),'geospatial_vertical_units','dbar');
%WHEN
netcdf.putAtt(ncid_Output,netcdf.getConstant('GLOBAL'),'time_coverage_start',datestr(min(timestamp),'yyyy-mm-ddTHH:MM:SSZ'));
netcdf.putAtt(ncid_Output,netcdf.getConstant('GLOBAL'),'time_coverage_end',datestr(max(timestamp),'yyyy-mm-ddTHH:MM:SSZ'));
% %WHO
netcdf.putAtt(ncid_Output,netcdf.getConstant('GLOBAL'),'data_centre_email','info@emii.org.au');
netcdf.putAtt(ncid_Output,netcdf.getConstant('GLOBAL'),'data_centre','eMarine Information Infrastructure (eMII)');
netcdf.putAtt(ncid_Output,netcdf.getConstant('GLOBAL'),'author',getenv('gattval_author_name'));
netcdf.putAtt(ncid_Output,netcdf.getConstant('GLOBAL'),'author_email','info@emii.org.au');
netcdf.putAtt(ncid_Output,netcdf.getConstant('GLOBAL'),'institution_references','http://imos.org.au/emii.html');
netcdf.putAtt(ncid_Output,netcdf.getConstant('GLOBAL'),'principal_investigator','Harcourt, Rob');

% %HOW
netcdf.putAtt(ncid_Output,netcdf.getConstant('GLOBAL'),'citation',getenv('gattval_citation'));
netcdf.putAtt(ncid_Output,netcdf.getConstant('GLOBAL'),'acknowledgment',getenv('gattval_acknowledgement'));
netcdf.putAtt(ncid_Output,netcdf.getConstant('GLOBAL'),'distribution_statement', getenv('gattval_distribution_statement'));

netcdf.putAtt(ncid_Output,netcdf.getConstant('GLOBAL'),'file_version','Level 0 - Raw data');
netcdf.putAtt(ncid_Output,netcdf.getConstant('GLOBAL'),'file_version_quality_control','Data in this file has not undergone quality control. There has been no QC performed on this real-time data.');
netcdf.putAtt(ncid_Output,netcdf.getConstant('GLOBAL'),'metadata_uuid',getenv('gattval_uuid'));

%% Creation of the DIMENSION
obs_dimid                    = netcdf.defDim(ncid_Output,'obs',dimobs);
profiles_dimid               = netcdf.defDim(ncid_Output,'profiles',dimprofile);
length_char_dimid            = netcdf.defDim(ncid_Output,'length_char',8);

%% Creation of the VARIABLES
TIME_id                      = netcdf.defVar(ncid_Output,'TIME','double',profiles_dimid);
LATITUDE_id                  = netcdf.defVar(ncid_Output,'LATITUDE','double',profiles_dimid);
LONGITUDE_id                 = netcdf.defVar(ncid_Output,'LONGITUDE','double',profiles_dimid);
TEMP_id                      = netcdf.defVar(ncid_Output,'TEMP','double',obs_dimid);
PRES_id                      = netcdf.defVar(ncid_Output,'PRES','double',obs_dimid);
PSAL_id                      = netcdf.defVar(ncid_Output,'PSAL','double',obs_dimid);
parentIndex_id               = netcdf.defVar(ncid_Output,'parentIndex','double',obs_dimid);
WMO_ID_id                    = netcdf.defVar(ncid_Output,'WMO_ID','char',[length_char_dimid,profiles_dimid]);

TIME_quality_control_id      = netcdf.defVar(ncid_Output,'TIME_quality_control','double',profiles_dimid);
LATITUDE_quality_control_id  = netcdf.defVar(ncid_Output,'LATITUDE_quality_control','double',profiles_dimid);
LONGITUDE_quality_control_id = netcdf.defVar(ncid_Output,'LONGITUDE_quality_control','double',profiles_dimid);
TEMP_quality_control_id      = netcdf.defVar(ncid_Output,'TEMP_quality_control','double',obs_dimid);
PRES_quality_control_id      = netcdf.defVar(ncid_Output,'PRES_quality_control','double',obs_dimid);
PSAL_quality_control_id      = netcdf.defVar(ncid_Output,'PSAL_quality_control','double',obs_dimid);

%% Definition of the VARIABLE ATTRIBUTES
netcdf.putAtt(ncid_Output,TIME_id,'standard_name','time');
netcdf.putAtt(ncid_Output,TIME_id,'long_name','analysis_time');
netcdf.putAtt(ncid_Output,TIME_id,'units','days since 1950-01-01 00:00:00');
netcdf.putAtt(ncid_Output,TIME_id,'axis','T');
netcdf.putAtt(ncid_Output,TIME_id,'valid_min',0);
netcdf.putAtt(ncid_Output,TIME_id,'valid_max',999999);
netcdf.putAtt(ncid_Output,TIME_id,'_FillValue',-9999);
netcdf.putAtt(ncid_Output,TIME_id,'ancillary_variables','TIME_quality_control');

netcdf.putAtt(ncid_Output,LATITUDE_id,'standard_name','latitude');
netcdf.putAtt(ncid_Output,LATITUDE_id,'long_name','latitude');
netcdf.putAtt(ncid_Output,LATITUDE_id,'units','degrees_north');
netcdf.putAtt(ncid_Output,LATITUDE_id,'axis','Y');
netcdf.putAtt(ncid_Output,LATITUDE_id,'valid_min',-90);
netcdf.putAtt(ncid_Output,LATITUDE_id,'valid_max',90);
netcdf.putAtt(ncid_Output,LATITUDE_id,'_FillValue',999.9);
netcdf.putAtt(ncid_Output,LATITUDE_id,'ancillary_variables','LATITUDE_quality_control');
netcdf.putAtt(ncid_Output,LATITUDE_id,'reference_datum','geographical coordinates, WGS84 projection');

netcdf.putAtt(ncid_Output,LONGITUDE_id,'standard_name','longitude');
netcdf.putAtt(ncid_Output,LONGITUDE_id,'long_name','longitude');
netcdf.putAtt(ncid_Output,LONGITUDE_id,'units','degrees_east');
netcdf.putAtt(ncid_Output,LONGITUDE_id,'axis','X');
netcdf.putAtt(ncid_Output,LONGITUDE_id,'valid_min',-180);
netcdf.putAtt(ncid_Output,LONGITUDE_id,'valid_max',180);
netcdf.putAtt(ncid_Output,LONGITUDE_id,'_FillValue',999.9);
netcdf.putAtt(ncid_Output,LONGITUDE_id,'ancillary_variables','LONGITUDE_quality_control');
netcdf.putAtt(ncid_Output,LONGITUDE_id,'reference_datum','geographical coordinates, WGS84 projection');

netcdf.putAtt(ncid_Output,TEMP_id,'standard_name','sea_water_temperature');
netcdf.putAtt(ncid_Output,TEMP_id,'long_name','sea_water_temperature');
netcdf.putAtt(ncid_Output,TEMP_id,'units','Celsius');
netcdf.putAtt(ncid_Output,TEMP_id,'valid_min',-2);
netcdf.putAtt(ncid_Output,TEMP_id,'valid_max',40);
netcdf.putAtt(ncid_Output,TEMP_id,'_FillValue',9999);
netcdf.putAtt(ncid_Output,TEMP_id,'ancillary_variables','TEMP_quality_control');

netcdf.putAtt(ncid_Output,PSAL_id,'standard_name','sea_water_salinity');
netcdf.putAtt(ncid_Output,PSAL_id,'long_name','sea_water_salinity');
netcdf.putAtt(ncid_Output,PSAL_id,'units','1e-3');
netcdf.putAtt(ncid_Output,PSAL_id,'_FillValue',9999);
netcdf.putAtt(ncid_Output,PSAL_id,'ancillary_variables','PSAL_quality_control');

netcdf.putAtt(ncid_Output,PRES_id,'standard_name','sea_water_pressure');
netcdf.putAtt(ncid_Output,PRES_id,'long_name','sea_water_pressure');
netcdf.putAtt(ncid_Output,PRES_id,'units','dbar');
netcdf.putAtt(ncid_Output,PRES_id,'_FillValue',9999);
netcdf.putAtt(ncid_Output,PRES_id,'ancillary_variables','PRES_quality_control');

netcdf.putAtt(ncid_Output,WMO_ID_id,'long_name','WMO device number');
netcdf.putAtt(ncid_Output,parentIndex_id,'long_name','index of profile');
netcdf.putAtt(ncid_Output,parentIndex_id,'ragged_row_index','profile');
netcdf.putAtt(ncid_Output,parentIndex_id,'comment','the pressure(i), temperature(i) and salinity(i) is associated with the coordiante values time(p), lat(p), lon(p) where p=parentIndex(i).');

%% QC variables
flagvalues = [0 1 2 3 4 5 6 7 8 9];

netcdf.putAtt(ncid_Output,TIME_quality_control_id,'standard_name','time status_flag');
netcdf.putAtt(ncid_Output,TIME_quality_control_id,'long_name','Quality Control flag for time');
netcdf.putAtt(ncid_Output,TIME_quality_control_id,'quality_control_conventions','IMOS standard set using IODE flags');
netcdf.putAtt(ncid_Output,TIME_quality_control_id,'quality_control_set',1);
netcdf.putAtt(ncid_Output,TIME_quality_control_id,'_FillValue',9999);
netcdf.putAtt(ncid_Output,TIME_quality_control_id,'valid_min',0);
netcdf.putAtt(ncid_Output,TIME_quality_control_id,'valid_max',9);
netcdf.putAtt(ncid_Output,TIME_quality_control_id,'flag_values',flagvalues);
netcdf.putAtt(ncid_Output,TIME_quality_control_id,'flag_meanings','no_qc_performed good_data probably_good_data bad_data_that_are_potentially_correctable bad_data value_changed not_used not_used interpolated_values missing_values');

netcdf.putAtt(ncid_Output,LATITUDE_quality_control_id,'standard_name','latitude status_flag');
netcdf.putAtt(ncid_Output,LATITUDE_quality_control_id,'long_name','Quality Control flag for latitude');
netcdf.putAtt(ncid_Output,LATITUDE_quality_control_id,'quality_control_conventions','IMOS standard set using IODE flags');
netcdf.putAtt(ncid_Output,LATITUDE_quality_control_id,'quality_control_set',1);
netcdf.putAtt(ncid_Output,LATITUDE_quality_control_id,'_FillValue',9999);
netcdf.putAtt(ncid_Output,LATITUDE_quality_control_id,'valid_min',0);
netcdf.putAtt(ncid_Output,LATITUDE_quality_control_id,'valid_max',9);
netcdf.putAtt(ncid_Output,LATITUDE_quality_control_id,'flag_values',flagvalues);
netcdf.putAtt(ncid_Output,LATITUDE_quality_control_id,'flag_meanings','no_qc_performed good_data probably_good_data bad_data_that_are_potentially_correctable bad_data value_changed not_used not_used interpolated_values missing_values');

netcdf.putAtt(ncid_Output,LONGITUDE_quality_control_id,'standard_name','longitude status_flag');
netcdf.putAtt(ncid_Output,LONGITUDE_quality_control_id,'long_name','Quality Control flag for longitude');
netcdf.putAtt(ncid_Output,LONGITUDE_quality_control_id,'quality_control_conventions','IMOS standard set using IODE flags');
netcdf.putAtt(ncid_Output,LONGITUDE_quality_control_id,'quality_control_set',1);
netcdf.putAtt(ncid_Output,LONGITUDE_quality_control_id,'_FillValue',9999);
netcdf.putAtt(ncid_Output,LONGITUDE_quality_control_id,'valid_min',0);
netcdf.putAtt(ncid_Output,LONGITUDE_quality_control_id,'valid_max',9);
netcdf.putAtt(ncid_Output,LONGITUDE_quality_control_id,'flag_values',flagvalues);
netcdf.putAtt(ncid_Output,LONGITUDE_quality_control_id,'flag_meanings','no_qc_performed good_data probably_good_data bad_data_that_are_potentially_correctable bad_data value_changed not_used not_used interpolated_values missing_values');

netcdf.putAtt(ncid_Output,TEMP_quality_control_id,'standard_name','sea_surface_temperature status_flag');
netcdf.putAtt(ncid_Output,TEMP_quality_control_id,'long_name','Quality Control flag for temperature');
netcdf.putAtt(ncid_Output,TEMP_quality_control_id,'quality_control_conventions','IMOS standard set using IODE flags');
netcdf.putAtt(ncid_Output,TEMP_quality_control_id,'quality_control_set',1);
netcdf.putAtt(ncid_Output,TEMP_quality_control_id,'_FillValue',9999);
netcdf.putAtt(ncid_Output,TEMP_quality_control_id,'valid_min',0);
netcdf.putAtt(ncid_Output,TEMP_quality_control_id,'valid_max',9);
netcdf.putAtt(ncid_Output,TEMP_quality_control_id,'flag_values',flagvalues);
netcdf.putAtt(ncid_Output,TEMP_quality_control_id,'flag_meanings','no_qc_performed good_data probably_good_data bad_data_that_are_potentially_correctable bad_data value_changed not_used not_used interpolated_values missing_values');

netcdf.putAtt(ncid_Output,PRES_quality_control_id,'standard_name','sea_water_pressure status_flag');
netcdf.putAtt(ncid_Output,PRES_quality_control_id,'long_name','Quality Control flag for pressure');
netcdf.putAtt(ncid_Output,PRES_quality_control_id,'quality_control_conventions','IMOS standard set using IODE flags');
netcdf.putAtt(ncid_Output,PRES_quality_control_id,'quality_control_set',1);
netcdf.putAtt(ncid_Output,PRES_quality_control_id,'_FillValue',9999);
netcdf.putAtt(ncid_Output,PRES_quality_control_id,'valid_min',0);
netcdf.putAtt(ncid_Output,PRES_quality_control_id,'valid_max',9);
netcdf.putAtt(ncid_Output,PRES_quality_control_id,'flag_values',flagvalues);
netcdf.putAtt(ncid_Output,PRES_quality_control_id,'flag_meanings','no_qc_performed good_data probably_good_data bad_data_that_are_potentially_correctable bad_data value_changed not_used not_used interpolated_values missing_values');

netcdf.putAtt(ncid_Output,PSAL_quality_control_id,'standard_name','sea_water_salinity status_flag');
netcdf.putAtt(ncid_Output,PSAL_quality_control_id,'long_name','Quality Control flag for salinity');
netcdf.putAtt(ncid_Output,PSAL_quality_control_id,'quality_control_conventions','IMOS standard set using IODE flags');
netcdf.putAtt(ncid_Output,PSAL_quality_control_id,'quality_control_set',1);
netcdf.putAtt(ncid_Output,PSAL_quality_control_id,'_FillValue',9999);
netcdf.putAtt(ncid_Output,PSAL_quality_control_id,'valid_min',0);
netcdf.putAtt(ncid_Output,PSAL_quality_control_id,'valid_max',9);
netcdf.putAtt(ncid_Output,PSAL_quality_control_id,'flag_values',flagvalues);
netcdf.putAtt(ncid_Output,PSAL_quality_control_id,'flag_meanings','no_qc_performed good_data probably_good_data bad_data_that_are_potentially_correctable bad_data value_changed not_used not_used interpolated_values missing_values');

netcdf.endDef(ncid_Output)

netcdf.putVar(ncid_Output,TIME_id,time(:));
netcdf.putVar(ncid_Output,LATITUDE_id,lat(:));
netcdf.putVar(ncid_Output,LONGITUDE_id,lon(:));
netcdf.putVar(ncid_Output,TEMP_id,TEMPE(:));
netcdf.putVar(ncid_Output,PRES_id,PRES(:));
netcdf.putVar(ncid_Output,PSAL_id,PSAL(:));
netcdf.putVar(ncid_Output,parentIndex_id,indexprofile(:));
blankmatrix = zeros(dimprofile,1);
netcdf.putVar(ncid_Output,TIME_quality_control_id,blankmatrix(:,1));
netcdf.putVar(ncid_Output,LATITUDE_quality_control_id,blankmatrix(:,1));
netcdf.putVar(ncid_Output,LONGITUDE_quality_control_id,blankmatrix(:,1));
blankmatrix = zeros(dimobs,1);
netcdf.putVar(ncid_Output,TEMP_quality_control_id,blankmatrix(:,1));
netcdf.putVar(ncid_Output,PSAL_quality_control_id,blankmatrix(:,1));
netcdf.putVar(ncid_Output,PRES_quality_control_id,blankmatrix(:,1));

for tt = 1:dimprofile
    netcdf.putVar(ncid_Output,WMO_ID_id,[0,tt-1],[8,1],SEAL_ID(1,:));
end

netcdf.close(ncid_Output);

ncFileDestination = strcat(dataWIP_Path,filesep,'NETCDF',filesep,SEAL_ID(1,:),filesep);
filetodelete      = dir(strcat(ncFileDestination,filesep,'*.nc'));
if ~isempty(filetodelete)
    delete (strcat(ncFileDestination,filetodelete(1).name))
end
movefile(aggregatedFileOutput,ncFileDestination);

clear timestamp TEMPE lat lon indexprofile time PSAL PRES  SEAL_ID

end

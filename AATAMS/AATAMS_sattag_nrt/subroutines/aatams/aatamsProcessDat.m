function [tagProcessed] = aatamsProcessDat(datFileToProcess)
% function to process each *.dat file. This function also calls
% readDevice_wmo_ref which check if the profiles within a dat file
% is an australian tag or not.
% takes the path of a dat file as an entry

dataWIP_Path       = getenv('data_wip_path');
australianTagsFile = getenv('australian_tags_filepath');

%% Read the file which contains all the Australian tags.
australianTags     = readDevice_wmo_ref(australianTagsFile);
nbAUStags          = length(australianTags);

%% Read the daily file containing all the profile of each seal around the world.
temp               = importdata(datFileToProcess);
dimfile            = length(temp.data);

%% Number of profiles
timeConverted      = datenum(temp.textdata(:,2),'yyyy-mm-dd HH:MM:SS');
j                  = 1;
checkprofile(j,1)  = 1;
for i = 2:dimfile
    if timeConverted(i) ~= timeConverted(i-1)
        checkprofile(j,2) = i-1;
        j                 = j+1;
        checkprofile(j,1) = i;
    end
end
checkprofile(j,2) = dimfile;
nbprofiles        = length(checkprofile(:,1));


%% Processing of each profile
tagProcessed      = cell(0);
nSecondsPerDay    = 60*60*24;
nTagProcessed     = 0;
for zz = 1:nbprofiles

    startobs        = checkprofile(zz,1);
    finalobs        = checkprofile(zz,2);
    dimobs          = finalobs - startobs +1;

    final(:,1)      = temp.data(startobs:finalobs,1);
    final(:,2)      = temp.data(startobs:finalobs,2);
    final(:,3)      = temp.data(startobs:finalobs,3);
    final(:,4)      = temp.data(startobs:finalobs,4);
    final(:,5)      = temp.data(startobs:finalobs,5);

    timeprofile     = timeConverted(startobs);
    timestart       = [1950, 1, 1, 0, 0, 0];
    timenc(1)       = (etime(datevec(timeprofile(1)),timestart))/nSecondsPerDay;

    %% CHECK IF THE TAGS IS AN AUSTRALIAN TAGS
    verifaussietags = 0;
    for ll = 1:nbAUStags
        if (temp.textdata{startobs} == australianTags{ll})
            verifaussietags = verifaussietags + 1;
        end
    end

    %% IF IT IS AN AUSTRALIAN TAG THEN WE OUTPUT A NETCDF FILE AND A CSV FILE

    if (verifaussietags)
        %% NETCDF OUTPUT
        ncFilePath = strcat(dataWIP_Path,filesep,'IMOS_AATAMS-SATTAG_TSP_',datestr(timeprofile,'yyyymmddTHHMMSSZ'),'_',temp.textdata{startobs},'_FV00.nc');
        nc         = netcdf.create(ncFilePath,'NC_CLOBBER');

        %% Creation of the GLOBAL ATTRIBUTES

        netcdf.putAtt(nc,netcdf.getConstant('GLOBAL'),'project','Integrated Marine Observing System (IMOS)');
        netcdf.putAtt(nc,netcdf.getConstant('GLOBAL'),'conventions','IMOS-1.2');
        netcdf.putAtt(nc,netcdf.getConstant('GLOBAL'),'date_created',datestr(datenum(clock)-10/24,'yyyy-mm-ddTHH:MM:SSZ'));
        netcdf.putAtt(nc,netcdf.getConstant('GLOBAL'),'title','Temperature, Salinity and Depth profiles in near real time');
        netcdf.putAtt(nc,netcdf.getConstant('GLOBAL'),'institution','AATAMS');
        netcdf.putAtt(nc,netcdf.getConstant('GLOBAL'),'site','CTD Satellite Relay Data Logger');

        netcdf.putAtt(nc,netcdf.getConstant('GLOBAL'),'abstract',getenv('gattval_abstract'));
        netcdf.putAtt(nc,netcdf.getConstant('GLOBAL'),'source','SMRU CTD Satellite relay Data Logger on marine mammals');

        netcdf.putAtt(nc,netcdf.getConstant('GLOBAL'),'keywords',getenv('gattval_keywords'));
        netcdf.putAtt(nc,netcdf.getConstant('GLOBAL'),'references','http://imos.org.au/aatams.html');
        netcdf.putAtt(nc,netcdf.getConstant('GLOBAL'),'platform_code',temp.textdata{startobs});
        netcdf.putAtt(nc,netcdf.getConstant('GLOBAL'),'netcdf_version','3.6');
        netcdf.putAtt(nc,netcdf.getConstant('GLOBAL'),'naming_authority','IMOS');
        netcdf.putAtt(nc,netcdf.getConstant('GLOBAL'),'quality_control_set','1');
        netcdf.putAtt(nc,netcdf.getConstant('GLOBAL'),'cdm_data_type','Trajectory');

        netcdf.putAtt(nc,netcdf.getConstant('GLOBAL'),'geospatial_lat_min',final(1,4));
        netcdf.putAtt(nc,netcdf.getConstant('GLOBAL'),'geospatial_lat_max',final(1,4));
        netcdf.putAtt(nc,netcdf.getConstant('GLOBAL'),'geospatial_lat_units','degrees_north');
        netcdf.putAtt(nc,netcdf.getConstant('GLOBAL'),'geospatial_lon_min',final(1,5));
        netcdf.putAtt(nc,netcdf.getConstant('GLOBAL'),'geospatial_lon_max',final(1,5));
        netcdf.putAtt(nc,netcdf.getConstant('GLOBAL'),'geospatial_lon_units','degrees_east');
        netcdf.putAtt(nc,netcdf.getConstant('GLOBAL'),'geospatial_vertical_min',min(final(1,1)));
        netcdf.putAtt(nc,netcdf.getConstant('GLOBAL'),'geospatial_vertical_max',max(final(1,5)));
        netcdf.putAtt(nc,netcdf.getConstant('GLOBAL'),'geospatial_vertical_units','dbar');

        netcdf.putAtt(nc,netcdf.getConstant('GLOBAL'),'time_coverage_start',datestr(timeprofile,'yyyy-mm-ddTHH:MM:SSZ'));
        netcdf.putAtt(nc,netcdf.getConstant('GLOBAL'),'time_coverage_end',datestr(timeprofile,'yyyy-mm-ddTHH:MM:SSZ'));

        netcdf.putAtt(nc,netcdf.getConstant('GLOBAL'),'data_centre_email','info@emii.org.au');
        netcdf.putAtt(nc,netcdf.getConstant('GLOBAL'),'data_centre','eMarine Information Infrastructure (eMII)');
        netcdf.putAtt(nc,netcdf.getConstant('GLOBAL'),'author',getenv('gattval_author_name'));
        netcdf.putAtt(nc,netcdf.getConstant('GLOBAL'),'author_email','info@emii.org.au');
        netcdf.putAtt(nc,netcdf.getConstant('GLOBAL'),'institution_references','http://imos.org.au/emii.html');
        netcdf.putAtt(nc,netcdf.getConstant('GLOBAL'),'principal_investigator','Harcourt, Rob');


        netcdf.putAtt(nc,netcdf.getConstant('GLOBAL'),'citation',getenv('gattval_citation'));
        netcdf.putAtt(nc,netcdf.getConstant('GLOBAL'),'acknowledgment',getenv('gattval_acknowledgement'));
        netcdf.putAtt(nc,netcdf.getConstant('GLOBAL'),'distribution_statement', getenv('gattval_distribution_statement'));
        netcdf.putAtt(nc,netcdf.getConstant('GLOBAL'),'file_version','Level 0 - Raw data');
        netcdf.putAtt(nc,netcdf.getConstant('GLOBAL'),'file_version_quality_control','Data in this file has not undergone quality control. There has been no QC performed on this real-time data.');
        netcdf.putAtt(nc,netcdf.getConstant('GLOBAL'),'metadata_uuid',getenv('gattval_uuid'));

        %% Creation of the DIMENSION
        obs_dimid                    = netcdf.defDim(nc,'obs',dimobs);
        profiles_dimid               = netcdf.defDim(nc,'profiles',1);
        length_char_dimid            = netcdf.defDim(nc,'length_char',8);

        %% Creation of the VARIABLES
        TIME_id                      = netcdf.defVar(nc,'TIME','double',profiles_dimid);
        LATITUDE_id                  = netcdf.defVar(nc,'LATITUDE','double',profiles_dimid);
        LONGITUDE_id                 = netcdf.defVar(nc,'LONGITUDE','double',profiles_dimid);
        TEMP_id                      = netcdf.defVar(nc,'TEMP','double',obs_dimid);
        PRES_id                      = netcdf.defVar(nc,'PRES','double',obs_dimid);
        PSAL_id                      = netcdf.defVar(nc,'PSAL','double',obs_dimid);
        WMO_ID_id                    = netcdf.defVar(nc,'WMO_ID','char',[length_char_dimid,profiles_dimid]);

        TIME_quality_control_id      = netcdf.defVar(nc,'TIME_quality_control','double',profiles_dimid);
        LATITUDE_quality_control_id  = netcdf.defVar(nc,'LATITUDE_quality_control','double',profiles_dimid);
        LONGITUDE_quality_control_id = netcdf.defVar(nc,'LONGITUDE_quality_control','double',profiles_dimid);
        TEMP_quality_control_id      = netcdf.defVar(nc,'TEMP_quality_control','double',obs_dimid);
        PRES_quality_control_id      = netcdf.defVar(nc,'PRES_quality_control','double',obs_dimid);
        PSAL_quality_control_id      = netcdf.defVar(nc,'PSAL_quality_control','double',obs_dimid);

        %% Definition of the VARIABLE ATTRIBUTES

        netcdf.putAtt(nc,TIME_id,'standard_name','time');
        netcdf.putAtt(nc,TIME_id,'long_name','analysis_time');
        netcdf.putAtt(nc,TIME_id,'units','days since 1950-01-01 00:00:00');
        netcdf.putAtt(nc,TIME_id,'axis','T');
        netcdf.putAtt(nc,TIME_id,'valid_min',0);
        netcdf.putAtt(nc,TIME_id,'valid_max',999999);
        netcdf.putAtt(nc,TIME_id,'_FillValue',-9999);
        netcdf.putAtt(nc,TIME_id,'ancillary_variables','TIME_quality_control');

        netcdf.putAtt(nc,LATITUDE_id,'standard_name','latitude');
        netcdf.putAtt(nc,LATITUDE_id,'long_name','latitude');
        netcdf.putAtt(nc,LATITUDE_id,'units','degrees_north');
        netcdf.putAtt(nc,LATITUDE_id,'axis','Y');
        netcdf.putAtt(nc,LATITUDE_id,'valid_min',-90);
        netcdf.putAtt(nc,LATITUDE_id,'valid_max',90);
        netcdf.putAtt(nc,LATITUDE_id,'_FillValue',999.9);
        netcdf.putAtt(nc,LATITUDE_id,'ancillary_variables','LATITUDE_quality_control');
        netcdf.putAtt(nc,LATITUDE_id,'reference_datum','geographical coordinates, WGS84 projection');

        netcdf.putAtt(nc,LONGITUDE_id,'standard_name','longitude');
        netcdf.putAtt(nc,LONGITUDE_id,'long_name','longitude');
        netcdf.putAtt(nc,LONGITUDE_id,'units','degrees_east');
        netcdf.putAtt(nc,LONGITUDE_id,'axis','X');
        netcdf.putAtt(nc,LONGITUDE_id,'valid_min',-180);
        netcdf.putAtt(nc,LONGITUDE_id,'valid_max',180);
        netcdf.putAtt(nc,LONGITUDE_id,'_FillValue',999.9);
        netcdf.putAtt(nc,LONGITUDE_id,'ancillary_variables','LONGITUDE_quality_control');
        netcdf.putAtt(nc,LONGITUDE_id,'reference_datum','geographical coordinates, WGS84 projection');

        netcdf.putAtt(nc,TEMP_id,'standard_name','sea_water_temperature');
        netcdf.putAtt(nc,TEMP_id,'long_name','sea_water_temperature');
        netcdf.putAtt(nc,TEMP_id,'units','Celsius');
        netcdf.putAtt(nc,TEMP_id,'valid_min',-2);
        netcdf.putAtt(nc,TEMP_id,'valid_max',40);
        netcdf.putAtt(nc,TEMP_id,'_FillValue',9999);
        netcdf.putAtt(nc,TEMP_id,'ancillary_variables','TEMP_quality_control');

        netcdf.putAtt(nc,PSAL_id,'standard_name','sea_water_salinity');
        netcdf.putAtt(nc,PSAL_id,'long_name','sea_water_salinity');
        netcdf.putAtt(nc,PSAL_id,'units','1e-3');
        netcdf.putAtt(nc,PSAL_id,'_FillValue',9999);
        netcdf.putAtt(nc,PSAL_id,'ancillary_variables','PSAL_quality_control');

        netcdf.putAtt(nc,PRES_id,'standard_name','sea_water_pressure');
        netcdf.putAtt(nc,PRES_id,'long_name','sea_water_pressure');
        netcdf.putAtt(nc,PRES_id,'units','dbar');
        netcdf.putAtt(nc,PRES_id,'_FillValue',9999);
        netcdf.putAtt(nc,PRES_id,'ancillary_variables','PRES_quality_control');

        netcdf.putAtt(nc,WMO_ID_id,'long_name','WMO device number');

        %% QC variables

        flagvalues = [0 1 2 3 4 5 6 7 8 9];

        netcdf.putAtt(nc,TIME_quality_control_id,'standard_name','time status_flag');
        netcdf.putAtt(nc,TIME_quality_control_id,'long_name','Quality Control flag for time');
        netcdf.putAtt(nc,TIME_quality_control_id,'quality_control_conventions','IMOS standard set using IODE flags');
        netcdf.putAtt(nc,TIME_quality_control_id,'quality_control_set',1);
        netcdf.putAtt(nc,TIME_quality_control_id,'_FillValue',9999);
        netcdf.putAtt(nc,TIME_quality_control_id,'valid_min',0);
        netcdf.putAtt(nc,TIME_quality_control_id,'valid_max',9);
        netcdf.putAtt(nc,TIME_quality_control_id,'flag_values',flagvalues);
        netcdf.putAtt(nc,TIME_quality_control_id,'flag_meanings','no_qc_performed good_data probably_good_data bad_data_that_are_potentially_correctable bad_data value_changed not_used not_used interpolated_values missing_values');

        netcdf.putAtt(nc,LATITUDE_quality_control_id,'standard_name','latitude status_flag');
        netcdf.putAtt(nc,LATITUDE_quality_control_id,'long_name','Quality Control flag for latitude');
        netcdf.putAtt(nc,LATITUDE_quality_control_id,'quality_control_conventions','IMOS standard set using IODE flags');
        netcdf.putAtt(nc,LATITUDE_quality_control_id,'quality_control_set',1);
        netcdf.putAtt(nc,LATITUDE_quality_control_id,'_FillValue',9999);
        netcdf.putAtt(nc,LATITUDE_quality_control_id,'valid_min',0);
        netcdf.putAtt(nc,LATITUDE_quality_control_id,'valid_max',9);
        netcdf.putAtt(nc,LATITUDE_quality_control_id,'flag_values',flagvalues);
        netcdf.putAtt(nc,LATITUDE_quality_control_id,'flag_meanings','no_qc_performed good_data probably_good_data bad_data_that_are_potentially_correctable bad_data value_changed not_used not_used interpolated_values missing_values');

        netcdf.putAtt(nc,LONGITUDE_quality_control_id,'standard_name','longitude status_flag');
        netcdf.putAtt(nc,LONGITUDE_quality_control_id,'long_name','Quality Control flag for longitude');
        netcdf.putAtt(nc,LONGITUDE_quality_control_id,'quality_control_conventions','IMOS standard set using IODE flags');
        netcdf.putAtt(nc,LONGITUDE_quality_control_id,'quality_control_set',1);
        netcdf.putAtt(nc,LONGITUDE_quality_control_id,'_FillValue',9999);
        netcdf.putAtt(nc,LONGITUDE_quality_control_id,'valid_min',0);
        netcdf.putAtt(nc,LONGITUDE_quality_control_id,'valid_max',9);
        netcdf.putAtt(nc,LONGITUDE_quality_control_id,'flag_values',flagvalues);
        netcdf.putAtt(nc,LONGITUDE_quality_control_id,'flag_meanings','no_qc_performed good_data probably_good_data bad_data_that_are_potentially_correctable bad_data value_changed not_used not_used interpolated_values missing_values');

        netcdf.putAtt(nc,TEMP_quality_control_id,'standard_name','sea_surface_temperature status_flag');
        netcdf.putAtt(nc,TEMP_quality_control_id,'long_name','Quality Control flag for temperature');
        netcdf.putAtt(nc,TEMP_quality_control_id,'quality_control_conventions','IMOS standard set using IODE flags');
        netcdf.putAtt(nc,TEMP_quality_control_id,'quality_control_set',1);
        netcdf.putAtt(nc,TEMP_quality_control_id,'_FillValue',9999);
        netcdf.putAtt(nc,TEMP_quality_control_id,'valid_min',0);
        netcdf.putAtt(nc,TEMP_quality_control_id,'valid_max',9);
        netcdf.putAtt(nc,TEMP_quality_control_id,'flag_values',flagvalues);
        netcdf.putAtt(nc,TEMP_quality_control_id,'flag_meanings','no_qc_performed good_data probably_good_data bad_data_that_are_potentially_correctable bad_data value_changed not_used not_used interpolated_values missing_values');

        netcdf.putAtt(nc,PRES_quality_control_id,'standard_name','sea_water_pressure status_flag');
        netcdf.putAtt(nc,PRES_quality_control_id,'long_name','Quality Control flag for pressure');
        netcdf.putAtt(nc,PRES_quality_control_id,'quality_control_conventions','IMOS standard set using IODE flags');
        netcdf.putAtt(nc,PRES_quality_control_id,'quality_control_set',1);
        netcdf.putAtt(nc,PRES_quality_control_id,'_FillValue',9999);
        netcdf.putAtt(nc,PRES_quality_control_id,'valid_min',0);
        netcdf.putAtt(nc,PRES_quality_control_id,'valid_max',9);
        netcdf.putAtt(nc,PRES_quality_control_id,'flag_values',flagvalues);
        netcdf.putAtt(nc,PRES_quality_control_id,'flag_meanings','no_qc_performed good_data probably_good_data bad_data_that_are_potentially_correctable bad_data value_changed not_used not_used interpolated_values missing_values');

        netcdf.putAtt(nc,PSAL_quality_control_id,'standard_name','sea_water_salinity status_flag');
        netcdf.putAtt(nc,PSAL_quality_control_id,'long_name','Quality Control flag for salinity');
        netcdf.putAtt(nc,PSAL_quality_control_id,'quality_control_conventions','IMOS standard set using IODE flags');
        netcdf.putAtt(nc,PSAL_quality_control_id,'quality_control_set',1);
        netcdf.putAtt(nc,PSAL_quality_control_id,'_FillValue',9999);
        netcdf.putAtt(nc,PSAL_quality_control_id,'valid_min',0);
        netcdf.putAtt(nc,PSAL_quality_control_id,'valid_max',9);
        netcdf.putAtt(nc,PSAL_quality_control_id,'flag_values',flagvalues);
        netcdf.putAtt(nc,PSAL_quality_control_id,'flag_meanings','no_qc_performed good_data probably_good_data bad_data_that_are_potentially_correctable bad_data value_changed not_used not_used interpolated_values missing_values');

        netcdf.endDef(nc)

        netcdf.putVar(nc,TIME_id,timenc(1));
        netcdf.putVar(nc,LATITUDE_id,final(1,4));
        netcdf.putVar(nc,LONGITUDE_id,final(1,5));
        netcdf.putVar(nc,TEMP_id,final(:,2));
        netcdf.putVar(nc,PRES_id,final(:,1));
        netcdf.putVar(nc,PSAL_id,final(:,3));
        netcdf.putVar(nc,TIME_quality_control_id,0);
        netcdf.putVar(nc,LATITUDE_quality_control_id,0);
        netcdf.putVar(nc,LONGITUDE_quality_control_id,0);
        blankmatrix = zeros(length(final(:,1)),1);
        netcdf.putVar(nc,TEMP_quality_control_id,blankmatrix(:,1));
        netcdf.putVar(nc,PSAL_quality_control_id,blankmatrix(:,1));
        netcdf.putVar(nc,PRES_quality_control_id,blankmatrix(:,1));
        k           = length(temp.textdata{startobs});
        netcdf.putVar(nc,WMO_ID_id,[0,0],[8,1],temp.textdata{startobs});

        netcdf.close(nc);

        netcdfPath     = strcat(dataWIP_Path,filesep,'NETCDF');
        tagProfilePath = strcat(temp.textdata{startobs},filesep,'profiles');

        % move file
        filedirectionnetcdf = strcat(netcdfPath,filesep,tagProfilePath);

        mkpath(filedirectionnetcdf);
        movefile(ncFilePath,filedirectionnetcdf);


        nTagProcessed               = nTagProcessed +1 ;
        tagProcessed{nTagProcessed} = temp.textdata{startobs};
    end


    clear final

end

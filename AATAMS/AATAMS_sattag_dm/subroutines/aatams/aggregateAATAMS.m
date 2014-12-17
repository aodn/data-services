function aggregateAATAMS(missionPath)
%aggregateAATAMS - aggregate all the different profiles stored as NetCDF
%into one for each subfolder.
%
% Syntax:  createAATAMS_1profile_netcdf(CTD_DATA, METADATA)
%
% Inputs:
%
%
% Outputs:
%
% Example:
%    aggregateAATAMS
%
% Other files required: none
% Other m-files required:
% Subfunctions: none
% MAT-files required: none
%
% See also: aatams_sealtags_main,createAATAMS_1profile_netcdf
%
% Author: Laurent Besnard, Sebastien Mancini, IMOS/eMII
% email: laurent.besnard@utas.edu.au
% Website: http://imos.org.au/  http://froggyscripts.blogspot.com
% Aug 2012; Last revision: 16-Aug-2012

dataWIP_Path = getenv('data_wip_path');

listfolder = dir (missionPath);
nbprocessedfolder = length(listfolder);

for i = 3:nbprocessedfolder
    if (listfolder(i).isdir)
        if ( exist(strcat(missionPath,filesep,listfolder(i).name,'/profiles'), 'dir') ) == 7

            listfiles = dir(strcat(missionPath,filesep,listfolder(i).name,'/profiles/','*.nc'));
            nbfiles = length(listfiles);

            if nbfiles~=0
                for j =1:nbfiles
                    timestamp(1,j) = datenum(listfiles(j).name(24:38),'yyyymmddTHHMMSS');
                end
                %Read all the NetCDF files for one seal

                t_fin = 0;
                time1 = 0;

                mkpath(strcat(missionPath,filesep,listfolder(i).name,'/profiles/temporary/'));
                for j = 1:nbfiles
                    %     for j =1:2
                    nc                              = netcdf.open(strcat(missionPath,filesep,listfolder(i).name,'/profiles/',listfiles(j).name),'NC_NOWRITE');
                    temp_varid                      = netcdf.inqVarID(nc,'TIME');
                    temp                            = netcdf.getVar(nc,temp_varid);
                    time1                           = temp(:);

                    %Variable LATITUDE and LONGITUDE
                    temp_varid                      = netcdf.inqVarID(nc,'LATITUDE');
                    temp                            = netcdf.getVar(nc,temp_varid);
                    lat1                            = temp(:);

                    temp_varid                      = netcdf.inqVarID(nc,'LONGITUDE');
                    temp                            = netcdf.getVar(nc,temp_varid);
                    lon1                            = temp(:);

                    %Variable TEMPERATURE, Pressure and SALINITY
                    temp_varid                      = netcdf.inqVarID(nc,'TEMP');
                    temp                            = netcdf.getVar(nc,temp_varid);
                    TEMPE1                          = temp(:);
                    temp_varid                      = netcdf.inqVarID(nc,'PSAL');
                    temp                            = netcdf.getVar(nc,temp_varid);
                    PSAL1                           = temp(:);
                    temp_varid                      = netcdf.inqVarID(nc,'PRES');
                    temp                            = netcdf.getVar(nc,temp_varid);
                    PRES1                           = temp(:);
                    %Variable WMO_ID
                    %                 temp_varid    = netcdf.inqVarID(nc,'WMO_ID');
                    %                 temp          = netcdf.getVar(nc,temp_varid);
                    %                 SEAL_ID1      =temp(:);
                    %Close the NetCDF file
                    netcdf.close(nc)

                    dimfile                         = length(TEMPE1);
                    t_deb                           = t_fin+1;
                    t_fin                           = t_deb+dimfile-1;
                    time(j)                         = time1;
                    lat(j)                          = lat1;
                    lon(j)                          = lon1;
                    %                 SEAL_ID(j, :) = SEAL_ID1;
                    TEMPE(t_deb:t_fin)              = TEMPE1;
                    PSAL(t_deb:t_fin)               = PSAL1;
                    PRES(t_deb:t_fin)               = PRES1;
                    indexprofile(t_deb:t_fin)       = j;
                    %Clear the temporary variable
                    clear TEMPE1 lat1 lon1 time1 PSAL1 PRES1  SEAL_ID1
                end

                nc                               = netcdf.open(strcat(missionPath,filesep,listfolder(i).name,'/profiles/',listfiles(j).name),'NC_NOWRITE');
                [gattname,gattval]               = getGlobAttNC(nc);
                netcdf.close(nc)

                idxGlobAtt_WMO                   = strcmpi(gattname,'wmo_identifier')==1;
                GlobAtt_WMO                      = gattval{idxGlobAtt_WMO};

                idxGlobAtt_unique_reference_code = strcmpi(gattname,'unique_reference_code')==1;
                GlobAtt_unique_reference_code    = gattval{idxGlobAtt_unique_reference_code};

                idxGlobAtt_UUID                  = strcmpi(gattname,'metadata_uuid')==1;
                GlobAtt_UUID                     = gattval{idxGlobAtt_UUID};

                idxGlobAtt_body_code             = strcmpi(gattname,'body_code')==1;
                GlobAtt_body_code                = gattval{idxGlobAtt_body_code};

                idxGlobAtt_ptt_code              = strcmpi(gattname,'ptt_code')==1;
                GlobAtt_ptt_code                 = gattval{idxGlobAtt_ptt_code};

                idxGlobAtt_species_name          = strcmpi(gattname,'species_name')==1;
                GlobAtt_species_name             = gattval{idxGlobAtt_species_name};

                idxGlobAtt_release_site          = strcmpi(gattname,'release_site')==1;
                GlobAtt_release_site             = gattval{idxGlobAtt_release_site};

                idxGlobAtt_sattag_program        = strcmpi(gattname,'sattag_program')==1;
                GlobAtt_sattag_program           = gattval{idxGlobAtt_sattag_program};


                dimobs                           = length(TEMPE);
                dimprofile                       = nbfiles;

                %%Creation of the aggregated NETCDF FILE
                fileoutput                       = char(strcat(missionPath,filesep,listfolder(i).name,'/profiles/temporary/',...
                    'IMOS_AATAMS-SATTAG_TSP_',datestr(min(timestamp),'yyyymmddTHHMMSSZ'),'_',GlobAtt_unique_reference_code,'_END-',datestr(max(timestamp),'yyyymmddTHHMMSSZ'),'_FV00.nc'));

                nc                               = netcdf.create(fileoutput,'NOCLOBBER');

                %% Creation of the GLOBAL ATTRIBUTES
                %WHAT
                netcdf.putAtt(nc,netcdf.getConstant('GLOBAL'),'project','Integrated Marine Observing System (IMOS)');
                netcdf.putAtt(nc,netcdf.getConstant('GLOBAL'),'conventions','IMOS-1.2');
                netcdf.putAtt(nc,netcdf.getConstant('GLOBAL'),'date_created',datestr(datenum(clock)-10/24,'yyyy-mm-ddTHH:MM:SSZ'));
                netcdf.putAtt(nc,netcdf.getConstant('GLOBAL'),'title','Temperature, Salinity and Depth profiles in near real time');
                netcdf.putAtt(nc,netcdf.getConstant('GLOBAL'),'institution','AATAMS');
                netcdf.putAtt(nc,netcdf.getConstant('GLOBAL'),'site','CTD Satellite Relay Data Logger');
                netcdfabstract = ['CTD Satellite Relay Data Loggers are used to explore how'...
                    ' marine mammal behaviour relates to their oceanic environment. Loggers'...
                    ' developped at the University of St Andrews Sea Mammal Research Unit'...
                    ' transmit data in near real time via the Argo satellite system'];
                netcdf.putAtt(nc,netcdf.getConstant('GLOBAL'),'abstract',netcdfabstract);
                netcdf.putAtt(nc,netcdf.getConstant('GLOBAL'),'source','SMRU CTD Satellite relay Data Logger on marine mammals');
                aatamskeywords = ['Oceans>Ocean Temperature>Water Temperature ;'...
                    'Oceans>Salinity/Density>Conductivity ;'...
                    'Oceans>Marine Biology>Marine Mammals'];
                netcdf.putAtt(nc,netcdf.getConstant('GLOBAL'),'keywords',aatamskeywords);
                netcdf.putAtt(nc,netcdf.getConstant('GLOBAL'),'references','http://imos.org.au/aatams.html');


                netcdf.putAtt(nc,netcdf.getConstant('GLOBAL'),'unique_reference_code',(GlobAtt_unique_reference_code));
                netcdf.putAtt(nc,netcdf.getConstant('GLOBAL'),'platform_code',(GlobAtt_WMO));
                netcdf.putAtt(nc,netcdf.getConstant('GLOBAL'),'netcdf_version','3.6');
                netcdf.putAtt(nc,netcdf.getConstant('GLOBAL'),'naming_authority','IMOS');
                netcdf.putAtt(nc,netcdf.getConstant('GLOBAL'),'quality_control_set','1');
                netcdf.putAtt(nc,netcdf.getConstant('GLOBAL'),'cdm_data_type','Trajectory');
                %WHERE
                netcdf.putAtt(nc,netcdf.getConstant('GLOBAL'),'geospatial_lat_min',min(lat));
                netcdf.putAtt(nc,netcdf.getConstant('GLOBAL'),'geospatial_lat_max',max(lat));
                netcdf.putAtt(nc,netcdf.getConstant('GLOBAL'),'geospatial_lat_units','degrees_north');
                netcdf.putAtt(nc,netcdf.getConstant('GLOBAL'),'geospatial_lon_min',min(lon));
                netcdf.putAtt(nc,netcdf.getConstant('GLOBAL'),'geospatial_lon_max',max(lon));
                netcdf.putAtt(nc,netcdf.getConstant('GLOBAL'),'geospatial_lon_units','degrees_east');
                netcdf.putAtt(nc,netcdf.getConstant('GLOBAL'),'geospatial_vertical_min',min(PRES));
                netcdf.putAtt(nc,netcdf.getConstant('GLOBAL'),'geospatial_vertical_max',max(PRES));
                netcdf.putAtt(nc,netcdf.getConstant('GLOBAL'),'geospatial_vertical_units','dbar');
                %WHEN
                netcdf.putAtt(nc,netcdf.getConstant('GLOBAL'),'time_coverage_start',datestr(min(timestamp),'yyyy-mm-ddTHH :MM:SSZ'));
                netcdf.putAtt(nc,netcdf.getConstant('GLOBAL'),'time_coverage_end',datestr(max(timestamp),'yyyy-mm-ddTHH   :MM:SSZ'));
                %WHO
                netcdf.putAtt(nc,netcdf.getConstant('GLOBAL'),'data_centre_email',getenv('gattval_data_center_email'));
                netcdf.putAtt(nc,netcdf.getConstant('GLOBAL'),'data_centre','eMarine Information Infrastructure (eMII)');
                netcdf.putAtt(nc,netcdf.getConstant('GLOBAL'),'author',getenv('gattval_author_name'));
                netcdf.putAtt(nc,netcdf.getConstant('GLOBAL'),'author_email',getenv('gattval_author_email'));
                netcdf.putAtt(nc,netcdf.getConstant('GLOBAL'),'institution_references','http                              ://imos.org.au/emii.html');
                netcdf.putAtt(nc,netcdf.getConstant('GLOBAL'),'principal_investigator','Harcourt, Rob');
                %HOW
                aatamscitation       = getenv('gattval_citation');
                netcdf.putAtt(nc,netcdf.getConstant('GLOBAL'),'citation',aatamscitation);
                aatamsacknowledgment = getenv('gattval_acknowledgement');
                netcdf.putAtt(nc,netcdf.getConstant('GLOBAL'),'acknowledgment',aatamsacknowledgment);
                aatamsdistribution   = getenv('gattval_distribution_statement');
                netcdf.putAtt(nc,netcdf.getConstant('GLOBAL'),'distribution_statement',aatamsdistribution);
                netcdf.putAtt(nc,netcdf.getConstant('GLOBAL'),'file_version','Level 0 - Raw data');
                netcdf.putAtt(nc,netcdf.getConstant('GLOBAL'),'file_version_quality_control','Data in this file has not undergone quality control. There has been no QC performed on this real-time data.');


                netcdf.putAtt(nc,netcdf.getConstant('GLOBAL'),'metadata_uuid',(GlobAtt_UUID));

                netcdf.putAtt(nc,netcdf.getConstant('GLOBAL'),'body_code',(GlobAtt_body_code));
                netcdf.putAtt(nc,netcdf.getConstant('GLOBAL'),'ptt_code',(GlobAtt_ptt_code));
                netcdf.putAtt(nc,netcdf.getConstant('GLOBAL'),'species_name',(GlobAtt_species_name));
                netcdf.putAtt(nc,netcdf.getConstant('GLOBAL'),'release_site',(GlobAtt_release_site));
                netcdf.putAtt(nc,netcdf.getConstant('GLOBAL'),'sattag_program',(GlobAtt_sattag_program));


                %% Creation of the DIMENSION
                obs_dimid                    = netcdf.defDim(nc,'obs',dimobs);
                profiles_dimid               = netcdf.defDim(nc,'profiles',dimprofile);
                length_char_dimid            = netcdf.defDim(nc,'length_char',8);

                %% Creation of the VARIABLES
                TIME_id                      = netcdf.defVar(nc,'TIME','double',profiles_dimid);
                LATITUDE_id                  = netcdf.defVar(nc,'LATITUDE','double',profiles_dimid);
                LONGITUDE_id                 = netcdf.defVar(nc,'LONGITUDE','double',profiles_dimid);
                TEMP_id                      = netcdf.defVar(nc,'TEMP','double',obs_dimid);
                PRES_id                      = netcdf.defVar(nc,'PRES','double',obs_dimid);
                PSAL_id                      = netcdf.defVar(nc,'PSAL','double',obs_dimid);
                parentIndex_id               = netcdf.defVar(nc,'parentIndex','double',obs_dimid);
                %             WMO_ID_id      = netcdf.defVar(nc,'WMO_ID','char',[length_char_dimid,profiles_dimid]);
                % %
                TIME_quality_control_id      = netcdf.defVar(nc,'TIME_quality_control','double',profiles_dimid);
                LATITUDE_quality_control_id  = netcdf.defVar(nc,'LATITUDE_quality_control','double',profiles_dimid);
                LONGITUDE_quality_control_id = netcdf.defVar(nc,'LONGITUDE_quality_control','double',profiles_dimid);
                TEMP_quality_control_id      = netcdf.defVar(nc,'TEMP_quality_control','double',obs_dimid);
                PRES_quality_control_id      = netcdf.defVar(nc,'PRES_quality_control','double',obs_dimid);
                PSAL_quality_control_id      = netcdf.defVar(nc,'PSAL_quality_control','double',obs_dimid);

                %% Definition of the VARIABLE ATTRIBUTES

                %Time
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

                %             netcdf.putAtt(nc,WMO_ID_id,'long_name','WMO device number');

                netcdf.putAtt(nc,parentIndex_id,'long_name','index of profile');
                netcdf.putAtt(nc,parentIndex_id,'ragged_row_index','profile');
                netcdf.putAtt(nc,parentIndex_id,'comment','the pressure(i), temperature(i) and salinity(i) is associated with the coordiante values time(p), lat(p), lon(p) where p=parentIndex(i).');

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

                netcdf.putVar(nc,TIME_id,time(:));
                netcdf.putVar(nc,LATITUDE_id,lat(:));
                netcdf.putVar(nc,LONGITUDE_id,lon(:));
                netcdf.putVar(nc,TEMP_id,TEMPE(:));
                netcdf.putVar(nc,PRES_id,PRES(:));
                netcdf.putVar(nc,PSAL_id,PSAL(:));
                netcdf.putVar(nc,parentIndex_id,indexprofile(:));
                blankmatrix = zeros(dimprofile,1);
                netcdf.putVar(nc,TIME_quality_control_id,blankmatrix(:,1));
                netcdf.putVar(nc,LATITUDE_quality_control_id,blankmatrix(:,1));
                netcdf.putVar(nc,LONGITUDE_quality_control_id,blankmatrix(:,1));
                blankmatrix = zeros(dimobs,1);
                netcdf.putVar(nc,TEMP_quality_control_id,blankmatrix(:,1));
                netcdf.putVar(nc,PSAL_quality_control_id,blankmatrix(:,1));
                netcdf.putVar(nc,PRES_quality_control_id,blankmatrix(:,1));
                %
                %             for tt = 1:dimprofile
                %                 netcdf.putVar(nc,WMO_ID_id,[0,tt-1],[8,1],SEAL_ID(1,:));
                %             end
                %
                %Close the current NetCDF file
                netcdf.close(nc);

                filedirectionnetcdf = strcat(missionPath,filesep,listfolder(i).name,filesep);
                filetodelete = dir(strcat(filedirectionnetcdf,'*.nc'));
                if (~isempty(filetodelete))
                    delete (strcat(filedirectionnetcdf,filetodelete(1).name))
                end
                [~,~,~]=movefile(fileoutput,filedirectionnetcdf);
                filepath=fileparts(fileoutput);
                rmdir(filepath)

                clear timestamp TEMPE lat lon indexprofile time PSAL PRES  SEAL_ID

            end
        end
    end
end
end
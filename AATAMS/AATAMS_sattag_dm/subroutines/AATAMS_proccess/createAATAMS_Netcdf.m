function createAATAMS_Netcdf(CTD_DATA, METADATA)
%createAATAMS_Netcdf - creates one NetCDF file per profile.
%Check existence of data for PRES, TEMP, SAL, FLUORO, COND, OXY ...
%So far, only T,P,S are written as NetCDF files.
%
%
% Syntax:  createAATAMS_Netcdf(CTD_DATA, METADATA)
%
% Inputs:
%    CTD_DATA - structure of data
%
% Outputs:
%    METADATA - structure of metadata
%
% Example:
%    createAATAMS_Netcdf(CTD_DATA, METADATA)
%
% Other files required: none
% Other m-files required: findWMO
% Subfunctions: none
% MAT-files required: none
%
% See also: aatams_sealtags_main,loadCTD_datafromDB
%
% Author: Laurent Besnard, IMOS/eMII
% email: laurent.besnard@utas.edu.au
% Website: http://imos.org.au/  http://froggyscripts.blogspot.com
% Aug 2012; Last revision: 09-Aug-2012


dataWIP_Path       = readConfig('dataWIP.path', 'config.txt','=');
FILLVALUE_TEMP_SAL = 9999;

%sattagFolderName
missionFolderName    = createSattagProgFolderName (CTD_DATA, METADATA);
allMissionFolderPath = strcat(dataWIP_Path,filesep,'NETCDF');
missionFolderPath    = strcat(allMissionFolderPath,filesep,missionFolderName);

% create a temporary mission folder. And if this subroutine succeed, then
% we delete missionFolderPath ( previously created ), and replace it with
% this temporary folder. This is a more robust way to keep at least the
% previous version of data if this routine fails for any reason.
tempDir = tempname;
missionFolderPathTemporary = strcat(tempDir,filesep,'NETCDF',filesep,missionFolderName);



count              =1;
%% Creation of global attributes
gattname{1}        = 'project';
gattval{1}         = 'Integrated Marine Observing System (IMOS)';

gattname{2}        = 'conventions';
gattval{2}         = 'IMOS-1.2';

gattname{3}        = 'date_created';
gattval{3}         = datestr(now,'yyyy-mm-ddTHH:MM:SSZ');

gattname{4}        = 'title';
gattval{4}         = 'Temperature, Salinity and Depth profiles in near real time';

gattname{5}        = 'institution';
gattval{5}         = 'AATAMS';

gattname{6}        = 'site';
gattval{6}         = 'CTD Satellite Relay Data Logger';

gattname{7}        = 'abstract';
gattval{7}         = 'CTD Satellite Relay Data Loggers are used to explore how marine mammal behaviour relates to their oceanic environment. Loggers developped at the University of St Andrews Sea Mammal Research Unit transmit data in near real time via the Argo satellite system';

gattname{8}        = 'source';
gattval{8}         = 'SMRU CTD Satellite relay Data Logger on marine mammals';

gattname{9}        = 'keywords';
gattval{9}         = 'Oceans>Ocean Temperature>Water Temperature ;Oceans>Salinity/Density>Conductivity ;Oceans>Marine Biology>Marine Mammals';

gattname{10}       = 'references';
gattval{10}        = 'http://imos.org.au/aatams.html';

gattname{12}       = 'netcdf_version';
gattval{12}        = '3.6';

gattname{13}       = 'naming_authority';
gattval{13}        = 'IMOS';

gattname{14}       = 'quality_control_set';
gattval{14}        = '1';

gattname{15}       = 'cdm_data_type';
gattval{15}        = 'profile';

gattname{22}       = 'data_centre_email';
gattval{22}        = 'info@emii.org.au';

gattname{23}       = 'data_centre';
gattval{23}        = 'eMarine Information Infrastructure (eMII)';

gattname{24}       = 'author';
gattval{24}        = 'Besnard, Laurent ';

gattname{25}       = 'author_email';
gattval{25}        = 'laurent.besnard@utas.edu.au';

gattname{26}       = 'institution_references';
gattval{26}        = 'http://imos.org.au/emii.html';

gattname{27}       = 'principal_investigator';
gattval{27}        = 'Harcourt, Rob';

gattname{28}       = 'citation';
gattval{28}        = 'Citation to be used in publications should follow the format: IMOS, [year-of-data-download], [Title], [data-access-URL],accessed [date-of-access]';

gattname{29}       = 'acknowledgment';
gattval{29}        = 'Any users of IMOS data are required to clearly acknowledge the source of the material in the format: "Data was sourced from the Integrated Marine Observing System (IMOS) - IMOS is supported by the Australian Government through the National Collaborative Research Infrastructure Strategy (NCRIS) and the Super Science Initiative (SSI)"';

gattname{30}       = 'distribution_statement';
gattval{30}        = 'AATAMS data may be re-used, provided that related metadata explaining the data has been reviewed by the user and the data is appropriately acknowledged. Data, products and services from IMOS are provided "as is" without any warranty as to fitness for uniqueTagNames particular purpose';

gattname{31}       = 'file_version';
gattval{31}        = 'Level 0 - Raw data';

gattname{32}       = 'file_version_quality_control';
gattval{32}        = 'Data in this file has not undergone quality control. There has been no QC performed on this real-time data.';


[uniqueTagNames,~,positionUniqueTagNames] = unique_no_sort((CTD_DATA.ref)');
nTag                                      = length(uniqueTagNames);
for iiTag = 1:nTag
    
    indexesTag           = positionUniqueTagNames==iiTag ;
    tagName              = char(unique(CTD_DATA.ref(indexesTag)));  
    pttCode              = unique(CTD_DATA.PTT(indexesTag));
    
    END_DATE             = CTD_DATA.END_DATE(indexesTag);
    [END_DATE_sorted,IX] = sort(END_DATE);
    
    lon_Tag              = CTD_DATA.LON(indexesTag);
    lat_Tag              = CTD_DATA.LAT(indexesTag);
    
    
    n_temp_Tag           = CTD_DATA.N_TEMP(indexesTag); % sometime N_TEMP can be NaN or N_SAL can be NaN. But not necessary both at the same time. So we get the value which is not NaN for the dimension
    n_sal_Tag            = CTD_DATA.N_SAL(indexesTag);
    sal_dbar_Tag         = CTD_DATA.SAL_DBAR(indexesTag);
    sal_vals_Tag         = CTD_DATA.SAL_VALS(indexesTag);
    temp_dbar_Tag        = CTD_DATA.TEMP_DBAR(indexesTag);
    temp_vals_Tag        = CTD_DATA.TEMP_VALS(indexesTag);
    
    
    
    nProfile             = sum(indexesTag); %or length(END_DATE)
    
    
    gattname{33}         = 'metadata_uuid';
    gattval{33}          = readConfig('gAttVal.uuid', 'config.txt','=');
    
    gattname{34}         = 'unique_reference_code';
    gattval{34}          = strtrim(tagName);
    
    %% we want to create one file per profile
    WMO_NUMBER           = getWMO (pttCode);
    bodyNumber           = getbodyNumber (pttCode);
    speciesName          = getSpeciesName (pttCode);
    releaseSiteName      = getreleaseSite(pttCode);
    
    sattagProgram        = getSATTAG(pttCode);
    pptCodeName          = num2str(pttCode);
    
    gattname{11}         = 'wmo_identifier';
    gattval{11}          = WMO_NUMBER;
    
    gattname{35}         = 'body_code';
    gattval{35}          = bodyNumber;
    
    gattname{36}         = 'ptt_code';
    gattval{36}          = pptCodeName;
    
    gattname{37}         = 'species_name';
    gattval{37}          = speciesName;
    
    gattname{38}         = 'release_site';
    gattval{38}          = releaseSiteName;
    
    gattname{39}         = 'sattag_program';
    gattval{39}          = sattagProgram;
    
    
    for iiProfileOrderedInTime = 1:nProfile
        TIME       = END_DATE_sorted(iiProfileOrderedInTime);
        profileIDX = IX(iiProfileOrderedInTime);
        
        LON        = lon_Tag(profileIDX);
        LAT        = lat_Tag(profileIDX);
        
        N_TEMP     = (n_temp_Tag(profileIDX)); % sometime N_TEMP can be NaN or N_SAL can be NaN. But not necessary both at the same time. So we get the value which is not NaN for the dimension
        N_SAL      = (n_sal_Tag(profileIDX));
        N_DEPTH    = max(N_TEMP,N_SAL);
        
        if N_DEPTH~=0
            if ~isnan(N_DEPTH)
                %Salinity
                if ~(isnan(N_SAL) || N_SAL==0)
                    
                    SAL_DBAR             = (sal_dbar_Tag(profileIDX));
                    SAL_VALS             = (sal_vals_Tag(profileIDX));
                    
                    SAL_VALS_profile_pre = cell2mat(textscan(SAL_VALS{1},'%f', N_SAL(1),'delimiter', ','));
                    SAL_DBAR_profile     = cell2mat(textscan(SAL_DBAR{1},'%f', N_SAL(1),'delimiter', ','));
                    

                    
                else
                    NaNmatrix            = NaN(N_DEPTH,1);
                    SAL_DBAR_profile     = NaNmatrix;
                    SAL_VALS_profile_pre = NaNmatrix;
                end
                
                %Temperature
                if ~(isnan(N_TEMP) || N_TEMP==0)
                    
                    TEMP_DBAR             = (temp_dbar_Tag(profileIDX));
                    TEMP_VALS             = (temp_vals_Tag(profileIDX));
                    
                    TEMP_VALS_profile_pre = cell2mat(textscan(TEMP_VALS{1},'%f', N_TEMP(1),'delimiter', ','));
                    TEMP_DBAR_profile     = cell2mat(textscan(TEMP_DBAR{1},'%f', N_TEMP(1),'delimiter', ','));

                    
                else
                    NaNmatrix             = NaN(N_DEPTH,1);
                    TEMP_DBAR_profile     = NaNmatrix;
                    TEMP_VALS_profile_pre = NaNmatrix;
                end
                % we reprocess now that we have data for both temp and sal, we
                % create a new vector of depth, which is the union of both
                DBAR_profile          = union(TEMP_DBAR_profile ,SAL_DBAR_profile);
                N_DEPTH               = length(DBAR_profile);
                TEMP_VALS_profile     = NaN(N_DEPTH,1);
                SAL_VALS_profile      = NaN(N_DEPTH,1);
                
                clear tf loc
                [tf,loc]              = ismember(DBAR_profile,TEMP_DBAR_profile);
                TEMP_VALS_profile(tf) = TEMP_VALS_profile_pre(loc(loc~=0));
                
                clear tf loc
                [tf,loc]              = ismember(DBAR_profile,SAL_DBAR_profile);
                SAL_VALS_profile(tf)  = SAL_VALS_profile_pre(loc(loc~=0));
                
            else
                fprintf('%s - WARNING: Tag "%s" DEBUG, NO DATA \n',datestr(now),char(tagName))
            end
            
            
            gattname{16} = 'geospatial_lat_min';
            gattval{16}  = min(LAT);
            
            gattname{17} = 'geospatial_lat_max';
            gattval{17}  = max(LAT);
            
            gattname{18} = 'geospatial_lon_min';
            gattval{18}  = min(LON);
            
            gattname{19} = 'geospatial_lon_max';
            gattval{19}  = max(LON);
            
            gattname{20} = 'time_coverage_start';
            gattval{20}  = datestr(TIME,'yyyy-mm-ddTHH:MM:SSZ') ;
            
            gattname{21} = 'time_coverage_end';
            gattval{21}  = datestr(TIME,'yyyy-mm-ddTHH:MM:SSZ') ;
            
            missionPath = missionFolderPathTemporary ;
            ncFilename  = char(strcat(missionPath,filesep,tagName,filesep,'profiles',filesep,'IMOS_AATAMS-SATTAG_TSP_',datestr(TIME,'yyyymmddTHHMMSSZ'),'_',tagName,'_FV00.nc'));
            mkpath(strcat(missionPath,filesep,tagName,filesep,'profiles'))
            ncid        = netcdf.create(ncFilename,'CLOBBER');
            
            for uu=1:length(gattname)                
                netcdf.putAtt(ncid,netcdf.getConstant('GLOBAL'),gattname{uu}, gattval{uu});
            end
            
            %% Creation of the DIMENSION
            dimObs            = N_DEPTH;
            if ~isnan(dimObs)
                obs_dimid         = netcdf.defDim(ncid,'obs',dimObs);
                profiles_dimid    = netcdf.defDim(ncid,'profiles',1);
    %             length_char_dimid = netcdf.defDim(ncid,'length_char',8);
                
                %Creation of the VARIABLES
                TIME_id                      = netcdf.defVar(ncid,'TIME','double',profiles_dimid);
                LATITUDE_id                  = netcdf.defVar(ncid,'LATITUDE','double',profiles_dimid);
                LONGITUDE_id                 = netcdf.defVar(ncid,'LONGITUDE','double',profiles_dimid);
                TEMP_id                      = netcdf.defVar(ncid,'TEMP','double',obs_dimid);
                PRES_id                      = netcdf.defVar(ncid,'PRES','double',obs_dimid);
                PSAL_id                      = netcdf.defVar(ncid,'PSAL','double',obs_dimid);
                %             WMO_ID_id      = netcdf.defVar(ncid,'WMO_ID','char',[length_char_dimid,profiles_dimid]);
                
                TIME_quality_control_id      = netcdf.defVar(ncid,'TIME_quality_control','double',profiles_dimid);
                LATITUDE_quality_control_id  = netcdf.defVar(ncid,'LATITUDE_quality_control','double',profiles_dimid);
                LONGITUDE_quality_control_id = netcdf.defVar(ncid,'LONGITUDE_quality_control','double',profiles_dimid);
                TEMP_quality_control_id      = netcdf.defVar(ncid,'TEMP_quality_control','double',obs_dimid);
                PRES_quality_control_id      = netcdf.defVar(ncid,'PRES_quality_control','double',obs_dimid);
                PSAL_quality_control_id      = netcdf.defVar(ncid,'PSAL_quality_control','double',obs_dimid);
                
                % %Definition of the VARIABLE ATTRIBUTES
                
                %Time
                netcdf.putAtt(ncid,TIME_id,'standard_name','time');
                netcdf.putAtt(ncid,TIME_id,'long_name','analysis_time');
                netcdf.putAtt(ncid,TIME_id,'units','days since 1950-01-01 00:00:00');
                netcdf.putAtt(ncid,TIME_id,'axis','T');
                netcdf.putAtt(ncid,TIME_id,'valid_min',0);
                netcdf.putAtt(ncid,TIME_id,'valid_max',999999);
                netcdf.putAtt(ncid,TIME_id,'_FillValue',-9999);
                netcdf.putAtt(ncid,TIME_id,'ancillary_variables','TIME_quality_control');
                
                %latitude
                netcdf.putAtt(ncid,LATITUDE_id,'standard_name','latitude');
                netcdf.putAtt(ncid,LATITUDE_id,'long_name','latitude');
                netcdf.putAtt(ncid,LATITUDE_id,'units','degrees_north');
                netcdf.putAtt(ncid,LATITUDE_id,'axis','Y');
                netcdf.putAtt(ncid,LATITUDE_id,'valid_min',-90);
                netcdf.putAtt(ncid,LATITUDE_id,'valid_max',90);
                netcdf.putAtt(ncid,LATITUDE_id,'_FillValue',999.9);
                netcdf.putAtt(ncid,LATITUDE_id,'ancillary_variables','LATITUDE_quality_control');
                netcdf.putAtt(ncid,LATITUDE_id,'reference_datum','geographical coordinates, WGS84 projection');
                
                %longitude
                netcdf.putAtt(ncid,LONGITUDE_id,'standard_name','longitude');
                netcdf.putAtt(ncid,LONGITUDE_id,'long_name','longitude');
                netcdf.putAtt(ncid,LONGITUDE_id,'units','degrees_east');
                netcdf.putAtt(ncid,LONGITUDE_id,'axis','X');
                netcdf.putAtt(ncid,LONGITUDE_id,'valid_min',-180);
                netcdf.putAtt(ncid,LONGITUDE_id,'valid_max',180);
                netcdf.putAtt(ncid,LONGITUDE_id,'_FillValue',999.9);
                netcdf.putAtt(ncid,LONGITUDE_id,'ancillary_variables','LONGITUDE_quality_control');
                netcdf.putAtt(ncid,LONGITUDE_id,'reference_datum','geographical coordinates, WGS84 projection');
                
                %temp
                netcdf.putAtt(ncid,TEMP_id,'standard_name','sea_water_temperature');
                netcdf.putAtt(ncid,TEMP_id,'long_name','sea_water_temperature');
                netcdf.putAtt(ncid,TEMP_id,'units','Celsius');
                netcdf.putAtt(ncid,TEMP_id,'valid_min',-2);
                netcdf.putAtt(ncid,TEMP_id,'valid_max',40);
                netcdf.putAtt(ncid,TEMP_id,'_FillValue',FILLVALUE_TEMP_SAL);
                netcdf.putAtt(ncid,TEMP_id,'ancillary_variables','TEMP_quality_control');
                
                %sal
                netcdf.putAtt(ncid,PSAL_id,'standard_name','sea_water_salinity');
                netcdf.putAtt(ncid,PSAL_id,'long_name','sea_water_salinity');
                netcdf.putAtt(ncid,PSAL_id,'units','1e-3');
                netcdf.putAtt(ncid,PSAL_id,'_FillValue',FILLVALUE_TEMP_SAL);
                netcdf.putAtt(ncid,PSAL_id,'ancillary_variables','PSAL_quality_control');
                
                %pres
                netcdf.putAtt(ncid,PRES_id,'standard_name','sea_water_pressure');
                netcdf.putAtt(ncid,PRES_id,'long_name','sea_water_pressure');
                netcdf.putAtt(ncid,PRES_id,'units','dbar');
                netcdf.putAtt(ncid,PRES_id,'_FillValue',FILLVALUE_TEMP_SAL);
                netcdf.putAtt(ncid,PRES_id,'ancillary_variables','PRES_quality_control');
                
                %netcdf.putAtt(ncid,WMO_ID_id,'long_name','WMO device number');
                
                %% QC variables
                
                flagvalues = [0 1 2 3 4 5 6 7 8 9];
                %time
                netcdf.putAtt(ncid,TIME_quality_control_id,'standard_name','time status_flag');
                netcdf.putAtt(ncid,TIME_quality_control_id,'long_name','Quality Control flag for time');
                netcdf.putAtt(ncid,TIME_quality_control_id,'quality_control_conventions','IMOS standard set using IODE flags');
                netcdf.putAtt(ncid,TIME_quality_control_id,'quality_control_set',1);
                netcdf.putAtt(ncid,TIME_quality_control_id,'_FillValue',FILLVALUE_TEMP_SAL);
                netcdf.putAtt(ncid,TIME_quality_control_id,'valid_min',0);
                netcdf.putAtt(ncid,TIME_quality_control_id,'valid_max',9);
                netcdf.putAtt(ncid,TIME_quality_control_id,'flag_values',flagvalues);
                netcdf.putAtt(ncid,TIME_quality_control_id,'flag_meanings','no_qc_performed good_data probably_good_data bad_data_that_are_potentially_correctable bad_data value_changed not_used not_used interpolated_values missing_values');
                
                %lat
                netcdf.putAtt(ncid,LATITUDE_quality_control_id,'standard_name','latitude status_flag');
                netcdf.putAtt(ncid,LATITUDE_quality_control_id,'long_name','Quality Control flag for latitude');
                netcdf.putAtt(ncid,LATITUDE_quality_control_id,'quality_control_conventions','IMOS standard set using IODE flags');
                netcdf.putAtt(ncid,LATITUDE_quality_control_id,'quality_control_set',1);
                netcdf.putAtt(ncid,LATITUDE_quality_control_id,'_FillValue',FILLVALUE_TEMP_SAL);
                netcdf.putAtt(ncid,LATITUDE_quality_control_id,'valid_min',0);
                netcdf.putAtt(ncid,LATITUDE_quality_control_id,'valid_max',9);
                netcdf.putAtt(ncid,LATITUDE_quality_control_id,'flag_values',flagvalues);
                netcdf.putAtt(ncid,LATITUDE_quality_control_id,'flag_meanings','no_qc_performed good_data probably_good_data bad_data_that_are_potentially_correctable bad_data value_changed not_used not_used interpolated_values missing_values');
                
                %lon
                netcdf.putAtt(ncid,LONGITUDE_quality_control_id,'standard_name','longitude status_flag');
                netcdf.putAtt(ncid,LONGITUDE_quality_control_id,'long_name','Quality Control flag for longitude');
                netcdf.putAtt(ncid,LONGITUDE_quality_control_id,'quality_control_conventions','IMOS standard set using IODE flags');
                netcdf.putAtt(ncid,LONGITUDE_quality_control_id,'quality_control_set',1);
                netcdf.putAtt(ncid,LONGITUDE_quality_control_id,'_FillValue',FILLVALUE_TEMP_SAL);
                netcdf.putAtt(ncid,LONGITUDE_quality_control_id,'valid_min',0);
                netcdf.putAtt(ncid,LONGITUDE_quality_control_id,'valid_max',9);
                netcdf.putAtt(ncid,LONGITUDE_quality_control_id,'flag_values',flagvalues);
                netcdf.putAtt(ncid,LONGITUDE_quality_control_id,'flag_meanings','no_qc_performed good_data probably_good_data bad_data_that_are_potentially_correctable bad_data value_changed not_used not_used interpolated_values missing_values');

                
                netcdf.putAtt(ncid,TEMP_quality_control_id,'standard_name','sea_surface_temperature status_flag');
                netcdf.putAtt(ncid,TEMP_quality_control_id,'long_name','Quality Control flag for temperature');
                netcdf.putAtt(ncid,TEMP_quality_control_id,'quality_control_conventions','IMOS standard set using IODE flags');
                netcdf.putAtt(ncid,TEMP_quality_control_id,'quality_control_set',1);
                netcdf.putAtt(ncid,TEMP_quality_control_id,'_FillValue',FILLVALUE_TEMP_SAL);
                netcdf.putAtt(ncid,TEMP_quality_control_id,'valid_min',0);
                netcdf.putAtt(ncid,TEMP_quality_control_id,'valid_max',9);
                netcdf.putAtt(ncid,TEMP_quality_control_id,'flag_values',flagvalues);
                netcdf.putAtt(ncid,TEMP_quality_control_id,'flag_meanings','no_qc_performed good_data probably_good_data bad_data_that_are_potentially_correctable bad_data value_changed not_used not_used interpolated_values missing_values');
                
                %pres
                netcdf.putAtt(ncid,PRES_quality_control_id,'standard_name','sea_water_pressure status_flag');
                netcdf.putAtt(ncid,PRES_quality_control_id,'long_name','Quality Control flag for pressure');
                netcdf.putAtt(ncid,PRES_quality_control_id,'quality_control_conventions','IMOS standard set using IODE flags');
                netcdf.putAtt(ncid,PRES_quality_control_id,'quality_control_set',1);
                netcdf.putAtt(ncid,PRES_quality_control_id,'_FillValue',FILLVALUE_TEMP_SAL);
                netcdf.putAtt(ncid,PRES_quality_control_id,'valid_min',0);
                netcdf.putAtt(ncid,PRES_quality_control_id,'valid_max',9);
                netcdf.putAtt(ncid,PRES_quality_control_id,'flag_values',flagvalues);
                netcdf.putAtt(ncid,PRES_quality_control_id,'flag_meanings','no_qc_performed good_data probably_good_data bad_data_that_are_potentially_correctable bad_data value_changed not_used not_used interpolated_values missing_values');
                
                %sal
                netcdf.putAtt(ncid,PSAL_quality_control_id,'standard_name','sea_water_salinity status_flag');
                netcdf.putAtt(ncid,PSAL_quality_control_id,'long_name','Quality Control flag for salinity');
                netcdf.putAtt(ncid,PSAL_quality_control_id,'quality_control_conventions','IMOS standard set using IODE flags');
                netcdf.putAtt(ncid,PSAL_quality_control_id,'quality_control_set',1);
                netcdf.putAtt(ncid,PSAL_quality_control_id,'_FillValue',FILLVALUE_TEMP_SAL);
                netcdf.putAtt(ncid,PSAL_quality_control_id,'valid_min',0);
                netcdf.putAtt(ncid,PSAL_quality_control_id,'valid_max',9);
                netcdf.putAtt(ncid,PSAL_quality_control_id,'flag_values',flagvalues);
                netcdf.putAtt(ncid,PSAL_quality_control_id,'flag_meanings','no_qc_performed good_data probably_good_data bad_data_that_are_potentially_correctable bad_data value_changed not_used not_used interpolated_values missing_values');
                netcdf.endDef(ncid)
                
                TimeForNetCDF = (TIME -datenum('1950-01-01','yyyy-mm-dd')); %num of day
                
                netcdf.putVar(ncid,TIME_id,TimeForNetCDF);
                netcdf.putVar(ncid,LATITUDE_id,LAT);
                netcdf.putVar(ncid,LONGITUDE_id,LON);
                
                TEMP_VALS_profile(isnan(TEMP_VALS_profile)) =FILLVALUE_TEMP_SAL;
                netcdf.putVar(ncid,TEMP_id,TEMP_VALS_profile );
                
                SAL_VALS_profile(isnan(SAL_VALS_profile))   =FILLVALUE_TEMP_SAL;
                netcdf.putVar(ncid,PSAL_id,SAL_VALS_profile);
                
                netcdf.putVar(ncid,PRES_id,DBAR_profile);
                
                netcdf.putVar(ncid,TIME_quality_control_id,0);
                netcdf.putVar(ncid,LATITUDE_quality_control_id,0);
                netcdf.putVar(ncid,LONGITUDE_quality_control_id,0);
                
                
                blankmatrix                                 = zeros(N_DEPTH,1);
                netcdf.putVar(ncid,TEMP_quality_control_id,blankmatrix(:,1));
                
                netcdf.putVar(ncid,PSAL_quality_control_id,blankmatrix(:,1));
                netcdf.putVar(ncid,PRES_quality_control_id,blankmatrix(:,1));          
               
                netcdf.close(ncid);
            else
                delete(ncFilename)
            end

            
            if isempty(WMO_NUMBER)
                tagNameWithNoWMO{count}=tagName;
                count=count+1;
            end

        end
    end
    
end

if exist('tagNameWithNoWMO','var')
    tagNameWithNoWMO=unique(tagNameWithNoWMO);
    for iiWrong=1:length(tagNameWithNoWMO)
        fprintf('%s - WARNING: No WMO  code for tag %s',datestr(now),char(tagNameWithNoWMO{iiWrong}))
    end
end

fprintf('%s - Remove bad profiles with bad Latitude/Longitude,North hemisphere ...\n',datestr(now))
cleanNetCDF(missionPath)

fprintf('%s - Aggregate NetCDF profile\n',datestr(now))
aggregateAATAMS(missionPath)


% if the mission folder (where nc files are processed) already exists, we
% delete it 
if exist(missionFolderPath,'dir') == 7
    rmdir(missionFolderPath,'s');
else
    mkpath(missionFolderPath)
end

% because of tmp and allMissionFolderPath on different devide.inter-device move
copyfile(missionFolderPathTemporary,missionFolderPath)
rmdir(missionFolderPathTemporary,'s');

rmdir(tempDir,'s');

end
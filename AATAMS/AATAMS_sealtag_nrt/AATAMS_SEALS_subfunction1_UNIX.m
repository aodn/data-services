function [] = AATAMS_SEALS_subfunction1_UNIX(fileinput2)
%
%Initialisation of all the input and output files or directories
%
%Information about the Australian TAGS
fileinput1 = '/usr/local/emii/data/matlab/AATAMS/australiantags.txt';
%DAILY FILE with RAW DATA
%fileinput2 = 'SMRU_GTS_20100531_2341.dat';
%OUTPUT DIRECTORY ON LOCAL MACHINE
outputdir = '/usr/local/emii/data/matlab/AATAMS/processed_data';
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%Read the file which contains all the Australian tags.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
fid = fopen(fileinput1,'r');
line=fgetl(fid);
AUStags{1} = line ;
i=2;
while line~=-1,
  line=fgetl(fid);
  AUStags{i} = line ;
  i=i+1;
end
nbAUStags = length(AUStags)-1;
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%Read the daily file containing all the profile of each seal around the
%world.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%Import all the data
temp = importdata(fileinput2);
%
dimfile = length(temp.data);
%Number of profiles
j=1;
checkprofile(j,1) = 1;
for i = 2:dimfile
    if (datenum(temp.textdata(i,2)) ~= datenum(temp.textdata(i-1,2)))
        checkprofile(j,2) = i-1;
        j=j+1;
        checkprofile(j,1) = i;
    end
end
checkprofile(j,2) = dimfile;
%
nbprofiles = length(checkprofile(:,1));
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%Processing of each profile
%
for zz = 1:nbprofiles
%
startobs = checkprofile(zz,1);
finalobs = checkprofile(zz,2);
dimobs = finalobs - startobs +1;
%
final(:,1) = temp.data(startobs:finalobs,1);
final(:,2) = temp.data(startobs:finalobs,2);
final(:,3) = temp.data(startobs:finalobs,3);
final(:,4) = temp.data(startobs:finalobs,4);
final(:,5) = temp.data(startobs:finalobs,5);
%
timeprofile = datenum(temp.textdata(startobs,2));
timestart = [1950, 1, 1, 0, 0, 0];
timenc(1) = (etime(datevec(timeprofile(1)),timestart))/(60*60*24);
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%VERIFiCATION IF THE TAGS IS AN AUSTRALIAN TAGS
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    verifaussietags = 0;
    for ll=1:nbAUStags
         if (temp.textdata{startobs} == AUStags{ll})
            verifaussietags = verifaussietags + 1;
         end
    end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%IF IT IS AN AUSTRALIAN TAGS THEN WE OUTPUT A NETCDF FILE AND A CSV FILE
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
if (verifaussietags)
% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% %NETCDF OUTPUT
% %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
     fileoutput = strcat('IMOS_AATAMS-SATTAG_TSP_',datestr(timeprofile,'yyyymmddTHHMMSSZ'),'_',temp.textdata{startobs},'_FV00.nc');
% %
    nc = netcdf.create(fileoutput,'NC_CLOBBER');
% %
% %Creation of the GLOBAL ATTRIBUTES
% %
% %WHAT
      netcdf.putatt(nc,netcdf.getConstant('GLOBAL'),'project','Integrated Marine Observing System (IMOS)');
      netcdf.putatt(nc,netcdf.getConstant('GLOBAL'),'conventions','IMOS-1.2');
      netcdf.putatt(nc,netcdf.getConstant('GLOBAL'),'date_created',datestr(datenum(clock)-10/24,'yyyy-mm-ddTHH:MM:SSZ'));
      netcdf.putatt(nc,netcdf.getConstant('GLOBAL'),'title','Temperature, Salinity and Depth profiles in near real time');
      netcdf.putatt(nc,netcdf.getConstant('GLOBAL'),'institution','AATAMS');
      netcdf.putatt(nc,netcdf.getConstant('GLOBAL'),'site','CTD Satellite Relay Data Logger');
      netcdfabstract = ['CTD Satellite Relay Data Loggers are used to explore how'...
     ' marine mammal behaviour relates to their oceanic environment. Loggers'...
     ' developped at the University of St Andrews Sea Mammal Research Unit'...
     ' transmit data in near real time via the Argo satellite system'];
      netcdf.putatt(nc,netcdf.getConstant('GLOBAL'),'abstract',netcdfabstract);
      netcdf.putatt(nc,netcdf.getConstant('GLOBAL'),'source','SMRU CTD Satellite relay Data Logger on marine mammals');
      aatamskeywords = ['Oceans>Ocean Temperature>Water Temperature ;'...
                'Oceans>Salinity/Density>Conductivity ;'...
                'Oceans>Marine Biology>Marine Mammals'];
      netcdf.putatt(nc,netcdf.getConstant('GLOBAL'),'keywords',aatamskeywords);    
      netcdf.putatt(nc,netcdf.getConstant('GLOBAL'),'references','http://imos.org.au/aatams.html'); 
      netcdf.putatt(nc,netcdf.getConstant('GLOBAL'),'platform_code',temp.textdata{startobs});
      netcdf.putatt(nc,netcdf.getConstant('GLOBAL'),'netcdf_version','3.6');
      netcdf.putatt(nc,netcdf.getConstant('GLOBAL'),'naming_authority','IMOS');
      netcdf.putatt(nc,netcdf.getConstant('GLOBAL'),'quality_control_set','1');
      netcdf.putatt(nc,netcdf.getConstant('GLOBAL'),'cdm_data_type','Trajectory');
% %WHERE
      netcdf.putatt(nc,netcdf.getConstant('GLOBAL'),'geospatial_lat_min',final(1,4));
      netcdf.putatt(nc,netcdf.getConstant('GLOBAL'),'geospatial_lat_max',final(1,4));
      netcdf.putatt(nc,netcdf.getConstant('GLOBAL'),'geospatial_lat_units','degrees_north');
      netcdf.putatt(nc,netcdf.getConstant('GLOBAL'),'geospatial_lat_min',final(1,5));
      netcdf.putatt(nc,netcdf.getConstant('GLOBAL'),'geospatial_lat_max',final(1,5));
      netcdf.putatt(nc,netcdf.getConstant('GLOBAL'),'geospatial_lat_units','degrees_east');
      netcdf.putatt(nc,netcdf.getConstant('GLOBAL'),'geospatial_vertical_min',min(final(1,1)));
      netcdf.putatt(nc,netcdf.getConstant('GLOBAL'),'geospatial_vertical_max',max(final(1,5)));
      netcdf.putatt(nc,netcdf.getConstant('GLOBAL'),'geospatial_vertical_units','dbar');
% %WHEN
      netcdf.putatt(nc,netcdf.getConstant('GLOBAL'),'time_coverage_start',datestr(timeprofile,'yyyy-mm-ddTHH:MM:SSZ'));
      netcdf.putatt(nc,netcdf.getConstant('GLOBAL'),'time_coverage_end',datestr(timeprofile,'yyyy-mm-ddTHH:MM:SSZ'));
% %WHO
      netcdf.putatt(nc,netcdf.getConstant('GLOBAL'),'data_centre_email','info@emii.org.au');
      netcdf.putatt(nc,netcdf.getConstant('GLOBAL'),'data_centre','eMarine Information Infrastructure (eMII)');
      netcdf.putatt(nc,netcdf.getConstant('GLOBAL'),'author','Mancini, Sebastien');
      netcdf.putatt(nc,netcdf.getConstant('GLOBAL'),'author_email','info@emii.org.au');
      netcdf.putatt(nc,netcdf.getConstant('GLOBAL'),'institution_references','http://imos.org.au/emii.html');
      netcdf.putatt(nc,netcdf.getConstant('GLOBAL'),'principal_investigator','Harcourt, Rob');
% %HOW
     aatamscitation = ['Citation to be used in publications should follow the format:'...
     ' IMOS, [year-of-data-download], [Title], [data-access-URL],accessed [date-of-access]'];
     netcdf.putatt(nc,netcdf.getConstant('GLOBAL'),'citation',aatamscitation);
     aatamsacknowledgment = ['Any users of IMOS data are required to clearly acknowledge'...
     ' the source of the material in the format: "Data was sourced from the Integrated Marine'...
     ' Observing System (IMOS) - IMOS is supported by the Australian Government through the'...
     ' National Collaborative Research Infrastructure Strategy (NCRIS) and'...
     ' the Super Science Initiative (SSI)"'];
     netcdf.putatt(nc,netcdf.getConstant('GLOBAL'),'acknowledgment',aatamsacknowledgment);
     aatamsdistribution = ['AATAMS data may be re-used, provided that related '...
     ' metadata explaining the data has been reviewed by the user and the data is'...
     ' appropriately acknowledged. Data, products and services'...
     ' from IMOS are provided "as is" without any warranty as to fitness'...
     ' for a particular purpose'];  
     netcdf.putatt(nc,netcdf.getConstant('GLOBAL'),'distribution_statement',aatamsdistribution);
     netcdf.putatt(nc,netcdf.getConstant('GLOBAL'),'file_version','Level 0 - Raw data');
     netcdf.putatt(nc,netcdf.getConstant('GLOBAL'),'file_version_quality_control','Data in this file has not undergone quality control. There has been no QC performed on this real-time data.');
     netcdf.putatt(nc,netcdf.getConstant('GLOBAL'),'metadata','http://imosmest.aodn.org.au/geonetwork/srv/en/metadata.show?uuid=4637bd9b-8fba-4a10-bf23-26a511e17042');
% %
% %Creation of the DIMENSION
% %
      obs_dimid = netcdf.defdim(nc,'obs',dimobs);
      profiles_dimid = netcdf.defdim(nc,'profiles',1);
      length_char_dimid = netcdf.defdim(nc,'length_char',8);
% %
% %Creation of the VARIABLES
% %
      TIME_id = netcdf.defVar(nc,'TIME','double',profiles_dimid);
      LATITUDE_id = netcdf.defVar(nc,'LATITUDE','double',profiles_dimid);
      LONGITUDE_id = netcdf.defVar(nc,'LONGITUDE','double',profiles_dimid);
      TEMP_id = netcdf.defVar(nc,'TEMP','double',obs_dimid);
      PRES_id = netcdf.defVar(nc,'PRES','double',obs_dimid);
      PSAL_id = netcdf.defVar(nc,'PSAL','double',obs_dimid);
      WMO_ID_id = netcdf.defVar(nc,'WMO_ID','char',[length_char_dimid,profiles_dimid]);
% %
      TIME_quality_control_id = netcdf.defVar(nc,'TIME_quality_control','double',profiles_dimid);
      LATITUDE_quality_control_id = netcdf.defVar(nc,'LATITUDE_quality_control','double',profiles_dimid);
      LONGITUDE_quality_control_id = netcdf.defVar(nc,'LONGITUDE_quality_control','double',profiles_dimid);
      TEMP_quality_control_id = netcdf.defVar(nc,'TEMP_quality_control','double',obs_dimid);
      PRES_quality_control_id = netcdf.defVar(nc,'PRES_quality_control','double',obs_dimid);
      PSAL_quality_control_id = netcdf.defVar(nc,'PSAL_quality_control','double',obs_dimid);
% %
% %Definition of the VARIABLE ATTRIBUTES
% %
% %Time
      netcdf.putatt(nc,TIME_id,'standard_name','time');
      netcdf.putatt(nc,TIME_id,'long_name','analysis_time');
      netcdf.putatt(nc,TIME_id,'units','days since 1950-01-01 00:00:00');
      netcdf.putatt(nc,TIME_id,'axis','T');
      netcdf.putatt(nc,TIME_id,'valid_min',0);
      netcdf.putatt(nc,TIME_id,'valid_max',999999);
      netcdf.putatt(nc,TIME_id,'_FillValue',-9999);
      netcdf.putatt(nc,TIME_id,'ancillary_variables','TIME_quality_control');
% %
      netcdf.putatt(nc,LATITUDE_id,'standard_name','latitude');
      netcdf.putatt(nc,LATITUDE_id,'long_name','latitude');
      netcdf.putatt(nc,LATITUDE_id,'units','degrees_north');
      netcdf.putatt(nc,LATITUDE_id,'axis','Y');
      netcdf.putatt(nc,LATITUDE_id,'valid_min',-90);
      netcdf.putatt(nc,LATITUDE_id,'valid_max',90);
      netcdf.putatt(nc,LATITUDE_id,'_FillValue',999.9);
      netcdf.putatt(nc,LATITUDE_id,'ancillary_variables','LATITUDE_quality_control');
      netcdf.putatt(nc,LATITUDE_id,'reference_datum','geographical coordinates, WGS84 projection');
% %
      netcdf.putatt(nc,LONGITUDE_id,'standard_name','longitude');
      netcdf.putatt(nc,LONGITUDE_id,'long_name','longitude');
      netcdf.putatt(nc,LONGITUDE_id,'units','degrees_east');
      netcdf.putatt(nc,LONGITUDE_id,'axis','X');
      netcdf.putatt(nc,LONGITUDE_id,'valid_min',-180);
      netcdf.putatt(nc,LONGITUDE_id,'valid_max',180);
      netcdf.putatt(nc,LONGITUDE_id,'_FillValue',999.9);
      netcdf.putatt(nc,LONGITUDE_id,'ancillary_variables','LONGITUDE_quality_control');
      netcdf.putatt(nc,LONGITUDE_id,'reference_datum','geographical coordinates, WGS84 projection');
% %
      netcdf.putatt(nc,TEMP_id,'standard_name','sea_water_temperature');
      netcdf.putatt(nc,TEMP_id,'long_name','sea_water_temperature');
      netcdf.putatt(nc,TEMP_id,'units','Celsius');
      netcdf.putatt(nc,TEMP_id,'valid_min',-2);
      netcdf.putatt(nc,TEMP_id,'valid_max',40);
      netcdf.putatt(nc,TEMP_id,'_FillValue',9999);
      netcdf.putatt(nc,TEMP_id,'ancillary_variables','TEMP_quality_control');
% %
      netcdf.putatt(nc,PSAL_id,'standard_name','sea_water_salinity');
      netcdf.putatt(nc,PSAL_id,'long_name','sea_water_salinity');
      netcdf.putatt(nc,PSAL_id,'units','1e-3');
      netcdf.putatt(nc,PSAL_id,'_FillValue',9999);
      netcdf.putatt(nc,PSAL_id,'ancillary_variables','PSAL_quality_control');
% %
      netcdf.putatt(nc,PRES_id,'standard_name','sea_water_pressure');
      netcdf.putatt(nc,PRES_id,'long_name','sea_water_pressure');
      netcdf.putatt(nc,PRES_id,'units','dbar');
      netcdf.putatt(nc,PRES_id,'_FillValue',9999);
      netcdf.putatt(nc,PRES_id,'ancillary_variables','PRES_quality_control');
% %
      netcdf.putatt(nc,WMO_ID_id,'long_name','WMO device number');
% %
% %QC variables
% %
     flagvalues = [0 1 2 3 4 5 6 7 8 9];
% %
      netcdf.putatt(nc,TIME_quality_control_id,'standard_name','time status_flag');
      netcdf.putatt(nc,TIME_quality_control_id,'long_name','Quality Control flag for time');
      netcdf.putatt(nc,TIME_quality_control_id,'quality_control_conventions','IMOS standard set using IODE flags');
      netcdf.putatt(nc,TIME_quality_control_id,'quality_control_set',1);
      netcdf.putatt(nc,TIME_quality_control_id,'_FillValue',9999);
      netcdf.putatt(nc,TIME_quality_control_id,'valid_min',0);
      netcdf.putatt(nc,TIME_quality_control_id,'valid_max',9);
      netcdf.putatt(nc,TIME_quality_control_id,'flag_values',flagvalues);
      netcdf.putatt(nc,TIME_quality_control_id,'flag_meanings','no_qc_performed good_data probably_good_data bad_data_that_are_potentially_correctable bad_data value_changed not_used not_used interpolated_values missing_values');
%
      netcdf.putatt(nc,LATITUDE_quality_control_id,'standard_name','latitude status_flag');
      netcdf.putatt(nc,LATITUDE_quality_control_id,'long_name','Quality Control flag for latitude');
      netcdf.putatt(nc,LATITUDE_quality_control_id,'quality_control_conventions','IMOS standard set using IODE flags');
      netcdf.putatt(nc,LATITUDE_quality_control_id,'quality_control_set',1);
      netcdf.putatt(nc,LATITUDE_quality_control_id,'_FillValue',9999);
      netcdf.putatt(nc,LATITUDE_quality_control_id,'valid_min',0);
      netcdf.putatt(nc,LATITUDE_quality_control_id,'valid_max',9);
      netcdf.putatt(nc,LATITUDE_quality_control_id,'flag_values',flagvalues);
      netcdf.putatt(nc,LATITUDE_quality_control_id,'flag_meanings','no_qc_performed good_data probably_good_data bad_data_that_are_potentially_correctable bad_data value_changed not_used not_used interpolated_values missing_values');
% %
% %
      netcdf.putatt(nc,LONGITUDE_quality_control_id,'standard_name','longitude status_flag');
      netcdf.putatt(nc,LONGITUDE_quality_control_id,'long_name','Quality Control flag for longitude');
      netcdf.putatt(nc,LONGITUDE_quality_control_id,'quality_control_conventions','IMOS standard set using IODE flags');
      netcdf.putatt(nc,LONGITUDE_quality_control_id,'quality_control_set',1);
      netcdf.putatt(nc,LONGITUDE_quality_control_id,'_FillValue',9999);
      netcdf.putatt(nc,LONGITUDE_quality_control_id,'valid_min',0);
      netcdf.putatt(nc,LONGITUDE_quality_control_id,'valid_max',9);
      netcdf.putatt(nc,LONGITUDE_quality_control_id,'flag_values',flagvalues);
      netcdf.putatt(nc,LONGITUDE_quality_control_id,'flag_meanings','no_qc_performed good_data probably_good_data bad_data_that_are_potentially_correctable bad_data value_changed not_used not_used interpolated_values missing_values');
% %
% %
      netcdf.putatt(nc,TEMP_quality_control_id,'standard_name','sea_surface_temperature status_flag');
      netcdf.putatt(nc,TEMP_quality_control_id,'long_name','Quality Control flag for temperature');
      netcdf.putatt(nc,TEMP_quality_control_id,'quality_control_conventions','IMOS standard set using IODE flags');
      netcdf.putatt(nc,TEMP_quality_control_id,'quality_control_set',1);
      netcdf.putatt(nc,TEMP_quality_control_id,'_FillValue',9999);
      netcdf.putatt(nc,TEMP_quality_control_id,'valid_min',0);
      netcdf.putatt(nc,TEMP_quality_control_id,'valid_max',9);
      netcdf.putatt(nc,TEMP_quality_control_id,'flag_values',flagvalues);
      netcdf.putatt(nc,TEMP_quality_control_id,'flag_meanings','no_qc_performed good_data probably_good_data bad_data_that_are_potentially_correctable bad_data value_changed not_used not_used interpolated_values missing_values');
% %
      netcdf.putatt(nc,PRES_quality_control_id,'standard_name','sea_water_pressure status_flag');
      netcdf.putatt(nc,PRES_quality_control_id,'long_name','Quality Control flag for pressure');
      netcdf.putatt(nc,PRES_quality_control_id,'quality_control_conventions','IMOS standard set using IODE flags');
      netcdf.putatt(nc,PRES_quality_control_id,'quality_control_set',1);
      netcdf.putatt(nc,PRES_quality_control_id,'_FillValue',9999);
      netcdf.putatt(nc,PRES_quality_control_id,'valid_min',0);
      netcdf.putatt(nc,PRES_quality_control_id,'valid_max',9);
      netcdf.putatt(nc,PRES_quality_control_id,'flag_values',flagvalues);
      netcdf.putatt(nc,PRES_quality_control_id,'flag_meanings','no_qc_performed good_data probably_good_data bad_data_that_are_potentially_correctable bad_data value_changed not_used not_used interpolated_values missing_values');
% %
% %
      netcdf.putatt(nc,PSAL_quality_control_id,'standard_name','sea_water_salinity status_flag');
      netcdf.putatt(nc,PSAL_quality_control_id,'long_name','Quality Control flag for salinity');
      netcdf.putatt(nc,PSAL_quality_control_id,'quality_control_conventions','IMOS standard set using IODE flags');
      netcdf.putatt(nc,PSAL_quality_control_id,'quality_control_set',1);
      netcdf.putatt(nc,PSAL_quality_control_id,'_FillValue',9999);
      netcdf.putatt(nc,PSAL_quality_control_id,'valid_min',0);
      netcdf.putatt(nc,PSAL_quality_control_id,'valid_max',9);
      netcdf.putatt(nc,PSAL_quality_control_id,'flag_values',flagvalues);
      netcdf.putatt(nc,PSAL_quality_control_id,'flag_meanings','no_qc_performed good_data probably_good_data bad_data_that_are_potentially_correctable bad_data value_changed not_used not_used interpolated_values missing_values');
% %
% %
      netcdf.endDef(nc)
%
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
% %
     k = length(temp.textdata{startobs});
     netcdf.putVar(nc,WMO_ID_id,[0,0],[8,1],temp.textdata{startobs});

% %
% %Close the current NetCDF file
%     nc=close(nc);
      netcdf.close(nc);
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%CSV OUTPUT FILE
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    fileoutputcsv = strcat('IMOS_AATAMS-SATTAG_TSP_',datestr(timeprofile,'yyyymmddTHHMMSSZ'),'_',temp.textdata{startobs},'_FV00.csv');
%
    fid_w = fopen(fileoutputcsv, 'w');
%
    fprintf(fid_w, 'Project:,Integrated Marine Observing System (IMOS)\r');
    fprintf(fid_w, 'Source:,SMRU CTD Satellite Relay Data Logger on marine mammals\r');
    fprintf(fid_w, 'Latitude:,%f\r',final(1,4));
    fprintf(fid_w, 'Longitude:,%f\r',final(1,5));
    fprintf(fid_w, 'Date/Time:,%s\r',temp.textdata{startobs,2});
    fprintf(fid_w, 'File creation:,%s\r',datestr(clock,'dd//mm/yyyy HH:MM:SS'));
    fprintf(fid_w, 'Platform Code:,%s\r',temp.textdata{startobs});
    fprintf(fid_w, 'Comment:,For more information on how to acknowlege distribute and cite this dataset please refer to the IMOS website http://imos.org.au or access the eMII Metadata catalogue http://imosmest.aodn.org.au and search for IMOS metadata record\r');
    fprintf(fid_w, 'Metadata:, http://imosmest.emii.org.au/geonetwork/srv/en/metadata.show?uuid=4637bd9b-8fba-4a10-bf23-26a511e17042\r');
    fprintf(fid_w, 'file_version:,Level 0 - Raw Data\r');
    fprintf(fid_w, 'file_version_quality_control:,Data in this file has not undergone quality control. There has been no QC performed on this real-time data.\r');
    fprintf(fid_w, 'Pressure units:, dbar\r');
    fprintf(fid_w, 'Temperature units:, degrees Celsius\r');
    fprintf(fid_w, 'Salinity units:, 1e-3\r');
    fprintf(fid_w, 'Pressure,Temperature,Salinity\r');
%
    for gg=1:dimobs
        fprintf(fid_w, '%f,%f,%f\r',final(gg,1),final(gg,2),final(gg,3));
    end
    fclose(fid_w)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%Move the netcdf file to a different directory
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
filedir = dir(strcat(outputdir,'/CSV'));
    testverif =0;
    if (length(filedir) > 2)
        for hh = 3:length(filedir)
            if ( temp.textdata{startobs} == filedir(hh).name)
                testverif = testverif +1;
            end
        end
    end
%
    if testverif
        filedirectioncsv = strcat(outputdir,'/CSV/',temp.textdata{startobs},'/profiles');
        filedirectionnetcdf = strcat(outputdir,'/NETCDF/',temp.textdata{startobs},'/profiles');
        [status,message,messageid]=movefile(fileoutput,filedirectionnetcdf);   
        [status,message,messageid]=movefile(fileoutputcsv,filedirectioncsv); 
    else
        filedirectionnetcdf = strcat(outputdir,'/NETCDF/',temp.textdata{startobs},'/profiles');
        filedirectioncsv = strcat(outputdir,'/CSV/',temp.textdata{startobs},'/profiles');
        mkdir(filedirectionnetcdf);
        mkdir(filedirectioncsv);
        [status,message,messageid]=movefile(fileoutput,filedirectionnetcdf);
        [status,message,messageid]=movefile(fileoutputcsv,filedirectioncsv); 
    end
%
end
%
clear final
%
end

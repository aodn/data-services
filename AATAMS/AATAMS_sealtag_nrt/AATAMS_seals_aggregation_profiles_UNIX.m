%
dirprocessed = '/usr/local/emii/data/matlab/AATAMS/processed_data/NETCDF/';
listfolder = dir(strcat(dirprocessed,'Q*'));
%
nbprocessedfolder = length(listfolder);
%
for i =1:nbprocessedfolder
%for i =1:1    
    listfiles = dir(strcat(dirprocessed,listfolder(i).name,'/profiles/','*.nc'));
    nbfiles = length(listfiles);
%    
    for j =1:nbfiles
%    for j =1:2   
        timestamp(1,j) = datenum(listfiles(j).name(24:38),'yyyymmddTHHMMSS');
    end
%Read all the NetCDF files for one seal
%
    t_fin = 0;
    time1 = 0;
    for j = 1:nbfiles
%     for j =1:2  
        nc = netcdf.open(strcat(dirprocessed,listfolder(i).name,'/profiles/',listfiles(j).name),'NC_NOWRITE');
        temp_varid = netcdf.inqVarID(nc,'TIME');
        temp = netcdf.getVar(nc,temp_varid);
        time1 = temp(:);
%
%Variable LATITUDE and LONGITUDE
        temp_varid= netcdf.inqvarID(nc,'LATITUDE');
        temp= netcdf.getVar(nc,temp_varid);
        lat1=temp(:);
%
        temp_varid= netcdf.inqvarID(nc,'LONGITUDE');
        temp= netcdf.getVar(nc,temp_varid);
        lon1=temp(:);
%
%Variable TEMPERATURE, Pressure and SALINITY
        temp_varid= netcdf.inqvarID(nc,'TEMP');
        temp= netcdf.getVar(nc,temp_varid);
        TEMPE1=temp(:);    
        temp_varid= netcdf.inqvarID(nc,'PSAL');
        temp= netcdf.getVar(nc,temp_varid);
        PSAL1=temp(:);
        temp_varid= netcdf.inqvarID(nc,'PRES');
        temp= netcdf.getVar(nc,temp_varid);
        PRES1=temp(:);
%Variable WMO_ID
        temp_varid= netcdf.inqvarID(nc,'WMO_ID');
        temp= netcdf.getVar(nc,temp_varid);
        SEAL_ID1=temp(:);        
%Close the NetCDF file
    netcdf.close(nc) 
%
        dimfile = length(TEMPE1);
        t_deb = t_fin+1;
        t_fin = t_deb+dimfile-1;
        time(j) = time1;
        lat(j) = lat1;
        lon(j) = lon1;
        SEAL_ID(j,:) = SEAL_ID1;
        TEMPE(t_deb:t_fin)= TEMPE1;
        PSAL(t_deb:t_fin)= PSAL1;
        PRES(t_deb:t_fin)= PRES1;
        indexprofile(t_deb:t_fin) = j;
%Clear the temporary variable
        clear TEMPE1 lat1 lon1
        clear time1 PSAL1 PRES1  SEAL_ID1      
    end
%
dimobs = length(TEMPE);
dimprofile = nbfiles;
%Creation of teh aggregated NETCDF FILE
    fileoutput = strcat('IMOS_AATAMS-SATTAG_TSP_',datestr(min(timestamp),'yyyymmddTHHMMSSZ'),'_',SEAL_ID(1,:),'_END-',datestr(max(timestamp),'yyyymmddTHHMMSSZ'),'_FV00.nc');
%
    nc = netcdf.create(fileoutput,'NC_CLOBBER');
%
%Creation of the GLOBAL ATTRIBUTES
%
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
      netcdf.putatt(nc,netcdf.getConstant('GLOBAL'),'platform_code',SEAL_ID(1,:));
      netcdf.putatt(nc,netcdf.getConstant('GLOBAL'),'netcdf_version','3.6');
      netcdf.putatt(nc,netcdf.getConstant('GLOBAL'),'naming_authority','IMOS');
      netcdf.putatt(nc,netcdf.getConstant('GLOBAL'),'quality_control_set','1');
      netcdf.putatt(nc,netcdf.getConstant('GLOBAL'),'cdm_data_type','Trajectory');
%WHERE
      netcdf.putatt(nc,netcdf.getConstant('GLOBAL'),'geospatial_lat_min',min(lat));
      netcdf.putatt(nc,netcdf.getConstant('GLOBAL'),'geospatial_lat_max',max(lat));
      netcdf.putatt(nc,netcdf.getConstant('GLOBAL'),'geospatial_lat_units','degrees_north');
      netcdf.putatt(nc,netcdf.getConstant('GLOBAL'),'geospatial_lat_min',min(lon));
      netcdf.putatt(nc,netcdf.getConstant('GLOBAL'),'geospatial_lat_max',max(lon));
      netcdf.putatt(nc,netcdf.getConstant('GLOBAL'),'geospatial_lat_units','degrees_east');
      netcdf.putatt(nc,netcdf.getConstant('GLOBAL'),'geospatial_vertical_min',min(PRES));
      netcdf.putatt(nc,netcdf.getConstant('GLOBAL'),'geospatial_vertical_max',max(PRES));
      netcdf.putatt(nc,netcdf.getConstant('GLOBAL'),'geospatial_vertical_units','dbar');
%WHEN
      netcdf.putatt(nc,netcdf.getConstant('GLOBAL'),'time_coverage_start',datestr(min(timestamp),'yyyy-mm-ddTHH:MM:SSZ'));
      netcdf.putatt(nc,netcdf.getConstant('GLOBAL'),'time_coverage_end',datestr(max(timestamp),'yyyy-mm-ddTHH:MM:SSZ'));
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
%Creation of the DIMENSION
%
      obs_dimid = netcdf.defdim(nc,'obs',dimobs);
      profiles_dimid = netcdf.defdim(nc,'profiles',dimprofile);
      length_char_dimid = netcdf.defdim(nc,'length_char',8);
%
% %Creation of the VARIABLES
% %
      TIME_id = netcdf.defVar(nc,'TIME','double',profiles_dimid);
      LATITUDE_id = netcdf.defVar(nc,'LATITUDE','double',profiles_dimid);
      LONGITUDE_id = netcdf.defVar(nc,'LONGITUDE','double',profiles_dimid);
      TEMP_id = netcdf.defVar(nc,'TEMP','double',obs_dimid);
      PRES_id = netcdf.defVar(nc,'PRES','double',obs_dimid);
      PSAL_id = netcdf.defVar(nc,'PSAL','double',obs_dimid);
      parentIndex_id = netcdf.defVar(nc,'parentIndex','double',obs_dimid);
      WMO_ID_id = netcdf.defVar(nc,'WMO_ID','char',[length_char_dimid,profiles_dimid]);
% %
      TIME_quality_control_id = netcdf.defVar(nc,'TIME_quality_control','double',profiles_dimid);
      LATITUDE_quality_control_id = netcdf.defVar(nc,'LATITUDE_quality_control','double',profiles_dimid);
      LONGITUDE_quality_control_id = netcdf.defVar(nc,'LONGITUDE_quality_control','double',profiles_dimid);
      TEMP_quality_control_id = netcdf.defVar(nc,'TEMP_quality_control','double',obs_dimid);
      PRES_quality_control_id = netcdf.defVar(nc,'PRES_quality_control','double',obs_dimid);
      PSAL_quality_control_id = netcdf.defVar(nc,'PSAL_quality_control','double',obs_dimid);
%
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
%
      netcdf.putatt(nc,parentIndex_id,'long_name','index of profile');
      netcdf.putatt(nc,parentIndex_id,'ragged_row_index','profile');
      netcdf.putatt(nc,parentIndex_id,'comment','the pressure(i), temperature(i) and salinity(i) is associated with the coordiante values time(p), lat(p), lon(p) where p=parentIndex(i).');
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
    for tt = 1:dimprofile
      netcdf.putVar(nc,WMO_ID_id,[0,tt-1],[8,1],SEAL_ID(1,:));
    end
%
%Close the current NetCDF file
    netcdf.close(nc);
%    
    filedirectionnetcdf = strcat('/usr/local/emii/data/matlab/AATAMS/processed_data/NETCDF/',SEAL_ID(1,:),'/');
    filetodelete = dir(strcat(filedirectionnetcdf,'*.nc'));
    delete (strcat(filedirectionnetcdf,filetodelete(1).name))
    [status,message,messageid]=movefile(fileoutput,filedirectionnetcdf);
%
    clear timestamp
    clear TEMPE lat lon indexprofile
    clear time PSAL PRES  SEAL_ID
%
end
quit

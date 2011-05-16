function [dateforfileSQL] = radar_CODAR_non_QC_to_ncWMS_subfunction2_UNIX_v1(filename,site_code,zz)
%
global dfradialdata
%reminder: dfradialdata ='/home/matlab_3/datafabric_root/opendap/ACORN/sea-state/';
%see matlab script 'radar_CODAR_non_QC_to_ncWMS_main_UNIX_v1.m' for any changes
global inputdir
%reminder: inputdir = '/var/lib/matlab_3/ACORN/CODAR/nonQC_gridded/';
%see matlab script 'radar_CODAR_non_QC_to_ncWMS_main_UNIX_v1.m' for any changes
global outputdir
%reminder: outputdir = '/var/lib/matlab_3/ACORN/CODAR/nonQC_gridded/output/';
%see matlab script 'radar_CODAR_non_QC_to_ncWMS_main_UNIX_v1.m' for any changes
%
dateforfileSQL = filename(14:28);
yearDF = dateforfileSQL(1:4);
monthDF = dateforfileSQL(5:6);
dayDF = dateforfileSQL(7:8);
%
%ACCESSING THE DATA
ncid = netcdf.open(strcat(dfradialdata,site_code,'/',filename(14:17),'/',filename(18:19),'/',filename(20:21),'/',filename(1:end-3),'.nc'),'NC_NOWRITE');
temp_varid = netcdf.inqVarID(ncid,'POSITION');
temp = netcdf.getVar(ncid,temp_varid);
POS = temp(:);
dimfile = length(POS);
temp_varid = netcdf.inqVarID(ncid,'ssr_Surface_Eastward_Sea_Water_Velocity');
temp = netcdf.getVar(ncid,temp_varid);
EAST = temp(:);
temp_varid = netcdf.inqVarID(ncid,'ssr_Surface_Northward_Sea_Water_Velocity');
temp = netcdf.getVar(ncid,temp_varid);
NORTH = temp(:);
%
%
%OPEN THE TEXT FILE CONTAINING THE GRID
filetoread = strcat(inputdir,'TURQ_grid_for_ncWMS.dat');
rawdata = importdata(filetoread);
%
comptlat = 55;
comptlon = 57;
k=1;
for j=1:comptlat;
    for i=1:comptlon
        X(j,i) = rawdata(k,1);
        Y(j,i) = rawdata(k,2);
        k=k+1;
    end
end
%
%
Zrad = NaN(comptlat,comptlon);
Urad = NaN(comptlat,comptlon);
Vrad = NaN(comptlat,comptlon);
%
for i = 1:dimfile
    index = POS(i);
    indexj = floor((index-1)/comptlon)+1;
    if (~mod(index,comptlon))
        indexi = comptlon;
    else
        indexi = mod(index,comptlon);
    end
    Urad(indexj,indexi)   = EAST(i);
    Vrad(indexj,indexi)   = NORTH(i);
    Zrad(indexj,indexi)   = sqrt(Urad(indexj,indexi)*Urad(indexj,indexi)+Vrad(indexj,indexi)*Vrad(indexj,indexi));
end
%
%NetCDF file creation
%
%
Urad(isnan(Urad))   = 9999;
Vrad(isnan(Vrad))   = 9999;
Zrad(isnan(Zrad))   = 9999;
%
timestart = [1950, 1, 1, 0, 0, 0];
%timefin = [2008, 9, 1, 0, 0, 0];
timefin = [str2num(filename(14:17)),str2num(filename(18:19)),str2num(filename(20:21)),str2num(filename(23:24)),str2num(filename(25:26)),str2num(filename(27:28))];
timenc = (etime(timefin,timestart))/(60*60*24);
%
%
switch site_code
    case {'TURQ','SBRD','CRVT'}
        pathoutput = strcat(outputdir,'ncwms/gridded_1havg_currentmap_nonQC/TURQ/');
    case {'BONC','BFCV','NOCR'}
        pathoutput = strcat(outputdir,'ncwms/gridded_1havg_currentmap_nonQC/BONC/');
 end
%
if (~exist(pathoutput,'dir'))
    mkdir(pathoutput)
end
%if (~exist(strcat(pathoutput,yearDF,'\',monthDF,'\',dayDF),'dir'))
%    mkdir(strcat(pathoutput,yearDF,'\',monthDF,'\',dayDF))
%end
%netcdfoutput = strcat(pathoutput,yearDF,'\',monthDF,'\',dayDF,'\',filename,'_CODAR-to-ncWMS.nc');
netcdfoutput = strcat(pathoutput,filename(1:end-3),'_CODAR-to-ncWMS.nc');
%
nc = netcdf.create(netcdfoutput,'NC_CLOBBER');
%
%Creation of the GLOBAL ATTRIBUTES
%
%WHAT
%timestampseb{i} = global_attr.Global_Attributes.NC_GLOBAL.time_coverage_start(2:end-1);
netcdf.putatt(nc,netcdf.getConstant('GLOBAL'),'project','Integrated Marine Observing System (IMOS)');
netcdf.putatt(nc,netcdf.getConstant('GLOBAL'),'Conventions','CF-1.4');
netcdf.putatt(nc,netcdf.getConstant('GLOBAL'),'institution','Australian Coastal Ocean Radar Network');
    tmpglobalattr = netcdf.getatt(ncid,netcdf.getConstant('GLOBAL'),'Metadata_Conventions');
netcdf.putatt(nc,netcdf.getConstant('GLOBAL'),'Metadata_Conventions',tmpglobalattr); 
    clear tmpglobalattr
%
switch site_code
    case {'TURQ','CRVT','SBRD'}
        tmpglobalattr = netcdf.getatt(ncid,netcdf.getConstant('GLOBAL'),'title');
    netcdf.putatt(nc,netcdf.getConstant('GLOBAL'),'title',tmpglobalattr); 
        clear tmpglobalattr        
    netcdf.putatt(nc,netcdf.getConstant('GLOBAL'),'site_code','TURQ, Turqoise Coast (Western Australia)');
    netcdf.putatt(nc,netcdf.getConstant('GLOBAL'),'ssr_Stations','SeaBird (SBRD), Cervantes (CRVT)');
        tmpglobalattr = netcdf.getatt(ncid,netcdf.getConstant('GLOBAL'),'id');
    netcdf.putatt(nc,netcdf.getConstant('GLOBAL'),'id',tmpglobalattr); 
        clear tmpglobalattr 
    case {'BONC','BFCV','NOCR'}
         tmpglobalattr = netcdf.getatt(ncid,netcdf.getConstant('GLOBAL'),'title');
    netcdf.putatt(nc,netcdf.getConstant('GLOBAL'),'title',tmpglobalattr); 
        clear tmpglobalattr        
    netcdf.putatt(nc,netcdf.getConstant('GLOBAL'),'site_code','BONC, Bonney Coast (South Australia)');
    netcdf.putatt(nc,netcdf.getConstant('GLOBAL'),'ssr_Stations','Cape Douglas (BFCV), Nora Creina (NOCR)');
        tmpglobalattr = netcdf.getatt(ncid,netcdf.getConstant('GLOBAL'),'id');
    netcdf.putatt(nc,netcdf.getConstant('GLOBAL'),'id',tmpglobalattr); 
        clear tmpglobalattr 
end
%
netcdf.putatt(nc,netcdf.getConstant('GLOBAL'),'date_created',datestr(clock,'yyyy-mm-ddTHH:MM:SSZ'));
%
netcdf.putatt(nc,netcdf.getConstant('GLOBAL'),'source','CODAR Ocean Sensors/SeaSonde');
acornkeywords = ['SSR'];
netcdf.putatt(nc,netcdf.getConstant('GLOBAL'),'keywords',acornkeywords);
netcdf.putatt(nc,netcdf.getConstant('GLOBAL'),'netcdf_version','3.6');
netcdf.putatt(nc,netcdf.getConstant('GLOBAL'),'naming_authority','IMOS');
netcdf.putatt(nc,netcdf.getConstant('GLOBAL'),'quality_control_set','1');
netcdf.putatt(nc,netcdf.getConstant('GLOBAL'),'file_version','Level 0 - Raw data');
netcdf.putatt(nc,netcdf.getConstant('GLOBAL'),'file_version-quality_control','Data in this file has not been quality controlled');
netcdf.putatt(nc,netcdf.getConstant('GLOBAL'),'processing_level','CODAR Ocean Sensors');
netcdf.putatt(nc,netcdf.getConstant('GLOBAL'),'ssr_Data_Type','Sea_State');
netcdf.putatt(nc,netcdf.getConstant('GLOBAL'),'ssr_Radar','SeaSonde');
netcdf.putatt(nc,netcdf.getConstant('GLOBAL'),'ssr_Technology','Direction_Finding');
netcdf.putatt(nc,netcdf.getConstant('GLOBAL'),'ssr_Ranging','Chirp');
%
%WHERE
    clear tmpglobalattr 
    tmpglobalattr = netcdf.getatt(ncid,netcdf.getConstant('GLOBAL'),'geospatial_lat_min');
netcdf.putatt(nc,netcdf.getConstant('GLOBAL'),'geospatial_lat_min',tmpglobalattr);
    clear tmpglobalattr 
    tmpglobalattr = netcdf.getatt(ncid,netcdf.getConstant('GLOBAL'),'geospatial_lat_max');
netcdf.putatt(nc,netcdf.getConstant('GLOBAL'),'geospatial_lat_max',tmpglobalattr);
netcdf.putatt(nc,netcdf.getConstant('GLOBAL'),'geospatial_lat_units','degrees_north');
    clear tmpglobalattr 
    tmpglobalattr = netcdf.getatt(ncid,netcdf.getConstant('GLOBAL'),'geospatial_lon_min');
netcdf.putatt(nc,netcdf.getConstant('GLOBAL'),'geospatial_lon_min',tmpglobalattr);
    clear tmpglobalattr 
    tmpglobalattr = netcdf.getatt(ncid,netcdf.getConstant('GLOBAL'),'geospatial_lon_max');
netcdf.putatt(nc,netcdf.getConstant('GLOBAL'),'geospatial_lon_max',tmpglobalattr);
netcdf.putatt(nc,netcdf.getConstant('GLOBAL'),'geospatial_lon_units','degrees_east');
netcdf.putatt(nc,netcdf.getConstant('GLOBAL'),'geospatial_vertical_min',0);
netcdf.putatt(nc,netcdf.getConstant('GLOBAL'),'geospatial_vertical_max',0);
netcdf.putatt(nc,netcdf.getConstant('GLOBAL'),'geospatial_vertical_units','m');
netcdf.putatt(nc,netcdf.getConstant('GLOBAL'),'geospatial_vertical_positive','up');
netcdf.putatt(nc,netcdf.getConstant('GLOBAL'),'geospatial_vertical_reference_datum','Sea surface');
netcdf.putatt(nc,netcdf.getConstant('GLOBAL'),'geospatial_geo_reference_datum','World Geodetic System 1984');
%WHEN
    clear tmpglobalattr 
    tmpglobalattr = netcdf.getatt(ncid,netcdf.getConstant('GLOBAL'),'time_coverage_start');
netcdf.putatt(nc,netcdf.getConstant('GLOBAL'),'time_coverage_start',tmpglobalattr );
    clear tmpglobalattr 
    tmpglobalattr = netcdf.getatt(ncid,netcdf.getConstant('GLOBAL'),'time_coverage_duration');
netcdf.putatt(nc,netcdf.getConstant('GLOBAL'),'time_coverage_duration',tmpglobalattr );
%WHO
netcdf.putatt(nc,netcdf.getConstant('GLOBAL'),'data_centre_email','info@emii.org.au');
netcdf.putatt(nc,netcdf.getConstant('GLOBAL'),'data_centre','eMarine Information Infrastructure (eMII)');
netcdf.putatt(nc,netcdf.getConstant('GLOBAL'),'author','Mancini, Sebastien');
netcdf.putatt(nc,netcdf.getConstant('GLOBAL'),'author_email','info@emii.org.au');
netcdf.putatt(nc,netcdf.getConstant('GLOBAL'),'institution_references','http://www.imos.org.au/acorn.html');
netcdf.putatt(nc,netcdf.getConstant('GLOBAL'),'principal_investigator','Mal Heron');
%HOW
acorncitation = [' The citation in a list of references is:'...
    ' IMOS, [year-of-data-download], [Title], [data-access-URL], accessed [date-of-access]'];
netcdf.putatt(nc,netcdf.getConstant('GLOBAL'),'citation',acorncitation);
acornacknowledgment = ['Data was sourced from the Integrated Marine Observing System (IMOS) - '...
    ' IMOS is supported by the Australian Government through the National Collaborative Research Infrastructure'...
    ' Strategy (NCRIS) and the Super Science Initiative (SSI).'];
netcdf.putatt(nc,netcdf.getConstant('GLOBAL'),'acknowledgment',acornacknowledgment);
acorndistribution = ['Data, products and services'...
    ' from IMOS are provided "as is" without any warranty as to fitness'...
    ' for a particular purpose'];
netcdf.putatt(nc,netcdf.getConstant('GLOBAL'),'distribution_statement',acorndistribution);
    netcdfabstract = netcdf.getatt(ncid,netcdf.getConstant('GLOBAL'),'abstract');
netcdf.putatt(nc,netcdf.getConstant('GLOBAL'),'abstract',netcdfabstract);
    netcdfhistory = netcdf.getatt(ncid,netcdf.getConstant('GLOBAL'),'history');
    netcdf.putatt(nc,netcdf.getConstant('GLOBAL'),'history',strcat(netcdfhistory,'Modification of the NetCDF format by eMII to visualise the data using ncWMS',clock));
    netcdfcomment = netcdf.getatt(ncid,netcdf.getConstant('GLOBAL'),'comment');
    netcdf.putatt(nc,netcdf.getConstant('GLOBAL'),'comment',strcat(netcdfcomment,'The file has been modified by eMII in order to visualise the data using the ncWMS software'));
%
%
%Creation of the DIMENSION
%
      TIME_dimid = netcdf.defdim(nc,'TIME',1);
      j_dimid = netcdf.defdim(nc,'j',comptlat);
      i_dimid = netcdf.defdim(nc,'i',comptlon);
%
%Creation of the VARIABLES
%
TIME_id = netcdf.defVar(nc,'TIME','double',TIME_dimid);
LATITUDE_id = netcdf.defVar(nc,'LATITUDE','double',[i_dimid,j_dimid]);
LONGITUDE_id = netcdf.defVar(nc,'LONGITUDE','double',[i_dimid,j_dimid]);
SPEED_id = netcdf.defVar(nc,'SPEED','double',[i_dimid,j_dimid,TIME_dimid]);
UCUR_id = netcdf.defVar(nc,'UCUR','double',[i_dimid,j_dimid,TIME_dimid]);
VCUR_id = netcdf.defVar(nc,'VCUR','double',[i_dimid,j_dimid,TIME_dimid]);
%
%
%Creation of the VARIABLE ATTRIBUTES
%
%Time
      netcdf.putatt(nc,TIME_id,'standard_name','time');
      netcdf.putatt(nc,TIME_id,'long_name','analysis_time');
      netcdf.putatt(nc,TIME_id,'units','days since 1950-01-01 00:00:00');
      netcdf.putatt(nc,TIME_id,'axis','T');
      netcdf.putatt(nc,TIME_id,'valid_min',0);
      netcdf.putatt(nc,TIME_id,'valid_max',999999);
%Latitude
      netcdf.putatt(nc,LATITUDE_id,'standard_name','latitude');
      netcdf.putatt(nc,LATITUDE_id,'long_name','latitude');
      netcdf.putatt(nc,LATITUDE_id,'units','degrees_north');
      netcdf.putatt(nc,LATITUDE_id,'axis','Y');
      netcdf.putatt(nc,LATITUDE_id,'valid_min',-90);
      netcdf.putatt(nc,LATITUDE_id,'valid_max',90);
      netcdf.putatt(nc,LATITUDE_id,'_FillValue',9999);
      netcdf.putatt(nc,LATITUDE_id,'reference_datum','geographical coordinates, WGS84 projection');
%Longitude
      netcdf.putatt(nc,LONGITUDE_id,'standard_name','longitude');
      netcdf.putatt(nc,LONGITUDE_id,'long_name','longitude');
      netcdf.putatt(nc,LONGITUDE_id,'units','degrees_east');
      netcdf.putatt(nc,LONGITUDE_id,'axis','X');
      netcdf.putatt(nc,LONGITUDE_id,'valid_min',-180);
      netcdf.putatt(nc,LONGITUDE_id,'valid_max',180);
      netcdf.putatt(nc,LONGITUDE_id,'_FillValue',9999);
      netcdf.putatt(nc,LONGITUDE_id,'reference_datum','geographical coordinates, WGS84 projection');
%nc{'LONGITUDE'}.ancillary_variables    = 'LONGITUDE_quality_control';
%Current speed
      netcdf.putatt(nc,SPEED_id,'standard_name','sea_water_speed');
      netcdf.putatt(nc,SPEED_id,'long_name','sea water speed');
      netcdf.putatt(nc,SPEED_id,'units','m s-1');
      netcdf.putatt(nc,SPEED_id,'_FillValue',9999);
      netcdf.putatt(nc,SPEED_id,'coordinates','TIME LATITUDE LONGITUDE');
%Eastward component of the Current speed
      netcdf.putatt(nc,UCUR_id,'standard_name','eastward_sea_water_velocity');
      netcdf.putatt(nc,UCUR_id,'long_name','sea water velocity U component');
      netcdf.putatt(nc,UCUR_id,'units','m s-1');
      netcdf.putatt(nc,UCUR_id,'_FillValue',9999);
      netcdf.putatt(nc,UCUR_id,'coordinates','TIME LATITUDE LONGITUDE');
%Northward component of the Current speed
      netcdf.putatt(nc,VCUR_id,'standard_name','northward_sea_water_velocity');
      netcdf.putatt(nc,VCUR_id,'long_name','sea water velocity V component');
      netcdf.putatt(nc,VCUR_id,'units','m s-1');
      netcdf.putatt(nc,VCUR_id,'_FillValue',9999);
      netcdf.putatt(nc,VCUR_id,'coordinates','TIME LATITUDE LONGITUDE');
%
      netcdf.endDef(nc)
%Data values for each variable
%
%
      netcdf.putVar(nc,TIME_id,timenc(:));
%      netcdf.putVar(nc,LATITUDE_id,Y(:,:));
%      netcdf.putVar(nc,LONGITUDE_id,X(:,:));
  for tt = 1:comptlon
      for ww = 1:comptlat
      netcdf.putVar(nc,LATITUDE_id,[tt-1,ww-1],[1,1],Y(ww,tt));
      netcdf.putVar(nc,LONGITUDE_id,[tt-1,ww-1],[1,1],X(ww,tt));
      netcdf.putVar(nc,SPEED_id,[tt-1,ww-1,0],[1,1,1],round(Zrad(ww,tt)*100000)/100000);
      netcdf.putVar(nc,UCUR_id,[tt-1,ww-1,0],[1,1,1],round(Urad(ww,tt)*100000)/100000);
      netcdf.putVar(nc,VCUR_id,[tt-1,ww-1,0],[1,1,1],round(Vrad(ww,tt)*100000)/100000);
      end
  end
%
%Close the two NetCDF file
netcdf.close(nc)
netcdf.close(ncid)
%

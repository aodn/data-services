function [dateforfileSQL] = radar_WERA_non_QC_subfunction2_UNIX_v1(namefile,site_code,zz)
%This subfunction will open NetCDF files and process the data in order to
%create a new netCDF file.
%This new NetCDF file will contain the current data (intensity and
%direction) averaged over an hour.
%
global dfradialdata
%reminder: dfradialdata ='/home/matlab_3/datafabric_root/opendap/ACORN/radial/';
%see matlab script 'radar_WERA_non_QC_main_UNIX_v1.m' for any changes
global inputdir
%reminder: inputdir = '/var/lib/matlab_3/ACORN/WERA/radial_nonQC/';
%see matlab script 'radar_WERA_non_QC_main_UNIX_v1.m' for any changes
global outputdir
%reminder: outputdir = '/var/lib/matlab_3/ACORN/WERA/radial_nonQC/output/';
%see matlab script 'radar_WERA_non_QC_main_UNIX_v1.m' for any changes
%
%Creation of the variable "data" to store the filenames of the 12 input
%NetCDF files (6 per radar stations)
for i = 1:12
    data{i} = namefile{i};
end
%
%
temp = datenum(namefile{1}(15:29),'yyyymmddTHHMMSS');
dateforfileSQL = datestr(temp+1/48,'yyyymmddTHHMMSS');
yearDF = dataforfileSQL(1:4);
monthDF = dataforfileSQL(5:6);
dayDF = dataforfileSQL(7:8);
clear temp
%
%File dimension
dimfile = length(data);
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%In the following loop, I will only access the variable POSITION
%The maximum value of the variable POSITION is then calculated
%
maxPOS = 0;
%
for i = 1:dimfile
%    
    nc = netcdf.open(strcat(dfradialdata,data{i}(32:34),'/',data{i}(15:18),'/',data{i}(19:20),'/',data{i}(21:22),'/',data{i}(1:end-3),'.nc'),'NC_NOWRITE');
    temp_varid = netcdf.inqVarID(nc,'POSITION');
    temp = netcdf.getVar(nc,temp_varid);
    POS = temp(:);
%
    maxtemp = max(POS);
    if ( maxtemp>maxPOS)
        maxPOS=maxtemp;
    end
    netcdf.close(nc)
end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%Creation of two matrices.
%I will use those two matrices to store all the data available in the
%NetCDF files
%The matrices are filled with NaN
station1 = NaN(maxPOS,9,7);
station2 = NaN(maxPOS,9,7);
%
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
%ACCESS the NetCDF files for the first radar station
t=1;
for i = 1:2:dimfile
%OPEN NETCDF FILE    
    nc = netcdf.open(strcat(dfradialdata,data{i}(32:34),'/',data{i}(15:18),'/',data{i}(19:20),'/',data{i}(21:22),'/',data{i}(1:end-3),'.nc'),'NC_NOWRITE');
    temp_varid = netcdf.inqVarID(nc,'POSITION');
    temp = netcdf.getVar(nc,temp_varid);
    POS = temp(:);
    dimtemp = length(POS);
%READ ALL VARIABLES
    temp_varid = netcdf.inqVarID(nc,'LONGITUDE');
    temp = netcdf.getVar(nc,temp_varid);
    lon = temp(:);
    temp_varid = netcdf.inqVarID(nc,'LATITUDE');
    temp = netcdf.getVar(nc,temp_varid);
    lat = temp(:);
    temp_varid = netcdf.inqVarID(nc,'ssr_Surface_Radial_Sea_Water_Speed');
    temp = netcdf.getVar(nc,temp_varid);
    speed = temp(:);
    temp_varid = netcdf.inqVarID(nc,'ssr_Surface_Radial_Direction_Of_Sea_Water_Velocity');
    temp = netcdf.getVar(nc,temp_varid);
    dir = temp(:);
%READ SOME GLOBAL ATTRIBUTES
    tmpglobalattr = netcdf.getatt(nc,netcdf.getConstant('GLOBAL'),'time_coverage_start');
    timestampseb{i} = tmpglobalattr(1:end);
%CLOSE NETCDF FILE    
    netcdf.close(nc);
%
%Variable Standard Error
    nc = netcdf.open(strcat(dfradialdata,data{i}(32:34),'/',data{i}(15:18),'/',data{i}(19:20),'/',data{i}(21:22),'/',data{i}(1:end-3),'.nc'),'NC_NOWRITE');
    temp_varid = netcdf.inqVarID(nc,'ssr_Surface_Radial_Sea_Water_Speed_Standard_Error');
    temp = netcdf.getVar(nc,temp_varid);
    error = temp(:);
%Variable Bragg signal to noise ratio
    temp_varid = netcdf.inqVarID(nc,'ssr_Bragg_Signal_To_Noise');
    temp = netcdf.getVar(nc,temp_varid);
    bragg = temp(:);
    netcdf.close(nc);
%STORE THE DATA IN THE VARIABLE "STATION1"
%variable 1 : POSITION
%variable 2 : LATITUDE
%variable 3 : LONGITUDE
%variable 4 : SPEED (The value can be positive [when the current is going
%away from the radar station] or negative [when the current is going toward
%the radar station])
%variable 5 : DIRECTION (value calculated between the radar station and the grid point)
%variable 6 : U component of the current speed (calculated from SPEED and
%DIRECTION
%variable 7 : V component of the current speed (calculated from SPEED and
%DIRECTION
%variable 8 : STANDARD ERROR of the current speed
    for j=1:dimtemp
        station1(POS(j),1,t) = POS(j);
        station1(POS(j),2,t) = lon(j);
        station1(POS(j),3,t) = lat(j);
        station1(POS(j),4,t) = speed(j);
        station1(POS(j),5,t) = dir(j);
%Calculation of the U and V component of the radial vector
        station1(POS(j),6,t) = speed(j)*sin(dir(j)*pi/180);
        station1(POS(j),7,t) = speed(j)*cos(dir(j)*pi/180);
%STANDARD ERROR of the current speed
        station1(POS(j),8,t) = error(j);
%Bragg ratio information
        station1(POS(j),9,t) = bragg(j);
    end
    t=t+1;
end
clear POS lat lon speed dir
%%%%%%%%%%%%%%%%%%DATA CHECK%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
%Find grid data points where the current speed is higher than a specified 
%value ("maxnorme") 
%The corresponding values are then replaced by NaN
%
%maxnorme = 1;
%for i=1:6
%I = find(abs(station1(:,4,i))>maxnorme);
%station1(I,:,i) = NaN;
%end
%
%BRAGG RATIO CRITERIA
%I had a look at the data for different radar stations, and i found that
%when the BRAGG Ratio is under a value of 8 the data is less accurate.
%this value can be cahnged or removed if necessary
for i=1:6
    K = find(station1(:,9,i)<8);
    station1(K,:,i) = NaN;
end
%
%STANDARD ERROR CRITERIA
%for i=1:6
%K = find((abs(station1(:,4,i))./station1(:,8,i))<1);
%station1(K,:,i) = NaN;
%end
%
%NUMBER OF VALID RADIALS CRITERIA
%If for each grid point, there is less than 3 valid data over 1 hour, then
%the data at that grid point is considered as BAD.
for i=1:maxPOS
    checkradial(i) = sum(~isnan(station1(i,4,1:6)));
end
J = find(checkradial<3);
station1(J,:,:) = NaN;
station2(J,:,:) = NaN;
clear checkradial J
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%ACCESS the NetCDF files for the SECOND radar station
%
t=1;
for i = 2:2:dimfile
    nc = netcdf.open(strcat(dfradialdata,data{i}(32:34),'/',data{i}(15:18),'/',data{i}(19:20),'/',data{i}(21:22),'/',data{i}(1:end-3),'.nc'),'NC_NOWRITE');
    temp_varid = netcdf.inqVarID(nc,'POSITION');
    temp = netcdf.getVar(nc,temp_varid);
    POS = temp(:);
    dimtemp = length(POS);
%
    temp_varid = netcdf.inqVarID(nc,'LONGITUDE');
    temp = netcdf.getVar(nc,temp_varid);
    lon = temp(:);
    temp_varid = netcdf.inqVarID(nc,'LATITUDE');
    temp = netcdf.getVar(nc,temp_varid);
    lat = temp(:);
    temp_varid = netcdf.inqVarID(nc,'ssr_Surface_Radial_Sea_Water_Speed');
    temp = netcdf.getVar(nc,temp_varid);
    speed = temp(:);
    temp_varid = netcdf.inqVarID(nc,'ssr_Surface_Radial_Direction_Of_Sea_Water_Velocity');
    temp = netcdf.getVar(nc,temp_varid);
    dir = temp(:);
%
    tmpglobalattr = netcdf.getatt(nc,netcdf.getConstant('GLOBAL'),'time_coverage_start');
    timestampseb{i} = tmpglobalattr(1:end);
    netcdf.close(nc)
%Variable Standard Error
    nc = netcdf.open(strcat('/home/smancini/datafabric_root/opendap/ACORN/radial/',data{i}(32:34),'/',data{i}(15:18),'/',data{i}(19:20),'/',data{i}(21:22),'/',data{i}(1:end-3),'.nc'),'NC_NOWRITE');
    temp_varid = netcdf.inqVarID(nc,'ssr_Surface_Radial_Sea_Water_Speed_Standard_Error');
    temp = netcdf.getVar(nc,temp_varid);
    error = temp(:);
%
    temp_varid = netcdf.inqVarID(nc,'ssr_Bragg_Signal_To_Noise');
    temp = netcdf.getVar(nc,temp_varid);
    bragg = temp(:);
    netcdf.close(nc)
%
%
    for j=1:dimtemp
        station2(POS(j),1,t) = POS(j);
        station2(POS(j),2,t) = lon(j);
        station2(POS(j),3,t) = lat(j);
        station2(POS(j),4,t) = speed(j);
        station2(POS(j),5,t) = dir(j);
%U and V components of the CURRENT SPEED      
        station2(POS(j),6,t) = speed(j)*sin(dir(j)*pi/180);
        station2(POS(j),7,t) = speed(j)*cos(dir(j)*pi/180);
%STANDARD ERROR OF THE CURRENT SPEED
        station2(POS(j),8,t) = error(j);
%BRAGG RATIO VARIABLE
        station2(POS(j),9,t) = bragg(j);        
    end
    t=t+1;
end
%%%%%%%%%%%%%%%%%%DATA CHECK%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
%Find grid data points where the current speed is higher than a specified 
%value ("maxnorme") 
%The corresponding values are then replaced by NaN
%
%for i=1:6
%I = find(abs(station2(:,4,i))>maxnorme);
%station2(I,:,i) = NaN;
%end
%
%BRAGG RATIO CRITERIA
%I had a look at the data for different radar stations, and i found that
%when the BRAGG Ratio is under a value of 8 the data is less accurate.
%this value can be cahnged or removed if necessary
for i=1:6
    K = find(station2(:,9,i)<8);
    station2(K,:,i) = NaN;
end
%
%STANDARD ERROR CRITERIA
%for i=1:6
%K = find((abs(station2(:,4,i))./station2(:,8,i))<1);
%station2(K,:,i) = NaN;
%end
%
%NUMBER OF VALID RADIALS CRITERIA
%If for each grid point, there is less than 3 valid data over 1 hour, then
%the data at that grid point is considered as BAD.
for i=1:maxPOS
    checkradial(i) = sum(~isnan(station2(i,4,1:6)));
end
J = find(checkradial<3);
station2(J,:,:) = NaN;
station1(J,:,:) = NaN;
clear checkradial J
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%Calculation of the average of each variable
%Ia m calculating the average of the U and V components of the radial
%vector. Then I will use those average values to retrieve the value of the 
%current speed and the current direction for each grid point and each radar station 
%
%
for i=1:maxPOS
    for j=1:9
        station1(i,j,7) = nanmean(station1(i,j,1:6));
        station2(i,j,7) = nanmean(station2(i,j,1:6));
    end
%CALCULATION OF THE CURRENT SPEED USING THE U AND V COMPONENTS
%station 1
    station1(i,4,7) = sqrt(station1(i,6,7)*station1(i,6,7)+station1(i,7,7)*station1(i,7,7));
%station 2
    station2(i,4,7) = sqrt(station2(i,6,7)*station2(i,6,7)+station2(i,7,7)*station2(i,7,7));
%CALCULATION OF THE CURRENT DIRECTION USING THE U AND V COMPONENTS
%station1
    station1(i,5,7) = abs(atan(station1(i,6,7)/station1(i,7,7))*180/pi);
%
    if (station1(i,6,7) == 0 && station1(i,7,7) > 0)
        station1(i,5,7) = 0;
            elseif (station1(i,6,7) == 0 && station1(i,7,7) < 0)
        station1(i,5,7) = 180;
            elseif (station1(i,7,7) == 0 && station1(i,6,7) > 0)
        station1(i,5,7) = 90;
            elseif (station1(i,7,7) == 0 && station1(i,6,7) < 0)
        station1(i,5,7) = 270;
            elseif (station1(i,6,7) > 0 && station1(i,7,7) > 0)
        station1(i,5,7) = station1(i,5,7);
            elseif (station1(i,6,7) > 0 && station1(i,7,7) < 0)
        station1(i,5,7) = 180 - station1(i,5,7);
            elseif (station1(i,6,7) < 0 && station1(i,7,7) < 0)
        station1(i,5,7) = 180 + station1(i,5,7);
    else
        station1(i,5,7) = 360 - station1(i,5,7);
    end
%station 2
    station2(i,5,7) = abs(atan(station2(i,6,7)/station2(i,7,7))*180/pi);
%
    if (station2(i,6,7) == 0 && station2(i,7,7) > 0)
        station2(i,5,7) = 0;
            elseif (station2(i,6,7) == 0 && station2(i,7,7) < 0)
        station2(i,5,7) = 180;
            elseif (station2(i,7,7) == 0 && station2(i,6,7) > 0)
        station2(i,5,7) = 90;
            elseif (station2(i,7,7) == 0 && station2(i,6,7) < 0)
        station2(i,5,7) = 270;
            elseif (station2(i,6,7) > 0 && station2(i,7,7) > 0)
        station2(i,5,7) = station2(i,5,7);
            elseif (station2(i,6,7) > 0 && station2(i,7,7) < 0)
        station2(i,5,7) = 180 - station2(i,5,7);
            elseif (station2(i,6,7) < 0 && station2(i,7,7) < 0)
        station2(i,5,7) = 180 + station2(i,5,7);
    else
        station2(i,5,7) = 360 - station2(i,5,7);
    end
%
end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%CALCULATION OF THE RESULTANT VECTOR USING THE TWO RADIALS COMPONENTS
%I USED THE SAME EQUATION AS DESCRIBED ON THE FOLLOWING ARTICLE
% "MEASUREMNT OF OCEAN SURFACE CURRENTS BY THE CRL HF OCEAN SURFACE RADAR
% OF FCMW TYPE. PART 2. CURRENT VECTOR"
%
k=1;
for i =1:maxPOS
     for j=1:maxPOS
%CHECK IF DATA EXISTS AT THE SAME GRID POINT FOR THE TWO RADAR STATIONS            
         if (station1(i,1,7) == station2(j,1,7))
%LONGITUDE             
            final(k,1)=station1(i,2,7);
%LATITUDE            
         final(k,2)=station1(i,3,7);
%POSITION         
         final(k,7)=station1(i,1,7);
%EASTWARD COMPONENT OF THE VELOCITY         
  final(k,3)=(station1(i,4,7)*cos(station2(j,5,7)*pi/180)-station2(j,4,7)*cos(station1(i,5,7)*pi/180))/sin((station1(i,5,7)-station2(j,5,7))*pi/180);
%NORTHWARD COMPONENT OF THE VELOCITY
  final(k,4)=(-1*station1(i,4,7)*sin(station2(j,5,7)*pi/180)+station2(j,4,7)*sin(station1(i,5,7)*pi/180))/sin((station1(i,5,7)-station2(j,5,7))*pi/180);
%NORME DE LA VITESSE
  final(k,5)=sqrt(final(k,3)*final(k,3)+final(k,4)*final(k,4));
%EASTWARD COMPONENT  OF THE STANDARD ERROR OF THE VELOCITY
  final(k,8)=(station1(i,8,7)*cos(station2(j,5,7)*pi/180)-station2(j,8,7)*cos(station1(i,5,7)*pi/180))/sin((station1(i,5,7)-station2(j,5,7))*pi/180);
%NORTHWARD COMPONENT OF THE STANDARD ERROR OF THE VELOCITY
  final(k,9)=(-1*station1(i,8,7)*sin(station2(j,5,7)*pi/180)+station2(j,8,7)*sin(station1(i,5,7)*pi/180))/sin((station1(i,5,7)-station2(j,5,7))*pi/180);
%NORME DE LA STANDARD ERROR DE LA VITESSE
  final(k,10)=sqrt(final(k,8)*final(k,8)+final(k,9)*final(k,9));
%RATIO ENTRE LES NORMES DE LA STANDARD ERROR ET LA VITESSE
  final(k,11) = final(k,10)/final(k,5);
%CORRESPONDING BRAGG RATIO OF STATION 1
  final(k,12) = station1(i,9,7);
%CORRESPONDING BRAGG RATIO OF STATION 2  
  final(k,13) = station2(i,9,7);
%  
         k=k+1;
         end
     end
end
%
dimfinal = k-1;
%
%CALCULATION OF THE DIRECTION OF THE CURRENT SPEED
for k=1:dimfinal
    final(k,6) = abs(atan(final(k,3)/final(k,4))*180/pi);
%
    if (final(k,3) == 0 && final(k,4) > 0)
        final(k,6) = 0;
            elseif (final(k,3) == 0 && final(k,4) < 0)
        final(k,6) = 180;
            elseif (final(k,4) == 0 && final(k,3) > 0)
        final(k,6) = 90;
            elseif (final(k,4) == 0 && final(k,3) < 0)
        final(k,6) = 270;
            elseif (final(k,3) > 0 && final(k,4) > 0)
        final(k,6) = final(k,6);
            elseif (final(k,3) > 0 && final(k,4) < 0)
        final(k,6) = 180 - final(k,6);
            elseif (final(k,3) < 0 && final(k,4) < 0)
        final(k,6) = 180 + final(k,6);
    else
        final(k,6) = 360 - final(k,6);
    end
end
%
%Find grid data points where the current speed is higher than a specified 
%value ("1.5 m/s") 
%The corresponding values are then replaced by NaN
%
%I = find(final(:,5)>1.5);
%final(I,3:6) = NaN;
%
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%NETCDF OUTPUT
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
%NECESSITY TO IMPORT THE LATITUDE AND THE LONGITUDE VALUES OF THE OUTPUT GRID 
%
switch site_code
    case {'SAG','CWI','CSP'}
%LATITUDE VALUE OF THE GRID       
        fid = fopen(strcat(inputdir,'LAT_SAG.dat'),'r');
        line=fgetl(fid);
        datalat{1} = line ;
        i=2;
        while line~=-1,
          line=fgetl(fid);
          datalat{i} = line ;
          i=i+1;
        end
        dimlat = length(datalat);
        %
        for i = 1:dimlat-1
            Y(i) = str2num(datalat{i});
        end
%LONGITUDE VALUE OF THE GRID
        fid = fopen(strcat(inputdir,'LON_SAG.dat'),'r');
        line=fgetl(fid);
        datalon{1} = line ;
        i=2;
        while line~=-1,
          line=fgetl(fid);
          datalon{i} = line ;
          i=i+1;
        end
        dimlon = length(datalon);
        %
        for i = 1:dimlon-1
            X(i) = str2num(datalon{i});
        end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%        
       case {'GBR','TAN','LEI','CBG'}
%COMMENT: THE GRID CHANGED ON THE 01/03/2011 at 04:04 to be 72*64 (4km grid)
%the previous grid was a 80*80 (3km spacing)
%LATITUDE VALUE OF THE GRID    
       if (datenum(namefile{1}(15:29),'yyyymmddTHHMMSS') < datenum('20110301T050000','yyyymmddTHHMMSS'))
        fid = fopen(strcat(inputdir,'LAT_CBG.dat'),'r');
       else
        fid = fopen(strcat(inputdir,'LAT_CBG_grid022011.dat'),'r');   
       end
        line=fgetl(fid);
        datalat{1} = line ;
        i=2;
        while line~=-1,
          line=fgetl(fid);
          datalat{i} = line ;
          i=i+1;
        end
        dimlat = length(datalat);
        %
        for i = 1:dimlat-1
            Y(i) = str2num(datalat{i});
        end
%LONGITUDE VALUE OF THE GRID
       if (datenum(namefile{1}(15:29),'yyyymmddTHHMMSS') < datenum('20110301T050000','yyyymmddTHHMMSS'))
        fid = fopen(strcat(inputdir,'LON_CBG.dat'),'r');
       else
        fid = fopen(strcat(inputdir,'LON_CBG_grid022011.dat'),'r');   
       end
        line=fgetl(fid);
        datalon{1} = line ;
        i=2;
        while line~=-1,
          line=fgetl(fid);
          datalon{i} = line ;
          i=i+1;
        end
        dimlon = length(datalon);
        %
        for i = 1:dimlon-1
            X(i) = str2num(datalon{i});
        end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%        
        case {'PCY','FRE','GUI','ROT'}
%LATITUDE VALUE OF THE GRID       
        fid = fopen(strcat(inputdir,'LAT_ROT.dat'),'r');
        line=fgetl(fid);
        datalat{1} = line ;
        i=2;
        while line~=-1,
          line=fgetl(fid);
          datalat{i} = line ;
          i=i+1;
        end
        dimlat = length(datalat);
        %
        for i = 1:dimlat-1
            Y(i) = str2num(datalat{i})
        end
%LONGITUDE VALUE OF THE GRID
        fid = fopen(strcat(inputdir,'LON_ROT.dat'),'r');
        line=fgetl(fid);
        datalon{1} = line ;
        i=2;
        while line~=-1,
          line=fgetl(fid);
          datalon{i} = line ;
          i=i+1;
        end
        dimlon = length(datalon);
        %
        for i = 1:dimlon-1
            X(i) = str2num(datalon{i});
        end
end
%
%
comptlon = length(X);
comptlat = length(Y);
%
Zrad = NaN(comptlat,comptlon);
Urad = NaN(comptlat,comptlon);
Vrad = NaN(comptlat,comptlon);
%
for i = 1:length(final(:,1))
    index = final(i,7);
    indexj = floor((index-1)/comptlat)+1;
    if (~mod(index,comptlat))
        indexi = comptlat;
    else
        indexi = mod(index,comptlat);
    end
    Zrad(indexi,indexj) = final(i,5);
    Urad(indexi,indexj) = final(i,3);
    Vrad(indexi,indexj) = final(i,4);
end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%NetCDF file creation
%This NETCDF FILE IS TO BE USED BY NCWMS
%IT DOES NOT CONTAIN ANY QUALITY CONTROL VARIABLE
%
Urad(isnan(Urad)) = 9999;
Vrad(isnan(Vrad)) = 9999;
Zrad(isnan(Zrad)) = 9999;
%
timestart = [1950, 1, 1, 0, 0, 0];
%timefin = [2008, 9, 1, 0, 0, 0];
timefin = [str2num(data{1}(15:18)),str2num(data{1}(19:20)),str2num(data{1}(21:22)),str2num(data{1}(24:25)),str2num(data{1}(26:27)),str2num(data{1}(28:29))];
timenc = (etime(timefin,timestart))/(60*60*24);
%
%EXPORT OUTPUT FILES
%This file is to be used by ncWMS for visualisation purposes
switch site_code
    case {'SAG','CWI','CSP'}
        pathoutput = strcat(outputdir,'ncwms/gridded_1havg_currentmap_nonQC/SAG/');
    case {'GBR','TAN','LEI','CBG'}
        pathoutput = strcat(outputdir,'ncwms/gridded_1havg_currentmap_nonQC/GBR/');
        site_code = 'GBR';
    case {'PCY','FRE','GUI','ROT'}
        pathoutput = strcat(outputdir,'ncwms/gridded_1havg_currentmap_nonQC/PCY/');
        site_code = 'PCY';
 end
%
netcdfoutput = strcat(pathoutput,'IMOS_ACORN_V_',dateforfileSQL,'_',site_code,'_FV00_1-hour-avg.nc');
%
nc = netcdf.create(netcdfoutput,'NC_CLOBBER');
%
%Creation of the GLOBAL ATTRIBUTES
%
%WHAT
      netcdf.putatt(nc,netcdf.getConstant('GLOBAL'),'project','Integrated Marine Observing System (IMOS)');
      netcdf.putatt(nc,netcdf.getConstant('GLOBAL'),'conventions','CF-1.4');
      netcdf.putatt(nc,netcdf.getConstant('GLOBAL'),'institution','Australian Coastal Ocean Radar Network');
%
switch site_code
    case {'SAG','CWI','CSP'}
      netcdf.putatt(nc,netcdf.getConstant('GLOBAL'),'title',strcat('IMOS ACORN South Australia Gulf (SAG), one hour averaged current data, ',datestr(timenc(1)+datenum(timestart)+1/48,'yyyy-mm-ddTHH:MM:SSZ')));    
    case {'GBR','TAN','LEI','CBG'}
      netcdf.putatt(nc,netcdf.getConstant('GLOBAL'),'title',strcat('IMOS ACORN Great Barrier Reef (GBR), one hour averaged current data, ',datestr(timenc(1)+datenum(timestart)+1/48,'yyyy-mm-ddTHH:MM:SSZ')));    
    case {'PCY','FRE','GUI','ROT'}
      netcdf.putatt(nc,netcdf.getConstant('GLOBAL'),'title',strcat('IMOS ACORN Perth Canyon (PCY), one hour averaged current data, ',datestr(timenc(1)+datenum(timestart)+1/48,'yyyy-mm-ddTHH:MM:SSZ')));    
end
%
      netcdf.putatt(nc,netcdf.getConstant('GLOBAL'),'date_created',datestr(clock,'yyyy-mm-ddTHH:MM:SSZ'));
%
netcdfabstract = [''];
netcdf.putatt(nc,netcdf.getConstant('GLOBAL'),'abstract',netcdfabstract);
      netcdf.putatt(nc,netcdf.getConstant('GLOBAL'),'source','WERA Oceanographic HF Radar/Helzel Messtechnik, GmbH');
acornkeywords = ['Oceans'];
netcdf.putatt(nc,netcdf.getConstant('GLOBAL'),'keywords',acornkeywords);
netcdf.putatt(nc,netcdf.getConstant('GLOBAL'),'netcdf_version','3.6');
netcdf.putatt(nc,netcdf.getConstant('GLOBAL'),'naming_authority','IMOS');
netcdf.putatt(nc,netcdf.getConstant('GLOBAL'),'quality_control_set','1');
%WHERE
netcdf.putatt(nc,netcdf.getConstant('GLOBAL'),'geospatial_lat_min',min(Y));
netcdf.putatt(nc,netcdf.getConstant('GLOBAL'),'geospatial_lat_max',max(Y));
netcdf.putatt(nc,netcdf.getConstant('GLOBAL'),'geospatial_lon_min',min(X));
netcdf.putatt(nc,netcdf.getConstant('GLOBAL'),'geospatial_lon_max',max(X));
netcdf.putatt(nc,netcdf.getConstant('GLOBAL'),'geospatial_vertical_min',0);
netcdf.putatt(nc,netcdf.getConstant('GLOBAL'),'geospatial_vertical_max',0);
%WHEN
netcdf.putatt(nc,netcdf.getConstant('GLOBAL'),'time_coverage_start',datestr(timenc(1)+datenum(timestart),'yyyy-mm-ddTHH:MM:SSZ'));
netcdf.putatt(nc,netcdf.getConstant('GLOBAL'),'time_coverage_end',datestr(timenc(1)+datenum(timestart),'yyyy-mm-ddTHH:MM:SSZ'));
%WHO
netcdf.putatt(nc,netcdf.getConstant('GLOBAL'),'data_centre_email','info@emii.org.au');
netcdf.putatt(nc,netcdf.getConstant('GLOBAL'),'data_centre','eMarine Information Infrastructure (eMII)');
netcdf.putatt(nc,netcdf.getConstant('GLOBAL'),'author','Mancini, Sebastien');
netcdf.putatt(nc,netcdf.getConstant('GLOBAL'),'author_email','info@emii.org.au');
netcdf.putatt(nc,netcdf.getConstant('GLOBAL'),'institution_references','http://www.imos.org.au/acorn.html');
%HOW
acorncitation = [' The citation in a list of references is:'...
    ' IMOS, [year-of-data-download], [Title], [data-access-URL], accessed [date-of-access]'];
netcdf.putatt(nc,netcdf.getConstant('GLOBAL'),'citation',acorncitation);
acornacknowledgment = ['IMOS is supported by the Australian Government'...
    ' through the National Collaborative Research Infrastructure'...
    ' Strategy (NCRIS) and the Super Science Initiative (SSI).'];
netcdf.putatt(nc,netcdf.getConstant('GLOBAL'),'acknowledgment',acornacknowledgment);
acorndistribution = ['Data, products and services'...
    ' from IMOS are provided "as is" without any warranty as to fitness'...
    ' for a particular purpose'];
netcdf.putatt(nc,netcdf.getConstant('GLOBAL'),'distribution_statement',acorndistribution);
acorncomment = ['These data have not been quality controlled.'...
    ' The ACORN facility is producing NetCDF files with radials data for each station every ten minutes. '...
    ' The radial values have been calculated using software provided '...
    ' by the manufacturer of the instrument.'...
    ' eMII is using a Matlab program to read all the netcdf files with radial data for two different stations '...
    ' and produce a one hour average product with U and V components '...
    ' of the current. The final product is produced on a regular geographic (latitude longitude) grid'];
netcdf.putatt(nc,netcdf.getConstant('GLOBAL'),'comment',acorncomment);
%
%
%Creation of the DIMENSION
%
      TIME_dimid = netcdf.defdim(nc,'TIME',1);
      LATITUDE_dimid = netcdf.defdim(nc,'LATITUDE',comptlat);
      LONGITUDE_dimid = netcdf.defdim(nc,'LONGITUDE',comptlon);
%
%Creation of the VARIABLES
%
TIME_id = netcdf.defVar(nc,'TIME','double',TIME_dimid);
LATITUDE_id = netcdf.defVar(nc,'LATITUDE','double',LATITUDE_dimid);
LONGITUDE_id = netcdf.defVar(nc,'LONGITUDE','double',LONGITUDE_dimid);
SPEED_id = netcdf.defVar(nc,'SPEED','double',[LONGITUDE_dimid,LATITUDE_dimid,TIME_dimid]);
UCUR_id = netcdf.defVar(nc,'UCUR','double',[LONGITUDE_dimid,LATITUDE_dimid,TIME_dimid]);
VCUR_id = netcdf.defVar(nc,'VCUR','double',[LONGITUDE_dimid,LATITUDE_dimid,TIME_dimid]);
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
      netcdf.putatt(nc,TIME_id,'_FillValue',-9999);
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
%Current speed
      netcdf.putatt(nc,SPEED_id,'standard_name','sea_water-speed');
      netcdf.putatt(nc,SPEED_id,'long_name','sea water speed');
      netcdf.putatt(nc,SPEED_id,'units','m s-1');
      netcdf.putatt(nc,SPEED_id,'_FillValue',9999);
%Eastward component of the Current speed
      netcdf.putatt(nc,UCUR_id,'standard_name','eastward_sea_water_velocity');
      netcdf.putatt(nc,UCUR_id,'long_name','sea water velocity U component');
      netcdf.putatt(nc,UCUR_id,'units','m s-1');
      netcdf.putatt(nc,UCUR_id,'_FillValue',9999);
%Northward component of the Current speed
      netcdf.putatt(nc,VCUR_id,'standard_name','northward_sea_water_velocity');
      netcdf.putatt(nc,VCUR_id,'long_name','sea water velocity V component');
      netcdf.putatt(nc,VCUR_id,'units','m s-1');
      netcdf.putatt(nc,VCUR_id,'_FillValue',9999);
%
      netcdf.endDef(nc)
%
%Data values for each variable
%
%
      netcdf.putVar(nc,TIME_id,timenc(:));
      netcdf.putVar(nc,LATITUDE_id,Y(:));
      netcdf.putVar(nc,LONGITUDE_id,X(:));
  for tt = 1:comptlon
      for ww = 1:comptlat
      netcdf.putVar(nc,SPEED_id,[tt-1,ww-1,0],[1,1,1],round(Zrad(ww,tt)*100000)/100000);
      netcdf.putVar(nc,UCUR_id,[tt-1,ww-1,0],[1,1,1],round(Urad(ww,tt)*100000)/100000);
      netcdf.putVar(nc,VCUR_id,[tt-1,ww-1,0],[1,1,1],round(Vrad(ww,tt)*100000)/100000);
      end
  end
%
%Close the first NetCDF file
	netcdf.close(nc);
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
%CREATION OF A SECOND NETCDF FILE 
%THIS NETCDF FILE WILL THEN BE AVAILABLE ON THE DATAFABRIC AND ON THE QCIF OPENDAP SERVER
%
switch site_code
    case {'SAG','CWI','CSP'}
        pathoutput = strcat(outputdir,'datafabric/gridded_1havg_currentmap_nonQC/SAG/');
    case {'GBR','TAN','LEI','CBG'}
        pathoutput = strcat(outputdir,'datafabric/gridded_1havg_currentmap_nonQC/CBG/');
        site_code = 'CBG';
    case {'PCY','FRE','GUI','ROT'}
        pathoutput = strcat(outputdir,'datafabric/gridded_1havg_currentmap_nonQC/ROT/');
        site_code = 'ROT';
 end
%
if (~exist(strcat(pathoutput,yearDF,'/',monthDF,'/',dayDF),'dir'))
    mkdir(strcat(pathoutput,yearDF,'/',monthDF,'/',dayDF))
end
%
netcdfoutput = strcat(pathoutput,yearDF,'/',monthDF,'/',dayDF,'/','IMOS_ACORN_V_',dateforfileSQL,'Z_',site_code,'_FV00_1-hour-avg.nc');
%
nc = netcdf.create(netcdfoutput,'NC_CLOBBER');
%
%Creation of the GLOBAL ATTRIBUTES
%
%WHAT
      netcdf.putatt(nc,netcdf.getConstant('GLOBAL'),'project','Integrated Marine Observing System (IMOS)');
      netcdf.putatt(nc,netcdf.getConstant('GLOBAL'),'Conventions','CF-1.4');
      netcdf.putatt(nc,netcdf.getConstant('GLOBAL'),'institution','Australian Coastal Ocean Radar Network');
%
switch site_code
    case {'SAG','CWI','CSP'}
      netcdf.putatt(nc,netcdf.getConstant('GLOBAL'),'title',strcat('IMOS ACORN South Australia Gulf (SAG), one hour averaged current data, ',datestr(timenc(1)+datenum(timestart)+1/48,'yyyy-mm-ddTHH:MM:SSZ')));    
      netcdf.putatt(nc,netcdf.getConstant('GLOBAL'),'site_code','SAG, South Australia Gulf'); 
      netcdf.putatt(nc,netcdf.getConstant('GLOBAL'),'ssr_Stations','Cape Wiles (CWI), Cape Spencer (CSP)'); 
    case {'GBR','TAN','LEI','CBG'}
      netcdf.putatt(nc,netcdf.getConstant('GLOBAL'),'title',strcat('IMOS ACORN Capricorn Bunker Group (CBG), one hour averaged current data, ',datestr(timenc(1)+datenum(timestart)+1/48,'yyyy-mm-ddTHH:MM:SSZ')));    
      netcdf.putatt(nc,netcdf.getConstant('GLOBAL'),'site_code','CBG, Capricorn Bunker Group'); 
      netcdf.putatt(nc,netcdf.getConstant('GLOBAL'),'ssr_Stations','Tannum Sands (TAN), Lady Elliott Island (LEI)');    
    case {'PCY','FRE','GUI','ROT'}
      netcdf.putatt(nc,netcdf.getConstant('GLOBAL'),'title',strcat('IMOS ACORN Rottnest Shelf (ROT), one hour averaged current data, ',datestr(timenc(1)+datenum(timestart)+1/48,'yyyy-mm-ddTHH:MM:SSZ')));    
      netcdf.putatt(nc,netcdf.getConstant('GLOBAL'),'site_code','ROT, Rottnest Shelf'); 
      netcdf.putatt(nc,netcdf.getConstant('GLOBAL'),'ssr_Stations','Fremantle (FRE), Guilderton (GUI)'); 
end
%
      netcdf.putatt(nc,netcdf.getConstant('GLOBAL'),'date_created',datestr(clock,'yyyy-mm-ddTHH:MM:SSZ'));
%
netcdf.putatt(nc,netcdf.getConstant('GLOBAL'),'source','WERA Oceanographic HF Radar/Helzel Messtechnik, GmbH');
acornkeywords = ['Oceans'];
netcdf.putatt(nc,netcdf.getConstant('GLOBAL'),'keywords',acornkeywords);
netcdf.putatt(nc,netcdf.getConstant('GLOBAL'),'netcdf_version','3.6');
netcdf.putatt(nc,netcdf.getConstant('GLOBAL'),'naming_authority','IMOS');
netcdf.putatt(nc,netcdf.getConstant('GLOBAL'),'quality_control_set','1');
netcdf.putatt(nc,netcdf.getConstant('GLOBAL'),'file_version','Level 0 - Raw data');
netcdf.putatt(nc,netcdf.getConstant('GLOBAL'),'file_version_quality_control','Data in this file has not been quality controlled');
%WHERE
netcdf.putatt(nc,netcdf.getConstant('GLOBAL'),'geospatial_lat_min',min(Y));
netcdf.putatt(nc,netcdf.getConstant('GLOBAL'),'geospatial_lat_max',max(Y));
netcdf.putatt(nc,netcdf.getConstant('GLOBAL'),'geospatial_lat_units','degrees_north');
netcdf.putatt(nc,netcdf.getConstant('GLOBAL'),'geospatial_lon_min',min(X));
netcdf.putatt(nc,netcdf.getConstant('GLOBAL'),'geospatial_lon_max',max(X));
netcdf.putatt(nc,netcdf.getConstant('GLOBAL'),'geospatial_lon_units','degrees_east');
netcdf.putatt(nc,netcdf.getConstant('GLOBAL'),'geospatial_vertical_min',0);
netcdf.putatt(nc,netcdf.getConstant('GLOBAL'),'geospatial_vertical_max',0);
netcdf.putatt(nc,netcdf.getConstant('GLOBAL'),'geospatial_vertical_units','m');
%WHEN
netcdf.putatt(nc,netcdf.getConstant('GLOBAL'),'time_coverage_start',datestr(timenc(1)+datenum(timestart),'yyyy-mm-ddTHH:MM:SSZ'));
netcdf.putatt(nc,netcdf.getConstant('GLOBAL'),'time_coverage_end',datestr(timenc(1)+datenum(timestart)+(1/24),'yyyy-mm-ddTHH:MM:SSZ'));
%WHO
netcdf.putatt(nc,netcdf.getConstant('GLOBAL'),'data_centre_email','info@emii.org.au');
netcdf.putatt(nc,netcdf.getConstant('GLOBAL'),'data_centre','eMarine Information Infrastructure (eMII)');
netcdf.putatt(nc,netcdf.getConstant('GLOBAL'),'author','Mancini, Sebastien; eMII');
netcdf.putatt(nc,netcdf.getConstant('GLOBAL'),'author_email','info@emii.org.au');
netcdf.putatt(nc,netcdf.getConstant('GLOBAL'),'institution_references','http://www.imos.org.au/acorn.html');
%HOW
acorncitation = [' The citation in a list of references is:'...
    ' IMOS, [year-of-data-download], [Title], [data-access-URL], accessed [date-of-access]'];
netcdf.putatt(nc,netcdf.getConstant('GLOBAL'),'citation',acorncitation);
acornacknowledgment = ['Data was sourced from the Integrated Marine Observing System (IMOS)'...
    ' - IMOS is supported by the Australian Government'...
    ' through the National Collaborative Research Infrastructure'...
    ' Strategy (NCRIS) and the Super Science Initiative (SSI)..'];
netcdf.putatt(nc,netcdf.getConstant('GLOBAL'),'acknowledgment',acornacknowledgment);
acorndistribution = ['Data, products and services'...
    ' from IMOS are provided "as is" without any warranty as to fitness'...
    ' for a particular purpose'];
netcdf.putatt(nc,netcdf.getConstant('GLOBAL'),'distribution_statement',acorndistribution);
acorncomment = ['This NetCDF file has been created using the'...
              ' IMOS NetCDF User Manual v1.2.'...
              ' A copy of the document is available at http://imos.org.au/facility_manuals.html'];
netcdf.putatt(nc,netcdf.getConstant('GLOBAL'),'comment',acorncomment);
netcdfabstract = ['These data have not been quality controlled.'...
    ' The ACORN facility is producing NetCDF files with radials data for each station every ten minutes. '...
    ' Radials represent the surface sea water state component '...
    ' along the radial direction from the receiver antenna '...
    ' and are calculated from the shift of and area under '...
    ' the bragg peaks in a Beam Power Spectrum. '...    
    ' The radial values have been calculated using software provided '...
    ' by the manufacturer of the instrument.'...
    ' eMII is using a Matlab program to read all the netcdf files with radial data for two different stations '...
    ' and produce a one hour average product with U and V components of the current.'...
    ' The final product is produced on a regular geographic (latitude longitude) grid'...
    ' More information on the data processing is available through the IMOS MEST '...
    ' http://imosmest.aodn.org.au/geonetwork/srv/en/main.home'];
netcdf.putatt(nc,netcdf.getConstant('GLOBAL'),'abstract',netcdfabstract);
%
%
%Creation of the DIMENSION
%
      TIME_dimid = netcdf.defdim(nc,'TIME',1);
      LATITUDE_dimid = netcdf.defdim(nc,'LATITUDE',comptlat);
      LONGITUDE_dimid = netcdf.defdim(nc,'LONGITUDE',comptlon);
%
%Creation of the VARIABLES
%
TIME_id = netcdf.defVar(nc,'TIME','double',TIME_dimid);
LATITUDE_id = netcdf.defVar(nc,'LATITUDE','double',LATITUDE_dimid);
LONGITUDE_id = netcdf.defVar(nc,'LONGITUDE','double',LONGITUDE_dimid);
SPEED_id = netcdf.defVar(nc,'SPEED','double',[LONGITUDE_dimid,LATITUDE_dimid,TIME_dimid]);
UCUR_id = netcdf.defVar(nc,'UCUR','double',[LONGITUDE_dimid,LATITUDE_dimid,TIME_dimid]);
VCUR_id = netcdf.defVar(nc,'VCUR','double',[LONGITUDE_dimid,LATITUDE_dimid,TIME_dimid]);
%
TIME_quality_control_id = netcdf.defVar(nc,'TIME_quality_control','double',TIME_dimid);
LATITUDE_quality_control_id = netcdf.defVar(nc,'LATITUDE_quality_control','double',LATITUDE_dimid);
LONGITUDE_quality_control_id = netcdf.defVar(nc,'LONGITUDE_quality_control','double',LONGITUDE_dimid);
SPEED_quality_control_id = netcdf.defVar(nc,'SPEED_quality_control','double',[LONGITUDE_dimid,LATITUDE_dimid,TIME_dimid]);
UCUR_quality_control_id = netcdf.defVar(nc,'UCUR_quality_control','double',[LONGITUDE_dimid,LATITUDE_dimid,TIME_dimid]);
VCUR_quality_control_id = netcdf.defVar(nc,'VCUR_quality_control','double',[LONGITUDE_dimid,LATITUDE_dimid,TIME_dimid]);
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
%      netcdf.putatt(nc,TIME_id,'_FillValue',-9999);
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
%Current speed
      netcdf.putatt(nc,SPEED_id,'standard_name','sea_water_speed');
      netcdf.putatt(nc,SPEED_id,'long_name','sea water speed');
      netcdf.putatt(nc,SPEED_id,'units','m s-1');
      netcdf.putatt(nc,SPEED_id,'_FillValue',9999);
%Eastward component of the Current speed
      netcdf.putatt(nc,UCUR_id,'standard_name','eastward_sea_water_velocity');
      netcdf.putatt(nc,UCUR_id,'long_name','sea water velocity U component');
      netcdf.putatt(nc,UCUR_id,'units','m s-1');
      netcdf.putatt(nc,UCUR_id,'_FillValue',9999);
%Northward component of the Current speed
      netcdf.putatt(nc,VCUR_id,'standard_name','northward_sea_water_velocity');
      netcdf.putatt(nc,VCUR_id,'long_name','sea water velocity V component');
      netcdf.putatt(nc,VCUR_id,'units','m s-1');
      netcdf.putatt(nc,VCUR_id,'_FillValue',9999);
%
%QUALITY CONTROL VARIABLES
flagvalues = [0 1 2 3 4 5 6 7 8 9];
%
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
%
      netcdf.putatt(nc,LONGITUDE_quality_control_id,'standard_name','longitude status_flag');
      netcdf.putatt(nc,LONGITUDE_quality_control_id,'long_name','Quality Control flag for longitude');
      netcdf.putatt(nc,LONGITUDE_quality_control_id,'quality_control_conventions','IMOS standard set using IODE flags');
      netcdf.putatt(nc,LONGITUDE_quality_control_id,'quality_control_set',1);
      netcdf.putatt(nc,LONGITUDE_quality_control_id,'_FillValue',9999);
      netcdf.putatt(nc,LONGITUDE_quality_control_id,'valid_min',0);
      netcdf.putatt(nc,LONGITUDE_quality_control_id,'valid_max',9);
      netcdf.putatt(nc,LONGITUDE_quality_control_id,'flag_values',flagvalues);
      netcdf.putatt(nc,LONGITUDE_quality_control_id,'flag_meanings','no_qc_performed good_data probably_good_data bad_data_that_are_potentially_correctable bad_data value_changed not_used not_used interpolated_values missing_values');
%
      netcdf.putatt(nc,SPEED_quality_control_id,'standard_name','sea_water_speed status_flag');
      netcdf.putatt(nc,SPEED_quality_control_id,'long_name','Quality Control flag for sea_water_speed');
      netcdf.putatt(nc,SPEED_quality_control_id,'quality_control_conventions','IMOS standard set using IODE flags');
      netcdf.putatt(nc,SPEED_quality_control_id,'quality_control_set',1);
      netcdf.putatt(nc,SPEED_quality_control_id,'_FillValue',9999);
      netcdf.putatt(nc,SPEED_quality_control_id,'valid_min',0);
      netcdf.putatt(nc,SPEED_quality_control_id,'valid_max',9);
      netcdf.putatt(nc,SPEED_quality_control_id,'flag_values',flagvalues);
      netcdf.putatt(nc,SPEED_quality_control_id,'flag_meanings','no_qc_performed good_data probably_good_data bad_data_that_are_potentially_correctable bad_data value_changed not_used not_used interpolated_values missing_values');
%
      netcdf.putatt(nc,UCUR_quality_control_id,'standard_name','eastward_sea_water_velocity status_flag');
      netcdf.putatt(nc,UCUR_quality_control_id,'long_name','Quality Control flag for eastward_sea_water_velocity');
      netcdf.putatt(nc,UCUR_quality_control_id,'quality_control_conventions','IMOS standard set using IODE flags');
      netcdf.putatt(nc,UCUR_quality_control_id,'quality_control_set',1);
      netcdf.putatt(nc,UCUR_quality_control_id,'_FillValue',9999);
      netcdf.putatt(nc,UCUR_quality_control_id,'valid_min',0);
      netcdf.putatt(nc,UCUR_quality_control_id,'valid_max',9);
      netcdf.putatt(nc,UCUR_quality_control_id,'flag_values',flagvalues);
      netcdf.putatt(nc,UCUR_quality_control_id,'flag_meanings','no_qc_performed good_data probably_good_data bad_data_that_are_potentially_correctable bad_data value_changed not_used not_used interpolated_values missing_values');
%
      netcdf.putatt(nc,VCUR_quality_control_id,'standard_name','northward_sea_water_velocity status_flag');
      netcdf.putatt(nc,VCUR_quality_control_id,'long_name','Quality Control flag for northward_sea_water_velocity');
      netcdf.putatt(nc,VCUR_quality_control_id,'quality_control_conventions','IMOS standard set using IODE flags');
      netcdf.putatt(nc,VCUR_quality_control_id,'quality_control_set',1);
      netcdf.putatt(nc,VCUR_quality_control_id,'_FillValue',9999);
      netcdf.putatt(nc,VCUR_quality_control_id,'valid_min',0);
      netcdf.putatt(nc,VCUR_quality_control_id,'valid_max',9);
      netcdf.putatt(nc,VCUR_quality_control_id,'flag_values',flagvalues);
      netcdf.putatt(nc,VCUR_quality_control_id,'flag_meanings','no_qc_performed good_data probably_good_data bad_data_that_are_potentially_correctable bad_data value_changed not_used not_used interpolated_values missing_values');
%
      netcdf.endDef(nc)
%
%Data values for each variable
%
%
      netcdf.putVar(nc,TIME_id,timenc(:));
      netcdf.putVar(nc,LATITUDE_id,Y(:));
      netcdf.putVar(nc,LONGITUDE_id,X(:));
  for tt = 1:comptlon
      for ww = 1:comptlat
      netcdf.putVar(nc,SPEED_id,[tt-1,ww-1,0],[1,1,1],round(Zrad(ww,tt)*100000)/100000);
      netcdf.putVar(nc,UCUR_id,[tt-1,ww-1,0],[1,1,1],round(Urad(ww,tt)*100000)/100000);
      netcdf.putVar(nc,VCUR_id,[tt-1,ww-1,0],[1,1,1],round(Vrad(ww,tt)*100000)/100000);
      end
  end
%
timenc_qc = timenc;
timenc_qc(:) =1;
Y_qc = Y;
Y_qc(:) =1;
X_qc = X;
X_qc(:) =1;
Zrad_qc = Zrad;
Zrad_qc(:) =0;
%
      netcdf.putVar(nc,TIME_quality_control_id,timenc_qc(:));
      netcdf.putVar(nc,LATITUDE_quality_control_id,Y_qc);
      netcdf.putVar(nc,LONGITUDE_quality_control_id,X_qc);
  for tt = 1:comptlon
      for ww = 1:comptlat
      netcdf.putVar(nc,SPEED_quality_control_id,[tt-1,ww-1,0],[1,1,1],round(Zrad_qc(ww,tt)*100000)/100000);
      netcdf.putVar(nc,UCUR_quality_control_id,[tt-1,ww-1,0],[1,1,1],round(Zrad_qc(ww,tt)*100000)/100000);
      netcdf.putVar(nc,VCUR_quality_control_id,[tt-1,ww-1,0],[1,1,1],round(Zrad_qc(ww,tt)*100000)/100000);
      end
  end
%
%Close the second NetCDF file
	netcdf.close(nc);    
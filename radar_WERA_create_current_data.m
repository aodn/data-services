function [dateforfileSQL] = radar_WERA_create_current_data(nameFile, theoreticalNamefile, site_code, isQC)
%This subfunction will open NetCDF files and process the data in order to
%create a new netCDF file.
%This new NetCDF file will contain the current data (intensity and
%direction) averaged over an hour on a grid.
%

%see files radar_WERA_main.m and config.txt for any changes on the
%following global variables
global logfile
global dfradialdata
global inputdir
global outputdir
global ncwmsdir
global dateFormat

temp = datenum(theoreticalNamefile{1}(15:29), dateFormat);
dateforfileSQL = datestr(temp + (1/24)/2, dateFormat); %+ 30min to adjust the average at the middle of the hour
yearDF = dateforfileSQL(1:4);
monthDF = dateforfileSQL(5:6);
dayDF = dateforfileSQL(7:8);
clear temp

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%In the following loop, I will only access the variable POSITION
%The maximum value of the variable POSITION is then calculated
%
maxPOS = 0;
dimfile = length(nameFile);
ncFileName = cell(dimfile, 1);
for i = 1:dimfile
    if strcmpi(nameFile{i}, ''), continue; end
    
    try 
        ncFileName{i} = fullfile(dfradialdata, nameFile{i}(32:34), nameFile{i}(15:18), ...
            nameFile{i}(19:20), nameFile{i}(21:22), [nameFile{i}(1:end-3), '.nc']);
    
        nc = netcdf.open(ncFileName{i}, 'NC_NOWRITE');
        temp_varid = netcdf.inqVarID(nc, 'POSITION');
        temp = netcdf.getVar(nc, temp_varid);
        POS = temp(:);
        netcdf.close(nc);
    catch e
        % we try to close netCDF file if still open
        netcdf.close(nc);
        
        % print error to logfile and console
				titleErrorFormat = '%s %s %s\r\n';
				titleError = ['Problem in ' func2str(@radar_WERA_create_current_data) ' to read POSITION in the following file'];
				messageErrorFormat = '%s\r\n';
				stackErrorFormat = '\t%s\t(%s: %i)\r\n';
 				clockStr = datestr(clock);
        
        fid_w5 = fopen(logfile, 'a');
        fprintf(fid_w5, titleErrorFormat, clockStr, titleError, ncFileName{i});
        fprintf(titleErrorFormat, clockStr, titleError, ncFileName{i});
        fprintf(fid_w5, messageErrorFormat, e.message);
        fprintf(messageErrorFormat, e.message);
        s = e.stack;
        for k=1:length(s)
            fprintf(fid_w5, stackErrorFormat, s(k).name, s(k).file, s(k).line);
            fprintf(stackErrorFormat, s(k).name, s(k).file, s(k).line);
        end
        fclose(fid_w5);
        
        continue;
    end

    maxtemp = max(POS);
    if (maxtemp > maxPOS)
        maxPOS = maxtemp;
    end
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%Creation of two matrices.
%I will use those two matrices to store all the data available in the
%NetCDF files
%The matrices are filled with NaN
if isQC
    nVar = 10;
else
    nVar = 9;
end
station1 = NaN(maxPOS, nVar, dimfile/2+1);
station2 = NaN(maxPOS, nVar, dimfile/2+1);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
%ACCESS the NetCDF files for the radar stations
k1 = 1;
k2 = 1;
for i = 1:dimfile
    POS     = 1;
    lon     = NaN;
    lat     = NaN;
    speed   = NaN;
    dir     = NaN;
    error   = NaN;
    if isQC, speedQC = NaN; end
    bragg   = NaN;
    
    if ~isempty(ncFileName{i})
    		varName = '';
        try
            %OPEN NETCDF FILE
            nc = netcdf.open(ncFileName{i}, 'NC_NOWRITE');
            varName = 'POSITION';
            temp_varid = netcdf.inqVarID(nc, varName);
            temp = netcdf.getVar(nc, temp_varid);
            POS = temp(:);
            
            %READ ALL VARIABLES
            varName = 'LONGITUDE';
            temp_varid = netcdf.inqVarID(nc, varName);
            temp = netcdf.getVar(nc, temp_varid);
            lon = temp(:);
            
            varName = 'LATITUDE';
            temp_varid = netcdf.inqVarID(nc, varName);
            temp = netcdf.getVar(nc, temp_varid);
            lat = temp(:);
            
            varName = 'ssr_Surface_Radial_Sea_Water_Speed';
            temp_varid = netcdf.inqVarID(nc, varName);
            temp = netcdf.getVar(nc, temp_varid);
            speed = temp(:);
            
            varName = 'ssr_Surface_Radial_Direction_Of_Sea_Water_Velocity';
            temp_varid = netcdf.inqVarID(nc, varName);
            temp = netcdf.getVar(nc, temp_varid);
            dir = temp(:);
            
            %Variable Standard Error
            varName = 'ssr_Surface_Radial_Sea_Water_Speed_Standard_Error';
            temp_varid = netcdf.inqVarID(nc, varName);
            temp = netcdf.getVar(nc, temp_varid);
            error = temp(:);
            
            if isQC
            		varName = 'ssr_Surface_Radial_Sea_Water_Speed_quality_control';
                temp_varid = netcdf.inqVarID(nc, varName);
                temp = netcdf.getVar(nc, temp_varid);
                speedQC = temp(:);
            end
            
            %Variable Bragg signal to noise ratio
            varName = 'ssr_Bragg_Signal_To_Noise';
            temp_varid = netcdf.inqVarID(nc, varName);
            temp = netcdf.getVar(nc, temp_varid);
            bragg = temp(:);
            clear temp;
            
            netcdf.close(nc);
        catch e
            % we try to close netCDF file if still open
            netcdf.close(nc);
            
            % print error to logfile and console
						titleErrorFormat = '%s %s %s\r\n';
						titleError = ['Problem in ' func2str(@radar_WERA_create_current_data) ' to read ' varName ' in the following file'];
						messageErrorFormat = '%s\r\n';
						stackErrorFormat = '\t%s\t(%s: %i)\r\n';
		 				clockStr = datestr(clock);
            
            fid_w5 = fopen(logfile, 'a');
            fprintf(fid_w5, titleErrorFormat, clockStr, titleError, ncFileName{i});
            fprintf(titleErrorFormat, clockStr, titleError, ncFileName{i});
            fprintf(fid_w5, messageErrorFormat, e.message);
            fprintf(messageErrorFormat, e.message);
            s = e.stack;
            for k=1:length(s)
                fprintf(fid_w5, stackErrorFormat, s(k).name, s(k).file, s(k).line);
                fprintf(stackErrorFormat, s(k).name, s(k).file, s(k).line);
            end
            fclose(fid_w5);
        
            % force reinitialising like if we haven't read anything
            POS     = 1;
            lon     = NaN;
            lat     = NaN;
            speed   = NaN;
            dir     = NaN;
            error   = NaN;
            if isQC, speedQC = NaN; end
            bragg   = NaN;
        end
    end
    
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
    %variable 9 : BRAGG ration information
    %variable 10 : Quality control information of the Current Speed
    if (mod(i, 2) == 1)
        station1(POS, 1, k1) = POS;
        station1(POS, 2, k1) = lon;
        station1(POS, 3, k1) = lat;
        station1(POS, 4, k1) = speed;
        station1(POS, 5, k1) = dir;
        
        %Calculation of the U and V component of the radial vector
        station1(POS, 6, k1) = speed .* sin(dir * pi/180);
        station1(POS, 7, k1) = speed .* cos(dir * pi/180);
        
        %STANDARD ERROR of the current speed
        station1(POS, 8, k1) = error;
        
        %Bragg ratio information
        station1(POS, 9, k1) = bragg;
        
        %Quality control information of the Current Speed
        if isQC, station1(POS, 10, k1) = speedQC; end
        k1 = k1 + 1;
    else
        station2(POS, 1, k2) = POS;
        station2(POS, 2, k2) = lon;
        station2(POS, 3, k2) = lat;
        station2(POS, 4, k2) = speed;
        station2(POS, 5, k2) = dir;
        
        %Calculation of the U and V component of the radial vector
        station2(POS, 6, k2) = speed .* sin(dir * pi/180);
        station2(POS, 7, k2) = speed .* cos(dir * pi/180);
        
        %STANDARD ERROR of the current speed
        station2(POS, 8, k2) = error;
        
        %Bragg ratio information
        station2(POS, 9, k2) = bragg;
        
        %Quality control information of the Current Speed
        if isQC, station2(POS, 10, k2) = speedQC; end
        k2 = k2 + 1;
    end
    clear POS lat lon speed dir error bragg speedQC;
end

%%%%%%%%%%%%%%%%%%DATA CHECK%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
%Find grid data points where the current speed is higher than a specified 
%value ("maxnorme") 
%The corresponding values are then replaced by NaN
% maxnorme = 1;
% iTest = (abs(station1(:, 4, 1:end-1)) > maxnorme);
% iTest = repmat(iTest, 1, nVar);
% iTest = cat(3, iTest, false(maxPOS, nVar));
% station1(iTest) = NaN;
% iTest = (abs(station2(:, 4, 1:end-1)) > maxnorme);
% iTest = repmat(iTest, 1, nVar);
% iTest = cat(3, iTest, false(maxPOS, nVar));
% station2(iTest) = NaN;
% clear iTest;

%BRAGG RATIO CRITERIA
%I had a look at the data for different radar stations, and i found that
%when the BRAGG Ratio is under a value of 8 the data is less accurate.
%this value can be changed or removed if necessary
iTest = (station1(:, 9, 1:end-1) < 8);
iTest = repmat(iTest, 1, nVar);
iTest = cat(3, iTest, false(maxPOS, nVar));
station1(iTest) = NaN;

iTest = (station2(:, 9, 1:end-1) < 8);
iTest = repmat(iTest, 1, nVar);
iTest = cat(3, iTest, false(maxPOS, nVar));
station2(iTest) = NaN;
clear iTest;

%QC Criteria on the current speed
%only flags 1 and 2 are kept in output netCDF file
if isQC
    iTest = (station1(:, 10, 1:end-1) < 1) & (station1(:, 10, 1:end-1) > 2);
    iTest = repmat(iTest, 1, nVar);
    iTest = cat(3, iTest, false(maxPOS, nVar));
    station1(iTest) = NaN;
    
    iTest = (station2(:, 10, 1:end-1) < 1) & (station2(:, 10, 1:end-1) > 2);
    iTest = repmat(iTest, 1, nVar);
    iTest = cat(3, iTest, false(maxPOS, nVar));
    station2(iTest) = NaN;
    clear iTest;
end

%STANDARD ERROR CRITERIA
% iTest = ((abs(station1(:, 4, 1:end-1))./station1(:, 8, 1:end-1)) < 1);
% iTest = repmat(iTest, 1, nVar);
% iTest = cat(3, iTest, false(maxPOS, nVar));
% station1(iTest) = NaN;
% iTest = ((abs(station2(:, 4, 1:end-1))./station2(:, 8, 1:end-1)) < 1);
% iTest = repmat(iTest, 1, nVar);
% iTest = cat(3, iTest, false(maxPOS, nVar));
% station2(iTest) = NaN;
% clear iTest;

%NUMBER OF VALID RADIALS CRITERIA
%If for each grid point, there is less than 3 valid data over 1 hour, then
%the data at that grid point is considered as BAD.
checkradial1 = sum(~isnan(station1(:, 6, 1:end-1)), 3);
checkradial2 = sum(~isnan(station2(:, 6, 1:end-1)), 3);

iTest = (checkradial1 < (dimfile/2)/2) | (checkradial2 < (dimfile/2)/2);
if any(iTest)
    station1(iTest, :, :) = NaN;
    station2(iTest, :, :) = NaN;
end
clear checkradial1 checkradial2 iTest

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%Calculation of the average of each variable
%I am calculating the average of the U and V components of the radial
%vector. Then I will use those averaged values to retrieve the value of the 
%current speed and the current direction for each grid point and each radar station
if isQC
    station1(:, 1:nVar-1, end) = nanmean(station1(:, 1:nVar-1, 1:end-1), 3);
    station2(:, 1:nVar-1, end) = nanmean(station2(:, 1:nVar-1, 1:end-1), 3);
    
    qc1 = station1(:, nVar, 1:end-1);
    qc2 = station2(:, nVar, 1:end-1);
    
    iKOQC1 = (qc1 < 1) & (qc1 > 2);
    iKOQC2 = (qc2 < 1) & (qc2 > 2);
    
    qc1(iKOQC1) = NaN;
    qc2(iKOQC2) = NaN;
    
    station1(:, nVar, end) = max(qc1, [], 3);
    station2(:, nVar, end) = max(qc2, [], 3);
else
    station1(:, :, end) = nanmean(station1(:, :, 1:end-1), 3);
    station2(:, :, end) = nanmean(station2(:, :, 1:end-1), 3);
end

%CALCULATION OF THE CURRENT SPEED USING U AND V COMPONENTS
station1(:, 4, end) = sqrt(station1(:, 6, end) .^2 + station1(:, 7, end) .^2);
station2(:, 4, end) = sqrt(station2(:, 6, end) .^2 + station2(:, 7, end) .^2);

%CALCULATION OF THE CURRENT DIRECTION USING U AND V COMPONENTS
station1(:, 5, end) = computeCurrentDirection(station1(:, 6, end), station1(:, 7, end));
station2(:, 5, end) = computeCurrentDirection(station2(:, 6, end), station2(:, 7, end));

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%CALCULATION OF THE RESULTANT VECTOR USING THE TWO RADIALS COMPONENTS
%I USED THE SAME EQUATION AS DESCRIBED ON THE FOLLOWING ARTICLE
% "MEASUREMNT OF OCEAN SURFACE CURRENTS BY THE CRL HF OCEAN SURFACE RADAR
% OF FCMW TYPE. PART 2. CURRENT VECTOR"
%Author: Akitsugu Nadai, Hiroshi Kuroiwa, Masafumi Mizutori and Shin'ichi Sakai
%

i2DataPoint = (station1(:, 1, end) == station2(:, 1, end));

site = nan(sum(i2DataPoint), nVar + 4);
station1 = station1(i2DataPoint, :, :);
station2 = station2(i2DataPoint, :, :);
clear i2DataPoint;

%LONGITUDE
site(:, 1) = station1(:, 2, end);
%LATITUDE
site(:, 2) = station1(:, 3, end);
%POSITION
site(:, 7) = station1(:, 1, end);
%EASTWARD COMPONENT OF THE VELOCITY
site(:, 3) = (station1(:, 4, end) .* cos(station2(:, 5, end) * pi/180) - station2(:, 4, end) .* cos(station1(:, 5, end) * pi/180)) ...
    ./ sin((station1(:, 5, end) - station2(:, 5, end)) * pi/180);
%NORTHWARD COMPONENT OF THE VELOCITY
site(:, 4) = (station2(:, 4, end) .* sin(station1(:, 5, end) * pi/180) - station1(:, 4, end) .* sin(station2(:, 5, end) * pi/180)) ...
    ./ sin((station1(:, 5, end) - station2(:, 5, end)) * pi/180);
%NORME DE LA VITESSE
site(:, 5) = sqrt(site(:, 3).^2 + site(:,4).^2);
%EASTWARD COMPONENT  OF THE STANDARD ERROR OF THE VELOCITY
site(:, 8) = (station1(:, 8, end) .* cos(station2(:, 5, end) * pi/180) - station2(:, 8, end) .* cos(station1(:, 5, end) * pi/180)) ...
    ./ sin((station1(:, 5, end) - station2(:, 5, end)) * pi/180);
%NORTHWARD COMPONENT OF THE STANDARD ERROR OF THE VELOCITY
site(:, 9) = (station2(:, 8, end) .* sin(station1(:, 5, end) * pi/180) - station1(:, 8, end) .* sin(station2(:, 5, end) * pi/180)) ...
    ./ sin((station1(:, 5, end) - station2(:, 5, end)) * pi/180);
%NORME DE LA STANDARD ERROR DE LA VITESSE
site(:, 10) = sqrt(site(:, 8).^2 + site(:,9).^2);
%RATIO ENTRE LES NORMES DE LA STANDARD ERROR ET LA VITESSE
site(:, 11) = site(:, 10) ./ site(:, 5);
%CORRESPONDING BRAGG RATIO OF STATION 1
site(:, 12) = station1(:, 9, end);
%CORRESPONDING BRAGG RATIO OF STATION 2
site(:, 13) = station2(:, 9, end);
%CALCULATION OF THE DIRECTION OF THE CURRENT SPEED
site(:, 6) = computeCurrentDirection(site(:, 3), site(:, 4));
%CURRENT SPEED QC INFORMATION
if isQC
    site(:, 14) = max(station1(:, nVar, end), station2(:, nVar, end));
end

%Find grid data points where the current speed is higher than a specified 
%value ("1.5 m/s") 
%The corresponding values are then replaced by NaN
%
% iTest = (site(:, 5) > 1.5);
% site(iTest, 3:6) = NaN;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%NETCDF OUTPUT
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
%NECESSITY TO IMPORT THE LATITUDE AND THE LONGITUDE VALUES OF THE OUTPUT GRID 
%
switch site_code
    case {'SAG', 'CWI', 'CSP'}
        fileLat = 'LAT_SAG.dat';
        fileLon = 'LON_SAG.dat';
        
    case {'GBR', 'TAN', 'LEI', 'CBG'}
        %COMMENT: THE GRID CHANGED ON THE 01/03/2011 at 04:04 to be 72*64 (4km grid)
        %the previous grid was a 80*80 (3km spacing)
        dateChange = '20110301T050000';
        %LATITUDE VALUE OF THE GRID
        if (datenum(theoreticalNamefile{1}(15:29), dateFormat) < datenum(dateChange, dateFormat))
            fileLat = 'LAT_CBG.dat';
            fileLon = 'LON_CBG.dat';
        else
            fileLat = 'LAT_CBG_grid022011.dat';
            fileLon = 'LON_CBG_grid022011.dat';
        end
        
    case {'PCY', 'FRE', 'GUI', 'ROT'}
        fileLat = 'LAT_ROT.dat';
        fileLon = 'LON_ROT.dat';
        
    case {'COF', 'RRK', 'NNB'}
        fileLat = 'LAT_COF_26032012.dat';
        fileLon = 'LON_COF_26032012.dat';

end

%LATITUDE VALUE OF THE GRID
fid = fopen(fullfile(inputdir, fileLat), 'r');
line = fgetl(fid);
datalat(1) = str2double(line);
i = 2;
while line ~= -1,
    line = fgetl(fid);
    datalat(i) = str2double(line);
    i = i + 1;
end
fclose(fid);
dimlat = length(datalat);
Y = datalat(1:dimlat-1);

%LONGITUDE VALUE OF THE GRID
fid = fopen(fullfile(inputdir, fileLon), 'r');
line = fgetl(fid);
datalon(1) = str2double(line);
i = 2;
while line ~= -1,
    line = fgetl(fid);
    datalon(i) = str2double(line);
    i = i + 1;
end
fclose(fid);
dimlon = length(datalon);
X = datalon(1:dimlon-1);

comptlon = length(X);
comptlat = length(Y);

Zrad = NaN(comptlat, comptlon);
Urad = NaN(comptlat, comptlon);
Vrad = NaN(comptlat, comptlon);
QCrad = NaN(comptlat, comptlon);

% let's find out the i lines and j columns from the POSITION
POS = site(:, 7);
totalPOS = (1:1:comptlat*comptlon)';
iMember = ismember(totalPOS, POS);
iMember = reshape(iMember, comptlat, comptlon);

Zrad(iMember) = site(:, 5);
Urad(iMember) = site(:, 3);
Vrad(iMember) = site(:, 4);
if isQC
    QCrad(iMember) = site(:, 14);
else
    QCrad(iMember) = 0;
end

%NetCDF file creation
timestart = [1950, 1, 1, 0, 0, 0];
timefin = [str2double(theoreticalNamefile{1}(15:18)), str2double(theoreticalNamefile{1}(19:20)), str2double(theoreticalNamefile{1}(21:22)), ...
    str2double(theoreticalNamefile{1}(24:25)), str2double(theoreticalNamefile{1}(26:27)), str2double(theoreticalNamefile{1}(28:29))];

% time in averaged netCDF file is first file date + 30min to adjust the average at the middle of the hour
timenc = (etime(timefin, timestart))/(60*60*24) + (1/24)/2;

timeStr = datestr(timenc(1) + datenum(timestart), 'yyyy-mm-ddTHH:MM:SSZ');

if isQC
    fileVersionCode = 'FV01';
else
    fileVersionCode = 'FV00';
end

%EXPORT OUTPUT FILES

%this netcdf file will then be available on the datafabric and on the qcif opendap server
%
switch site_code
    case {'SAG', 'CWI', 'CSP'}
        pathoutput = fullfile(outputdir, 'SAG');
        
    case {'GBR', 'TAN', 'LEI', 'CBG'}
        pathoutput = fullfile(outputdir, 'CBG');

    case {'PCY', 'FRE', 'GUI', 'ROT'}
        pathoutput = fullfile(outputdir, 'ROT');

    case {'COF', 'RRK', 'NNB'}
        pathoutput = fullfile(outputdir, 'COF');
end

finalPathOutput = fullfile(pathoutput, yearDF, monthDF, dayDF);
if (~exist(finalPathOutput, 'dir'))
    mkdir(finalPathOutput);
end

netcdfFilename = ['IMOS_ACORN_V_', dateforfileSQL, 'Z_', site_code, '_' fileVersionCode '_1-hour-avg.nc'];
netcdfoutput = fullfile(finalPathOutput, netcdfFilename);

createNetCDF(netcdfoutput, site_code, isQC, timenc, timeStr, X, Y, Zrad, Urad, Vrad, QCrad, true, 6);

end

function stationCurrentDirection = computeCurrentDirection(u, v)

stationCurrentDirection = abs(atan(u ./ v) *180/pi);

iUzero  = (u == 0);
iVzero  = (v == 0);
iUpos   = (u > 0);
iVpos   = (v > 0);
iUneg   = (u < 0);
iVneg   = (v < 0);

iNorth  = iUzero & iVpos;
iSouth  = iUzero & iVneg;
iEast   = iUpos & iVzero;
iWest   = iUneg & iVzero;

iNorthEast  = iUpos & iVpos;
iSouthEast  = iUpos & iVneg;
iNorthWest  = iUneg & iVpos;
iSouthWest  = iUneg & iVneg;

if any(iNorth)
    stationCurrentDirection(iNorth) = 0;
end
if any(iSouth)
    stationCurrentDirection(iSouth) = 180;
end
if any(iEast)
    stationCurrentDirection(iEast) = 90;
end
if any(iWest)
    stationCurrentDirection(iWest) = 270;
end
if any(iNorthEast)
    % all good, we do nothing
end
if any(iSouthEast)
    stationCurrentDirection(iSouthEast) = 180 - stationCurrentDirection(iSouthEast);
end
if any(iSouthWest)
    stationCurrentDirection(iSouthWest) = 180 + stationCurrentDirection(iSouthWest);
end
if any(iNorthWest)
    stationCurrentDirection(iNorthWest) = 360 - stationCurrentDirection(iNorthWest);
end

end

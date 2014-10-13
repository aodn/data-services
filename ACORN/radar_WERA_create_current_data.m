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
global dateFormat

temp = datenum(theoreticalNamefile{1}(15:29), dateFormat);
dateforfileSQL = datestr(temp + (1/24)/2, dateFormat); %+ 30min to adjust the average at the middle of the hour
yearDF  = dateforfileSQL(1:4);
monthDF = dateforfileSQL(5:6);
dayDF   = dateforfileSQL(7:8);
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
        
        % print detailed error to logfile and short message to console
        titleErrorFormat = '%s %s %s\r\n';
        titleError = ['Problem in ' func2str(@radar_WERA_create_current_data) ' to read POSITION in the following file'];
        messageErrorFormat = '%s\r\n';
        stackErrorFormat = '\t%s\t(%s: %i)\r\n';
        clockStr = datestr(clock);
        
        fid_w5 = fopen(logfile, 'a');
        fprintf(fid_w5, titleErrorFormat, clockStr, titleError, ncFileName{i});
        fprintf(fid_w5, messageErrorFormat, e.message);
        s = e.stack;
        for k=1:length(s)
            fprintf(fid_w5, stackErrorFormat, s(k).name, s(k).file, s(k).line);
        end
        fclose(fid_w5);
        
        fprintf(titleErrorFormat, clockStr, titleError, ncFileName{i});
        
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
%radial NetCDF files
%The matrices are first filled with NaN
varNames = {'POS', 'lon', 'lat', 'speed', 'dir', 'u', 'v', 'error', 'bragg', 'speedQC'};
varTypes = {'single', 'double', 'double', 'single', 'single', 'single', 'single', 'single', 'single', 'single'};
if ~isQC
    varNames(end) = [];
end
nVar = length(varNames);

station1 = struct;
station2 = struct;
station1Mean = struct;
station2Mean = struct;
for i = 1:nVar
    station1.(varNames{i}) = NaN(maxPOS, dimfile/2, varTypes{i});
    station2.(varNames{i}) = NaN(maxPOS, dimfile/2, varTypes{i});
    station1Mean.(varNames{i}) = NaN(maxPOS, 1, varTypes{i});
    station2Mean.(varNames{i}) = NaN(maxPOS, 1, varTypes{i});
end

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
            fillValue = netcdf.getAtt(nc, temp_varid, '_FillValue');
            iPOSNaN = POS == fillValue;
            POS(iPOSNaN) = [];
            
            %READ ALL VARIABLES
            varName = 'LONGITUDE';
            temp_varid = netcdf.inqVarID(nc, varName);
            temp = netcdf.getVar(nc, temp_varid);
            lon = temp(:);
            fillValue = netcdf.getAtt(nc, temp_varid, '_FillValue');
            iNaN = lon == fillValue;
            lon(iNaN) = NaN;
            lon(iPOSNaN) = [];
            
            varName = 'LATITUDE';
            temp_varid = netcdf.inqVarID(nc, varName);
            temp = netcdf.getVar(nc, temp_varid);
            lat = temp(:);
            fillValue = netcdf.getAtt(nc, temp_varid, '_FillValue');
            iNaN = lat == fillValue;
            lat(iNaN) = NaN;
            lat(iPOSNaN) = [];
            
            varName = 'ssr_Surface_Radial_Sea_Water_Speed';
            temp_varid = netcdf.inqVarID(nc, varName);
            temp = netcdf.getVar(nc, temp_varid);
            speed = temp(:);
            fillValue = netcdf.getAtt(nc, temp_varid, '_FillValue');
            iNaN = speed == fillValue;
            speed(iNaN) = NaN;
            speed(iPOSNaN) = [];
            
            varName = 'ssr_Surface_Radial_Direction_Of_Sea_Water_Velocity';
            temp_varid = netcdf.inqVarID(nc, varName);
            temp = netcdf.getVar(nc, temp_varid);
            dir = temp(:);
            fillValue = netcdf.getAtt(nc, temp_varid, '_FillValue');
            iNaN = dir == fillValue;
            dir(iNaN) = NaN;
            dir(iPOSNaN) = [];
            
            %Variable Standard Error
            varName = 'ssr_Surface_Radial_Sea_Water_Speed_Standard_Error';
            temp_varid = netcdf.inqVarID(nc, varName);
            temp = netcdf.getVar(nc, temp_varid);
            error = temp(:);
            fillValue = netcdf.getAtt(nc, temp_varid, '_FillValue');
            iNaN = error == fillValue;
            error(iNaN) = NaN;
            error(iPOSNaN) = [];
            
            if isQC
                varName = 'ssr_Surface_Radial_Sea_Water_Speed_quality_control';
                temp_varid = netcdf.inqVarID(nc, varName);
                temp = netcdf.getVar(nc, temp_varid);
                speedQC = temp(:);
                fillValue = netcdf.getAtt(nc, temp_varid, '_FillValue');
                iNaN = speedQC == fillValue;
                speedQC(iNaN) = NaN;
                speedQC(iPOSNaN) = [];
            end
            
            %Variable Bragg signal to noise ratio
            varName = 'ssr_Bragg_Signal_To_Noise';
            temp_varid = netcdf.inqVarID(nc, varName);
            temp = netcdf.getVar(nc, temp_varid);
            bragg = temp(:);
            fillValue = netcdf.getAtt(nc, temp_varid, '_FillValue');
            iNaN = bragg == fillValue;
            bragg(iNaN) = NaN;
            bragg(iPOSNaN) = [];
            
            clear temp iNaN iPOSNaN fillValue;
            
            netcdf.close(nc);
        catch e
            % we try to close netCDF file if still open
            netcdf.close(nc);
            
            % print detailed error to logfile and short message to console
            titleErrorFormat = '%s %s %s\r\n';
            titleError = ['Problem in ' func2str(@radar_WERA_create_current_data) ' to read ' varName ' in the following file'];
            messageErrorFormat = '%s\r\n';
            stackErrorFormat = '\t%s\t(%s: %i)\r\n';
            clockStr = datestr(clock);
            
            fid_w5 = fopen(logfile, 'a');
            fprintf(fid_w5, titleErrorFormat, clockStr, titleError, ncFileName{i});
            fprintf(fid_w5, messageErrorFormat, e.message);
            s = e.stack;
            for k=1:length(s)
                fprintf(fid_w5, stackErrorFormat, s(k).name, s(k).file, s(k).line);
            end
            fclose(fid_w5);
            
            fprintf(titleErrorFormat, clockStr, titleError, ncFileName{i});
        
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
    
    %STORE THE DATA IN THE VARIABLE "STATION1" or "STATION2"
    % POS
    % LATITUDE
    % LONGITUDE
    % SPEED (The value can be positive [when the current is going
    % away from the radar station] or negative [when the current is going toward
    % the radar station])
    % DIRECTION (value calculated between the radar station and the grid point)
    % STANDARD ERROR of the current speed
    % BRAGG ration information
    % Quality control information of the Current Speed
    if (mod(i, 2) == 1)
        for j = 1:nVar
            if strcmpi(varNames{j}, 'u')
                %Calculation of the U component of the radial vector
                station1.u(POS, k1) = speed .* sin(dir * pi/180);
            elseif strcmpi(varNames{j}, 'v')
                %Calculation of the V component of the radial vector
                station1.v(POS, k1) = speed .* cos(dir * pi/180);
            else
                station1.(varNames{j})(POS, k1) = eval(varNames{j});
            end
        end
        
        k1 = k1 + 1;
    else
        for j = 1:nVar
            if strcmpi(varNames{j}, 'u')
                %Calculation of the U component of the radial vector
                station2.u(POS, k2) = speed .* sin(dir * pi/180);
            elseif strcmpi(varNames{j}, 'v')
                %Calculation of the V component of the radial vector
                station2.v(POS, k2) = speed .* cos(dir * pi/180);
            else
                station2.(varNames{j})(POS, k2) = eval(varNames{j});
            end
        end

        k2 = k2 + 1;
    end
    clear POS lat lon speed dir error bragg speedQC;
end

%%%%%%%%%%%%%%%%%%DATA CHECK%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
%Find grid data points where the current speed is higher than a specified 
%value ("maxnorme") 
%The corresponding values are then replaced by NaN
switch site_code
    case {'GBR', 'CBG'} 
        maxnorme = 2;
    otherwise
        maxnorme = 3;
end
iTest = (abs(station1.speed) >= maxnorme);
for j = 1:nVar
    station1.(varNames{j})(iTest) = NaN;
end

iTest = (abs(station2.speed) >= maxnorme);
for j = 1:nVar
    station1.(varNames{j})(iTest) = NaN;
end
clear iTest;

%BRAGG RATIO CRITERIA
% I had a look at the data for different radar stations, and i found that
% when signal/noise ratio is under a value of 8dB the data is less accurate.
% this value can be changed or removed if necessary
iTest1 = (station1.bragg < 8);
iTest2 = (station2.bragg < 8);
for j = 1:nVar
    station1.(varNames{j})(iTest1) = NaN;
    station2.(varNames{j})(iTest2) = NaN;
end
% When signal/noise ratio is between 8 and 10dB we can set the flag to 2 if
% relevant
if isQC
    iTest1 = (station1.bragg >= 8) & (station1.bragg < 10);
    iTest2 = (station2.bragg >= 8) & (station2.bragg < 10);
    iGood1 = station1.speedQC == 1;
    iGood2 = station2.speedQC == 1;
    station1.speedQC(iTest1 & iGood1) = 2;
    station2.speedQC(iTest2 & iGood2) = 2;
    clear iTest1 iTest2 iGood1 iGood2
end

%QC Criteria on the current speed
%only flags 1 and 2 are kept in output netCDF file
if isQC
    iTest1 = (station1.speedQC < 1) | (station1.speedQC > 2);
    iTest2 = (station2.speedQC < 1) | (station2.speedQC > 2);
    for j = 1:nVar
        station1.(varNames{j})(iTest1) = NaN;
        station2.(varNames{j})(iTest2) = NaN;
    end
    clear iTest1 iTest2
end

%STANDARD ERROR CRITERIA
% iTest = ((abs(station1.error./station1.error < 1);
% for j = 1:nVar
%     station1.(varNames{j})(iTest) = NaN;
% end
%
% iTest = ((abs(station2.error./station2.error < 1);
% for j = 1:nVar
%     station1.(varNames{j})(iTest) = NaN;
% end
% clear iTest;

%NUMBER OF VALID RADIALS CRITERIA
%If for each grid point, there is less than 3 valid data over 1 hour, then
%the data at that grid point is considered as BAD.
checkradial1 = sum(~isnan(station1.u), 2);
checkradial2 = sum(~isnan(station2.u), 2);

iTest = (checkradial1 < (dimfile/2)/2) | (checkradial2 < (dimfile/2)/2);
if any(iTest)
    for j = 1:nVar
        station1.(varNames{j})(iTest, :) = NaN;
        station2.(varNames{j})(iTest, :) = NaN;
    end
end
clear checkradial1 checkradial2 iTest

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%Calculation of the average of each variable
%I am calculating the average of the U and V components of the radial
%vector. Then I will use those averaged values to retrieve the value of the 
%current speed and the current direction for each grid point and each radar station
for j = 1:nVar
    switch varNames{j}
        case 'error'
            iNaN1 = isnan(station1.error);
            iNaN2 = isnan(station2.error);
            
            iNaN1Mean = all(iNaN1, 2);
            iNaN2Mean = all(iNaN2, 2);
            
            sigma1 = station1.error(~iNaN1Mean, :);
            sigma2 = station2.error(~iNaN2Mean, :);
            
            iNaN1 = isnan(sigma1);
            iNaN2 = isnan(sigma2);
            
            nSigma1 = sum(~iNaN1, 2);
            nSigma2 = sum(~iNaN2, 2);
            
            sigma1(iNaN1) = 0;
            sigma2(iNaN2) = 0;
            
            station1Mean.error(~iNaN1Mean) = sqrt(sum(sigma1.^2, 2)./nSigma1);
            station2Mean.error(~iNaN2Mean) = sqrt(sum(sigma2.^2, 2)./nSigma2);
            
        case 'speedQC'
            station1Mean.speedQC = max(station1.speedQC, [], 2);
            station2Mean.speedQC = max(station2.speedQC, [], 2);
            
        otherwise
            station1Mean.(varNames{j}) = nanmean(station1.(varNames{j}), 2);
            station2Mean.(varNames{j}) = nanmean(station2.(varNames{j}), 2);
    end
end

% %CALCULATION OF THE CURRENT SPEED USING U AND V COMPONENTS
% station1Mean.speed = sqrt(station1Mean.u .^2 + station1Mean.v .^2);
% station2Mean.speed = sqrt(station2Mean.u .^2 + station2Mean.v .^2);
% 
% %CALCULATION OF THE CURRENT DIRECTION USING U AND V COMPONENTS
% station1Mean.dir = computeCurrentDirection(station1Mean.u, station1Mean.v);
% station2Mean.dir = computeCurrentDirection(station2Mean.u, station2Mean.v);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%CALCULATION OF THE RESULTANT VECTOR USING THE TWO RADIALS COMPONENTS
%I USED THE SAME EQUATION AS DESCRIBED ON THE FOLLOWING ARTICLE
% "MEASUREMENT OF OCEAN SURFACE CURRENTS BY THE CRL HF OCEAN SURFACE RADAR
% OF FCMW TYPE. PART 2. CURRENT VECTOR"
%Author: Akitsugu Nadai, Hiroshi Kuroiwa, Masafumi Mizutori and Shin'ichi Sakai
%

i2DataPoint = (station1Mean.POS == station2Mean.POS);

for j = 1:nVar
    site.(varNames{j}) = NaN(sum(i2DataPoint), nVar + 4);
    
    station1.(varNames{j}) = station1.(varNames{j})(i2DataPoint, :);
    station2.(varNames{j}) = station2.(varNames{j})(i2DataPoint, :);
    
    station1Mean.(varNames{j}) = station1Mean.(varNames{j})(i2DataPoint, :);
    station2Mean.(varNames{j}) = station2Mean.(varNames{j})(i2DataPoint, :);
end
clear i2DataPoint;

% number of observations per grid point and station
site.nObs1 = sum(~isnan(station1.u), 2);
site.nObs2 = sum(~isnan(station2.u), 2);

for j = 1:nVar
    switch varNames{j}
        case {'lon', 'lat', 'POS'}
            site.(varNames{j}) = station1Mean.(varNames{j});
            
        case 'speedQC'
            site.(varNames{j}) = max(station1Mean.(varNames{j}), station2Mean.(varNames{j}));
            
        case 'u'
            site.(varNames{j}) = (station1Mean.speed .* cos(station2Mean.dir * pi/180) - station2Mean.speed .* cos(station1Mean.dir * pi/180)) ...
    ./ sin((station1Mean.dir - station2Mean.dir) * pi/180);

        case 'v'
            site.(varNames{j}) = (station2Mean.speed .* sin(station1Mean.dir * pi/180) - station1Mean.speed .* sin(station2Mean.dir * pi/180)) ...
    ./ sin((station1Mean.dir - station2Mean.dir) * pi/180);

        case 'error'
            site.u_error = sqrt((station2Mean.error.^2 .* cos(station1Mean.dir * pi/180).^2 + station1Mean.error.^2 .* cos(station2Mean.dir * pi/180).^2) ...
    ./ sin((station1Mean.dir - station2Mean.dir) * pi/180).^2);
            site.v_error = sqrt((station2Mean.error.^2 .* sin(station1Mean.dir * pi/180).^2 + station1Mean.error.^2 .* sin(station2Mean.dir * pi/180).^2) ...
    ./ sin((station1Mean.dir - station2Mean.dir) * pi/180).^2);
    end
end


% %SPEED NORM
% site(:, 5) = sqrt(site(:, 3).^2 + site(:,4).^2);
% %EASTWARD COMPONENT  OF THE STANDARD ERROR OF THE VELOCITY
% site(:, 8) = (station1(:, 8, end) .* cos(station2(:, 5, end) * pi/180) - station2(:, 8, end) .* cos(station1(:, 5, end) * pi/180)) ...
%     ./ sin((station1(:, 5, end) - station2(:, 5, end)) * pi/180);
% %NORTHWARD COMPONENT OF THE STANDARD ERROR OF THE VELOCITY
% site(:, 9) = (station2(:, 8, end) .* sin(station1(:, 5, end) * pi/180) - station1(:, 8, end) .* sin(station2(:, 5, end) * pi/180)) ...
%     ./ sin((station1(:, 5, end) - station2(:, 5, end)) * pi/180);
% %SPEED STANDARD ERROR NORM
% site(:, 10) = sqrt(site(:, 8).^2 + site(:,9).^2);
% %SPEED STANDARD ERROR NORM OVER SPEED NORM RATIO
% site(:, 11) = site(:, 10) ./ site(:, 5);
% %CORRESPONDING BRAGG RATIO OF STATION 1
% site(:, 12) = station1(:, 9, end);
% %CORRESPONDING BRAGG RATIO OF STATION 2
% site(:, 13) = station2(:, 9, end);
% %CALCULATION OF THE DIRECTION OF THE CURRENT SPEED
% site(:, 6) = computeCurrentDirection(site(:, 3), site(:, 4));

% Find grid data points where the current speed is higher than a specified 
% value ("maxnorme") and give them a flag 3 when relevant
if isQC
    iTest = (site.u >= maxnorme) | (site.v >= maxnorme);
    iGood = (site.speedQC == 1) | (site.speedQC == 2);
    site.speedQC(iTest & iGood) = 3;
end

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
        fileLat  = 'LAT_SAG.dat';
        fileLon  = 'LON_SAG.dat';
        fileGDOP = 'SAG.gdop';
        
    case {'GBR', 'TAN', 'LEI', 'CBG'}
        %COMMENT: THE GRID CHANGED ON THE 01/03/2011 at 04:04 to be 72*64 (4km grid)
        %the previous grid was a 80*80 (3km spacing)
        % however, FV01 files have been back-processed so that data prior
        % to 01/03/2011 actually fits on the new grid.
        dateChange = '20110301T040500';
        %LATITUDE VALUE OF THE GRID
        if (datenum(theoreticalNamefile{end}(15:29), dateFormat) < datenum(dateChange, dateFormat)) && ~isQC
            fileLat = 'LAT_CBG-before_20110301T040500.dat';
            fileLon = 'LON_CBG-before_20110301T040500.dat';
            fileGDOP = 'CBG-before_20110301T040500.gdop';
        else
            fileLat = 'LAT_CBG.dat';
            fileLon = 'LON_CBG.dat';
            fileGDOP = 'CBG.gdop';
        end
        
    case {'PCY', 'FRE', 'GUI', 'ROT'}
        fileLat  = 'LAT_ROT.dat';
        fileLon  = 'LON_ROT.dat';
        fileGDOP = 'ROT.gdop';
        
    case {'COF', 'RRK', 'NNB'}
        fileLat  = 'LAT_COF.dat';
        fileLon  = 'LON_COF.dat';
        fileGDOP = 'COF.gdop';

end

% LATITUDE VALUES OF THE GRID
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

% LONGITUDE VALUES OF THE GRID
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

% GDOP VALUES OF THE GRID
formatGDOP = '%*d%*d%*f%*f%f%*d';

fid = fopen(fullfile(inputdir, fileGDOP), 'r');
dataGDOP = textscan(fid, formatGDOP, 'HeaderLines', 1);
fclose(fid);

dataGDOP = dataGDOP{1};
dataGDOP = reshape(dataGDOP, comptlat, comptlon);

% let's define the QC values according to GDOP
iSuspectGDOP    = (dataGDOP >= 150 & dataGDOP < 160) | (dataGDOP > 20 & dataGDOP <= 30);
iBadGDOP        = dataGDOP >= 160 | dataGDOP <= 20;

if isQC
    qcGDOP = ones(comptlat, comptlon);
else
    qcGDOP = zeros(comptlat, comptlon); % passing the GDOP test in the case of FV00 doesn't mean the data is good.
end

qcGDOP(iSuspectGDOP) = 3;
qcGDOP(iBadGDOP) = 4;

Urad = NaN(comptlat, comptlon);
Vrad = NaN(comptlat, comptlon);
UsdRad = NaN(comptlat, comptlon);
VsdRad = NaN(comptlat, comptlon);
QCrad = NaN(comptlat, comptlon);
nObsRad = NaN(comptlat, comptlon, 2);

% let's find out the i lines and j columns from the POSITION
totalPOS = (1:1:comptlat*comptlon)';
iMember = ismember(totalPOS, site.POS);
iMember = reshape(iMember, comptlat, comptlon);

Urad(iMember) = site.u;
Vrad(iMember) = site.v;
UsdRad(iMember) = site.u_error;
VsdRad(iMember) = site.v_error;
if isQC
    QCrad(iMember) = site.speedQC;
else
    QCrad(iMember) = 0;
end
iMember1 = repmat(iMember, [1, 1, 2]);
iMember2 = iMember1;
iMember1(:, :, 2) = false;
iMember2(:, :, 1) = false;
nObsRad(iMember1) = site.nObs1;
nObsRad(iMember2) = site.nObs2;

% let's update QCrad with qcGDOP when qcDOP is higher and QCrad not NaN
iNonQCrad = QCrad == 0;
iGoodQCrad = QCrad == 1;
iProbGoodQCrad = QCrad == 2;
iProbBadQCrad = QCrad == 3;

if any(any(iNonQCrad)),                     QCrad(iNonQCrad)                        = qcGDOP(iNonQCrad);                        end
if any(any(iGoodQCrad & iSuspectGDOP)),     QCrad(iGoodQCrad & iSuspectGDOP)        = qcGDOP(iGoodQCrad & iSuspectGDOP);        end
if any(any(iProbGoodQCrad & iSuspectGDOP)), QCrad(iProbGoodQCrad & iSuspectGDOP)    = qcGDOP(iProbGoodQCrad & iSuspectGDOP);    end
if any(any(iGoodQCrad & iBadGDOP)),         QCrad(iGoodQCrad & iBadGDOP)            = qcGDOP(iGoodQCrad & iBadGDOP);            end
if any(any(iProbGoodQCrad & iBadGDOP)),     QCrad(iProbGoodQCrad & iBadGDOP)        = qcGDOP(iProbGoodQCrad & iBadGDOP);        end
if any(any(iProbBadQCrad & iBadGDOP)),      QCrad(iProbBadQCrad & iBadGDOP)         = qcGDOP(iProbBadQCrad & iBadGDOP);         end

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

createNetCDF(netcdfoutput, site_code, isQC, timenc, timeStr, X, Y, Urad, Vrad, UsdRad, VsdRad, dataGDOP, QCrad, nObsRad, true, 6);

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

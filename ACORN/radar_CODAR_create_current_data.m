function [dateforfileSQL] = radar_CODAR_create_current_data(filename, site_code, isQC)
%This subfunction will open NetCDF files and process the data in order to
%create a new netCDF file.
%This new NetCDF file will contain the current data (intensity and
%direction) averaged over an hour on a grid.
%

%see files radar_CODAR_main.m and config.txt for any changes on the
%following global variables
global dfradialdata
global inputdir
global outputdir
global dateFormat

temp = datenum(filename(14:28), dateFormat);
dateforfileSQL = datestr(temp, dateFormat);
yearDF  = dateforfileSQL(1:4);
monthDF = dateforfileSQL(5:6);
dayDF   = dateforfileSQL(7:8);
clear temp

%ACCESSING THE DATA
filePath = fullfile(dfradialdata, site_code, filename(14:17), filename(18:19), filename(20:21), [filename(1:end-3), '.nc']);
ncid = netcdf.open(filePath, 'NC_NOWRITE');
temp_varid = netcdf.inqVarID(ncid, 'POSITION');
temp = netcdf.getVar(ncid, temp_varid);
POS = temp(:);
fillValue = netcdf.getAtt(ncid, temp_varid, '_FillValue');
iPOSNaN = POS == fillValue;
POS(iPOSNaN) = [];

temp_varid = netcdf.inqVarID(ncid, 'ssr_Surface_Eastward_Sea_Water_Velocity');
temp = netcdf.getVar(ncid, temp_varid);
EAST = temp(:);
fillValue = netcdf.getAtt(ncid, temp_varid, '_FillValue');
iNaN = EAST == fillValue;
EAST(iNaN) = NaN;
EAST(iPOSNaN) = [];

temp_varid = netcdf.inqVarID(ncid, 'ssr_Surface_Eastward_Sea_Water_Velocity_Standard_Error');
temp = netcdf.getVar(ncid, temp_varid);
EASTsd = temp(:);
fillValue = netcdf.getAtt(ncid, temp_varid, '_FillValue');
iNaN = EASTsd == fillValue;
EASTsd(iNaN) = NaN;
EASTsd(iPOSNaN) = [];

temp_varid = netcdf.inqVarID(ncid, 'ssr_Surface_Northward_Sea_Water_Velocity');
temp = netcdf.getVar(ncid, temp_varid);
NORTH = temp(:);
fillValue = netcdf.getAtt(ncid, temp_varid, '_FillValue');
iNaN = NORTH == fillValue;
NORTH(iNaN) = NaN;
NORTH(iPOSNaN) = [];

temp_varid = netcdf.inqVarID(ncid, 'ssr_Surface_Northward_Sea_Water_Velocity_Standard_Error');
temp = netcdf.getVar(ncid, temp_varid);
NORTHsd = temp(:);
fillValue = netcdf.getAtt(ncid, temp_varid, '_FillValue');
iNaN = NORTHsd == fillValue;
NORTHsd(iNaN) = NaN;
NORTHsd(iPOSNaN) = [];

temp_varid = netcdf.inqVarID(ncid, 'seasonde_LLUV_S1CN');
temp = netcdf.getVar(ncid, temp_varid);
NOBS1 = double(temp(:));
iNaN = NOBS1 == 0;
NOBS1(iNaN) = NaN;
NOBS1(iPOSNaN) = [];

iNObs = 2;
NOBS2 = NaN;
while all(isnan(NOBS2))
    nObs2Name = ['seasonde_LLUV_S' num2str(iNObs) 'CN'];

    temp_varid = netcdf.inqVarID(ncid, nObs2Name);
    temp = netcdf.getVar(ncid, temp_varid);
    NOBS2 = double(temp(:));
    iNaN = NOBS2 == 0;
    NOBS2(iNaN) = NaN;
    NOBS2(iPOSNaN) = [];

    iNObs = iNObs + 1;
end

%ACCESSING THE METADATA
meta.Metadata_Conventions   = netcdf.getAtt(ncid, netcdf.getConstant('GLOBAL'), 'Metadata_Conventions');
meta.title                  = netcdf.getAtt(ncid, netcdf.getConstant('GLOBAL'), 'title');
meta.id                     = netcdf.getAtt(ncid, netcdf.getConstant('GLOBAL'), 'id');
meta.geospatial_lat_min     = netcdf.getAtt(ncid, netcdf.getConstant('GLOBAL'), 'geospatial_lat_min');
meta.geospatial_lat_max     = netcdf.getAtt(ncid, netcdf.getConstant('GLOBAL'), 'geospatial_lat_max');
meta.geospatial_lon_min     = netcdf.getAtt(ncid, netcdf.getConstant('GLOBAL'), 'geospatial_lon_min');
meta.geospatial_lon_max     = netcdf.getAtt(ncid, netcdf.getConstant('GLOBAL'), 'geospatial_lon_max');
meta.time_coverage_start    = netcdf.getAtt(ncid, netcdf.getConstant('GLOBAL'), 'time_coverage_start');
meta.time_coverage_duration = netcdf.getAtt(ncid, netcdf.getConstant('GLOBAL'), 'time_coverage_duration');
meta.abstract               = netcdf.getAtt(ncid, netcdf.getConstant('GLOBAL'), 'abstract');
meta.history                = netcdf.getAtt(ncid, netcdf.getConstant('GLOBAL'), 'history');
meta.comment                = netcdf.getAtt(ncid, netcdf.getConstant('GLOBAL'), 'comment');
netcdf.close(ncid);

%
%OPEN THE TEXT FILE CONTAINING THE GRID
switch site_code
    case 'TURQ'
        dateChange = '20121215T000000';
        if (datenum(filename(14:28), dateFormat) < datenum(dateChange, dateFormat))
            fileGrid = fullfile(inputdir, 'grid_TURQ-before_20121215T000000.dat');
            fileGDOP = fullfile(inputdir, 'TURQ-before_20121215T000000.gdop');
            
            comptlat = 55;
            comptlon = 57;
        else
            fileGrid = fullfile(inputdir, 'grid_TURQ.dat');
            fileGDOP = fullfile(inputdir, 'TURQ.gdop');
            
            comptlat = 60;
            comptlon = 59;
        end
        
        
    case 'BONC'
        fileGrid = fullfile(inputdir, 'grid_BONC.dat');
        fileGDOP = fullfile(inputdir, 'BONC.gdop');
        
        comptlat = 69;
        comptlon = 69;
end

rawdata = importdata(fileGrid);

% points are listed from bottom left to top right so a complex reshape is
% needed to transform this array in a matrix
X = reshape(rawdata(:,1)', comptlon, comptlat)';
Y = reshape(rawdata(:,2)', comptlon, comptlat)';

% we still need to re-order points so that we have them from top left to bottom right
I = (comptlat:-1:1)';
X = X(I, :);
Y = Y(I, :);

% GDOP VALUES OF THE GRID
formatGDOP = '%*d%*d%*f%*f%f%*d';

fid = fopen(fileGDOP, 'r');
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

QCrad = NaN(comptlat, comptlon);

% let's find out the i lines and j columns from the POSITION
totalPOS = (1:1:comptlat*comptlon)';
iMember = ismember(totalPOS, POS);

totalEAST    = NaN(comptlat*comptlon, 1);
totalNORTH   = NaN(comptlat*comptlon, 1);
totalEASTsd  = NaN(comptlat*comptlon, 1);
totalNORTHsd = NaN(comptlat*comptlon, 1);
totalNOBS1   = NaN(comptlat*comptlon, 1);
totalNOBS2   = NaN(comptlat*comptlon, 1);

totalEAST(iMember) = EAST;
totalNORTH(iMember) = NORTH;
totalEASTsd(iMember) = EASTsd;
totalNORTHsd(iMember) = NORTHsd;
totalNOBS1(iMember) = NOBS1;
totalNOBS2(iMember) = NOBS2;
if isQC
    % for now there is no QC info
else
    totalQC = NaN(comptlat*comptlon, 1);
    totalQC(iMember) = 0;
end

% data is ordered from bottom left to top right so a complex reshape is
% needed
Urad = reshape(totalEAST', comptlon, comptlat)';
Vrad = reshape(totalNORTH', comptlon, comptlat)';
UsdRad = reshape(totalEASTsd', comptlon, comptlat)';
VsdRad = reshape(totalNORTHsd', comptlon, comptlat)';
nObs1 = reshape(totalNOBS1', comptlon, comptlat)';
nObs2 = reshape(totalNOBS2', comptlon, comptlat)';
if isQC
    % for now there is no QC info
else
    QCrad = reshape(totalQC', comptlon, comptlat)';
end

% let's re-order data from top left to bottom right
Urad = Urad(I, :);
Vrad = Vrad(I, :);
UsdRad = UsdRad(I, :);
VsdRad = VsdRad(I, :);
nObs1 = nObs1(I, :);
nObs2 = nObs2(I, :);
QCrad = QCrad(I, :);

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

%
%NetCDF file creation
timestart = [1950, 1, 1, 0, 0, 0];
timefin = [str2double(filename(14:17)), str2double(filename(18:19)), str2double(filename(20:21)), ...
    str2double(filename(23:24)), str2double(filename(25:26)), str2double(filename(27:28))];

% time in averaged netCDF file is first file date
timenc = (etime(timefin, timestart))/(60*60*24);

timeStr = datestr(timenc(1) + datenum(timestart), 'yyyy-mm-ddTHH:MM:SSZ');

if isQC
    fileVersionCode = 'FV01';
else
    fileVersionCode = 'FV00';
end

%this netcdf file will then be available on the datafabric and on the qcif opendap server
%
switch site_code
    case {'TURQ', 'SBRD', 'CRVT'}
        pathoutput = fullfile(outputdir, 'TURQ');
    
    case {'BONC', 'BFCV', 'NOCR'}
        pathoutput = fullfile(outputdir, 'BONC');
end

finalPathOutput = fullfile(pathoutput, yearDF, monthDF, dayDF);
if (~exist(finalPathOutput, 'dir'))
    mkdir(finalPathOutput);
end

netcdfFilename = ['IMOS_ACORN_V_', dateforfileSQL, 'Z_', site_code, '_' fileVersionCode '_1-hour-avg.nc'];
netcdfoutput = fullfile(finalPathOutput, netcdfFilename);

createNetCDF(netcdfoutput, site_code, isQC, timenc, timeStr, X, Y, Urad, Vrad, UsdRad, VsdRad, dataGDOP, QCrad, cat(3, nObs1, nObs2), true, 6, meta);

end

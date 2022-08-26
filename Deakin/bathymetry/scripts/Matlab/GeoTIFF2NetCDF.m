function GeoTIFF2NetCDF( geotiffPathFile )
%GEOTIFF2NETCDF Converts a GeoTIFF bathymetry file into a NetCDF file
% Makes use of the geotiff-bin Linux package and Matlab TIFF class

tiffObj = Tiff(geotiffPathFile, 'r');
depth = tiffObj.read();
tiffObj.close();

nanValue = min(min(depth));
depth(depth == nanValue) = NaN;
nanValue = max(max(depth));
depth(depth == nanValue) = NaN;

cmd = ['listgeo -d ' geotiffPathFile];
[~, listgeoOutput] = unix(cmd);

tkn = regexp(listgeoOutput, 'Upper Left    \(  ([\-0-9\.]+), ([\-0-9\.]+)\)  \([\-0-9\.]+,[\-0-9\.]+\)', 'tokens');
if ~isempty(tkn) 
    projCoordXMin = str2double(tkn{1}{1});
    projCoordYMax = str2double(tkn{1}{2});
else
    error('Upper Left coordinates impossible to read');
end

tkn = regexp(listgeoOutput, 'Lower Right   \(  ([\-0-9\.]+), ([\-0-9\.]+)\)  \([\-0-9\.]+,[\-0-9\.]+\)', 'tokens');
if ~isempty(tkn) 
    projCoordXMax = str2double(tkn{1}{1});
    projCoordYMin = str2double(tkn{1}{2});
else
    error('Lower Right coordinates impossible to read');
end

[nI, nJ] = size(depth);
projCoordX = linspace(projCoordXMin, projCoordXMax, nJ);
projCoordY = linspace(projCoordYMin, projCoordYMax, nI);
[X, Y] = meshgrid(projCoordX, projCoordY);

sample_data = struct();

sample_data.dimensions{1}.name = 'I';
sample_data.dimensions{1}.data = (1:nI);

sample_data.dimensions{2}.name = 'J';
sample_data.dimensions{2}.data = (1:nJ);

sample_data.variables{1}.name = 'LATITUDE';
sample_data.variables{1}.dimensions = [1 2];
sample_data.variables{1}.standard_name = 'latitude';
sample_data.variables{1}.data = Y;
sample_data.variables{1}.FillValue_ = 99999;

sample_data.variables{2}.name = 'LONGITUDE';
sample_data.variables{2}.dimensions = [1 2];
sample_data.variables{2}.standard_name = 'longitude';
sample_data.variables{2}.data = X;
sample_data.variables{2}.FillValue_ = 99999;

sample_data.variables{3}.name = 'DEPTH';
sample_data.variables{3}.dimensions = [1 2];
sample_data.variables{3}.standard_name = 'depth';
sample_data.variables{3}.coordinates = 'LATITUDE LONGITUDE';
sample_data.variables{3}.data = depth;
sample_data.variables{3}.FillValue_ = 99999;

[netCDFPath, netCDFName, ~] = fileparts(geotiffPathFile);
netCDFPathFile = fullfile(netCDFPath, [netCDFName, '.nc']);

myExportNetCDF(sample_data, netCDFPathFile, 6);

end


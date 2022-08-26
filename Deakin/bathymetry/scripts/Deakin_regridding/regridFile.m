function outputFile = regridFile( inputFile )
%REGRIDFILE Regrids a netcdf file on a rotated grid with lat / lon dependent on I
%and J on a straight grid with independant lat / lon.

[outputPath, outputFile, ~] = fileparts(inputFile);
outputFile = [fullfile(outputPath, outputFile), '_straight.nc'];

inputLat = ncread(inputFile, 'LATITUDE');
inputLon = ncread(inputFile, 'LONGITUDE');

% let's have a look at the average distance between LATs and between LONs
diffLat = mean(mean(diff(inputLat, 1, 2), 2));
diffLon = mean(mean(diff(inputLon, 1, 1), 1));

% now we can define our new grid
minLat = round(min(min(inputLat)) / diffLat) * diffLat;
maxLat = round(max(max(inputLat)) / diffLat) * diffLat;
minLon = round(min(min(inputLon)) / diffLon) * diffLon;
maxLon = round(max(max(inputLon)) / diffLon) * diffLon;

outputLat = (minLat:abs(diffLat):maxLat);
outputLon = (minLon:abs(diffLon):maxLon);

% let's update the output netcdf infos
outputInfo = ncinfo(inputFile);
outputInfo.Filename = outputFile;

iDimLat = 0;
iDimLon = 0;
% we trun Y and X into LATITUDE and LONGITUDE dimensions
for i=1:length(outputInfo.Dimensions)
    switch outputInfo.Dimensions(i).Name
        case 'Y'
            iDimLat = i;
            outputInfo.Dimensions(i).Name = 'LATITUDE';
            outputInfo.Dimensions(i).Length = length(outputLat);
        case 'X'
            iDimLon = i;
            outputInfo.Dimensions(i).Name = 'LONGITUDE';
            outputInfo.Dimensions(i).Length = length(outputLon);
    end
end

% we get rid of Y and X variables
iToDelete = [];
for i=1:length(outputInfo.Variables)
    switch outputInfo.Variables(i).Name
        case {'Y', 'X'}
            iToDelete(end+1) = i;
            
    end
end
outputInfo.Variables(iToDelete) = [];

for i=1:length(outputInfo.Variables)
    % we update the LATITUDE and LONGITUDE variables
    switch outputInfo.Variables(i).Name
        case 'LATITUDE'
            outputInfo.Variables(i).Dimensions = outputInfo.Dimensions(iDimLat);
            outputInfo.Variables(i).Size = length(outputLat);
            outputInfo.Variables(i).ChunkSize = [];
            outputInfo.Variables(i).DeflateLevel = [];
            outputInfo.Variables(i).Shuffle = false;
        case 'LONGITUDE'
            outputInfo.Variables(i).Dimensions = outputInfo.Dimensions(iDimLon);
            outputInfo.Variables(i).Size = length(outputLon);
            outputInfo.Variables(i).ChunkSize = [];
            outputInfo.Variables(i).DeflateLevel = [];
            outputInfo.Variables(i).Shuffle = false;
            
    end

    % we update any variable that is a function of X and Y
    for j=1:length(outputInfo.Variables(i).Dimensions)
        switch outputInfo.Variables(i).Dimensions(j).Name
            case 'Y'
                outputInfo.Variables(i).Dimensions(j).Name = 'LATITUDE';
                outputInfo.Variables(i).Dimensions(j).Length = length(outputLat);
                outputInfo.Variables(i).Size(j) = length(outputLat);
                if ~isempty(outputInfo.Variables(i).ChunkSize)
                    outputInfo.Variables(i).ChunkSize(j) = length(outputLat);
                end
            case 'X'
                outputInfo.Variables(i).Dimensions(j).Name = 'LONGITUDE';
                outputInfo.Variables(i).Dimensions(j).Length = length(outputLon);
                outputInfo.Variables(i).Size(j) = length(outputLon);
                if ~isempty(outputInfo.Variables(i).ChunkSize)
                    outputInfo.Variables(i).ChunkSize(j) = length(outputLon);
                end
                
        end
    end
    
    % we get rid of the scale_factor offset attributes
    iAttToDelete = [];
    for j=1:length(outputInfo.Variables(i).Attributes)
        switch outputInfo.Variables(i).Attributes(j).Name
            case {'add_offset', 'scale_factor'}
                iAttToDelete(end+1) = j;
                
        end
    end
    for j=1:length(iAttToDelete)
        outputInfo.Variables(i).Datatype = class(outputInfo.Variables(i).Attributes(iAttToDelete(j)).Value);
        outputInfo.Variables(i).FillValue = realmin(outputInfo.Variables(i).Datatype);
    end
    outputInfo.Variables(i).Attributes(iAttToDelete) = [];
end

% now we're ready to create the output file
ncwriteschema(outputFile, outputInfo);

for i=1:length(outputInfo.Variables)
    switch outputInfo.Variables(i).Name
        case 'LATITUDE'
            ncwrite(outputFile, 'LATITUDE', outputLat);
        case 'LONGITUDE'
            ncwrite(outputFile, 'LONGITUDE', outputLon);
        otherwise
            needToRegrid = false;
            for j=1:length(outputInfo.Variables(i).Dimensions)
                switch outputInfo.Variables(i).Dimensions(j).Name
                    case {'LATITUDE', 'LONGITUDE'}
                        needToRegrid = true;
                        
                end
            end
            
            if ~needToRegrid
                ncwrite(outputFile, outputInfo.Variables(i).Name, ncread(inputFile, outputInfo.Variables(i).Name));
            else
                % data in input file is in row / column order with row
                % going from top left so need to use flipud
                data = flipud(ncread(inputFile, outputInfo.Variables(i).Name));
                inputLat = flipud(inputLat);
                inputLon = flipud(inputLon);
                
                gridLat = repmat(outputLat, length(outputLon), 1);
                gridLon = repmat(outputLon', 1, length(outputLat));
                
%                 dataRegridded = interpFunc(inputLon, inputLat, data, gridLon, gridLat, 'linear');
                interpFunc = TriScatteredInterp(inputLon(:), inputLat(:), data(:));
                dataRegridded = interpFunc(gridLon(:), gridLat(:));
                dataRegridded = reshape(dataRegridded, length(outputLon), length(outputLat));
                
                ncwrite(outputFile, outputInfo.Variables(i).Name, dataRegridded);
            end
            
    end
end

end


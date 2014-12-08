function devicewmoref = readDevice_wmo_ref(australianTagsFile)

delimiter = ',';
startRow = 2;

%% Format string for each line of text:
%   column6: text (%s)
% For more information, see the TEXTSCAN documentation.
formatSpec = '%*s%*s%*s%*s%*s%s%*s%*s%*s%*s%*s%*s%*s%*s%*s%*s%*s%*s%*s%*s%*s%*s%*s%*s%*s%*s%*s%*s%[^\n\r]';

%% Open the text file.
fileID = fopen(australianTagsFile,'r');

%% Read columns of data according to format string.
% This call is based on the structure of the file used to generate this
% code. If an error occurs for a different file, try regenerating the code
% from the Import Tool.
dataArray = textscan(fileID, formatSpec, 'Delimiter', delimiter, 'HeaderLines' ,startRow-1, 'ReturnOnError', false);

%% Close the text file.
fclose(fileID);

%% Post processing for unimportable data.
% No unimportable data rules were applied during the import, so no post
% processing code is included. To generate code which works for
% unimportable data, select unimportable cells in a file and regenerate the
% script.

%% Allocate imported array to column variable names
devicewmoref = dataArray{:, 1};
devicewmoref = unique(strrep(devicewmoref,' ','')) ;
devicewmoref = devicewmoref(~cellfun('isempty', devicewmoref)); 
%% Clear temporary variables
clearvars australianTagsFile delimiter startRow formatSpec fileID dataArray ans;
end
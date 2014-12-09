function sha1sumValue = checksum(File)
%% count Nrows
tempResultFile = tempname;

commandStr = ['sha1sum ' File ' > ' tempResultFile ];
system(commandStr) ;
formatSpec = '%40s%[^\n\r]';

%% Open the text file.
fileID = fopen(tempResultFile,'r');

%% Read columns of data according to format string.
% This call is based on the structure of the file used to generate this
% code. If an error occurs for a different file, try regenerating the code
% from the Import Tool.
dataArray = textscan(fileID, formatSpec, 'Delimiter', '', 'WhiteSpace', '',  'ReturnOnError', false);

%% Close the text file.
fclose(fileID);

sha1sumValue = char(dataArray{1});
delete(tempResultFile)
end
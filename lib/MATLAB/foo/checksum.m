function sha1sumValue = checksum(File)
%checksum - performs a checksum on a file using the sha1sum algorithm
%
% Syntax:  checksum('test/test.file')
%
% Inputs:
%    file - full path of the folder name
%    
% Outputs:
%
%
% Other files required: sha1sum package installed on linux
% Other m-files required: none
% Subfunctions: none
% MAT-files required: none
%
% See also: 
%
% Author: Laurent Besnard, IMOS/eMII
% email: laurent.besnard@utas.edu.au
% Website: http://imos.org.au/  http://froggyscripts.blogspot.com
% Dec 2014; Last revision: 09-Dec-2014

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
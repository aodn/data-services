function csvChangeDelimiter(filenameCSV)
%% csvChangeDelimiter
% this function change the delimiter of a csv file , to |
% Syntax:  csvChangeDelimiter(filenameCSV)
%
% Inputs: filenameCSV - CSV file location
%   
%
% Outputs:
%
% Example: 
%    csvChangeDelimiter(filenameCSV)
%
% Other m-files
% required:
% Other files required: config.txt
% Subfunctions: none
% MAT-files required: none
%
% See also: 
% 
% Author: Laurent Besnard, IMOS/eMII
% email: laurent.besnard@utas.edu.au
% Website: http://imos.org.au/  http://froggyscripts.blogspot.com
% Aug 2011; Last revision: 28-Nov-2012

% filenameCSV=strcat(filenameCSV(1:end-3),'csv');
filenameCSV2=strcat(filenameCSV(1:end-3),'csv2');
% Directory=fileparts(filenameCSV);


%% convert , into ####
systemCmd = sprintf('sed ''s/,/####/g'' < "%s" > "%s" ; mv "%s" "%s";',filenameCSV,filenameCSV2,filenameCSV2,filenameCSV);
[~,~]=system(systemCmd,'-echo') ;

%% convert | into ,
systemCmd = sprintf('sed ''s/|/,/g'' < "%s" > "%s" ; mv "%s" "%s";',filenameCSV,filenameCSV2,filenameCSV2,filenameCSV);
[~,~]=system(systemCmd,'-echo') ;

%% convert #### into |
systemCmd = sprintf('sed ''s/####/|/g'' < "%s" > "%s" ; mv "%s" "%s";',filenameCSV,filenameCSV2,filenameCSV2,filenameCSV);
[~,~]=system(systemCmd,'-echo') ;


end


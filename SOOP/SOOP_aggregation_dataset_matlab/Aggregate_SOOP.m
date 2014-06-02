function Aggregate_SOOP
%% Aggregate_SOOP - aggregation of soop data
%The toolbox connects to the database to get a list of soop files to
%download. Files are copied locally, then aggregated together in a folder
%called aggregated_datasets.
%A config file called config.txt can be modified. This file is read by the
%subroutine readConfig. 
%
%if the aggregation succeed, a mat file alreadyAggregated.mat is updated 
%in each subfacility folder in order to know which file/dataset has already
%been used. Then all the used files (NCML and NetCDF) are deleted from the 
%working directory.
%
%Different requirements are essential to run this toolbox.
%1)having the java class  postgresql-9.1-902.jdbc4.jar and toolsUI-4.2.jar
%in the MATLAB javapath, this has to be set up in startup.m
%2)python must be installed
%
%if the java class has to be modified and recompiled :
% 
% javac -classpath myJavaClasses/toolsUI-4.2.jar AggregateNcML.java
% launch in shell
% java -classpath ".:myJavaClasses/toolsUI-4.2.jar" AggregateNcML NCMN_INPUT.ncml NETCDF_OUTPUT.nc
%
% Syntax:  Aggregate_SOOP
%
% Inputs:
%   
%
% Outputs:
%    aggregationLog.txt (stored in DATA_FOLDER)
%
% Example: 
%    Aggregate_SOOP
%
% Other m-files required:readConfig
% Other files required: config.txt
% Subfunctions: none
% MAT-files required: none
%
% See also: Aggregation_Sub_SOOP,readConfig,aggregateFiles
% 
% Author: Laurent Besnard, IMOS/eMII
% email: laurent.besnard@utas.edu.au
% Website: http://imos.org.au/  http://froggyscripts.blogspot.com
% Aug 2012; Last revision: 24-Aug-2012

%% Add to the Matlab path *.m and *.jar
WhereAreScripts=what;
SCRIPT_FOLDER=WhereAreScripts.path;
addpath(genpath(SCRIPT_FOLDER));

% Add any *.jar java library to the classpath. WANRING, this function
% clears all the global variables, so we have to create them again !!
addJarToPath([SCRIPT_FOLDER filesep 'myJavaClasses'])
clear SCRIPT_FOLDER

global SCRIPT_FOLDER;
SCRIPT_FOLDER=WhereAreScripts.path;

% we read config.txt to get the location of the folder where files will be
% processed
global AGGREGATED_DATA_FOLDER;
AGGREGATED_DATA_FOLDER = readConfig('dataSoop.path', 'config.txt','=');
mkpath(AGGREGATED_DATA_FOLDER);

%%
% Log File
diary (strcat(AGGREGATED_DATA_FOLDER,filesep,readConfig('logFile.name', 'config.txt','=')));

%% List soop tables to proccess
soopSubFacility=textscan(readConfig('soopSubFacility.tableName', 'config.txt','='),'%s','delimiter',',');
soopSubFacility=soopSubFacility{1};
soopSubFacility=soopSubFacility(~cellfun('isempty',soopSubFacility));

nTable=length(soopSubFacility);
for iTable=1:nTable
    try
        Aggregation_Sub_SOOP(soopSubFacility{iTable})
    catch
         fprintf('%s - ERROR for table: %s - Manual debug required\n',datestr(now),soopSubFacility{iTable})
    end
end
diary off

end

function Aggregation_Sub_SOOP(soopSubFacility)
%% Aggregation_Sub_SOOP
% query the database, download missing files for each sub-facility. And
% proccess the aggregation
%
% Syntax:  Aggregation_Sub_SOOP(soopSubFacility)
%
% Inputs:
%   
%
% Outputs:
%    
%
% Example: 
%    Aggregation_Sub_SOOP(soopSubFacility)
%
%
% Other m-files required:readConfig
% Other files required: config.txt
% Subfunctions: none
% MAT-files required: none
%
% See also:
% Aggregation_Sub_SOOP,readConfig,readDB,downloadFiles_Default,downloadFiles_V1
% aggregateFiles
% 
% Author: Laurent Besnard, IMOS/eMII
% email: laurent.besnard@utas.edu.au
% Website: http://imos.org.au/  http://froggyscripts.blogspot.com
% Aug 2012; Last revision: 24-Aug-2012

clear queryResult
global AGGREGATED_DATA_FOLDER;
global TEMPORARY_FOLDER;
global CREATION_DATE

TEMPORARY_FOLDER=char(strcat(AGGREGATED_DATA_FOLDER,filesep,'DATA_FOLDER/temporary_',soopSubFacility));
mkpath(TEMPORARY_FOLDER);

[Y, M, D, H, ~, ~]=datevec(now);
CREATION_DATE=datestr(datenum([Y, M, D, H, 0, 0]),'yyyymmddTHHMMSSZ');

fprintf('%s - Table: "%s" currently proccessed\n',datestr(now),char(soopSubFacility))
% query database. Require ~/.pgpass in home directory to get user
% password. Otherwise this can be bypassed by writting the password in the
% code. Not really safe though
server  =readConfig('server.address', 'config.txt','=');
dbName  =readConfig('server.database', 'config.txt','=');
port    =readConfig('server.port', 'config.txt','=');
user    =readConfig('server.user', 'config.txt','=');

try
    password=readConfig('server.password', 'config.txt','='); %read config file
catch
    password=getPgPass(server,port,user); % if line commented on config file, we read ~.pgpass
end

%% Query database to get list of NetCDF files
[queryResult]=readDB(server,dbName,port,user,password,soopSubFacility);

%% create virtual folder structure of files to be processed
% DF folder strucutre is not the same for each folder. We need to call
% different subroutines for different tables
% aggregationType=readConfig('aggregationType', 'config.txt','=');
if strcmpi(soopSubFacility,'soop_asf_mv')
    dataFileLocation = createFileListLocalFolder_V1(queryResult);
elseif strcmpi(soopSubFacility,'soop_sst_mv')
    dataFileLocation = createFileListLocalFolder(queryResult);
   %remove ship FHZI folder
   dataFileLocation = rmfield (dataFileLocation,'vessel_FHZI');
else %default ,soop_tmv_mv,soop_co2_mv,soop_ba_mv,soop_frrf_mv,soop_sst_mv
    dataFileLocation = createFileListLocalFolder(queryResult);
end


%% Aggregation of the downloaded files
aggregateFiles(soopSubFacility,dataFileLocation) %create one file per year

%% Move all files founds locally to the DF
% moveAggregatedFiles(soopSubFacility)

%% Remove all files which have to be deleted from the DF
% deleteSimilarSOOPFiles(soopSubFacility)
end
%% Aggregate_ACORN
% aggregation of ACORN hourly files
function Aggregate_ACORN
%% Aggregate_ACORN - aggregation of ACORN hourly files
% The toolbox connects to opendap catalog to get a list of acorn files to
% download (comparing with the previous files already downloaded. Files are
% copied locally, then aggregated together in a folder 'dataACORN.path'
% A config file called config.txt can be modified. This file is read by the
% subroutine readConfig.
%
% if the aggregation succeeds, a mat file alreadyAggregated.mat is updated
% in each station folder in order to know which file/dataset has already
% been used. Then all the temporary files (NCML and NetCDF) are deleted from
% the working directory.
%
% Different requirements are essential to run this toolbox.
% 1)python must be installed
% 2)all the other toolboxes required are given with this toolbox
% if the java class has to be modified and recompiled :
%
% javac -classpath lib/java/class/toolsUI-4.2.jar AggregateNcML.java
% launch in shell
% java -classpath ".:lib/java/class/toolsUI-4.2.jar" AggregateNcML NCMN_INPUT.ncml NETCDF_OUTPUT.nc
%
% Syntax:  Aggregate_ACORN
%
% Inputs:
%
%
% Outputs:
%    aggregationLog.txt (stored in DATA_FOLDER)
%
% Example:
%    Aggregate_ACORN
%
% Other m-files required:readConfig
% Other files required: config.txt
% Subfunctions: none
% MAT-files required: none
%
% See also: Aggregation_Sub_ACORN,readConfig,aggregateFiles,moveAggregatedFilestoDF,deleteSimilarFiles
%
% Author: Laurent Besnard, IMOS/eMII
% email: laurent.besnard@utas.edu.au
% Website: http://imos.org.au/  http://froggyscripts.blogspot.com
% June 2012; Last revision: 8-Oct-2012
% global SCRIPT_FOLDER;

%% Add to the Matlab path *.m and *.jar
WhereAreScripts=what;
SCRIPT_FOLDER=WhereAreScripts.path;
addpath(genpath(SCRIPT_FOLDER));

% Add any *.jar java library to the classpath. WANRING, this function
% clears all the global variables, so we have to create them again !!
addJarToPath([SCRIPT_FOLDER filesep 'lib/java/class'])
clear SCRIPT_FOLDER

global SCRIPT_FOLDER;
SCRIPT_FOLDER=WhereAreScripts.path;

%% list the config_*.txt , should be one for QAQC and one for noQAQC
listingConfigFiles=dir([SCRIPT_FOLDER filesep 'config_*']);
for iiConfigFile=1:length(listingConfigFiles)
    % we replace each time the config.txt so we can have one config file for QC and one for noQC
    copyfile([SCRIPT_FOLDER filesep listingConfigFiles(iiConfigFile).name], [SCRIPT_FOLDER filesep 'config.txt']);

    % we read config.txt to get the location of the folder where files will be
    % processed
    global AGGREGATED_DATA_FOLDER;
    AGGREGATED_DATA_FOLDER = readConfig('dataACORN.path', 'config.txt','=');
    mkpath(AGGREGATED_DATA_FOLDER);

    %%
    % Log File
    diary (strcat(AGGREGATED_DATA_FOLDER,filesep,readConfig('logFile.name', 'config.txt','=')));

    %% List of the ACORN station to process
    acornStation=textscan(readConfig('acornStation.code', 'config.txt','='),'%s','delimiter',',');
    acornStation=acornStation{1};
    acornStation=acornStation(~cellfun('isempty',acornStation));


    nStation=length(acornStation);
    for iStation=1:nStation
        try
            Aggregation_Sub_ACORN(acornStation{iStation})
        catch
            fprintf('%s - ERROR for station: %s - Manual debug required\n',datestr(now),acornStation{iStation})
        end
    end

    diary off
end
end

function Aggregation_Sub_ACORN(acornStation)
%% Aggregation_Sub_ACORN
% proccess the aggregation for each station
%
% Syntax:  Aggregation_Sub_ACORN(acornStation)
%
% Inputs:
%
%
% Outputs:
%
%
% Example:
%    Aggregation_Sub_ACORN(acornStation)
%
%
% Other m-files required:readConfig,moveAggregatedFilestoDF,deleteSimilarFiles
% Other files required: config.txt
% Subfunctions: none
% MAT-files required: none
%
% See also:
% Aggregation_Sub_ACORN,readConfig,downloadFiles
% aggregateFiles,moveAggregatedFilestoDF,deleteSimilarFiles
%
% Author: Laurent Besnard, IMOS/eMII
% email: laurent.besnard@utas.edu.au
% Website: http://imos.org.au/  http://froggyscripts.blogspot.com
% June 2012; Last revision: 7-Sept-2012

clear queryResult

global CREATION_DATE
global AGGREGATED_DATA_FOLDER;
global TEMPORARY_FOLDER;

fprintf('%s - Station %s currently proccessed\n',datestr(now),char(acornStation))
TEMPORARY_FOLDER=char(strcat(AGGREGATED_DATA_FOLDER,filesep,'DATA_FOLDER/temporary_',acornStation));
mkpath(TEMPORARY_FOLDER);

% unique creation date for all the same files
[Y, M, D, H, ~, ~]=datevec(now);
CREATION_DATE=datestr(datenum([Y, M, D, H, 0, 0]),'yyyymmddTHHMMSSZ');

% %% Harvest of the ACORN station OpenDaP catalog
% fprintf('%s - harvest the thredds catalog for the station %s.This might take a while.\n',datestr(now),char(acornStation))
% url_catalog=strcat(readConfig('opendap1.address', 'config.txt','='),char(acornStation),'/catalog.xml');
% [fileList,fileSize,urlNotReached]=List_NC_recur(url_catalog);
%
%
% %% Download the file which have to be processed
% if isempty(fileList)
%     fprintf('%s - The QCIF catalog is empty/not accessible.lets try with VPAC\n',datestr(now))
%     url_catalog=strcat(readConfig('opendap2.address', 'config.txt','='),char(acornStation),'/catalog.xml');
%
%     [fileList,fileSize,urlNotReached]=List_NC_recur(url_catalog);
%
%     %     [queryResult]=List_NC_recur_IO_toolbox(url_catalog);%use xml_io_tools
%     %     toolbox. but it appears to be much slower that the other toolbox used
%     %     aboved
%
%     if isempty(fileList)
%         fprintf('%s - The VPAC catalog is empty/not accessible.No data will be downloaded\n',datestr(now))
%     else
%         %download all the files for the station, create one directory per year
%         downloadFiles(fileList,fileSize,acornStation);
%     end
% else
%     %download all the files for the station, create one directory per year
%     downloadFiles(fileList,fileSize,acornStation);
% end

%% Aggregation of the downloaded files
fprintf('%s - Aggregation of the downloaded files.\n',datestr(now))
aggregateFiles(acornStation)

%% Move all files founds locally to the DF
moveAggregatedFilestoDF(acornStation)

%% Remove all files which have to be deleted from the DF
deleteSimilarFiles(acornStation)
end
function FAIMMS_Launcher
%% FAIMMS_Launcher - Download of RT FAIMMS data
% This toolbox has been written to download data from the FAIMMS facility
% (Wireless Sensor Networks (FAIMMS)) which is a facility of IMOS. Data is
% downloaded via a web service which converts a http query into a NetCDF
% files. All new data availabe is accessible via an RSS feed provided by
% AIMS. This RSS is then downloaded locally as an XML, then converted into a
% structure by a third party matlab toolbox.
% This structure of channels(sensor), is compared with what has been
% previously downloaded on the last launch of this code. New data available
% is downloaded. A SQL script runs to populate the different tables used for
% geoserver. The files are finally copied and deleted on the datafabric.
%
% Syntax:  FAIMMS_Launcher
%
% Inputs:
%   
%
% Outputs:
%    FAIMMS_Log.txt (stored in FAIMMS_DownloadFolder)
%
% Example: 
%    FAIMMS_Launcher
%
% Other m-files required:readConfig
% Other files required: config.txt
% Subfunctions: none
% MAT-files required: none
%
% See also: FAIMMS_processLevel,readConfig,DataFabricFileManagement,rewriteLog
% 
% Author: Laurent Besnard, IMOS/eMII
% email: laurent.besnard@utas.edu.au
% Website: http://imos.org.au/  http://froggyscripts.blogspot.com
% Aug 2012; Last revision: 24-Aug-2012

global FAIMMS_DownloadFolder;
global DataFabricFolder;


WhereAreScripts=what;
FAIMMS_Matlab_Folder=WhereAreScripts.path;
addpath(genpath(FAIMMS_Matlab_Folder));

%location of FAIMMS folders where files will be downloaded
FAIMMS_DownloadFolder = readConfig('dataFAIMMS.path', 'config.txt','=');
mkpath(FAIMMS_DownloadFolder);

% Data Fabric Folder
DataFabricFolder = readConfig('df.path', 'config.txt','=');


% Log File
diary (strcat(FAIMMS_DownloadFolder,filesep,readConfig('logFile.name', 'config.txt','=')));

fprintf('%s - START OF PROGRAM\n',datestr(now))
for level=0:1
    fprintf('%s - PROCESSING Level %d\n',datestr(now),level)
    
    %% Process FAIMMS data for each level
    FAIMMS_processLevel(level);
    %report(level) % to do the reporting of each channel

    %% Copy and Delete Files to OpenDAP . This part of the code can be launched independantly from the rest
    if exist(strcat(DataFabricFolder,filesep,'opendap'),'dir') == 7
        fprintf('%s - Data Fabric is connected, SWEET ;) : We are deleting old files, and copying the new ones onto it\n',datestr(now))
        DataFabricFileManagement(level)
        rewriteLog(level)
    else
        fprintf('%s - ERROR: Data Fabric is NOT connected, BUGGER |-( : Files will be copied next time\n',datestr(now))
    end
end

% [status,msg]=FAIMMS_remove_channel(channelID) % in case a channel has to be remove manually, simply type this command
rmpath(genpath(FAIMMS_Matlab_Folder))
fprintf('%s - END OF PROGRAM\n',datestr(now))
diary off
end
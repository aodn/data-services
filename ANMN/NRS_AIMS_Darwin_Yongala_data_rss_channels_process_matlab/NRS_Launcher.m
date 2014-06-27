function NRS_Launcher
%% NRS_Launcher - Download of RT NRS data
% This toolbox has been written to download data from the NRS facility
% (Wireless Sensor Networks (NRS)) which is a facility of IMOS. Data is
% downloaded via a web service which converts a http query into a NetCDF
% files. All new data availabe is accessible via an RSS feed provided by
% AIMS. This RSS is then downloaded locally as an XML, then converted into a
% structure by a third party matlab toolbox.
% This structure of channels(sensor), is compared with what has been
% previously downloaded on the last launch of this code. New data available
% is downloaded. A SQL script runs to populate the different tables used for
% geoserver. The files are finally copied and deleted on the datafabric.
%
% Syntax:  NRS_Launcher
%
% Inputs:
%   
%
% Outputs:
%    NRS_Log.txt (stored in NRS_DownloadFolder)
%
% Example: 
%    NRS_Launcher
%
% Other m-files required:readConfig
% Other files required: config.txt
% Subfunctions: none
% MAT-files required: none
%
% See also: NRS_processLevel,readConfig,DataFabricFileManagement,rewriteLog
% 
% Author: Laurent Besnard, IMOS/eMII
% email: laurent.besnard@utas.edu.au
% Website: http://imos.org.au/  http://froggyscripts.blogspot.com
% Aug 2012; Last revision: 04-Dec-2012

global NRS_DownloadFolder;
global DataFabricFolder;

WhereAreScripts=what;
NRS_Matlab_Folder=WhereAreScripts.path;
addpath(genpath(NRS_Matlab_Folder));

%location of NRS folders where files will be downloaded
NRS_DownloadFolder = readConfig('dataNRS.path', 'config.txt','=');
mkpath(NRS_DownloadFolder);

% Data Fabric Folder
DataFabricFolder = readConfig('df.path', 'config.txt','=');


% Log File
diary (strcat(NRS_DownloadFolder,filesep,readConfig('logFile.name', 'config.txt','=')));

fprintf('%s - START OF PROGRAM\n',datestr(now))
for level=0:1
    fprintf('%s - PROCESSING Level %d\n',datestr(now),level)

    %% Process NRS data for each level
    NRS_processLevel(level);
    %report(level)  % to do the reporting of each channel
    
    %% Copy and Delete Files to OpenDAP
    if exist(strcat(DataFabricFolder,filesep,'opendap'),'dir') == 7
        fprintf('%s - Data Fabric is connected, SWEET ;) : We are deleting old files, and copying the new ones onto it\n',datestr(now))
        DataFabricNRSFileManagement(level)
        rewriteLog(level)
    else
        fprintf('%s - ERROR: Data Fabric is NOT connected, BUGGER |-( : Files will be copied next time\n',datestr(now))
    end
end

% [status,msg]=NRS_remove_channel(channelID)  % in case a channel has to be remove manually, simply type this command
rmpath(genpath(NRS_Matlab_Folder))
fprintf('%s - END OF PROGRAM\n',datestr(now))
diary off
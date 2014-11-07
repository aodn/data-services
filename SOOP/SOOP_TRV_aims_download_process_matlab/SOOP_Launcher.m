function SOOP_Launcher
global SOOP_DownloadFolder;
global destinationPath;

levelQC = 1;

WhereAreScripts     = what;
SOOP_Matlab_Folder  = WhereAreScripts.path;
addpath(genpath(SOOP_Matlab_Folder));

%% Data Fabric Folder
destinationPath     = readConfig('destination.path', 'config.txt','=');

%% location of SOOP folder where files will be downloaded
SOOP_DownloadFolder = readConfig('dataSoop.path', 'config.txt','=');
mkpath(SOOP_DownloadFolder);

%% Log File
diary (strcat(SOOP_DownloadFolder,filesep, 'SOOP_Log.txt'));
fprintf('%s - START OF PROGRAM\n',datestr(now))

fprintf('%s - PROCESSING Level %d\n',datestr(now),levelQC)
ChannelIDdown = SOOP(levelQC);

if ~isempty(cell2mat(ChannelIDdown))
    fprintf('%s - ERROR: These following channels were down:\n %s \n',datestr(now),num2str(cell2mat(ChannelIDdown)))
end

rmpath(genpath(SOOP_Matlab_Folder))

exit;
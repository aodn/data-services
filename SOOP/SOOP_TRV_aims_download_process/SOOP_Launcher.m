function SOOP_Launcher
global dataWIP;
global destinationPath;

levelQC            = 1;

WhereAreScripts    = what;
SOOP_Matlab_Folder = WhereAreScripts.path;
addpath(genpath(SOOP_Matlab_Folder));

%% Opendap Folder
destinationPath    = getenv('data_opendap_path');
dataWIP            = getenv('data_wip_path');
mkpath(dataWIP);

%% Log File
diary (strcat(dataWIP,filesep, 'SOOP_Log.txt'));
fprintf('%s - START OF PROGRAM\n',datestr(now))

fprintf('%s - PROCESSING Level %d\n',datestr(now),levelQC)
ChannelIDdown = SOOP(levelQC);

if ~isempty(cell2mat(ChannelIDdown))
    fprintf('%s - ERROR: These following channels were down:\n %s \n',datestr(now),num2str(cell2mat(ChannelIDdown)))
end

rmpath(genpath(SOOP_Matlab_Folder))

exit;
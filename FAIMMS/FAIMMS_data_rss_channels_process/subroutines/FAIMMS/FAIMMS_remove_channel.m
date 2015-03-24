function [status,msg]=FAIMMS_remove_channel(channelID)

global dataWIP;
global dataOpendapRsync;

if exist(fullfile(dataWIP,'PreviousDownload.mat'),'file')
    load (fullfile(dataWIP,'PreviousDownload.mat'))
    
    %% we re-initialised values for this channel
    alreadyDownloaded.PreviousDateDownloaded_lev0{channelID}=[];
    alreadyDownloaded.PreviousDateDownloaded_lev1{channelID}=[];
    alreadyDownloaded.PreviousDownloadedFile_lev0{channelID}=[];
    alreadyDownloaded.PreviousDownloadedFile_lev1{channelID}=[];
    
    alreadyDownloaded.folderLongnameDepth{channelID}=[];
    alreadyDownloaded.channelStringInformation{channelID}=[];
    alreadyDownloaded.sensorsLongname{channelID}=[];
    

    subDataFabricFolder=strcat(dataOpendapRsync,'opendap');
    
    if ~isempty( ChannelFolderOpendap{channelID})
        pathstr  = (strcat(subDataFabricFolder,'/FAIMMS/',alreadyDownloaded.channelStringInformation{channelID}));
        if length(pathstr)~=length(strcat(subDataFabricFolder,'/FAIMMS/'))
            [status]=rmdir(pathstr,'s');
            if status==1
                msg=sprintf('Folder: %s \n has been entirely deleted from DF\n',strcat(pathstr));
               alreadyDownloaded.channelStringInformation{channelID}=[];
                save(fullfile(dataWIP,'PreviousDownload.mat'),'-regexp', 'alreadyDownloaded')
                
            elseif status==0
                msg=sprint('Folder: %s \n has not been entirely deleted from DF\n', strcat(pathstr));
            end
        end
    else
        msg=sprintf('Channel %s has already been deleted\n',num2str(channelID));
        status=0;
    end
end
function [status,msg]=NRS_remove_channel(channelID)

global NRS_DownloadFolder;
global DataFabricFolder;

if exist(fullfile(NRS_DownloadFolder,'PreviousDownload.mat'),'file')
    load (fullfile(NRS_DownloadFolder,'PreviousDownload.mat'))
    
    indexEndFirstPartFolderName=regexp(alreadyDownloaded.channelStringInformation{channelID},filesep);
    ChannelFolderOpendap{channelID}=strcat(alreadyDownloaded.channelStringInformation{channelID}(1:indexEndFirstPartFolderName(end)),alreadyDownloaded.folderLongnameDepth{channelID},'_channel_',num2str(channelID));
    
    subDataFabricFolder=strcat(DataFabricFolder,'opendap');
    
    if ~isempty( ChannelFolderOpendap{channelID})
        pathstr  = (strcat(subDataFabricFolder,'/ANMN/NRS/REAL_TIME/',ChannelFolderOpendap{channelID}));
        if length(pathstr)~=length(strcat(subDataFabricFolder,'/NRS/'))
            [status]=rmdir(pathstr,'s');
            if status==1
                msg=sprintf('Folder: %s \n has been entirely deleted from DF\n',strcat(pathstr));
                
                % we re-initialised values for this channel
                alreadyDownloaded.PreviousDateDownloaded_lev0{channelID}=[];
                alreadyDownloaded.PreviousDateDownloaded_lev1{channelID}=[];
                alreadyDownloaded.PreviousDownloadedFile_lev0{channelID}=[];
                alreadyDownloaded.PreviousDownloadedFile_lev1{channelID}=[];
                
                alreadyDownloaded.folderLongnameDepth{channelID}=[];
                alreadyDownloaded.channelStringInformation{channelID}=[];
                alreadyDownloaded.sensorsLongname{channelID}=[];
                
                save(fullfile(NRS_DownloadFolder,'PreviousDownload.mat'),'-regexp', 'alreadyDownloaded')
            elseif status==0
                msg=sprint('Folder: %s \n has not been entirely deleted from DF\n', strcat(pathstr));
            end
        end
    else
        msg=sprintf('Channel %s has already been deleted\n',num2str(channelID));
        status=0;
    end
end

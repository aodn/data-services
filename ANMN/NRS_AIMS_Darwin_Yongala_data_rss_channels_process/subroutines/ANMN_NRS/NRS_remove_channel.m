function [status,msg]=NRS_remove_channel(channelID)

dataWIP          = getenv('data_wip_path');
dataOpendapRsync = getenv('data_opendap_rsync_path');

if exist(fullfile(dataWIP,'PreviousDownload.mat'),'file')
    load (fullfile(dataWIP,'PreviousDownload.mat'))

    indexEndFirstPartFolderName=regexp(alreadyDownloaded.channelStringInformation{channelID},filesep);
    ChannelFolderOpendap{channelID} = strcat(alreadyDownloaded.channelStringInformation{channelID}(1:indexEndFirstPartFolderName(end)),alreadyDownloaded.folderLongnameDepth{channelID},'_channel_',num2str(channelID));

    subdataOpendapRsync=strcat(dataOpendapRsync,filesep,'opendap');

    if ~isempty(ChannelFolderOpendap{channelID})
        channelDirName  = (strcat(subdataOpendapRsync,filesep,ChannelFolderOpendap{channelID}));
            [status]=rmdir(channelDirName,'s');
            if status==1
                msg=sprintf('Folder: %s \n has been entirely deleted from DF\n',strcat(channelDirName));

                % we re-initialised values for this channel
                alreadyDownloaded.PreviousDateDownloaded_lev0{channelID}=[];
                alreadyDownloaded.PreviousDateDownloaded_lev1{channelID}=[];
                alreadyDownloaded.PreviousDownloadedFile_lev0{channelID}=[];
                alreadyDownloaded.PreviousDownloadedFile_lev1{channelID}=[];

                alreadyDownloaded.folderLongnameDepth{channelID}=[];
                alreadyDownloaded.channelStringInformation{channelID}=[];
                alreadyDownloaded.sensorsLongname{channelID}=[];

                save(fullfile(dataWIP,'PreviousDownload.mat'),'-regexp', 'alreadyDownloaded')
            elseif status==0
                msg=sprint('Folder: %s \n has not been entirely deleted from DF\n', strcat(channelDirName));
            end
    else
        msg=sprintf('Channel %s has already been deleted\n',num2str(channelID));
        status=0;
    end
else
    status = 0;
    msg = sprintf('Missing PreviousDownload.mat file');
end


function removeChannelfromLocalDB(channel2Remove)
warning('off','all')
global SOOP_DownloadFolder;


%% Load the last downloaded date for each channel if available
if exist(fullfile(SOOP_DownloadFolder,'PreviousDownload.mat'),'file')
    load (fullfile(SOOP_DownloadFolder,'PreviousDownload.mat'))
  
end


 PreviousDateDownloaded_lev0{channel2Remove}=[];
 PreviousDateDownloaded_lev1{channel2Remove}=[];
 PreviousDownloadedFile_lev0{channel2Remove}=[];
 PreviousDownloadedFile_lev1{channel2Remove}=[];

 save(fullfile(SOOP_DownloadFolder,'PreviousDownload.mat'),'-regexp', 'PreviousDateDownloaded_lev1','PreviousDateDownloaded_lev0','PreviousDownloadedFile_lev0','PreviousDownloadedFile_lev1')

end    
function removeChannelfromLocalDB(channel2Remove)
warning('off','all')
global dataWIP;


%% Load the last downloaded date for each channel if available
if exist(fullfile(dataWIP,'PreviousDownload.mat'),'file')
    load (fullfile(dataWIP,'PreviousDownload.mat'))

end


 PreviousDateDownloaded_lev0{channel2Remove}=[];
 PreviousDateDownloaded_lev1{channel2Remove}=[];
 PreviousDownloadedFile_lev0{channel2Remove}=[];
 PreviousDownloadedFile_lev1{channel2Remove}=[];

 save(fullfile(dataWIP,'PreviousDownload.mat'),'-regexp', 'PreviousDateDownloaded_lev1','PreviousDateDownloaded_lev0','PreviousDownloadedFile_lev0','PreviousDownloadedFile_lev1')

end
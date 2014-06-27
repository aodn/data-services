function removeRAW
global FAIMMS_DownloadFolder;
global DataFabricFolder;

if exist(strcat(FAIMMS_DownloadFolder,'/log_archive'),'dir') == 0
    mkdir(strcat(FAIMMS_DownloadFolder,'/log_archive'));
end


%% Copy new files to the DF
LogFoldersToDelete=dir(fullfile(FAIMMS_DownloadFolder,strcat('log_ToDo/NoQAQCfolders2delete_*')));

for tt=1:length(LogFoldersToDelete)
    fid2 = fopen(fullfile(FAIMMS_DownloadFolder,'log_ToDo',LogFoldersToDelete(tt).name));
    
    kk=1;
    tline = fgetl(fid2);
    while ischar(tline)
        FoldersToDelete{kk}=tline;
        kk=kk+1;
        tline= fgetl(fid2);
    end
    fclose(fid2);
    
    StatusError=1;
    for kk=1:length(FoldersToDelete)
        if exist(strcat(DataFabricFolder,'opendap/FAIMMS/',FoldersToDelete{kk}),'dir') == 7
            status= rmdir(strcat(DataFabricFolder,'opendap/FAIMMS/',FoldersToDelete{kk}),'s');
            if status==0
                StatusError=0;
            end
        end
    end
    
    if StatusError == 1
        movefile(fullfile(FAIMMS_DownloadFolder,'log_ToDo',LogFoldersToDelete(tt).name),strcat(FAIMMS_DownloadFolder,'/log_archive'));
    else
        fprintf('%s has to be check manually,RAW folder could not be removed for some reasons',LogFoldersToDelete(tt).name)
    end
    
end
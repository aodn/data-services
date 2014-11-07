function removeRAW
global dataWIP;
global dataOpendapRsync;

if exist(strcat(dataWIP,'/log_archive'),'dir') == 0
    mkdir(strcat(dataWIP,'/log_archive'));
end


%% Copy new files to the DF
LogFoldersToDelete=dir(fullfile(dataWIP,strcat('log_ToDo/NoQAQCfolders2delete_*')));

for tt=1:length(LogFoldersToDelete)
    fid2 = fopen(fullfile(dataWIP,'log_ToDo',LogFoldersToDelete(tt).name));
    
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
        if exist(strcat(dataOpendapRsync,'opendap/FAIMMS/',FoldersToDelete{kk}),'dir') == 7
            status= rmdir(strcat(dataOpendapRsync,'opendap/FAIMMS/',FoldersToDelete{kk}),'s');
            if status==0
                StatusError=0;
            end
        end
    end
    
    if StatusError == 1
        movefile(fullfile(dataWIP,'log_ToDo',LogFoldersToDelete(tt).name),strcat(dataWIP,'/log_archive'));
    else
        fprintf('%s has to be check manually,RAW folder could not be removed for some reasons',LogFoldersToDelete(tt).name)
    end
    
end
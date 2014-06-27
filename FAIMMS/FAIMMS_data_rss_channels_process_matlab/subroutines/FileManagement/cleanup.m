function cleanup

global FAIMMS_DownloadFolder;
global DataFabricFolder;

switch level
    case 0
        DataFabricFolder=strcat(DataFabricFolder,'archive');
        
    case 1
        DataFabricFolder=strcat(DataFabricFolder,'opendap');
end

LogFilesToDelete=dir(fullfile(FAIMMS_DownloadFolder,strcat('log_archive/file2delete_*')));
for tt=1:length(LogFilesToDelete)
    try
        fid = fopen(fullfile(FAIMMS_DownloadFolder,'log_archive',LogFilesToDelete(tt).name));
        kk=1;
        tline = fgetl(fid);
        while ischar(tline)
            FileToDelete{kk}=tline;
            kk=kk+1;
            tline= fgetl(fid);
        end
        
        fclose(fid);
        
        for kk=1:length(FileToDelete)
            if exist(strcat(DataFabricFolder,'/FAIMMS/',FileToDelete{kk}),'file')
                fprintf('%s was still present\n',strcat(DataFabricFolder,'/FAIMMS/',FileToDelete{kk}))
                delete(strcat(DataFabricFolder,'/FAIMMS/',FileToDelete{kk}))
                if exist(strcat(DataFabricFolder,'/FAIMMS/',FileToDelete{kk}),'file')
                    fprintf('%s has been deleted\n',strcat(DataFabricFolder,'/FAIMMS/',FileToDelete{kk}))
                else
                    fprintf('%s could not be deleted\n',strcat(DataFabricFolder,'/FAIMMS/',FileToDelete{kk}))
                end
            end
        end
        clear tline
        
    catch
        disp('No files to delete From the DF')
    end
end

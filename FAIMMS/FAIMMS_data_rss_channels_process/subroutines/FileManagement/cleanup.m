function cleanup

global dataWIP;
global dataOpendapRsync;

switch levelQC
    case 0
        dataOpendapRsync=strcat(dataOpendapRsync,'archive');
        
    case 1
        dataOpendapRsync=strcat(dataOpendapRsync,'opendap');
end

LogFilesToDelete=dir(fullfile(dataWIP,strcat('log_archive/file2delete_*')));
for tt=1:length(LogFilesToDelete)
    try
        fid = fopen(fullfile(dataWIP,'log_archive',LogFilesToDelete(tt).name));
        kk=1;
        tline = fgetl(fid);
        while ischar(tline)
            FileToDelete{kk}=tline;
            kk=kk+1;
            tline= fgetl(fid);
        end
        
        fclose(fid);
        
        for kk=1:length(FileToDelete)
            if exist(strcat(dataOpendapRsync,'/FAIMMS/',FileToDelete{kk}),'file')
                fprintf('%s was still present\n',strcat(dataOpendapRsync,'/FAIMMS/',FileToDelete{kk}))
                delete(strcat(dataOpendapRsync,'/FAIMMS/',FileToDelete{kk}))
                if exist(strcat(dataOpendapRsync,'/FAIMMS/',FileToDelete{kk}),'file')
                    fprintf('%s has been deleted\n',strcat(dataOpendapRsync,'/FAIMMS/',FileToDelete{kk}))
                else
                    fprintf('%s could not be deleted\n',strcat(dataOpendapRsync,'/FAIMMS/',FileToDelete{kk}))
                end
            end
        end
        clear tline
        
    catch
        disp('No files to delete From the DF')
    end
end

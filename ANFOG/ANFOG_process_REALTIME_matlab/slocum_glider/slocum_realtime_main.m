SOURCE = eval(readConfig('SOURCE_PATH'));
ARCHIVE = eval(readConfig('DEST_ARCHIVE_PATH'));
OPENDAP = eval(readConfig('DESTINATION_PATH'));
% LISTING OF FILES
incoming = rdir([SOURCE  '**/IMOS*FV00*.nc']);
onThredds =  rdir([OPENDAP  '**/IMOS*FV00*.nc']);
% 
if ~isempty(incoming)
    for i = 1:length(incoming)
        [pathstr,name,ext] = fileparts(incoming(i).name);
        incoming(i).path2file = pathstr;
        incoming(i).name = strcat(name,ext);
% STORES FILESIZE        
        fbytes(i) = incoming(i).bytes;
% SET PATH TO FILES TO BE PROCESSED
    end   
    % CHECK FILESIZE :REMOVE EMPTY FILE FROM LIST 
    incoming(fbytes(i)==0) = [];
    % FIND FILES TO PUBLISH
    [File2publish] = getFile2Publish(incoming);
    
    %COMPARE CREATION DATE WITH FILE ON OPENDAP FOR UPDATE 
    
    for nfile = 1 : length(File2publish)
        path2currentRT_Deployment = fullfile(OPENDAP,File2publish(nfile).deploymt);
        
        if ~exist(path2currentRT_Deployment,'dir') %NEW DEPLOYMENT
            mkdir(path2currentRT_Deployment)
            % MOVE NEW FILE TO OPENDAP
           [status,message,messageid] = movefile(File2publish(nfile).name,path2currentRT_Deployment);
           if status==0
               disp('Failed to move file to new Deployment folder');
               message;
               messageid;
           elseif status==1
                disp(['Moving file to opendap:',File2publish(nfile).name]);
           end
        else
            CurrentFile = dir(fullfile(path2currentRT_Deployment,'IMOS*FV00*.nc'));

            if CurrentFile(1).datenum < File2publish(nfile).datenum
            % UPDATE NEEDED
            % ARCHIVE OLD FILE FIRST
            % CHECK IF ARCHIVE FOLDER EXIST FOR THIS DEPLOYMENT. IF NOT,
            % CREATE
                Path2Archive =  fullfile(ARCHIVE,File2publish(nfile).deploymt);
                if ~exist(Path2Archive,'dir')
                    mkdir(Path2Archive);
                end
                try
                    [status1,message1,messageid1] = movefile(fullfile(path2currentRT_Deployment,CurrentFile(1).name),Path2Archive);
                    disp(['Moving file to opendap:',File2publish(nfile).name]);
                catch
                
                    error(message1)
            
                end
            
            % MOVE NEW FILE TO OPENDAP
           [status2,message2,messageid2] =  movefile(File2publish(nfile).name,path2currentRT_Deployment);
            disp(['Moving file to opendap:',File2publish(nfile).name]);
            end
        end
            
    end
    %CLEAN THE INCOMING FOLDER :CALL FROM HERE TO MAKE SURE IT
    %HAPPENS ONLY IF ABOVE PROCESS HAS RUN WITHOUT ERRORS.
    if exist('status2','var') & status2==1
    ! ./Staging2Archive.sh 
    else
        error('rsync not performed')
    end
else
    disp('NO new Realtime data')
end
exit   
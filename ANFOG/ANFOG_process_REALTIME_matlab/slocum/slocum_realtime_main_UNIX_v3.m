%THIS IS THE MAIN ROUTINE TO PROCESS THE REALTIME SLOCUM DEPLOYMENTS
%THIS ROUTINE CALLS SLOCUM_REALTIME_SUBFUNCTION1_UNIX.M
%CURRENT DIRECTORY
currentdir = readConfig('current_dir');
% WIP DIRECTORY
wipdir = readConfig('wip_dir');
%
% OUTPUT DIRECTORY
%
 outputdir = readConfig('output_dir');
if (~exist(outputdir,'dir'))
    mkdir(outputdir)
end
%
% OUTPUT: LOG FILE
log = readConfig('log_file');
logfile = fullfile(outputdir,log);
%
% STAGING DIRECTORY
fileinput = readConfig('file_input');
%
%LIST OF  AVAILABLE DEPLOYMENTS: 
All_deploy = dir(fileinput);
%REMOVE PARENT DIRECTORY AND CURRENT DIRECTORY FROM LIST
All_deploy(strncmp({All_deploy.name},'.',1))=[];
%
dimfileinput = length(All_deploy);
%
%LIST OF COMPLETED DEPLOYMENTS 
completeddeploy = readConfig('completed_deploy');
listofgliderrecovered = fullfile(currentdir,completeddeploy);
%
fid = fopen(listofgliderrecovered);
recovered = textscan(fid, '%s', 'delimiter' , '\n' );
fclose(fid);
%
%FIND DEPLOYMENTS NOT RECOVERED
filestoprocess = cell(1);
j = 1;
%
for i = 1:dimfileinput
    if ~ismember(All_deploy(i).name,recovered{1}(:))
        filestoprocess{j} = All_deploy(i).name;
        j = j+1;
    end
end
% PROCESSING DEPLOYMENTS NOT RECOVERED
if ~isempty(filestoprocess{1}) 
    dimfile = length(filestoprocess);
%
    for i =1:dimfile
        namefile = dir(fullfile(fileinput,filestoprocess{i},'*.txt'));
        if ~isempty(namefile)
            try
                %namefile = dir(fullfile(fileinput,filestoprocess{i},'*.txt'));
                gliderfileDF = fullfile(fileinput,filestoprocess{i},namefile(1).name);
                gliderlocalcopy = fullfile(wipdir,strcat(filestoprocess{i},'_',namefile(1).name));
                copyfile(gliderfileDF,gliderlocalcopy);
            catch
                message = get_reportmessage(4);
                print_message(logfile, message, filestoprocess{i});
            end
    % LIST OF ALL NETCDF FILES INCLUDED FOR A PARTICULAR DEPLOYMENT     
            C = dir(fullfile(fileinput,filestoprocess{i},'*.nc'));
            dimfileC = length(C);
            try
                test = slocum_realtime_subfunction1_UNIX_v3(gliderlocalcopy,filestoprocess{i},dimfileC);
                startmessage = get_reportmessage(7);
                if (test == 1)
                    message = get_reportmessage(test);         
                    print_message(logfile, startmessage, strcat(filestoprocess{i},message));
                elseif (test == 2)
                    message = get_reportmessage(test);
                    print_message(logfile, startmessage, strcat(filestoprocess{i},message));
                elseif (test == 3)
                    message = get_reportmessage(test);
                    print_message(logfile, startmessage, strcat(filestoprocess{i},message));
                end
            catch
                message = get_reportmessage(5); 
                print_message(logfile, message,filestoprocess{i});
            end
        else
            message = get_reportmessage(8); 
            print_message(logfile, message,filestoprocess{i});
        end
    end
else
    message = get_reportmessage(6);
    print_message(logfile, message);    
end
quit

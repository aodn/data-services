%Current Directory
global currentdir
currentdir = '/var/lib/matlab_3/ANFOG/realtime/seaglider';
%
%OUTPUT DIRECTORY
global outputdir
outputdir = '/var/lib/matlab_3/ANFOG/realtime/seaglider/output';
if (~exist(outputdir,'dir'))
    mkdir(outputdir)
end
%
%OUTPUT: LOG FILE
logfile = strcat(outputdir,'/','seaglider_realtime_logfile.txt');
%
%DATA FABRIC STAGING DIRECTORY
fileinput = '/home/matlab_3/datafabric_root/staging/ANFOG/REALTIME/seaglider';
%List of deployment available
A = dir(fileinput);
dimfileinput = length(A);
%
%List of deployments finished
listofgliderrecovered = strcat(currentdir,'/','seaglider_realtime_deployment_list_recovered.txt');
fid = fopen(listofgliderrecovered);
recovered = textscan(fid, '%s', 'delimiter' , '\n' );
fclose(fid)
%
%Find the deployment not recovered
filestoprocess = cell(1);
j=1;
for i=3:dimfileinput
    if ( (ismember(A(i).name,recovered{1}(:))) == 0)
        filestoprocess{j} = A(i).name;
        j = j+1;
    end
end
%PROCESSING DEPLOYMENTS NOT RECOVERED
if ( isempty(filestoprocess{1}) == 0 )
   dimfile = length(filestoprocess);
%
  for i =1:dimfile
    try
     gliderfileDF = strcat(fileinput,'/',filestoprocess{i},'/','comm.log');
     gliderlocalcopy = strcat(currentdir,'/',filestoprocess{i},'_comm.log');
     copyfile(gliderfileDF,gliderlocalcopy);
    catch
        fid_w = fopen(logfile,'a');
        fprintf(fid_w,'%s %s %s \r\n',datestr(clock),' PROBLEM to copy locally the comm.log file for the following deployment ',filestoprocess{i});
        fclose(fid_w);
    end
    C = dir(strcat(fileinput,'/',filestoprocess{i},'/','*.nc'));
    dimfileC = length(C);
%    try
    test = seaglider_realtime_subfunction1_v3(gliderlocalcopy,filestoprocess{i},dimfileC);
        if (test == 1)
            description = strcat(filestoprocess{i},' has been processed for the first time')
            fid_w = fopen(logfile,'a');
            fprintf(fid_w,'%s %s %s %s \r\n',datestr(clock),' The Deployment ',filestoprocess{i} , 'has been processed for the first time');
            fclose(fid_w);
        elseif (test == 2)
            description = strcat(filestoprocess{i},' has been updated')
            fid_w = fopen(logfile,'a');
            fprintf(fid_w,'%s %s %s %s \r\n',datestr(clock),' The Deployment ',filestoprocess{i} , 'has been updated');
            fclose(fid_w);
        elseif (test == 3)
            description = strcat(filestoprocess{i},' has NO UPDATE')
            fid_w = fopen(logfile,'a');
            fprintf(fid_w,'%s %s %s %s \r\n',datestr(clock),' The Deployment ',filestoprocess{i} , 'has NO UPDATE');
            fclose(fid_w);
        end
%    catch
%       fid_w = fopen(logfile,'a');
%       fprintf(fid_w,'%s %s %s \r\n',datestr(clock),' PROBLEM during the processing of the following deployment ',filestoprocess{i});
%       fclose(fid_w);
%    end
   end
else
        fid_w = fopen(logfile,'a');
        fprintf(fid_w,'%s %s \r\n',datestr(clock),' No Deployment to process');
        fclose(fid_w);
end
% quit

%Current directory
global currentdir
currentdir = '/var/lib/matlab_3/ANFOG/realtime/slocum';
%
%OUTPUT DIRECTORY
global outputdir
outputdir = '/var/lib/matlab_3/ANFOG/realtime/slocum/output';
if (~exist(outputdir,'dir'))
    mkdir(outputdir)
end
%
%OUTPUT: LOG FILE
logfile = strcat(outputdir,'/','slocum_realtime_logfile.txt');
%DATA FABRIC STAGING DIRECTORY
fileinput = '/home/matlab_3/datafabric_root/staging/ANFOG/REALTIME/slocum_glider';
%List of deployment available
A = dir(fileinput);
dimfileinput = length(A);
%
%List of deployments finished
listofgliderrecovered = strcat(currentdir,'/','slocum_realtime_deployment_list_recovered.txt');
fid = fopen(listofgliderrecovered);
recovered = textscan(fid, '%s', 'delimiter' , '\n' );
fclose(fid)
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
%
for i =1:dimfile
%    try
     namefile = dir(strcat(fileinput,'/',filestoprocess{i}));
     gliderfileDF = strcat(fileinput,'/',filestoprocess{i},'/',namefile(3).name);
     gliderlocalcopy = strcat(currentdir,'/',filestoprocess{i},'_',namefile(3).name);
     copyfile(gliderfileDF,gliderlocalcopy);
%    catch
%        fid_w = fopen(logfile,'a');
%        fprintf(fid_w,'%s %s %s \r\n',datestr(clock),' PROBLEM to copy locally the text file containing the GPS positions for the following deployment ',filestoprocess{i});
%        fclose(fid_w);
%    end
%List of all Netcdf files included for a particular deployment     
    C = dir(strcat(fileinput,'/',A(i).name,'/','*.nc'));
    dimfileC = length(C);
%    try
        test = slocum_realtime_subfunction1_UNIX_v3(gliderlocalcopy,filestoprocess{i},dimfileC);
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
quit
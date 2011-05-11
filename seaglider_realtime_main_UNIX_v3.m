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
%Data Fabric public directory
global dfpublicdir
dfpublicdir  = '/home/matlab_3/datafabric_root/public/ANFOG/Realtime/seaglider';
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
%List of all Netcdf files included for a particular deployment    
    C = dir(strcat(fileinput,'/',filestoprocess{i},'/','*.nc'));
    dimfileC = length(C);
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%COPY of NETCDF FILES on emii3-vm2
%
% try
%Creation of a Directory to store NetCDf files useful for the plotting
    mkdir(strcat(outputdir,'/plotting/',filestoprocess{i}));
    try
        mkdir(strcat(dfpublicdir,'/',filestoprocess{i}));
    catch
        fid_w = fopen(logfile,'a');
        fprintf(fid_w,'%s %s %s \r\n',datestr(clock),' PROBLEM to create a folder on the DataFabric for the following deployment ',filestoprocess{i});
        fclose(fid_w); 
    end
%List of files already available on emii3-vm2
    B = dir(strcat(outputdir,'/plotting/',filestoprocess{i},'/','*.nc'));
    dimfileB = length(B);
    if (dimfileC == 0)
        description = strcat(filestoprocess{i},' ne possede pas de fichier NetCDF')
    else
        if (dimfileB == 0)
%        COPY NETCDF FILES FROM A TO B
            for j=1:dimfileC
            filename1 = strcat(fileinput,'/',filestoprocess{i},'/',C(j).name);
            filename2 = strcat(outputdir,'/plotting/',filestoprocess{i},'/',C(j).name);
            copyfile(filename1,filename2);
            end
        else
%        ONLY COPY THE NEW FILES
%        CHECK IF THE NETCDF FILE ALREADY EXIT ON emii3-vm2
            for k=1:dimfileC
                toto =0;
                for j=1:dimfileB
                    if (strcmp(C(k).name,B(j).name))
                       toto = toto+1;
                    end
                end
                if (~toto)
                filename1 = strcat(fileinput,'/',filestoprocess{i},'/',C(k).name);
                filename2 = strcat(outputdir,'/plotting/',filestoprocess{i},'/',C(k).name);
                    try
                    copyfile(filename1,filename2);
                    end
                end
            end
        end
    end
% catch
%        fid_w = fopen(logfile,'a');
%        fprintf(fid_w,'%s %s %s \r\n',datestr(clock),' PROBLEM to copy locally NETCDF FILES for the following deployment ',filestoprocess{i});
%        fclose(fid_w);
% end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%PROCESSING OF THE GPS FILE
%CALL THE SUBROUTINE 'seaglider_realtime_subfunction1_UNIX_v3'
%
%    try
    test = seaglider_realtime_subfunction1_UNIX_v3(gliderlocalcopy,filestoprocess{i},dimfileC);
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
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%CREATION OF THE PLOT
%CALL OF THE SUBROUTINE 'seaglider_realtime_plotting_subfunction1_UNIX_v3'
%  try
    test2 = seaglider_realtime_plotting_subfunction1_UNIX_v3(strcat(outputdir,'/plotting'),filestoprocess{i});
    if (test2 == 1)
        description = strcat(filestoprocess{i},' ne possede pas de fichier NetCDF')
    elseif (test == 2)
        description = strcat(filestoprocess{i},' , les images ont ete mises a jour')
    end
%  catch
        fid_w = fopen(logfile,'a');
        fprintf(fid_w,'%s %s %s \r\n',datestr(clock),' PROBLEM to create the plots for the following deployment ',filestoprocess{i});
        fclose(fid_w);
%  end    
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
   end
else
        fid_w = fopen(logfile,'a');
        fprintf(fid_w,'%s %s \r\n',datestr(clock),' No Deployment to process');
        fclose(fid_w);
end
% quit

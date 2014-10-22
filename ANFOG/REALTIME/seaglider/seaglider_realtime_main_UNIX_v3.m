%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%	MAIN ROUTINE FOR PROCESSING OF REALTIME SEAGLIDER DATA 
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%Current Directory
currentdir = readConfig('current_dir');
%
%OUTPUT DIRECTORY
 outputdir = readConfig('output_dir');
 if ~exist(outputdir,'dir')
    mkdir(outputdir);
end
%
%OUTPUT: LOG FILE
log = readConfig('log_file');
logfile = fullfile(outputdir,log);
%
%STAGING DIRECTORY
fileinput = readConfig('file_input');
% PUBLIC DIRECTORY
dfpublicdir  = readConfig('dfpublic_dir');
%PLOTTING DIRECTORY
plottingdir = readConfig('plotting_dir');
%LIST OF DEPLOYMENT AVAILABLE
All_deploy = dir(fileinput);
%REMOVE PARENT DIRECTORY AND CURRENT DIRECTORY FROM LIST 
All_deploy(strncmp({All_deploy.name},'.',1))=[];
%
dimfileinput = length(All_deploy);
%
%LIST OF DEPLOYMENTS FINISHED
completeddeploy = readConfig('completed_deploy');
listofgliderrecovered = fullfile(currentdir,completeddeploy);
%
fid = fopen(listofgliderrecovered);
recovered = textscan(fid, '%s', 'delimiter' , '\n' );
fclose(fid);
%
%FIND THE DEPLOYMENT NOT RECOVERED
filestoprocess = cell(1);
j=1;
for i=1:dimfileinput
    if ~ismember(All_deploy(i).name,recovered{1}(:))
        filestoprocess{j} = All_deploy(i).name;
        j = j+1;
    end
end
%PROCESSING DEPLOYMENTS NOT RECOVERED
if ~isempty(filestoprocess{1})
   dimfile = length(filestoprocess);
%
  for i = 1:dimfile
    try
     gliderfileDF = fullfile(fileinput,filestoprocess{i},'comm.log');
     gliderlocalcopy = fullfile(currentdir,strcat(filestoprocess{i},'_comm.log'));
     copyfile(gliderfileDF,gliderlocalcopy);
    catch
     message = get_reportmessage(4);
     print_message(logfile, message, filestoprocess{i});
    end
%LIST OF ALL NETCDF FILES INCLUDED FOR A PARTICULAR DEPLOYMENT    
    C = dir(fullfile(fileinput,filestoprocess{i},'*.nc'));
    dimfileC = length(C);
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%COPY of NETCDF FILES 
%
try
%CREATION OF A DIRECTORY TO STORE NETCDF FILES USEFUL FOR THE PLOTTING
    if ~exist(fullfile(outputdir,plottingdir,filestoprocess{i}),'dir')
       mkdir(fullfile(outputdir,plottingdir,filestoprocess{i}));
    end
    try
        if ~exist(fullfile(dfpublicdir,filestoprocess{i}),'dir')
           mkdir(fullfile(dfpublicdir,filestoprocess{i}));
        end
    catch
        message = get_reportmessage(8);         
        print_message(logfile, message, filestoprocess{i});
    end
%LIST OF FILES ALREADY AVAILABLE 
    B = dir(fullfile(outputdir,plottingdir,filestoprocess{i},'*.nc'));
    dimfileB = length(B);
    if (dimfileC == 0)
        description = strcat(filestoprocess{i},' has no NetCDF files')
    else
        if (dimfileB == 0)
%        COPY NETCDF FILES FROM A TO B
            for j=1:dimfileC
                if C(j).bytes >0
                   filename1 = fullfile(fileinput,filestoprocess{i},C(j).name);
                   filename2 = fullfile(outputdir,plottingdir,filestoprocess{i},C(j).name);
                   copyfile(filename1,filename2);
                end
            end
        else
%        ONLY COPY THE NEW FILES
%        CHECK IF THE NETCDF FILE ALREADY EXIST ON emii3-vm2
            for k=1:dimfileC
                nbfile =0;
                for j=1:dimfileB
                    if (strcmp(C(k).name,B(j).name))
                       nbfile = nbfile+1;
                    end
                end
                if (~nbfile)
                    if C(k).bytes>0
                        filename1 = fullfile(fileinput,filestoprocess{i},C(k).name);
                        filename2 = fullfile(outputdir,plottingdir,filestoprocess{i},C(k).name);    
                        copyfile(filename1,filename2);
                    end
                    
                end
            end
        end
    end
 catch
      message = get_reportmessage(9);         
      print_message(logfile, message, filestoprocess{i});
 end 
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%PROCESSING OF THE GPS FILE
%CALL THE SUBROUTINE 'seaglider_realtime_subfunction1_UNIX_v3'
%
startmessage ='the Deployment ';  
    try
    test = seaglider_realtime_subfunction1_UNIX_vB(gliderlocalcopy,filestoprocess{i},dimfileC);
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
       print_message(logfile, message, filestoprocess{i});
    end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%CREATION OF THE PLOT
%CALL OF THE SUBROUTINE 'seaglider_realtime_plotting_subfunction1_UNIX_v3'
 try
    test2 = seaglider_realtime_plotting_subfunction1_UNIX_vB(fullfile(outputdir,plottingdir),filestoprocess{i});
    if (test2 == 1)
        description = strcat(filestoprocess{i},' has no NetCDF file')
    elseif (test2 == 2)
        description = strcat(filestoprocess{i},' ,images have been updated')
    end
  catch
       message = get_reportmessage(10);         
       print_message(logfile, message, filestoprocess{i});
 end    
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%CALL THE function to process files and send them to the GTS
%
   try
    test3 = seaglider_realtime_GTS_main_UNIX_vB(filestoprocess{i});
    if (test3 == 0)
        description = strcat(' NO GTS messages for this deployment', filestoprocess{i})
    elseif (test3 == 1)
        description = strcat(' NEW GTS messages for this deployment', filestoprocess{i})
    end
   catch
       message = get_reportmessage(11);         
       print_message(logfile, message, filestoprocess{i});
   end 
%  
  end
else
   message = get_reportmessage(6);         
   print_message(logfile, message);
%
end
quit

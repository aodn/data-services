function [status] = seaglider_realtime_GTS_main_UNIX_vB(deployment)
%
outputdir = readConfig('output_dir','configGTS.txt');
%
%OUTPUT: LOG FILE
log = readConfig('log_file','configGTS.txt');
logfile = fullfile(outputdir,log);
%
%OUTPUT: TESAC LOG FILE for this particular deployment
gtsdir = readConfig('gts_dir','configGTS.txt');
if ~exist(fullfile(outputdir, gtsdir, deployment),'dir')
    mkdir(fullfile(outputdir, gtsdir, deployment));
end
tesacfile = readConfig('tesac_file','configGTS.txt');
tesacmessagedir = readConfig('tesacmessage_dir','configGTS.txt');
filesProcessedToTESAC = fullfile(outputdir, gtsdir, deployment,strcat(deployment,tesacfile));
%
status = 0;
%
%List of NetCDF files available in the folder corresponding to the
%deployment
%PLOTTING DIRECTORY
plottingdir = readConfig('plotting_dir','configGTS.txt');
A = dir(fullfile(outputdir, plottingdir, deployment,'*.nc'));
%
if (~isempty(A))
    dimFile = length(A);
%
%
   if (exist(filesProcessedToTESAC, 'file') == 2)
%LIST OF FILES ALREADY PROCESSED FOR THIS PARTICULAR DEPLOYMENT       
      fid = fopen(filesProcessedToTESAC);
      processed = textscan(fid, '%s');
      fclose(fid);
      nProcessed = size(processed{1},1);
      for i =1:dimFile  
      nbfile = 0;
      nbfile = sum( strcmp(A(i).name, processed{:}) );
        if (~nbfile)
          try
           [nCycle, okForGTS] = seaglider_realtime_GTS_subfunction1_UNIX_vB( deployment, A(i).name );
           fid_w = fopen(filesProcessedToTESAC, 'a');
           fprintf(fid_w,'%s \r\n', A(i).name );
           fclose(fid_w);
           if (okForGTS)
             message = get_reportmessageGTS(1);
             fid_w = fopen(logfile, 'a');
             fprintf(fid_w,'%s %2.0f %s %s \r\n',datestr(clock), nCycle, message, A(i).name );
             fclose(fid_w);
           end
          catch
              message = get_reportmessageGTS(2);
              print_message(logfile, message, A(i).name);
          end 
        end
      end
   else
      for i =1:dimFile
        try
           [nCycle, okForGTS] = seaglider_realtime_GTS_subfunction1_UNIX_vB( deployment, A(i).name );
           fid_w = fopen(filesProcessedToTESAC, 'a');
           fprintf(fid_w,'%s \r\n', A(i).name );
           fclose(fid_w);
           if ( okForGTS)
               message =get_reportmessageGTS(3);
              fid_w = fopen(logfile, 'a');
              fprintf(fid_w,'%s %2.0f %s %s \r\n',datestr(clock), nCycle, message, A(i).name );
              fclose(fid_w);
           end
        catch
             message = get_reportmessageGTS(4);
             print_message(logfile, message, A(i).name);
        end
      end
   end
%
%
end
%
%COPY FILES TO THE BOM FTP SITE
%DELETE FILES FROM THE DIRECTORY
filesToBOM = fullfile(outputdir, gtsdir, deployment, tesacmessagedir);
B = dir( fullfile(filesToBOM, '*.txt') );
if (~isempty(B))
    dimFileToBOM = length(B);
    try
%CONNECTION TO BOM FTP SITE
%
     BOMusername = readConfig('BOMusnm','configGTS.txt');
    BOMpassword = readConfig('BOMpswd','configGTS.txt');
%BP%    testBOM = ftp('ftp.bom.gov.au', BOMusername, BOMpassword); 
%BP%    cd(testBOM, 'incoming')
%    
%BP%   for hh = 1:dimFileToBOM
%BP%       try
%BP%       fileToTransfer = strcat(filesToBOM,B(hh).name);
%BP%        mput(testBOM, fileToTransfer);
%BP%       delete(fileToTransfer);
      status = 1;
%BP%       catch
%BP%            message = get_reportmessageGTS(5);
%BP%             print_message(logfile, message, fileToTransfer);
%BP%        end
%BP%   end
%    
%BP%    close(testBOM)
    catch
             message = get_reportmessageGTS(6);
             print_message(logfile, message);
    end
%    
end
%
%COPY FILES TO THE NOAA FTP SITE
%DELETE FILES FROM THE DIRECTORY
noaadir = readConfig('noaa_dir','configGTS.txt');
filesToNOAA = fullfile(outputdir, gtsdir, deployment,tesacmessagedir,noaadir);
D = dir(fullfile(outputdir, gtsdir, deployment, tesacmessagedir, noaadir,'*.txt'));
if (~isempty(D))
    dimFileToNOAA = length(D);
    try
%Connection to NOAA ftp site
%
    NOAAusername = readConfig('NOAAusnm','configGTS.txt');
%BP%    NOAApassword = readConfig('NOAApswd','configGTS.txt');
%BP%    testNOAA = ftp('comms.ndbc.noaa.gov', NOAAusername, NOAApassword); 
%BP%    cd(testNOAA, 'delayed_data')
%    
%BP%    for hh = 1:dimFileToNOAA
%BP%        try
%BP%        fileToTransfer = strcat(filesToNOAA,D(hh).name);
%BP%        mput(testNOAA, fileToTransfer);
%BP%        delete(fileToTransfer);
       status = 1;
%BP%        catch
%BP%             message = get_reportmessageGTS(7);
%BP%             print_message(logfile, message, fileToTransfer);
%BP%        end
%BP%    end
%    
%BP%    close(testNOAA);
    catch
        message = get_reportmessageGTS(8);
        print_message(logfile, message);
   end
%    
end
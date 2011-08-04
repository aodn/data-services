function [test3] = seaglider_realtime_GTS_main_UNIX_v3(deployment)
%
global outputdir
outputdir = '/var/lib/matlab_3/ANFOG/realtime/seaglider/output';
%
%OUTPUT: LOG FILE
logfile = strcat(outputdir,'/','seaglider_realtime_logfile_TEST.txt');
%
%OUTPUT: TESAC LOG FILE for this particular deployment
if (~exist(strcat(outputdir, '/GTS/', deployment),'dir'))
    mkdir(strcat(outputdir, '/GTS/', deployment));
end
filesProcessedToTESAC = strcat(outputdir, '/GTS/', deployment, '/', deployment, '_TESAC_messages_processed.txt');
%
test3 = 0;
%
%List of NetCDF files available in the folder corresponding to the
%deployment
folderToProcess = strcat(outputdir, '/plotting/', deployment, '/');
A = dir( strcat(folderToProcess, '*.nc') );
%
if (~isempty(A))
    dimFile = length(A);
%
%
   if ( (exist(filesProcessedToTESAC, 'file') == 2) )
%List of files already processed for this particular deployment       
      fid = fopen(filesProcessedToTESAC);
      processed = textscan(fid, '%s');
      fclose(fid)
      nProcessed = size(processed{1},1);
      for i =1:dimFile
        i  
        toto = 0;
%        for j = 1:nProcessed
%              if (strcmp(A(i).name, processed{:}{j}(1:end-1)))
%                 toto = toto+1;
%              end
%        end
      toto = sum( strcmp(A(i).name, processed{:}) );
        if (~toto)
          try
           [nCycle, okForGTS] = seaglider_realtime_GTS_subfunction1_UNIX_v3( deployment, A(i).name );
           fid_w = fopen(filesProcessedToTESAC, 'a');
           fprintf(fid_w,'%s \r\n', A(i).name );
           fclose(fid_w);
           if (okForGTS)
             fid_w = fopen(logfile, 'a');
             fprintf(fid_w,'%s %2.0f %s %s \r\n',datestr(clock), nCycle, ' TESAC messages have been created for the NetCDF file ', A(i).name );
             fclose(fid_w);
           end
          catch
            fid_w = fopen(logfile, 'a');
            fprintf(fid_w,'%s %s %s \r\n',datestr(clock),' Problem when creating a TESAC message for the following NetCDF file ', A(i).name );
            fclose(fid_w);
          end 
        end
      end
   else
      for i =1:dimFile
        i
        try
           [nCycle, okForGTS] = seaglider_realtime_GTS_subfunction1_UNIX_v3( deployment, A(i).name );
           fid_w = fopen(filesProcessedToTESAC, 'a');
           fprintf(fid_w,'%s \r\n', A(i).name );
           fclose(fid_w);
           if ( okForGTS)
              fid_w = fopen(logfile, 'a');
              fprintf(fid_w,'%s %2.0f %s %s \r\n',datestr(clock), nCycle, ' TESAC messages have been created for the NetCDF file ', A(i).name );
              fclose(fid_w);
           end
        catch
            fid_w = fopen(logfile, 'a');
            fprintf(fid_w,'%s %s %s \r\n',datestr(clock),' Problem when creating a TESAC message for the following NetCDF file ', A(i).name );
            fclose(fid_w);
        end
      end
   end
%
%
end
%
%Copy files to the BOM ftp site
%Delete files from the directory
filesToBOM = strcat(outputdir, '/GTS/', deployment, '/TESACmessages/');
B = dir( strcat(filesToBOM, '*.txt') );
if (~isempty(B))
    dimFileToBOM = length(B);
    try
%Connection to BOM ftp site
%
    BOMusername = 'bom506';
    BOMpassword = '4onVocNed9';
    testBOM = ftp('ftp.bom.gov.au', BOMusername, BOMpassword); 
    cd(testBOM, 'incoming')
%    
    for hh = 1:dimFileToBOM
        try
        fileToTransfer = strcat(filesToBOM,B(hh).name);
        mput(testBOM, fileToTransfer);
        delete(fileToTransfer);
        test3 = 1;
        catch
             fid_w = fopen(logfile, 'a');
             fprintf(fid_w,'%s %s %s \r\n',datestr(clock),' Problem to COPY THE FOLLOWING FILE TO the BOM ftp site ',fileToTransfer);
             fclose(fid_w);
        end
    end
%    
    close(testBOM)
    catch
        fid_w = fopen(logfile, 'a');
        fprintf(fid_w,'%s %s \r\n',datestr(clock),' Problem to access the BOM ftp site ');
        fclose(fid_w); 
    end
%    
end
%
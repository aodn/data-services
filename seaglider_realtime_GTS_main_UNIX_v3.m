function [] = seaglider_realtime_GTS_main_UNIX_v3(deployment)
%
global outputdir
%outputdir = '/var/lib/matlab_3/ANFOG/realtime/seaglider/output';
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
%
%List of NetCDF files available in the folder corresponding to the
%deployment
folderToProcess = strcat(outputdir, '/plotting/', deployment, '/');
A = dir( folderToProcess, '*.nc');
%
if (~isempty(A))
    dimFile = length(A);
%
dimfile = 4;
%
   if ( (exist(filesProcessedToTESAC, 'file') == 2) )
%List of files already processed for this particular deployment       
      fid = fopen(filesProcessedToTESAC);
      processed = textscan(fid, '%s', 'delimiter' , '\n' );
      fclose(fid)
      nProcessed = size(processed{1},1);
      for i =1:dimFile
        toto = 0;
        for j = 1:nProcessed
              if (strcmp(A(i).name, processed{:}{j}))
                 toto = toto+1;
              end
        end
        if (~toto)
          try
           nCycle = seaglider_realtime_GTS_subfunction1_UNIX_v3( deployment, A(i).name );
           fid_w = fopen(filesProcessedToTESAC, 'a');
           fprintf(fid_w,'%s \r\n', A(1).name );
           fclose(fid_w);
           fid_w = fopen(logfile, 'a');
           fprintf(fid_w,'%s %2.0f %s %s \r\n',datestr(clock), nCycle, ' TESAC messages have been created for the NetCDF file ', A(1).name );
           fclose(fid_w);
          catch
            fid_w = fopen(logfile, 'a');
            fprintf(fid_w,'%s %s %s \r\n',datestr(clock),' Problem when creating a TESAC message for the following NetCDF file ', A(1).name );
            fclose(fid_w);
          end 
        end
      end
   else
      for i =1:dimFile
        try
           nCycle = seaglider_realtime_GTS_subfunction1_UNIX_v3( deployment, A(i).name );
           fid_w = fopen(filesProcessedToTESAC, 'a');
           fprintf(fid_w,'%s \r\n', A(1).name );
           fclose(fid_w);
           fid_w = fopen(logfile, 'a');
           fprintf(fid_w,'%s %2.0f %s %s \r\n',datestr(clock), nCycle, ' TESAC messages have been created for the NetCDF file ', A(1).name );
           fclose(fid_w);
        catch
            fid_w = fopen(logfile, 'a');
            fprintf(fid_w,'%s %s %s \r\n',datestr(clock),' Problem when creating a TESAC message for the following NetCDF file ', A(1).name );
            fclose(fid_w);
        end
      end
   end
%
%
end
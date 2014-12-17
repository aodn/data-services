%% This is the main routine for the ANMN _Tempearture regriddding processing
% This script calls function ListTargetFiles to get information for new 
% deployment  to process . THe relevant info (node, site and deployment)
% is parsed to regrid_ANMN_deploy to generate
% regridding product .

% READ PATH FROM CONFIG FILE
Path2Opendap = eval(readConfig('opendapdir'));
Path2Product = eval(readConfig('productdir'));
Path2Wip = eval(readConfig('wipdir'));
OutputDir= eval(readConfig('outputdir'));
logfile = eval(readConfig('log_file'));
failedlog = eval(readConfig('failed_log'));
refdate = eval(readConfig('reference_date'));
loglatest = eval(readConfig('log_latestfile'));

if ~isempty(refdate)
    %CONVERT REFERENCE DATE PARSED AS STRING INTO NUMERIC
    refdate = str2num(refdate);
    fListIn  = ListTargetFiles(Path2Opendap,refdate);
else
    fListIn  = ListTargetFiles(Path2Opendap);
end
if ~isempty(fListIn)
    fido =fopen(fullfile(Path2Wip,loglatest),'w');
    for i = 1:length(fListIn) 
    %% PROCESS LISTED DEPLOYMENTS
         try
    % GENERATE THE REGRIDDED PRODUCT
    [Tstamp,Zgrid,IallP,Lat,Lon,freq,nValStep] = agregANMN_v_ave_RegularGrid(fListIn(i).path2file,fListIn(i).flistDeploy,'TEMP');

    % TIME STRING FOR OUTPOUT FILE NAME
    Tstart = datestr(Tstamp(1),'yyyymmddTHHMMSSZ');
    Tend = datestr(Tstamp(end),'yyyymmddTHHMMSSZ');
    Tcreat = local_time_to_utc(now,30);

    % OUTPUT FILE NAME
    % CREATE OUTPUT DIR IF NOT EXISTING ALREADY
    if ~exist(fullfile(Path2Wip,OutputDir,fListIn(i).node,fListIn(i).site),'dir');
        mkdir(fullfile(Path2Wip,OutputDir,fListIn(i).node,fListIn(i).site));
    end
    fileOut = fullfile(Path2Wip,OutputDir,fListIn(i).node,fListIn(i).site,['IMOS_ANMN-',fListIn(i).node,'_','Temperature','_',Tstart,'_',fListIn(i).site,'_FV02_',fListIn(i).id,'-regridded_END-',Tend,'_C-',Tcreat,'.nc']);

    % CREATE A NETCDF FILE. 
    create_netcdf_deploy_v4nc(fListIn(i),fileOut,'TEMP',IallP,Tstamp,Zgrid,Lat,Lon,freq,nValStep)

     % RECORD PROCESSED DEPLOYMENT
              recorddate = datestr(now);
              disp('Process sucessful. Check log for new or udpdated product listing');
              fid =fopen(fullfile(Path2Wip,logfile),'a');
              fprintf(fid,'%s \t Successfully processed : %s \t %s \t %s \n',recorddate,fListIn(i).node,fListIn(i).site,fListIn(i).deploymt);
              fclose(fid);
  
              fprintf(fido,'%s \t Successfully processed : %s \t %s \t %s \n',recorddate,fListIn(i).node,fListIn(i).site,fListIn(i).deploymt);
           

         catch exception
    % RECORD FAILED DEPLOYMENTS  
               recorddate = datestr(now);
               disp('errors in deployment processing : check log for details');
               fid =fopen(fullfile(Path2Wip,failedlog),'a');
               fprintf(fid,'%s \t %s \t %s \t %s \t %s\n' ,recorddate,fListIn(i).id,exception.message,exception.stack(1).name,num2str(exception.stack(1).line));
               fclose(fid);
                continue
         end
    end
 fclose(fido);
else
    disp('No new deployment') ;

end
exit

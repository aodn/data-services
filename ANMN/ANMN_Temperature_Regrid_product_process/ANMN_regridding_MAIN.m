%% This is the main routine for the ANMN _Tempearture regriddding processing
% This script calls function ListTargetFiles to get information for new 
% deployment  to process . THe relevant info (node, site and deployment)
% is parsed to regrid_ANMN_deploy to generate
% regridding product .

% READ PATH FROM CONFIG FILE
Path2Opendap = readConfig('opendapdir','configtst.txt');
Path2Product = readConfig('productdir','configtst.txt');
Path2Wip = readConfig('wipdir','configtst.txt');
OutputDir= readConfig('outputdir','configtst.txt');
logfile = readConfig('log_file','configtst.txt');
failedlog = readConfig('failed_log','configtst.txt');
refdate = readConfig('reference_date','configtst.txt');

if ~isempty(refdate)
    %CONVERT STRING TO DATE  NUMBER
    refdate = datenum(refdate);
    fListIn  = ListTargetFiles(Path2Opendap,refdate);
else
    fListIn  = ListTargetFiles(Path2Opendap);

    if ~isempty(fListIn)

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
                  recorddate = datevec(now);
                  fid =fopen(fullfile(Path2Wip,logfile),'a');
                  fprintf(fid,'%s \t Successfully processed : %s \t %s \n',recorddate,fListIn(i).node,fListIn(i).id);
                  fclose(fid);

             catch exception
        % RECORD FAILED DEPLOYMENTS  
                   recorddate = datevec(now);
                   fid =fopen(fullfile(Path2Wip,failedlog),'a');
                   fprintf(fid,'%s \t %s \t %s \t %s \t %s\n' ,recorddate,fListIn(i).id,exception.message,exception.stack(1).name,num2str(exception.stack(1).line));
                   fclose(fid);
                    continue
             end
        end
    else
        disp('No new deployment') ;
      
    end
end
exit

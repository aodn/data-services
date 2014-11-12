%% This is the main routine for the ANMN _Tempearture regriddding processing
% This script calls function ListTargetFiles to get information for new 
% deployment  to process . THe relevant info (node, site and deployment)
% is parsed to regrid_ANMN_deploy to generate
% regridding product .

% READ PATH FROM CONFIG FILE
Path2Opendap = readConfig('opendapdir');
Path2Product = readConfig('productdir');
Path2Wip = readConfig('wipdir');
OutputDir= readConfig('outputdir');
logfile = readConfig('log_file');
failedlog = readConfig('failed_log');
refdate = readConfig('reference_date');

if ~isempty(refdate)
    fListIn  = ListTargetFiles(Path2Opendap,refdate);
else
    fListIn  = ListTargetFiles(Path2Opendap);

    if ~isempty(fListIn)

        for i = 1:length(fListIn) 
        % % % % % %     
        % % % % % % %% Check if product for the listed deployments are already present on
        % % % % % % % opendap . If so, move old product to archive.
        % % % % % % path2fich = [Path2Opendap,fList(i).node,fList(i).site,'Temperature/gridded'];
        % % % % % % 
        % % % % % % if exist(path2fich,'dir')
        % % % % % %     TGridFileList = dir(path2fich);
        % % % % % %     comparer les id des deploiement present avec les nouveaux
        % % % % % %     ceux deja present dpoivent etre deplace sur archive. 
        % % % % % %     ATTETION : il serait plus sur de faire l'archivage apres avoir generer le nouveau produit
        % % % % % %     

        %% PROCESS LISTED DEPLOYMENTS
             try
        % GENERATE THE REGRIDDED PRODUCT
        [Tstamp,Zgrid,IallP,Lat,Lon,freq,nValStep] = agregANMN_v_ave_RegularGrid(fListIn(i).path2file,fListIn(i).flistDeploy,'TEMP');

        % TIME STRING FOR OUTPOUT FILE NAME
        Tstart = datestr(Tstamp(1),'yyyymmddTHHMMSSZ');
        Tend = datestr(Tstamp(end),'yyyymmddTHHMMSSZ');
        Tcreat = local_time_to_utc(now,30);

        % OUTPUT FILE NAME
        fileOut = fullfile(Path2Wip,OutputDir,fListIn(i).node,fListIn(i).site,['IMOS_ANMN-',fListIn(i).node,'_','Temperature','_',Tstart,'_',fListIn(i).site,'_FV02_',fListIn(i).id,'-regridded_END-',Tend,'_C-',Tcreat,'.nc']);

        % CREATE A NETCDF FILE. 
        create_netcdf_deploy_v4nc(fListIn(i),fileOut,'TEMP',IallP,Tstamp,Zgrid,Lat,Lon,freq,nValStep)

         % RECORD PROCESSED DEPLOYMENT
                  recorddate = datevec(today);
                  fid =fopen(fullfile(Path2Wip,logfile),'a');
                  fprintf(fid,'%s \t Successfully processed : %s \t %s \n',recorddate,fListIn(i).node,fListIn(i).id);
                  fclose(fid);

             catch exception
        % RECORD FAILED DEPLOYMENTS  
                   recorddate = datevec(today);
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

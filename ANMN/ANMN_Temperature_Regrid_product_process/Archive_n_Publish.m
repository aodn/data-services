%% PURPOSE:
% CHECK IF PRODUCT FOR THE LISTED DEPLOYMENTS ARE ALREADY PRESENT ON
% OPENDAP . IF SO, MOVE OLD PRODUCT TO ARCHIVE.
%  MOVE CREATED PRODUCTS : ONLY RECENTTLY CREATED PRODUCT ARE MOVED( THE
%  SCRIPT IS RUN BY CRON JOB ONCE A WEEK AFTER RUNNING THE ANMN_REGRIDDING_MAIN.M SCRIPTS 
Path2Opendap = readConfig('opendapdir');
Path2Product = readConfig('productdir');
Path2Wip = readConfig('wipdir');
OutputDir= readConfig('outputdir');
Path2Archive = readConfig('archivedir');
newprodlog = readConfig('newprod_log');
updatedprodlog = readConfig('updated_log'); 
loglatest = readConfig('log_latestfile');

%% READ IN LIST OF NEWLY PROCESSED DEPLOYMENTS 
fidl = fopen(fullfile(Path2Wip,loglatest),'r');
fline = cell(1,500);
% REMOVE EMPTY CELLS
fline(cellfun(@isempty,fline))=[];
count = 0;
while ~feof(fidl)
   
    tempo = fgetl(fidl);
    if isempty(tempo) | ~ischar(tempo)
        continue
    else
        count = count + 1;
        fline{count} = tempo;
    end
end
fclose(fidl);

%% EXTRACT INFO FROM FLINE
d = struct('node',{},'site',{},'deploymt',{});
for i = 1:length(fline)
    C = strsplit(fline{i});
    
% CHECK CREATION DATE. MOVE ONLY  MOST RECENT PRODUCT (TIMING DEPEND ON
% DELAY BETWEEN CREATION AND MOVE OF PRODUCTS. 
% ATTENTION :THIS TEST WAS USEFUL WHEN SCRIPT WAS READING FROM 'logfile'
% BUT OBSOLETE NOW. KEPT IT THOUGH 
    if now - datenum(C{1})>7   
        continue
    else
        d(i).node = C{6};
        d(i).site = C{7};
        d(i).deploymt = C{8};	 
    end
% CHECK IF EXISTING FILES ON OPENDAP
    fl = dir(fullfile(Path2Opendap,d(i).node,d(i).site,Path2Product,['IMOS_ANMN-',d(i).node,'*',d(i).site,'_FV02_',d(i).site,'-',d(i).deploymt,'*.nc']));
    if size(fl)>0
% PREVIOUS FILE NEEDS TO BE MOVED TO ARCHIVE
% CREATE ARCHIVE DIR IF NOT EXISTING ALREADY
        if ~exist(fullfile(Path2Archive,d(i).node,d(i).site),'dir');
            mkdir(fullfile(Path2Archive,d(i).node,d(i).site));
        end
        try  
            for nf = 1:length(fl)
                recorddate = datestr(now);
               [s_o,mess_o,messid] = movefile(fullfile(Path2Opendap,d(i).node,d(i).site,Path2Product,fl(nf).name),fullfile(Path2Archive,d(i).node,d(i).site));
                fid = fopen(fullfile(Path2Wip,updatedprodlog),'a');
                fprintf(fid,'%s\t Succesfully archived : %s %s %s \n',recorddate,d(i).node,d(i).site,d(i).deploymt);
                fclose(fid);
            end
        catch 
            error('Could not move file ', fl(nf).name);
            continue
        end
    end 
 % NEW OR UPDATED PRODUCT 
 
     new_fl = dir(fullfile(Path2Wip,OutputDir,d(i).node,d(i).site,['IMOS_ANMN-',d(i).node,'*',d(i).site,'_FV02_',d(i).site,'-',d(i).deploymt,'*.nc']));
    [s_n,mess_n,messid] = movefile(fullfile(Path2Wip,OutputDir,d(i).node,d(i).site,new_fl(1).name),fullfile(Path2Opendap,d(i).node,d(i).site,Path2Product));

% LOG LIST OF FILES MOVED TO OPENDAP
    recorddate = datestr(now);
    fido =fopen(fullfile(Path2Wip,newprodlog),'a');
    fprintf(fido,'%s\t Succesfully moved : %s %s %s \n',recorddate,d(i).node,d(i).site,d(i).deploymt);
    fclose(fido);
end
exit
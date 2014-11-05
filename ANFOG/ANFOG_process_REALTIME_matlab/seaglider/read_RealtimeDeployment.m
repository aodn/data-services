function seagliderRT = read_RealtimeDeployment
%
file_path = strcat(getenv('ARCHIVE_DIR'), '/eMII/TALEND_harvester/ANFOG/HarvestdeploymentList.csv');
fid = fopen(file_path);
c = textscan(fid,'%s %s %s %s %s','delimiter',',','HeaderLines',1);
fclose(fid);
idxTrue = strcmp(c{3},'TRUE');
idxsg = strcmp(c{2},'seaglider') ;
seagliderRT = c{1}(idxTrue & idxsg);

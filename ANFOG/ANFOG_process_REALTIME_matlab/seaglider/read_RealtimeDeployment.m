function seagliderRT = read_RealtimeDeployment
%
fid = fopen('/mnt/imos-t4/IMOS/archive/eMII/TALEND_harvester/ANFOG/HarvestdeploymentList.csv');
c = textscan(fid,'%s %s %s %s %s','delimiter',',','HeaderLines',1);
fclose(fid);
idxTrue = strcmp(c{3},'TRUE');
idxsg = strcmp(c{2},'seaglider') ;
seagliderRT = c{1}(idxTrue & idxsg);

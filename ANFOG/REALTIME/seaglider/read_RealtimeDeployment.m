function seagliderRT = read_RealtimeDeployment
%
fid = fopen('HarvestdeploymentList.csv');
c = textscan(fid,'%s %s %s %s %s','delimiter',',','HeaderLines',1);
fclose(fid);
idxTrue = strcmp(c{3},'TRUE');
idxsg = strcmp(c{2},'seaglider') ;
seagliderRT = c{1}(idxTrue & idxsg);

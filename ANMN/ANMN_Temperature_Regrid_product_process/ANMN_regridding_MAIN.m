%% This script reads in information (node, site and deployment)
% from ANMN_fileToProcess and parse them to regrid_ANMN_deploy to generate
% regridding product of the whole ANMN temperature timeseries
fid = fopen('/home/bpasquer/ANMN/ROUTINES/ANMN_fileToProcess_0716.txt','r');
%fid = fopen('/home/bpasquer/ANMN/ROUTINES/FILE_TO_REPROCESS_formatted.txt','r');
fline = cell(300,1);
count = 0;
while ~feof(fid)
     count = count + 1;
     fline{count} = fgetl(fid);
end
fclose(fid);

% remove empty cells
fline(cellfun(@(fline) isempty(fline),fline))=[];
failedFiles = {}; 

for i =290:length(fline)
  i
    dash = regexp(fline{i},'-');
    node{i} = fline{i}(1:dash(1)-1);
	site{i} = fline{i}(dash(1)+1:dash(2)-1);
	deployment{i} = fline{i}(dash(2)+1:end);

    try
% call to the processing routine
      regrid_ANMN_deploy(node{i},site{i},deployment{i},'Temperature');  
    catch exception
      sitenm = [site{i},'-',deployment{i}];
      fid =fopen('failedDeployment.dat','a');
      fprintf(fid,'%s \t %s \t %s \t %s\n' ,sitenm,exception.message,exception.stack(1).name,num2str(exception.stack(1).line))
      fclose(fid)
      continue
 end
end

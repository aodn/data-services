fid = fopen('/home/bpasquer/ANMN/FileList_afterupdate.txt','r');
%fid = fopen('/home/bpasquer/ANMN/ROUTINES/FinalList_rev.txt','r');
%lit la liste des fichiers contenant des donnes a traiter
% output is deploymentID of all deployment that have more than 2 sample depth 
% need to add the site name to get all the info on depoyment for listing
fline = cell(1,3000);
count = 0;
while ~feof(fid)
   
    tempo = fgetl(fid);
    if isempty(tempo) | strncmp(tempo,'%',1) | ~ischar(tempo)|~isempty(strfind(tempo,'Biogeochem_timeseries'))
        continue
    else
 
     count = count + 1;
            fline{count} = tempo;
    end
end
fclose(fid)
% Remove empty cells
fline(cellfun(@(fline) isempty(fline),fline))=[];

node = cell(1,length(fline));site = cell(1,length(fline));
deploymentsfiles = cell(1,length(fline));

% Extract info from fline
for i = 1:length(fline)
	slash = regexp(fline{i},'/');
    fline{i}(1:slash(1)-1)=[];
    slash = regexp(fline{i},'/');
	node{i} = fline{i}(slash(6)+1:slash(7)-1);
	site{i} = fline{i}(slash(7)+1:slash(8)-1);
	deploymentfile{i} = fline{i}(slash(end)+1:end);
	dash = regexp(deploymentfile{i},'-');
	dep_id = deploymentfile{i}(dash(2)+1:dash(3)-1);
	deploymentID{i} = [char(site{i}),'-',dep_id];
end 

%list deployment
listDep_long = strcat(node,'-',deploymentID);
listDep = unique(listDep_long);
ndepth =zeros(1,length(listDep)); %get number of depth er deployment

for j= 1:length(listDep)
   
   ndepth(j) = length( find(strcmp(listDep(j),listDep_long)==1));
    
end

listDep(ndepth<=2)=[];

fid = fopen('ANMN_fileToProcess_code_rev.txt','w');
fprintf(fid,'%s \n',listDep{:});
fclose(fid);


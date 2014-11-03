fid = fopen(fullfile(pwd,'ANMN_Processsedfile.txt'),'r');

fline = cell(1,500);
count = 0;
while ~feof(fid)
   
    tempo = fgetl(fid);
    if isempty(tempo) | strncmp(tempo,'%',1) | ~ischar(tempo)
        continue
    else
        count = count + 1;
        fline{count} = tempo;
    end
end
fclose(fid);
% delete empty cells
fline(cellfun(@isempty, fline)) =[];
fid = fopen(fullfile(pwd,'ANMN_fileToProcess_0716.txt'),'r');
full_list = cell(1,500);
count = 0;
while ~feof(fid)
   
    tempo = fgetl(fid);
    if isempty(tempo) | strncmp(tempo,'%',1) | ~ischar(tempo)
        continue
    else
        count = count + 1;
        full_list{count} = tempo;
    end
end
fclose(fid);

% Identify index of processed deployments
out_indx = zeros(length(fline),1);
for n =1:length(fline)    
    out_indx(n) = find(strcmp(fline{n},full_list)==1);
end

  full_list(out_indx)= [] ;  
  upt_list = cell2struct(full_list,'name');
  fid =fopen('ANMN_fileToProcess_upt.txt', 'w');
  fprintf(fid,'%s\n',upt_list.name);
  fclose(fid);
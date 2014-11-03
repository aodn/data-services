%fid = fopen('/Users/vbpasquer/Documents/ANMN/Listing/FlistProcessed.txt','r');
% function to list processed deployments 
% 
flist = dir(fullfile(pwd,'IMOS*FV02*.nc'));

%extract info from flist
for i = 1:length(flist)
    
    dash = regexp(flist(i).name,'-');
    unders = regexp(flist(i).name,'_');
	node = flist(i).name(dash(1)+1:unders(2)-1);
	site_deploy = flist(i).name(unders(6)+1:dash(3)-1);
    listDepl(i).name = strcat(node,'-',site_deploy);
    
end 


fid = fopen('ANMN_Processsedfile.txt','w');

fprintf(fid,'%s \n',listDepl.name);
fclose(fid)


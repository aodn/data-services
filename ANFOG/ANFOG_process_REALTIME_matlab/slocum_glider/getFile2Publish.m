function [File2Publish] = getFile2Publish(fname) 
% 
% INPUT : 
%       -fname : structure of file name 
%          

% OUTPUT: 
%       -File2Publish:strcuture of datafile to publish
% 
% December 2014: add case deployment to get deployment file info
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

for nf = 1:length(fname)        
    slash = regexp(fname(nf).path2file,'/');
    RTfileList(nf).name = fname(nf).name;
    RTfileList(nf).deploymt = fname(nf).path2file(slash(end)+1:end);
end


[dplym_fulllist{1:length(fname)}] =  RTfileList.deploymt  ;

%DETERMINE NUMBER OF RT FILES PER DEPLOYMENT
RTdeploymentID = unique(dplym_fulllist);

for ndpl = 1: length(RTdeploymentID)
    [lia, lib] = ismember(dplym_fulllist,RTdeploymentID(ndpl));
    nfile = length(lib(lib==1));
    idx = find(lib==1);
    [creationdate{1:nfile}]  =  fname(idx).datenum;
    [val, indm] = max(cell2mat(creationdate));
    % DETERMINE LATEST FILE : ONLY THIS ONE Is TO BE PUBLISHED 
    File2Publish(ndpl).name= fullfile(fname(idx(indm)).path2file,fname(idx(indm)).name);
    File2Publish(ndpl).deploymt =  RTfileList(idx(indm)).deploymt;
    File2Publish(ndpl).datenum = fname(idx(indm)).datenum;
    clear creationdate
end
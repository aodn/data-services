function [subDir]=listSubDir(Folder)
if strcmpi(Folder(end),filesep)
    Folder=Folder(1:end-1);
end
[~,~,Files]=DIRR(Folder,'name','isdir','1');
[pathdir, ~, ~]=cellfun(@fileparts, Files', 'un',0);
subDir=uunique(pathdir);
end
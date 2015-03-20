function [subDir]=listSubDir(Folder)
%listSubDir - list all the subdirectories only
%The function calls DIRR.m
% Syntax:  [subDir]=listSubDir('FolderName')
%
% Inputs:
%    Folder - string of the folder name
%
% Outputs:
%    subDir - cell array of subfolders
%
% Example:
%    [subDir]=listSubDir(Folder)
%
% Other files required: none
% Other m-files required: DIRR
% Subfunctions: none
% MAT-files required: none
%
% See also: DIRR,mkpath
%
% Author: Laurent Besnard, IMOS/eMII
% email: laurent.besnard@utas.edu.au
% Website: http://imos.org.au/  http://froggyscripts.blogspot.com
% Aug 2012; Last revision: 09-Aug-2012

if strcmpi(Folder(end),filesep)
    Folder =Folder(1:end-1);
end

[~,~,Files]     = DIRR(Folder,'name','isdir','1');
[pathdir, ~, ~] = cellfun(@fileparts, Files', 'un',0);
subDir          = uunique(pathdir);

end
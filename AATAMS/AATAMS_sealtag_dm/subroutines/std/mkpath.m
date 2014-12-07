function mkpath(directory)
%mkpath - create the full path of a folder reccursively
%
% Syntax:  [mkpath(directory)
%
% Inputs:
%    directory - full path of the folder name
%    
% Outputs:
%
% Example: 
%    mkpath(directory)
%
% Other files required: none
% Other m-files required: none
% Subfunctions: none
% MAT-files required: none
%
% See also: DIRR,listSubDir
%
% Author: Laurent Besnard, IMOS/eMII
% email: laurent.besnard@utas.edu.au
% Website: http://imos.org.au/  http://froggyscripts.blogspot.com
% Aug 2012; Last revision: 09-Aug-2012

if iscell(directory)
    directory=char(directory);
end
indexSeparator=regexp((directory),filesep);
nSeparator=length(indexSeparator);

if iscell(indexSeparator)
    indexSeparator=cell2mat(indexSeparator);
    nSeparator=length(indexSeparator);
end

for iiSeparator=1:nSeparator
    if exist(char(directory(1:indexSeparator(iiSeparator))),'dir') == 7
        %         sprintf('directory "%s" already
        %         exist',directory(1:indexSeparator(iiSeparator)))
    elseif exist(char(directory(1:indexSeparator(iiSeparator))),'dir') == 0
        mkdir(char(directory(1:indexSeparator(iiSeparator)))); % we create at each iteration the full path.
    end
    
end



%% last iteration
if exist(char(directory),'dir') ==0
    mkdir(char(directory));
end

end
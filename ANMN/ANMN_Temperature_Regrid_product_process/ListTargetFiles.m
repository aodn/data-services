function [ fListOut ] = ListTargetFiles (path2dir,varargin)
% Function that lists and filters target files for processing. Lists 
% (recursively) all the files in the input path. 
% Filter based on modification date of file. 
% Inputs:
%   - path2dir  : target directory. 
%   - varargin{1} : reference date for filtering other than 'today'   
% 
% Output: - fListOut : strcuture containing deployment info (node, site,
%                   id)
%


fun = @(d) ~isempty(regexp(d.name,'Temperature', 'once')) && (d.datenum > today-1); 
fListIn = rdir(path2dir,fun,1);

% % Extract modification date
% modDate = cell(1,length(fListIn));
% [ modDate{1:length(fListIn)} ] = fListIn.datenum;

% Filter out processed deployments. Process run daily. Check files for newer
% modif date than 'today' or  other specified date

% if ~isempty(varargin)
%    fListIn = rdir(path2dir,'datenum>varargin{1}-1',regexp(name, '/Temperature/'),1);
% else
%    fListIn = rdir(path2dir,'datenum>today-1 & regexp(name, 'Biogeochem_timeseries')',1);
% end

%extract deployment info (node,site,deployment) from file name using regexp
if ~isempty(fListIn)
    for i = 1:length(fListIn)

        fline = fListIn(i).name;
        slash = regexp(fline,'/');   
%         fline(1:slash(end))=[]; % delete path

        dash = regexp(fline,'-'); uscore = regexp(fline,'_');

        fListOut(i).node = fline(dash(1)+1:uscore(2)-1);
        fListOut(i).site = fline(uscore(4)+1:uscore(5)-1);
        fListOut(i).id = fline(dash(2)+1:dash(3)-1);

    end 
end

end


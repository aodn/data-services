function [ fListOut ] = ListTargetFiles (path2dir,varargin)
% FUNCTION THAT LISTS AND FILTERS TARGET FILES FOR PROCESSING. LISTS 
% (RECURSIVELY) ALL THE FILES IN THE INPUT PATH. EXCLUDE DEPLOYMENTS WITH 2
% OR LESS DEPTH. 
% FILTER BASED ON MODIFICATION DATE OF FILE. 
% INPUTS:
%   - path2dir  : target directory. 
%   - varargin{1} : reference date for filtering. Default value is 'today'
%                   date must be a matlab datenum
%
% OUTPUT: - fListOut : strcuture containing deployment info (node, site,
%                   id,list of files in deployment )
%
%BPasquer November 2014
%
if ~isempty(varargin) 
    if ~isnumeric(varargin{1})
        error('reference date must be a date number')
    end
    fun = @(d) ~isempty(regexp(d.name,'Temperature', 'once')) && (d.datenum > varargin{1}); 
end    

fun = @(d) ~isempty(regexp(d.name,'Temperature', 'once')) && (d.datenum > now-7); 
flist = rdir([path2dir '**/*FV01*.nc'],fun);

% EXTRACT DEPLOYMENT INFO (NODE,SITE,DEPLOYMENT) FROM FILE NAME USING REGEXP
if ~isempty(flist)
    for i = 1:length(flist)
        [pathstr,name,ext] = fileparts(flist(i).name);
        flist(i).path2file = pathstr;
        flist(i).name = strcat(name,ext);
% % SET PATH TO FILES TO BE PROCESSED
    end     
    tempoList = scan_filename(flist,'deployment');
       
% CHECK NUMBER OF NOMINAL DEPTH PER DEPLOYEMNT
    [ listDep_long{1:length(tempoList)} ]  = tempoList.id;
    listDep = unique(listDep_long);
    ndepth =zeros(1,length(listDep)); %get number of depth per deployment

    for j= 1:length(listDep)

       ndepth(j) = length( find(strcmp(listDep(j),listDep_long)==1));  

    end
% EXCLUDE DEPLOYMENT WITH 2 OR LESS NOMINAL DEPTH
    listDep(ndepth<=2)=[];
     
    [lia, lib] = ismember(listDep,listDep_long); 
%lib :INDEX OF FIRST OCCURENCE OF FILES TO BE PROCESSED
    fListOut = tempoList(lib);
   
    %group file per deployment
    
     for i = 1:length(listDep)
     
         fListOut(i).flistDeploy =  dir(fullfile(flist(lib(i)).path2file,['IMOS_ANMN-',tempoList(lib(i)).node,'*_',tempoList(lib(i)).site,'_*_',tempoList(lib(i)).id,'*.nc']));
         fListOut(i).path2file = flist(lib(i)).path2file;
     end
    
else
    fListOut = [];   
end
    
end
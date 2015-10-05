function [fileList]=listThreddsNC_2(url_catalog)
% List_NC_recurTEST needs an http access to download the xml file of the
% thredds catalog. This function lists all the NetCDF files in the sub
% directories recursively and gives their full path.
% this one differs from listThreddsNC only because of a different xml toolbox used
% the io-xml toolbox
% SLOW version.
%
% example :
% url_catalog='http://thredds.aodn.org.au/thredds/catalog/IMOS/SOOP/SOOP-CO2/catalog.xml';
%
% Inputs:
%   url_catalog                - https address of the THREDDS catalog
%                                .XML,Not HTML
%
% Outputs :
%   fileList                   - Cell array of the NC files
%
% Author: Laurent Besnard <laurent.besnard@utas.edu.au>
%
%
% Copyright (c) 2011, eMarine Information Infrastructure (eMII) and Integrated
% Marine Observing System (IMOS).
% All rights reserved.
%

warning off all

% fix user input
[matchstart,matchend] =regexp(url_catalog,'/dodsC/');
if ~isempty(matchstart) &&  ~isempty(matchend)
    url_catalog = strcat(url_catalog(1:matchstart),'catalog',url_catalog(matchend:end));
end

% fix user input
[matchstart,matchend] =regexp(url_catalog,'/catalog.html$');
if ~isempty(matchstart) &&  ~isempty(matchend)
    url_catalog = strcat(url_catalog(1:matchstart),'catalog.xml');
end

%% Put in a structure called V the content of url_catalog
timeOut=5000;%in ms
url_catalog={url_catalog};
fileList=[]';

filenameXML=strcat(tempdir,'THREDDS.xml');

[~,opendap_server_online]=urlwrite2(url_catalog{1}, filenameXML,[],[],timeOut);
if ~opendap_server_online
    fprintf('%s ERROR: UNREACHABLE URL:"%s"\n',datestr(now),url_catalog{1})
end

% try
%     urlwrite(url_catalog{1}, filenameXML);
%     opendap_server_online=1;
%     TimeElapsed=0;
% catch
%     fprintf('Cannot reach URL:"%s"\n',url_catalog{1})
%     opendap_server_online=0;
% end


if opendap_server_online
    V = xml_read(filenameXML);
    delete(filenameXML);

    %%% List the files in the current page
    try
        NumberNCfiles=length(V.dataset.dataset);
        fileList=cell(length(V.dataset.dataset),1);

        for ii=1:length(V.dataset.dataset)
            fileList{ii}=V.dataset.dataset(ii,1).ATTRIBUTE.urlPath;
        end
    catch
    end


    %%% List the subfolders in the current page
    try
        NumberSubfolders=length(V.dataset.catalogRef);
        subDirs=cell(NumberSubfolders,1);
        for ii=1:NumberSubfolders
            subDirs{ii}=V.dataset.catalogRef(ii,1).ATTRIBUTE.xlink_COLON_href;
        end
%        if isnumeric(subDirs{1})
%            subDirs=cellfun(@(x) num2str(x),subDirs,'UniformOutput',0);
%        end
    catch
        subDirs=[];
        NumberSubfolders=0;
    end

    %%% call recursively the function to list all the NetCDF files in the
    %%% subdirectories
    if NumberSubfolders>0
        for jj=1:NumberSubfolders
            nextDir=strcat(url_catalog{1}(1:end-length('catalog.xml')),char(subDirs{jj}));
            fileList=[fileList;listThreddsNC_2(nextDir)];
        end
    end

else
    fileList=[];
    return
end
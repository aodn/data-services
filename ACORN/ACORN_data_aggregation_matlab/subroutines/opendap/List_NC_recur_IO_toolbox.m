function [fileList]=List_NC_recur_IO_toolbox(url_catalog)
% List_NC_recurTEST needs an http access to download the xml file of the
% thredds catalog. This function lists all the NetCDF files in the sub
% directories recursively and gives their full path.
%
% example :
% url_catalog='http://opendap-qcif.arcs.org.au/thredds/catalog/IMOS/ACORN/gridded_1h-avg-current-map_non-QC/CBG/2007/catalog.xml';
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
% Redistribution and use in source and binary forms, with or without
% modification, are permitted provided that the following conditions are met:
%
%     * Redistributions of source code must retain the above copyright notice,
%       this list of conditions and the following disclaimer.
%     * Redistributions in binary form must reproduce the above copyright
%       notice, this list of conditions and the following disclaimer in the
%       documentation and/or other materials provided with the distribution.
%     * Neither the name of the eMII/IMOS nor the names of its contributors
%       may be used to endorse or promote products derived from this software
%       without specific prior written permission.
%
% THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
% AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
% IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
% ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
% LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
% CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
% SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
% INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
% CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
% ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
% POSSIBILITY OF SUCH DAMAGE.
%

warning off all
%% Put in a structure called V the content of url_catalog
timeOut=5000;%in ms
url_catalog={url_catalog};
fileList=[]';

filenameXML='THREDDS.xml';

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
            fileList=[fileList;List_NC_recur_IO_toolbox(nextDir)];
        end
    end
    
else
    fileList=[];
    return
end
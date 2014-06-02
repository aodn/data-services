function [fileList,fileSize,urlNotReached]=List_NC_recur(url_catalog)
%% List_NC_recur 
% List_NC_recur needs an http access to download the xml file of the
% thredds catalog. This function lists all the NetCDF files in the sub
% directories recursively and gives their full path.
%
%
% Functional Requirements/software capabilitie
% <Itemize the detailed functional requirements associated with this feature. These are
% the software capabilities that must be present in order for the user to carry out the 
% services provided by the feature, or to execute the use case. Include how the product
% should respond to anticipated error conditions or invalid inputs. Requirements should
% be concise, complete, unambiguous, verifiable, and necessary. Use “TBD” as a placeholder 
% to indicate when necessary information is not yet available.>
%
% The harvest of the opendap catalog is made by going reccursively trough
% each xml pages. Each time a new folder is found, the subroutine is called
% recursively in order to list all the files in it. If a sub-catalog or page, or
% even if the main catalog does not exist (or is not available), then its
% address is added to the variable urlNotReached. When a catalog is not
% accessible, the subroutine is paused for a couple of second, to help the
% server to 'warm up', then it tries to harvest the catalog for a couple of
% tries until it has successed. If this takes too much time, the harvest passes 
% on to the next sub-catalog.
% 
%
% Requirements : URLWRITE2 from Fu-Sung Wang
%
% Example :
% url_catalog='http://opendap-qcif.arcs.org.au/thredds/catalog/IMOS/ACORN/gridded_1h-avg-current-map_non-QC/CBG/2007/catalog.xml';
% [fileList,urlNotReached]=List_NC_recur(url_catalog)
%
% Inputs:
%   url_catalog                - https address of the THREDDS catalog
%                                .XML,Not HTML
%
% Outputs :
%   fileList                   - Cell array of the NC files found with their
%                                opendap folder hierarchy
%   fileSize                   - Matrix of each NC file size as written in
%   the xml catalog (in bytes)
%   urlNotReached              - Cell array of the catalog URL which were not accessible
%
% Author: Laurent Besnard <laurent.besnard@utas.edu.au>
%
%
% Other m-files required:readConfig
% Other files required: config.txt
% Subfunctions: none
% MAT-files required: none
%
% See also:
% readConfig,aggregateFiles
%
% Author: Laurent Besnard, IMOS/eMII
% email: laurent.besnard@utas.edu.au
% Website: http://imos.org.au/  http://froggyscripts.blogspot.com
% Aug 2012; Last revision: 8-Oct-2012

% warning off all
%% Put in a structure called V the content of url_catalog
timeOut=10000;%in ms
url_catalog={url_catalog};
fileList=[]';
fileSize=[]';
urlNotReached=[]';


global TEMPORARY_FOLDER
filenameXML=strcat(TEMPORARY_FOLDER,filesep,'THREDDS.xml');

[~,opendap_server_online]=urlwrite2(url_catalog{1}, filenameXML,[],[],timeOut);
nIterationsMax=4;
nIterations=0;
% time to wait in sec
timeToPause=1;

% we try to download a catalog.xml. If it doesn't work the first time
% before timeOut, we try again nIterationsMax
while ( ~opendap_server_online && ~(nIterations>nIterationsMax))
    %     fprintf('%s ERROR: UNREACHABLE URL:"%s". We retry now.\n',datestr(now),url_catalog{1})
    pause(timeToPause) %in sec , and we start again
    [~,opendap_server_online]=urlwrite2(url_catalog{1}, filenameXML,[],[],timeOut);
    nIterations=nIterations+1;
end


if ~opendap_server_online
    fprintf('%s ERROR: UNREACHABLE URL:"%s"\n',datestr(now),url_catalog{1})
    urlNotReached=url_catalog{1};
    fileList=[];
    fileSize=[];
end

% if the xml file has been downloaded
if opendap_server_online
    V = xml_parseany(fileread(filenameXML));
    delete(filenameXML);
    
    %% List the files in the current page if there are any
    try
        %         NumberNCfiles=length(V.dataset{1,1}.dataset);
        fileList=cell(length(V.dataset{1,1}.dataset),1);
        fileSize=eye(length(V.dataset{1,1}.dataset),1);
        for ii=1:length(V.dataset{1,1}.dataset)
            fileList{ii}=V.dataset{1,1}.dataset{ii}.ATTRIBUTE.urlPath;
            try
                fileSize(ii)=str2double(V.dataset{1,1}.dataset{ii}.dataSize{1}.CONTENT);
            catch
                fileSize(ii)=0;
            end
        end
    catch
    end
    
    
    %% List the subfolders in the current page if there are any
    try
        NumberSubfolders=length(V.dataset{1}.catalogRef);
        subDirs=cell(NumberSubfolders,1);
        for ii=1:NumberSubfolders
            subDirs{ii}=V.dataset{1}.catalogRef{ii}.ATTRIBUTE.xlink_href;
        end
    catch
        subDirs=[];
        NumberSubfolders=0;
    end
    
    %% call recursively the function to list all the NetCDF files in the
    %% subdirectories
    if NumberSubfolders>0
        for jj=1:NumberSubfolders
            nextDir=strcat(url_catalog{1}(1:end-11),subDirs{jj});
            [fileList_nextDir,fileSize_nextDir,urlNotReached_nextDir]=List_NC_recur(nextDir);
            fileList=[fileList;fileList_nextDir];
            fileSize=[fileSize;fileSize_nextDir];

            urlNotReached=[urlNotReached;urlNotReached_nextDir];
        end
    end
    
end

end
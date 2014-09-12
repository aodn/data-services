function [header_data, errorID] = getImageinfoGDAL2(AUV_Folder,Campaign,Dive)
%getImageinfo harvests the metadata of a folder containing GeoTIFF images
% it requires to have gdalinfo and gdal-bin package
%
% Inputs:
%   AUV_Folder  - str pointing to the main AUV folder address ( could be
%                 local or on the DF -slow- through a mount.davfs
%   Campaign    - str containing the Campaign name.
%   Dive        - str containing the Dive name.
%
% Outputs:
%   header_data       - Structure containing images metadata.
%   errorID           - Cell array containing a list of corrupted image names.
%
% Author: Laurent Besnard <laurent.besnard@utas,edu,au>
% Oct 2012; Last revision: 31-Oct-2012

format long
warning('off','MATLAB:dispatcher:InexactCaseMatch')

divePath= (strcat(AUV_Folder,filesep,Campaign,filesep,Dive));
TIFF_dir=dir([divePath filesep 'i2*gtif']);
tiffPath=[divePath filesep TIFF_dir.name];

list_images=dir([tiffPath filesep '*LC16.tif']);

reverseStr = '';
errorID=[];
if ~isempty(list_images)
    fprintf('%s - Processing images for %s\n',datestr(now), [Campaign '-' Dive]);
%     header_data(length(list_images),1)=struct('upLlat',[],'upLlon',[],'upRlat',[],'upRlon',[],...
%         'lowRlat',[],'lowRlon',[],'lowLlat',[],'lowLlon',[],'lon_center',[],'lat_center',[]);
    k=0;
    eID=0; %errorID index
    for j=1:length(list_images)
        
        image_name_location= strcat(strcat(AUV_Folder,filesep,Campaign,filesep,Dive,filesep,TIFF_dir.name,filesep,list_images(j,1).name));
        gdalOutput=gdalInfo(image_name_location);
        if ~isempty(fieldnames(   gdalOutput))
            k=k+1;
           
            fieldNames=fieldnames(gdalOutput);
            for ff=1:length(fieldNames)
               header_data(k,1).([fieldNames{ff}])= gdalOutput.([fieldNames{ff}]);
            end
            
            % Display the progress
            msg = sprintf('%s - image proccessed :%d / %d \n',datestr(now),j,length(list_images)); %Don't forget this semicolon
            fprintf([reverseStr, msg]);
            reverseStr = repmat(sprintf('\b'), 1, length(msg));

        else
            eID=eID+1;
            errorID{eID}=list_images(j).name;
        end
        
    end
else
    fprintf('%s - WARNING: No images to process for %s\n',datestr(now), [Campaign '-' Dive]);
    header_data=struct;
end

end
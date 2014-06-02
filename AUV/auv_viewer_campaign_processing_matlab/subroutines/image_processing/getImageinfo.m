function [header_data, errorID] = getImageinfo(AUV_Folder,Campaign,Dive)
%getImageinfo harvests the metadata of a folder containing GeoTIFF images
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
%
%        systemCmd = sprintf('gdalinfo %s', image_name_location)
%        [~,tt]=system(systemCmd)
%     !gdalinfo /media/Laurent_emII/PROCCESSED/WA201004/r20100421_022145_rottnest_03_25m_s_out/i20100421_022145_gtif/PR_20100421_022959_950_LC16.tif > /home/lbesnard/gdalinfo.txt

format long
warning('off','MATLAB:dispatcher:InexactCaseMatch')


% cd (strcat(AUV_Folder,filesep,Campaign,filesep,Dive))
% TIFF_dir=dir('i2*gtif');        %directory of the images
% 
% cd(TIFF_dir.name);
% 
% list_images=dir('*.tif');
divePath= (strcat(AUV_Folder,filesep,Campaign,filesep,Dive));
TIFF_dir=dir([divePath filesep 'i2*gtif']);
tiffPath=[divePath filesep TIFF_dir.name];

list_images=dir([tiffPath filesep '*.tif']);

errorID=[];

header_data(length(list_images),1)=struct('upLlat',[],'upLlon',[],'upRlat',[],'upRlon',[],...
    'lowRlat',[],'lowRlon',[],'lowLlat',[],'lowLlon',[],'lon_center',[],'lat_center',[]);
k=0;    
eID=0; %errorID index
for j=1:length(list_images)
    
    image_name_location= strcat(strcat(AUV_Folder,filesep,Campaign,filesep,Dive,filesep,TIFF_dir.name,filesep,list_images(j,1).name));
    try   %try catch if the image is corrupted
        
    gdalinfo=geotiffinfo(image_name_location);
    k=k+1;  %the header_data works with the k index since it avoids to have an empty header_data index to occur if the image is corrupted
    CornerCoordinates=gdalinfo.CornerCoords;
    
    header_data(k,1).upLlat=CornerCoordinates.Lat(1,1);
    header_data(k,1).upLlon=CornerCoordinates.Lon(1,1);
    
    header_data(k,1).upRlat=CornerCoordinates.Lat(1,2);
    header_data(k,1).upRlon=CornerCoordinates.Lon(1,2);
    
    header_data(k,1).lowRlat=CornerCoordinates.Lat(1,3);
    header_data(k,1).lowRlon=CornerCoordinates.Lon(1,3);
    
    header_data(k,1).lowLlat=CornerCoordinates.Lat(1,4);
    header_data(k,1).lowLlon=CornerCoordinates.Lon(1,4);
    
    header_data(k,1).lon_center=(header_data(k,1).upLlon + header_data(k,1).upRlon + header_data(k,1).lowRlon + header_data(k,1).lowLlon)/4;
    header_data(k,1).lat_center=(header_data(k,1).upLlat + header_data(k,1).upRlat + header_data(k,1).lowRlat + header_data(k,1).lowLlat)/4;
    
    header_data(k,1).Width= gdalinfo.Width;
    header_data(k,1).Heigh= gdalinfo.Height;
    header_data(k,1).Projection=gdalinfo.Projection;
    header_data(k,1).GCS=gdalinfo.GCS;
    header_data(k,1).image=list_images(j).name;
    
    catch ME%if the image is corrupted, it is listed
         eID=eID+1;
         errorID{eID}=list_images(j).name;
     end
    
end

end



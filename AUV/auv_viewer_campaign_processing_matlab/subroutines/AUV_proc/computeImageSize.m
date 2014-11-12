function [Image_Width, Pixel_Size ,Divedistance] =  computeImageSize(header_data)
%% extract coordinates from header_data input
LON_TOP_LEFT    =[header_data.upLlon];                                             %Load of the structure create by geotiffinfo.m
LAT_TOP_LEFT    =[header_data.upLlat];
LON_TOP_RIGHT   =[header_data.upRlon];
LAT_TOP_RIGHT   =[header_data.upRlat];
ResolutionX     =[header_data.Width];

%% compute the distance in meters of the track overtook by the robot
dist=0;
Divedistance=0;
for k=1:length(header_data)-1
    dist = 1000*Dist2km(header_data(k).lon_center,header_data(k).lat_center,header_data(k+1).lon_center,header_data(k+1).lat_center);
    if isempty(dist)
        kk=k;
        continue
    end
    Divedistance=dist+Divedistance; %in meters
end


%% Compute the Pixel Size
Image_Width = Dist2km(LON_TOP_LEFT,LAT_TOP_LEFT,LON_TOP_RIGHT,LAT_TOP_RIGHT)*1000; % Width of images in meter
Pixel_Size  = Image_Width.*1.0 ./ ResolutionX;     
end
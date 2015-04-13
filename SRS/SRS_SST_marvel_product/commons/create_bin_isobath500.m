function bin = create_bin_isobath500(netcdf_filename,lon_nc_varname,lat_nc_varname)
% this function creates a bin gridded variable, or mask, containing points
% at the isobath 500m around Australia. The initial data is provided by a
% third party in a file called marvl_binned_points.csv.
% This function reads a SRS netcdf file, a proxy, and its lat lon
% coordinates, looks for similar coordinates as in the CSV file, and
% returns a bin gridded variable.
%
% input:
%       netcdf_filename
%       lon_nc_varname : string of the longitude variable name from NetCDF
%       lat_nc_varname : string of the latitude variable name from NetCDF
%
% output:
%        bin : gridded variable containing 1 where to keep data, NaN
%        everywhere else
%
% laurent.besnard@utas.edu.au

netcdf_info                        = ncinfo(netcdf_filename);

index_lat                          = (strcmp({netcdf_info.Dimensions.Name}, lat_nc_varname));
index_lon                          = (strcmp({netcdf_info.Dimensions.Name}, lon_nc_varname));

dim_lon                            = netcdf_info.Dimensions(index_lon).Length;
dim_lat                            = netcdf_info.Dimensions(index_lat).Length;


import_lat_lon ; % data created by xavier in CSV; returns Latitude, Longitude

ncid                               = netcdf.open(netcdf_filename,'NOWRITE');
lat                                = getVarNC(lat_nc_varname,ncid);
lon                                = getVarNC(lon_nc_varname,ncid);
netcdf.close(ncid)

% rounded to closest integer nc values
lat_rounded                        = round(lat*10)/10;
lon_rounded                        = round(lon*10)/10;

% create pairs of unrounded lat lon from netcdf
[p,q]                              = meshgrid(lon, lat);
pairs_lat_lon_nc_unrounded         = [p(:) q(:)];

% create pairs of rounded lat lon from netcdf
[p,q]                              = meshgrid(lon_rounded, lat_rounded);
pairs_lat_lon_nc_rounded           = [p(:) q(:)];

% create vector of xavier's mask pairs of Lat and Lon
pairs_lat_lon_mask                 = horzcat(Longitude,Latitude);

% find equivalent ones
existing_lat_lon_pairs             = ismember(pairs_lat_lon_nc_rounded,pairs_lat_lon_mask,'rows');


%% we look for the indexes to keep, by creating a bin
pairs_lat_lon_nc_unrounded_to_keep = unique(pairs_lat_lon_nc_unrounded(existing_lat_lon_pairs ==1,:),'rows');

bin = NaN(dim_lon,dim_lat);
for ii = 1 : length(pairs_lat_lon_nc_unrounded_to_keep)
    ilon_to_keep                   = lon == pairs_lat_lon_nc_unrounded_to_keep(ii,1);
    ilat_to_keep                   = lat == pairs_lat_lon_nc_unrounded_to_keep(ii,2);
    bin(ilon_to_keep,ilat_to_keep) = 1;
end

end
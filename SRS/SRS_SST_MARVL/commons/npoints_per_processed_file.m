output_dir            = '/home/lbesnard/IMOS/marvl_srs/L3S-1d_ngt_marvel';
[~,~,list_ncfiles]    = DIRR(strcat(output_dir,filesep,'*.nc'),'name');


for ii = 1 : length(list_ncfiles)
    
    netcdf_filename_input = char(list_ncfiles(ii));
    ncid               = netcdf.open(netcdf_filename_input,'NOWRITE');
    
    data              = getVarUnpackedNC('sea_surface_temperature' ,ncid);
    n_points(ii) = sum(sum(~isnan(data)));
    time_value(ii) = getVarUnpackedNC('time' , ncid);
    netcdf.close(ncid)
end

plot(time_value,n_points)
ylabel('n points')
sum(sum(n_points))
datetick('x','yyyy-mm')

matFile = 'n_points.mat';
save (matFile,'n_points','time_value')

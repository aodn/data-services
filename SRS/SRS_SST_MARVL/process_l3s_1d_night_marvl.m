input_dir             = '/mnt/opendap/2/SRS/sst/ghrsst/L3S-1d/ngt';
output_dir            = '/mnt/imos-t4/IMOS/archive/eMII/srs_sst_marvel/L3S-1d_ngt_marvel';

what_path = what;
addpath(genpath(what_path.path))
mkpath(output_dir)

[~,~,list_ncfiles]    = DIRR(strcat(input_dir,filesep,'*.nc'),'name');

lon_nc_varname        = 'lon';
lat_nc_varname        = 'lat';
netcdf_filename_proxy = char(list_ncfiles(1));


bin_grid_iso500       = create_bin_isobath500(netcdf_filename_proxy,lon_nc_varname,lat_nc_varname) ;


%% create unprocessed files
ind_1995              = strfind(list_ncfiles,'1995');
index_first_file_1995 = find (double(~cellfun(@isempty,ind_1995)), 1, 'first');
for ii = index_first_file_1995 : length(list_ncfiles)
    
    netcdf_filename_input             = char(list_ncfiles(ii));
    [pathstr, name, ext]              = fileparts(netcdf_filename_input);
    if strcmp(ext,'.nc')
        netcdf_filename_output        = [output_dir filesep name(1:4) filesep name '-marvel_iso500-ql_5' ext];
        mkpath([output_dir filesep name(1 :4)]);
        
        % check if we do have to reprocess the netcdf files
        if ~(exist(netcdf_filename_output,'file') == 2)
            create_srs_marvl_subset(netcdf_filename_input,lon_nc_varname,lat_nc_varname,bin_grid_iso500,netcdf_filename_output)
        end
    end
end


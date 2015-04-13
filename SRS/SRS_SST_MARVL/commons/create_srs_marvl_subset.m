function create_srs_marvl_subset(netcdf_filename_input,lon_nc_varname,lat_nc_varname,bin,netcdf_filename_output)
% creates a subset of srs data (used with L3S 1d, night product), keeping
% temperature/sst only. Only quality_level == 5 is kept, as well as data
% falling in the bin gridded variable.
%
% input:
%       netcdf_filename_input
%       netcdf_filename_output
%       bin : gridded variable containing 1 where to keep data, NaN
%             everywhere else
%       lon_nc_varname : string of the longitude variable name from NetCDF
%       lat_nc_varname : string of the latitude variable name from NetCDF
%
% output:
%        bin : gridded variable containing 1 where to keep data, NaN
%        everywhere else
%
% laurent.besnard@utas.edu.au

ncid               = netcdf.open(netcdf_filename_input,'NOWRITE');
quality_level_data = getVarUnpackedNC( 'quality_level',ncid);

%% Keep data with QL                          == 5 only
quality_level_data (quality_level_data ~= 5 ) = NaN;
quality_level_data(isnan(bin) )               = NaN;
sum_ql_5                                      = sum(sum(quality_level_data == 5));

%% we process file only if there is more than 1 QL == 5 point
if sum_ql_5 ~= 0
    bin(isnan(quality_level_data) ) = NaN; % modify the bin per file to keep only points QL == 5

    netcdf_info         = ncinfo(netcdf_filename_input);

    index_lat           = (strcmp({netcdf_info.Dimensions.Name}, lat_nc_varname));
    index_lon           = (strcmp({netcdf_info.Dimensions.Name}, lon_nc_varname));
    index_quality_level = (strcmp({netcdf_info.Variables.Name}, 'quality_level'));


    dim_lon             = netcdf_info.Dimensions(index_lon).Length;
    dim_lat             = netcdf_info.Dimensions(index_lat).Length;


    %% look for the list of variables which have lon lat time as dimensions
    jj = 1;
    for ii = 1 : length(netcdf_info.Variables)
        if sum(netcdf_info.Variables(ii).Size == [dim_lon dim_lat 1]) == 3
            varname_to_transform{jj} = netcdf_info.Variables(ii).Name ;
            jj                       = jj+1 ;
        end

    end



    copyfile(netcdf_filename_input,netcdf_filename_output)
    ncks = 'ncks -O -x -v ';
    ncks_var_to_remove ='';
    for ii = 1 : length(varname_to_transform)

        % delete variables from netcdf which don't have temperature in
        % their name
        if ~xor(isempty(strfind (varname_to_transform{ii},'temperature')),isempty(strfind (varname_to_transform{ii},'sst_')))
            ncks_var_to_remove = [ncks_var_to_remove varname_to_transform{ii} ',' ];
        else

            try
                data              = getVarUnpackedNC(varname_to_transform{ii} ,ncid);
                data(isnan(bin) ) = NaN;
                ncwrite(netcdf_filename_output,varname_to_transform{ii},data)
                clear data
            catch
                msg = ['issue with var ' varname_to_transform{ii} ' : ' netcdf_filename_input];
                disp(msg)
            end
        end
    end

    %% ncks command to remove unused variables ( do all at once, way faster)
    ncks = [ncks ' ' ncks_var_to_remove(1:end-1) ' ' netcdf_filename_output  ' ' netcdf_filename_output] ;
    system(ncks);
else
    disp(['no point for file :' netcdf_filename_input])
end
netcdf.close(ncid)

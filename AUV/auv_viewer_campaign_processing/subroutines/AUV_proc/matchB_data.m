function [metadata_B sample_data_B] = matchB_data(header_data,track_csv,Campaign,Dive)

nrows           = length(header_data);
datenumCSV      = datenum(track_csv.Year, track_csv.Month, track_csv.Day, track_csv.Hour, track_csv.Minute, track_csv.Sec);


if (length(datenumCSV) < nrows)
    fprintf('%s - WARNING %d images missing somewhere\n',datestr(now),abs(nrows-length(datenumCSV)))
    nrows=length(datenumCSV);
end



releasedCampaignPath = getenv('released_campaign_path');

divePath             = strcat(releasedCampaignPath,filesep,Campaign,filesep,Dive);
Hydro_dir            = dir([divePath filesep 'h*']);
hydroPath            = [divePath filesep Hydro_dir.name];
Files_Hydro_dir      = dir([hydroPath filesep 'IMOS_AUV_B*.nc']);

if ~size(Files_Hydro_dir,1)
    fprintf('%s - WARNING: Missing B file in "hydro_netcdf"  for %s\n',datestr(now), [Campaign '-' Dive]);

    metadata_B          = struct;
    sample_data_B       = struct;

    metadata_B.filename = '';

    sample_data_B.CDOM  = NaN(length(datenumCSV),1);
    sample_data_B.CPHL  = NaN(length(datenumCSV),1);
    sample_data_B.OPBS  = NaN(length(datenumCSV),1);

    return

else


    %% match ECO (csv) = B (netcdf) & LON LAT CSV in time with the images for the temp salinity since the images are not taken at the same time than in situ data
    metadata_B.filename = Files_Hydro_dir(1,1).name;
    Filename_B_Load    = strcat(releasedCampaignPath,filesep,Campaign,filesep,Dive,filesep,Hydro_dir.name,filesep,Files_Hydro_dir(1,1).name);
    fid               = Filename_B_Load;
    ncid              = netcdf.open(fid,'NC_NOWRITE');


    timeVarCorrupted = 0;
    try
        [TIME_fid,~] =getVarUnpackedNC('TIME',ncid);
    catch corrupted_ST_file
        TIME_fid = datenumCSV;
        timeVarCorrupted = 1;
        fprintf('%s - ERROR - corrupted TIME Var. NetCDF file %s \n',datestr(now),Filename_B_Load)
    end

    %% CDOM
    try
        [CDOM_fid,~] =getVarUnpackedNC('CDOM',ncid);
    catch
        fprintf('%s - WARNING - corrupted CDOM Var in NetCDF file %s \n',datestr(now),Filename_ST_Load)
        CDOM_fid =NaN(length(TIME_fid),1);
    end

    %% CPHL
    try
        [CPHL_fid,~] =getVarUnpackedNC('CPHL',ncid);
    catch
        fprintf('%s - WARNING - corrupted CPHL Var in NetCDF file %s \n',datestr(now),Filename_ST_Load)
        CPHL_fid =NaN(length(TIME_fid),1);
    end

    %% OPBS
    try
        [OPBS_fid,~] =getVarUnpackedNC('OPBS',ncid);
    catch
        fprintf('%s - WARNING - corrupted OPBS Var in NetCDF file %s \n',datestr(now),Filename_ST_Load)
        OPBS_fid =NaN(length(TIME_fid),1);
    end


    if timeVarCorrupted == 0

        index_equivalent = zeros(nrows,1);
        for k=1:nrows
            index_equivalent(k)=max(find (TIME_fid < datenumCSV(k) ));%#ok
        end
        index_equivalent  = int16(index_equivalent');

        sample_data_B      = struct;
        sample_data_B.CDOM = CDOM_fid(index_equivalent);
        sample_data_B.CPHL = CPHL_fid(index_equivalent);
        sample_data_B.OPBS = OPBS_fid(index_equivalent);

    elseif timeVarCorrupted == 1

        sample_data_B      = struct;
        sample_data_B.CDOM = NaN(length(TIME_fid),1);
        sample_data_B.CPHL = NaN(length(TIME_fid),1);
        sample_data_B.OPBS = NaN(length(TIME_fid),1);

    end

    try
    netcdf.close(ncid)
    end
end

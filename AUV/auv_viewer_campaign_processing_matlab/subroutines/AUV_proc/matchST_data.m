function [metadata_ST sample_data_ST]=matchST_data(header_data,track_csv,Campaign,Dive)


nrows      = length(header_data);
datenumCSV = datenum(track_csv.Year, track_csv.Month, track_csv.Day, track_csv.Hour, track_csv.Minute, track_csv.Sec);

if (length(datenumCSV) < nrows)
    fprintf('%s - WARNING %d images missing somewhere\n',datestr(now),abs(nrows-length(datenumCSV)))
    nrows=length(datenumCSV);
end

releasedCampaignPath = readConfig('releasedCampaign.path', 'config.txt','=');
divePath             = strcat(releasedCampaignPath,filesep,Campaign,filesep,Dive);
Hydro_dir            = dir([divePath filesep 'h*']);
hydroPath            = [divePath filesep Hydro_dir.name];
Files_Hydro_dir      = dir([hydroPath filesep 'IMOS_AUV_ST*.nc']); % structure 1 and 2 match the files

if ~size(Files_Hydro_dir,1)
    fprintf('%s - WARNING: Missing ST file in "hydro_netcdf"  for %s\n',datestr(now), [Campaign '-' Dive]);
    
    metadata_ST                = struct;
    metadata_ST.site_code      = '';
    metadata_ST.title          = '';
    metadata_ST.abstract       = '';
    metadata_ST.platform_code  = '';
    metadata_ST.filename       = '';
    
    sample_data_ST             = struct;
    sample_data_ST.TEMP        = NaN(length(datenumCSV),1);
    sample_data_ST.PSAL        = NaN(length(datenumCSV),1);  
    return
else
           
    metadata_ST.filename = Files_Hydro_dir(1,1).name;
    Filename_ST_Load  = strcat(releasedCampaignPath,filesep,Campaign,filesep,Dive,filesep,Hydro_dir.name,filesep,Files_Hydro_dir(1,1).name);
    
    %% match CT (csv) =ST (netcdf) & LON LAT CSV in time with the images for the temp salinity
    fid              = Filename_ST_Load;
    ncid             = netcdf.open(fid,'NC_NOWRITE');
    
    %NC ATTRIBUTES
    gattname0         = netcdf.inqAttName(ncid,netcdf.getConstant('NC_GLOBAL'),0);
    site_code         = netcdf.getAtt(ncid,netcdf.getConstant('NC_GLOBAL'),gattname0); % -> AUV
    
    gattname3         = netcdf.inqAttName(ncid,netcdf.getConstant('NC_GLOBAL'),3);
    title             = netcdf.getAtt(ncid,netcdf.getConstant('NC_GLOBAL'),gattname3); % -> AUV
    
    gattname5         = netcdf.inqAttName(ncid,netcdf.getConstant('NC_GLOBAL'),5);
    date_created      = netcdf.getAtt(ncid,netcdf.getConstant('NC_GLOBAL'),gattname5); % -> AUV
    
    gattname6         = netcdf.inqAttName(ncid,netcdf.getConstant('NC_GLOBAL'),6);
    abstract          = netcdf.getAtt(ncid,netcdf.getConstant('NC_GLOBAL'),gattname6);
    
    gattname14        = netcdf.inqAttName(ncid,netcdf.getConstant('NC_GLOBAL'),14);
    platform_code     = netcdf.getAtt(ncid,netcdf.getConstant('NC_GLOBAL'),gattname14);
    
    
    format bank
    
    try
        [TIME_fid,~] =getVarNetCDF('TIME',ncid);
    catch corrupted_ST_file
        fprintf('%s - ERROR - corrupted TIME Var. NetCDF file %s \n',datestr(now),Filename_ST_Load)
        TIME_fid = datenumCSV ;
        
        return
    end
    
    try
        [PSAL_fid,~] =getVarNetCDF('PSAL',ncid);
    catch
        fprintf('%s - WARNING - corrupted PSAL Var in NetCDF file %s \n',datestr(now),Filename_ST_Load)
        PSAL_fid =NaN(length(TIME_fid),1);
    end
    
    try
        [TEMP_fid,~] =getVarNetCDF('TEMP',ncid);
    catch
        fprintf('%s - WARNING - corrupted TEMP Var in NetCDF file %s \n',datestr(now),Filename_ST_Load)
        TEMP_fid=NaN(length(TIME_fid),1);
    end
    
    metadata_ST.platform_code = platform_code;
    metadata_ST.abstract      = abstract;
    metadata_ST.date_created  = date_created;
    metadata_ST.title         = title;
    metadata_ST.site_code     = site_code;
    
    
    
    
    index_equivalent = zeros(nrows,1);
    for j = 1:nrows
        if isempty(find (TIME_fid < datenumCSV(j) ))
            index_equivalent(j) = min(find (TIME_fid > datenumCSV(j) ));
        else
            index_equivalent(j) = max(find (TIME_fid < datenumCSV(j) ));
        end
    end
    
    index_equivalent   = int16(index_equivalent');
    
    sample_data_ST.TEMP = TEMP_fid(index_equivalent);
    sample_data_ST.PSAL = PSAL_fid(index_equivalent);
    
    try
        netcdf.close(ncid)
    end
end

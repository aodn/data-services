function createNetCDF(netcdfoutput, site_code, isQC, timenc, timeStr, X, Y, Urad, Vrad, UsdRad, VsdRad, dataGDOP, QCrad, netCDF4, compression, meta)

%see files radar_CODAR_main.m or radar_WERA_main.m for any change on the
%following global variables
global dateFormat

try
	[~, filename, ~] = fileparts(netcdfoutput);
	
    if netCDF4
        nc = netcdf.create(netcdfoutput, 'NETCDF4');
    else
        nc = netcdf.create(netcdfoutput, 'NC_CLOBBER');
    end
    
    % we don't want the API to automatically pre-fill with FillValue, we're
    % taking care of it ourselves and avoid 2 times writting on disk
    netcdf.setFill(nc, 'NC_NOFILL');
    
    %
    %Creation of the GLOBAL ATTRIBUTES
    %
    %WHAT
    netcdf.putAtt(nc, netcdf.getConstant('GLOBAL'), 'project',      'Integrated Marine Observing System (IMOS)');
    netcdf.putAtt(nc, netcdf.getConstant('GLOBAL'), 'Conventions',  'CF-1.5,IMOS-1.2');
    netcdf.putAtt(nc, netcdf.getConstant('GLOBAL'), 'institution',  'Australian Coastal Ocean Radar Network (ACORN)');
    
    if isQC
        infoQC = ' QC';
    else
        infoQC = ' non QC';
    end
    
    localTimeZone = [];
    switch site_code
        case {'SAG', 'CWI', 'CSP'}
            title = ['IMOS ACORN South Australia Gulf (SAG), one hour averaged current' infoQC ' data, ', timeStr];
            netcdf.putAtt(nc, netcdf.getConstant('GLOBAL'), 'title',        title);
            netcdf.putAtt(nc, netcdf.getConstant('GLOBAL'), 'instrument',   'WERA Oceanographic HF Radar/Helzel Messtechnik, GmbH');
            netcdf.putAtt(nc, netcdf.getConstant('GLOBAL'), 'site_code',    'SAG, South Australia Gulf');
            netcdf.putAtt(nc, netcdf.getConstant('GLOBAL'), 'ssr_Stations', 'Cape Wiles (CWI), Cape Spencer (CSP)');
            localTimeZone = 9.5;
            
        case {'GBR', 'TAN', 'LEI', 'CBG'}
            title = ['IMOS ACORN Capricorn Bunker Group (CBG), one hour averaged current' infoQC ' data, ', timeStr];
            netcdf.putAtt(nc, netcdf.getConstant('GLOBAL'), 'title',        title);
            netcdf.putAtt(nc, netcdf.getConstant('GLOBAL'), 'instrument',   'WERA Oceanographic HF Radar/Helzel Messtechnik, GmbH');
            netcdf.putAtt(nc, netcdf.getConstant('GLOBAL'), 'site_code',    'CBG, Capricorn Bunker Group');
            netcdf.putAtt(nc, netcdf.getConstant('GLOBAL'), 'ssr_Stations', 'Tannum Sands (TAN), Lady Elliott Island (LEI)');
            localTimeZone = 10;
            
        case {'PCY', 'FRE', 'GUI', 'ROT'}
            title = ['IMOS ACORN Rottnest Shelf (ROT), one hour averaged current' infoQC ' data, ', timeStr];
            netcdf.putAtt(nc, netcdf.getConstant('GLOBAL'), 'title',        title);
            netcdf.putAtt(nc, netcdf.getConstant('GLOBAL'), 'instrument',   'WERA Oceanographic HF Radar/Helzel Messtechnik, GmbH');
            netcdf.putAtt(nc, netcdf.getConstant('GLOBAL'), 'site_code',    'ROT, Rottnest Shelf');
            netcdf.putAtt(nc, netcdf.getConstant('GLOBAL'), 'ssr_Stations', 'Fremantle (FRE), Guilderton (GUI)');
            localTimeZone = 8;
            
        case {'COF', 'RRK', 'NNB'}
            title = ['IMOS ACORN Coffs Harbour (COF), one hour averaged current' infoQC ' data, ', timeStr];
            netcdf.putAtt(nc, netcdf.getConstant('GLOBAL'), 'title',        title);
            netcdf.putAtt(nc, netcdf.getConstant('GLOBAL'), 'instrument',   'WERA Oceanographic HF Radar/Helzel Messtechnik, GmbH');
            netcdf.putAtt(nc, netcdf.getConstant('GLOBAL'), 'site_code',    'COF, Coffs Harbour');
            netcdf.putAtt(nc, netcdf.getConstant('GLOBAL'), 'ssr_Stations', 'Red Rock (RRK), North Nambucca (NNB)');
            localTimeZone = 10;
            
        case {'TURQ', 'CRVT', 'SBRD'}
            title = ['IMOS ACORN Turqoise Coast (TURQ), one hour averaged current' infoQC ' data, ', timeStr];
            netcdf.putAtt(nc, netcdf.getConstant('GLOBAL'), 'title',        title);
            netcdf.putAtt(nc, netcdf.getConstant('GLOBAL'), 'instrument',   'CODAR Ocean Sensors/SeaSonde');
            netcdf.putAtt(nc, netcdf.getConstant('GLOBAL'), 'site_code',    'TURQ, Turqoise Coast');
            
			dateFirstChange = '20121215T000000';
            if (datenum(filename(14:28), dateFormat) < datenum(dateFirstChange, dateFormat))
                netcdf.putAtt(nc, netcdf.getConstant('GLOBAL'), 'ssr_Stations', 'SeaBird (SBRD), Cervantes (CRVT)');
            else
                dateSecondChange = '20130319T000000';
                if (datenum(filename(14:28), dateFormat) < datenum(dateSecondChange, dateFormat))
                    netcdf.putAtt(nc, netcdf.getConstant('GLOBAL'), 'ssr_Stations', 'SeaBird (SBRD), Green Head (GHED)');
                else
                    netcdf.putAtt(nc, netcdf.getConstant('GLOBAL'), 'ssr_Stations', 'Lancelin (LANC), Green Head (GHED)');
                end
            end
            localTimeZone = 8;
            
        case {'BONC', 'BFCV', 'NOCR'}
            title = ['IMOS ACORN Bonney Coast (BONC), one hour averaged current' infoQC ' data, ', timeStr];
            netcdf.putAtt(nc, netcdf.getConstant('GLOBAL'), 'title',        title);
            netcdf.putAtt(nc, netcdf.getConstant('GLOBAL'), 'instrument',   'CODAR Ocean Sensors/SeaSonde');
            netcdf.putAtt(nc, netcdf.getConstant('GLOBAL'), 'site_code',    'BONC, Bonney Coast');
            netcdf.putAtt(nc, netcdf.getConstant('GLOBAL'), 'ssr_Stations', 'Cape Douglas (BFCV), Nora Creina (NOCR)');
            localTimeZone = 9.5;
    end
    
    if exist('meta', 'var')
        netcdf.putAtt(nc, netcdf.getConstant('GLOBAL'), 'id', meta.id);
    end
    
    netcdf.putAtt(nc,netcdf.getConstant('GLOBAL'), 'date_created', datestr(clock, 'yyyy-mm-ddTHH:MM:SSZ'));
    
    if isQC
        warningQC = '';
        radialQC = ' Each radial value has a corresponding quality control flag.';
        fileVersionQC = 'Level 1 - Quality Controlled data';
        fileVersionDescriptionQC = ['Data in this file has been through the IMOS quality control procedure (Reference Table C). '...
            ' Every data point in this file has an associated quality flag.'];
    else
        warningQC = 'These data have not been quality controlled. ';
        radialQC = ' Each radial value has a quality control flag based on Geometric Dilution of Precision (GDOP) information only.';
        fileVersionQC = 'Level 0 - Raw data';
        fileVersionDescriptionQC = 'Data in this file has not been fully quality controlled.';
        if ~isempty(dataGDOP)
            fileVersionDescriptionQC = [fileVersionDescriptionQC, ...
                ' Provided flags are only based on Geometric Dilution of Precision (GDOP) information (radials crossing angles at each grid point).'];
        end
    end
    
    if ~exist('meta', 'var')
        netcdfabstract = [warningQC ...
            'The ACORN facility is producing NetCDF files with radials data for each station every ten minutes. '...
            'Radials represent the surface sea water state component '...
            'along the radial direction from the receiver antenna '...
            'and are calculated from the shift of an area under '...
            'the bragg peaks in a Beam Power Spectrum. '...
            'The radial values have been calculated using software provided '...
            'by the manufacturer of the instrument.'...
            radialQC ...
            ' eMII is using a Matlab program to read all the netcdf files with radial data for two different stations '...
            'and produce a one hour average product with U and V components of the current. '...
            'Only radial data with a signal to noise ratio >= 8dB, quality control flags 1 or 2 are considered valid in the averaging process. '...
            'In addition, at least 3 valid measurements for each radar station at each grid point are necessary to obtain an hourly averaged value. '...
            'The final product is produced on a regular geographic grid. '...
            'More information on the data processing is available through the IMOS MEST '...
            'http://imosmest.aodn.org.au/geonetwork/srv/en/main.home .'];
    else
        netcdfabstract = meta.abstract;
    end
    
    acornkeywords = 'Oceans';
    netcdf.putAtt(nc, netcdf.getConstant('GLOBAL'), 'abstract',                     netcdfabstract);
    
    if exist('meta', 'var')
        history = [meta.history ' ' datestr(clock, 'yyyy-mm-ddTHH:MM:SS') ' Modification of the NetCDF format by eMII to visualise the data using ncWMS.'];
        netcdf.putAtt(nc, netcdf.getConstant('GLOBAL'), 'history',                  history);
    end
    
    netcdf.putAtt(nc, netcdf.getConstant('GLOBAL'), 'source',                       'Terrestrial HF radar');
    netcdf.putAtt(nc, netcdf.getConstant('GLOBAL'), 'keywords',                     acornkeywords);
    if netCDF4
        netcdf.putAtt(nc, netcdf.getConstant('GLOBAL'), 'netcdf_version', '4.1.1');
    else
        netcdf.putAtt(nc, netcdf.getConstant('GLOBAL'), 'netcdf_version', '3.6');
    end
    netcdf.putAtt(nc, netcdf.getConstant('GLOBAL'), 'naming_authority',             'IMOS');
    netcdf.putAtt(nc, netcdf.getConstant('GLOBAL'), 'quality_control_set',          '1');
    netcdf.putAtt(nc, netcdf.getConstant('GLOBAL'), 'file_version',                 fileVersionQC);
    netcdf.putAtt(nc, netcdf.getConstant('GLOBAL'), 'file_version_quality_control', fileVersionDescriptionQC);
    
    %WHERE
    netcdf.putAtt(nc, netcdf.getConstant('GLOBAL'), 'geospatial_lat_min',       min(min(Y)));
    netcdf.putAtt(nc, netcdf.getConstant('GLOBAL'), 'geospatial_lat_max',       max(max(Y)));
    netcdf.putAtt(nc, netcdf.getConstant('GLOBAL'), 'geospatial_lat_units',     'degrees_north');
    netcdf.putAtt(nc, netcdf.getConstant('GLOBAL'), 'geospatial_lon_min',       min(min(X)));
    netcdf.putAtt(nc, netcdf.getConstant('GLOBAL'), 'geospatial_lon_max',       max(max(X)));
    netcdf.putAtt(nc, netcdf.getConstant('GLOBAL'), 'geospatial_lon_units',     'degrees_east');
    netcdf.putAtt(nc, netcdf.getConstant('GLOBAL'), 'geospatial_vertical_min',  0);
    netcdf.putAtt(nc, netcdf.getConstant('GLOBAL'), 'geospatial_vertical_max',  0);
    netcdf.putAtt(nc, netcdf.getConstant('GLOBAL'), 'geospatial_vertical_units','m');
    
    %WHEN
    netcdf.putAtt(nc, netcdf.getConstant('GLOBAL'), 'time_coverage_start',      timeStr);
    if ~exist('meta', 'var')
        netcdf.putAtt(nc, netcdf.getConstant('GLOBAL'), 'time_coverage_end',        timeStr);
    else
        netcdf.putAtt(nc, netcdf.getConstant('GLOBAL'), 'time_coverage_duration',   meta.time_coverage_duration);
    end
    netcdf.putAtt(nc, netcdf.getConstant('GLOBAL'), 'local_time_zone',          localTimeZone);
    
    %WHO
    netcdf.putAtt(nc, netcdf.getConstant('GLOBAL'), 'data_centre_email',        'info@emii.org.au');
    netcdf.putAtt(nc, netcdf.getConstant('GLOBAL'), 'data_centre',              'eMarine Information Infrastructure (eMII)');
    netcdf.putAtt(nc, netcdf.getConstant('GLOBAL'), 'author',                   'Galibert, Guillaume');
    netcdf.putAtt(nc, netcdf.getConstant('GLOBAL'), 'author_email',             'guillaume.galibert@utas.edu.au');
    netcdf.putAtt(nc, netcdf.getConstant('GLOBAL'), 'institution_references',   'http://www.imos.org.au/acorn.html');
    netcdf.putAtt(nc, netcdf.getConstant('GLOBAL'), 'principal_investigator',   'Wyatt, Lucy');
    
    %HOW
    acorncitation = [' The citation in a list of references is:'...
        ' IMOS, [year-of-data-download], [Title], [data-access-URL], accessed [date-of-access]'];
    acornacknowledgment = ['Data was sourced from the Integrated Marine Observing System (IMOS)'...
        ' - IMOS is supported by the Australian Government'...
        ' through the National Collaborative Research Infrastructure'...
        ' Strategy (NCRIS) and the Super Science Initiative (SSI).'];
    acorndistribution = ['Data, products and services'...
        ' from IMOS are provided "as is" without any warranty as to fitness'...
        ' for a particular purpose'];
    acorncomment = ['This NetCDF file has been created using the'...
        ' IMOS NetCDF User Manual v1.2.'...
        ' A copy of the document is available at http://imos.org.au/facility_manuals.html .'];
    
    if exist('meta', 'var')
        acorncomment = [meta.comment ' The file has been modified by eMII in '...
            'order to visualise the data using the ncWMS software. '...
            acorncomment];
    end
    
    netcdf.putAtt(nc, netcdf.getConstant('GLOBAL'), 'citation',                 acorncitation);
    netcdf.putAtt(nc, netcdf.getConstant('GLOBAL'), 'acknowledgment',           acornacknowledgment);
    netcdf.putAtt(nc, netcdf.getConstant('GLOBAL'), 'distribution_statement',   acorndistribution);
    netcdf.putAtt(nc, netcdf.getConstant('GLOBAL'), 'comment',                  acorncomment);
    
    if size(X, 2) > 1 && size(X, 1) > 1
        % irregular grid
        comptlon = size(X, 2);
        comptlat = size(X, 1);
    else
        % regular grid in an orthogonal cartesian space
        comptlon = length(X);
        comptlat = length(Y);
    end
    
    iNanUrad     = isnan(Urad);
    iNanVrad     = isnan(Vrad);
    iNanUsdRad   = isnan(UsdRad);
    iNanVsdRad   = isnan(VsdRad);
    iNanDataGDOP = isnan(dataGDOP);
    iNanQCrad    = isnan(QCrad);
    
    %Creation of the DIMENSION
    TIME_dimid      = netcdf.defDim(nc, 'TIME',         netcdf.getConstant('NC_UNLIMITED')); % TIME is going to be an UNLIMITED dimension (currently 1) for easier aggregation
    if size(X, 2) > 1 && size(X, 1) > 1
        I_dimid         = netcdf.defDim(nc, 'I',        comptlat);
        J_dimid         = netcdf.defDim(nc, 'J',        comptlon);
    else
        LATITUDE_dimid  = netcdf.defDim(nc, 'LATITUDE', comptlat);
        LONGITUDE_dimid = netcdf.defDim(nc, 'LONGITUDE',comptlon);
    end
    
    %Creation of the VARIABLES
    TIME_id             = netcdf.defVar(nc, 'TIME',         'double', TIME_dimid);
    if size(X, 2) > 1 && size(X, 1) > 1
        LATITUDE_id             = netcdf.defVar(nc, 'LATITUDE',             'double', [J_dimid, I_dimid]);
        LONGITUDE_id            = netcdf.defVar(nc, 'LONGITUDE',            'double', [J_dimid, I_dimid]);
        UCUR_id                 = netcdf.defVar(nc, 'UCUR',                 'float',  [J_dimid, I_dimid, TIME_dimid]);
        VCUR_id                 = netcdf.defVar(nc, 'VCUR',                 'float',  [J_dimid, I_dimid, TIME_dimid]);
        UCURsd_id               = netcdf.defVar(nc, 'UCUR_sd',              'float',  [J_dimid, I_dimid, TIME_dimid]);
        VCURsd_id               = netcdf.defVar(nc, 'VCUR_sd',              'float',  [J_dimid, I_dimid, TIME_dimid]);
        UCUR_quality_control_id = netcdf.defVar(nc, 'UCUR_quality_control', 'byte',   [J_dimid, I_dimid, TIME_dimid]);
        VCUR_quality_control_id = netcdf.defVar(nc, 'VCUR_quality_control', 'byte',   [J_dimid, I_dimid, TIME_dimid]);
        if ~isempty(dataGDOP)
            GDOP_id             = netcdf.defVar(nc, 'GDOP',                 'float',  [J_dimid, I_dimid]);
        end
    else
        LATITUDE_id             = netcdf.defVar(nc, 'LATITUDE',             'double', LATITUDE_dimid);
        LONGITUDE_id            = netcdf.defVar(nc, 'LONGITUDE',            'double', LONGITUDE_dimid);
        UCUR_id                 = netcdf.defVar(nc, 'UCUR',                 'float', [LONGITUDE_dimid, LATITUDE_dimid, TIME_dimid]);
        VCUR_id                 = netcdf.defVar(nc, 'VCUR',                 'float', [LONGITUDE_dimid, LATITUDE_dimid, TIME_dimid]);
        UCURsd_id               = netcdf.defVar(nc, 'UCUR_sd',              'float', [LONGITUDE_dimid, LATITUDE_dimid, TIME_dimid]);
        VCURsd_id               = netcdf.defVar(nc, 'VCUR_sd',              'float', [LONGITUDE_dimid, LATITUDE_dimid, TIME_dimid]);
        UCUR_quality_control_id = netcdf.defVar(nc, 'UCUR_quality_control', 'byte',  [LONGITUDE_dimid, LATITUDE_dimid, TIME_dimid]);
        VCUR_quality_control_id = netcdf.defVar(nc, 'VCUR_quality_control', 'byte',  [LONGITUDE_dimid, LATITUDE_dimid, TIME_dimid]);
        if ~isempty(dataGDOP)
            GDOP_id             = netcdf.defVar(nc, 'GDOP',                 'float', [LONGITUDE_dimid, LATITUDE_dimid]);
        end
    end
    
    if netCDF4                
        netcdf.defVarChunking(nc, UCUR_id,                  'CHUNKED', [comptlon comptlat 1]);
        netcdf.defVarChunking(nc, VCUR_id,                  'CHUNKED', [comptlon comptlat 1]);
        netcdf.defVarChunking(nc, UCURsd_id,                'CHUNKED', [comptlon comptlat 1]);
        netcdf.defVarChunking(nc, VCURsd_id,                'CHUNKED', [comptlon comptlat 1]);
        netcdf.defVarChunking(nc, UCUR_quality_control_id,  'CHUNKED', [comptlon comptlat 1]);
        netcdf.defVarChunking(nc, VCUR_quality_control_id,  'CHUNKED', [comptlon comptlat 1]);
        
        netcdf.defVarDeflate(nc, UCUR_id,                   true, true, compression);
        netcdf.defVarDeflate(nc, VCUR_id,                   true, true, compression);
        netcdf.defVarDeflate(nc, UCURsd_id,                 true, true, compression);
        netcdf.defVarDeflate(nc, VCURsd_id,                 true, true, compression);
        netcdf.defVarDeflate(nc, UCUR_quality_control_id,   true, true, compression);
        netcdf.defVarDeflate(nc, VCUR_quality_control_id,   true, true, compression);
        
        if ~isempty(dataGDOP)
            netcdf.defVarChunking(nc, GDOP_id,  'CHUNKED', [comptlon comptlat]);
            netcdf.defVarDeflate(nc, GDOP_id,  true, true, compression);
        end
    end
    
    % Creation of the VARIABLE ATTRIBUTES
    % Time
    netcdf.putAtt(nc, TIME_id,      'standard_name',        'time');
    netcdf.putAtt(nc, TIME_id,      'long_name',            'time');
    netcdf.putAtt(nc, TIME_id,      'units',                'days since 1950-01-01 00:00:00 UTC');
    netcdf.putAtt(nc, TIME_id,      'axis',                 'T');
    netcdf.putAtt(nc, TIME_id,      'valid_min',            double(0));
    netcdf.putAtt(nc, TIME_id,      'valid_max',            double(999999));
    netcdf.putAtt(nc, TIME_id,      'calendar',             'gregorian');
    netcdf.putAtt(nc, TIME_id,      'comment',              'Given time lays at the middle of the averaging time period.');
    netcdf.putAtt(nc, TIME_id,      'local_time_zone',      localTimeZone);
    % Latitude
    netcdf.putAtt(nc, LATITUDE_id,  'standard_name',        'latitude');
    netcdf.putAtt(nc, LATITUDE_id,  'long_name',            'latitude');
    netcdf.putAtt(nc, LATITUDE_id,  'units',                'degrees_north');
    netcdf.putAtt(nc, LATITUDE_id,  'axis',                 'Y');
    netcdf.putAtt(nc, LATITUDE_id,  'valid_min',            double(-90));
    netcdf.putAtt(nc, LATITUDE_id,  'valid_max',            double(90));
    netcdf.putAtt(nc, LATITUDE_id,  'reference_datum',      'geographical coordinates, WGS84 datum');
    % Longitude
    netcdf.putAtt(nc, LONGITUDE_id, 'standard_name',        'longitude');
    netcdf.putAtt(nc, LONGITUDE_id, 'long_name',            'longitude');
    netcdf.putAtt(nc, LONGITUDE_id, 'units',                'degrees_east');
    netcdf.putAtt(nc, LONGITUDE_id, 'axis',                 'X');
    netcdf.putAtt(nc, LONGITUDE_id, 'valid_min',            double(-180));
    netcdf.putAtt(nc, LONGITUDE_id, 'valid_max',            double(180));
    netcdf.putAtt(nc, LONGITUDE_id, 'reference_datum',      'geographical coordinates, WGS84 datum');
    % Mean Eastward component of the Current speed
    netcdf.putAtt(nc, UCUR_id,      'standard_name',        'eastward_sea_water_velocity');
    netcdf.putAtt(nc, UCUR_id,      'long_name',            'Mean of sea water velocity U component values in 1 hour, after rejection of flagged bad data.');
    netcdf.putAtt(nc, UCUR_id,      'units',                'm s-1');
    netcdf.putAtt(nc, UCUR_id,      'valid_min',            single(-10));
    netcdf.putAtt(nc, UCUR_id,      'valid_max',            single(10));
    netcdf.putAtt(nc, UCUR_id,      'cell_methods',         'TIME: mean');
    netcdf.putAtt(nc, UCUR_id,      'ancillary_variables',  'UCUR_quality_control, UCUR_sd');
    netcdf.putAtt(nc, UCUR_id,      'coordinates',          'TIME LATITUDE LONGITUDE');
    % Mean Northward component of the Current speed
    netcdf.putAtt(nc, VCUR_id,      'standard_name',        'northward_sea_water_velocity');
    netcdf.putAtt(nc, VCUR_id,      'long_name',            'Mean of sea water velocity V component values in 1 hour, after rejection of flagged bad data.');
    netcdf.putAtt(nc, VCUR_id,      'units',                'm s-1');
    netcdf.putAtt(nc, VCUR_id,      'valid_min',            single(-10));
    netcdf.putAtt(nc, VCUR_id,      'valid_max',            single(10));
    netcdf.putAtt(nc, VCUR_id,      'cell_methods',         'TIME: mean');
    netcdf.putAtt(nc, VCUR_id,      'ancillary_variables',  'VCUR_quality_control, VCUR_sd');
    netcdf.putAtt(nc, VCUR_id,      'coordinates',          'TIME LATITUDE LONGITUDE');
    % Standard deviation of Eastward component of the Current speed
    netcdf.putAtt(nc, UCURsd_id,    'long_name',            'Standard deviation of sea water velocity U component values in 1 hour, after rejection of flagged bad data.');
    netcdf.putAtt(nc, UCURsd_id,    'units',                'm s-1');
    netcdf.putAtt(nc, UCURsd_id,    'valid_min',            single(-10));
    netcdf.putAtt(nc, UCURsd_id,    'valid_max',            single(10));
    netcdf.putAtt(nc, UCURsd_id,    'cell_methods',         'TIME: standard_deviation');
    netcdf.putAtt(nc, UCURsd_id,    'coordinates',          'TIME LATITUDE LONGITUDE');
    % Standard deviation of Northward component of the Current speed
    netcdf.putAtt(nc, VCURsd_id,    'long_name',            'Standard deviation of sea water velocity V component values in 1 hour, after rejection of flagged bad data.');
    netcdf.putAtt(nc, VCURsd_id,    'units',                'm s-1');
    netcdf.putAtt(nc, VCURsd_id,    'valid_min',            single(-10));
    netcdf.putAtt(nc, VCURsd_id,    'valid_max',            single(10));
    netcdf.putAtt(nc, VCURsd_id,    'cell_methods',         'TIME: standard_deviation');
    netcdf.putAtt(nc, VCURsd_id,    'coordinates',          'TIME LATITUDE LONGITUDE');
    % GDOP angle
    if ~isempty(dataGDOP)
        netcdf.putAtt(nc, GDOP_id,  'long_name',            'radar beam intersection angle');
        netcdf.putAtt(nc, GDOP_id,  'units',                'Degrees');
        netcdf.putAtt(nc, GDOP_id,  'valid_min',            single(0));
        netcdf.putAtt(nc, GDOP_id,  'valid_max',            single(180));
        netcdf.putAtt(nc, GDOP_id,  'coordinates',          'LATITUDE LONGITUDE');
        netcdf.putAtt(nc, GDOP_id,  'comment',              ['This angle is used to assess the impact of Geometric Dilution of Precision. '...
            'If angle between [150; 160[ or ]30; 40], QC flag will not be lower than 3. '...
            'If angle >= 160 or <= 30, then QC flag will not be lower than 4.']);
    end

    paramFillValue = 999999;
    if netCDF4
        netcdf.defVarFill(nc,       UCUR_id,   false,	single(paramFillValue)); % false means noFillMode == false
        netcdf.defVarFill(nc,       VCUR_id,   false,	single(paramFillValue));
        netcdf.defVarFill(nc,       UCURsd_id, false,	single(paramFillValue));
        netcdf.defVarFill(nc,       VCURsd_id, false,	single(paramFillValue));
        if ~isempty(dataGDOP)
            netcdf.defVarFill(nc,   GDOP_id,   false,	single(paramFillValue));
        end
    else
        netcdf.putAtt(nc,       UCUR_id,    '_FillValue', single(paramFillValue));
        netcdf.putAtt(nc,       VCUR_id,    '_FillValue', single(paramFillValue));
        netcdf.putAtt(nc,       UCURsd_id,  '_FillValue', single(paramFillValue));
        netcdf.putAtt(nc,       VCURsd_id,  '_FillValue', single(paramFillValue));
        if ~isempty(dataGDOP)
            netcdf.putAtt(nc,   GDOP_id,    '_FillValue', single(paramFillValue));
        end
    end

    %QUALITY CONTROL VARIABLES
    flagFillValue = int8(99);
    flagvalues = int8([0 1 2 3 4 5 6 7 8 9]);
    flagmeaning =  ['no_qc_performed '...
        'good_data '...
        'probably_good_data '...
        'bad_data_that_are_potentially_correctable '...
        'bad_data '...
        'value_changed '...
        'not_used '...
        'not_used '...
        'interpolated_values '...
        'missing_values'];
    
    netcdf.putAtt(nc, UCUR_quality_control_id,      'standard_name',    'eastward_sea_water_velocity status_flag');
    netcdf.putAtt(nc, UCUR_quality_control_id,      'long_name',        'quality flag for eastward_sea_water_velocity');
    
    netcdf.putAtt(nc, VCUR_quality_control_id,      'standard_name',    'northward_sea_water_velocity status_flag');
    netcdf.putAtt(nc, VCUR_quality_control_id,      'long_name',        'quality flag for northward_sea_water_velocity');
    
    
    quality_control_ids =  [UCUR_quality_control_id, VCUR_quality_control_id];
    
    for i=1:length(quality_control_ids)
        netcdf.putAtt(nc, quality_control_ids(i), 'coordinates',                  'TIME LATITUDE LONGITUDE');
        netcdf.putAtt(nc, quality_control_ids(i), 'quality_control_conventions',  'IMOS standard set using IODE flags');
        netcdf.putAtt(nc, quality_control_ids(i), 'quality_control_set',          1);
        
        if netCDF4
            netcdf.defVarFill(nc, quality_control_ids(i), false,	flagFillValue); % false means noFillMode == false
        else
            netcdf.putAtt(nc, quality_control_ids(i), '_FillValue', flagFillValue);
        end
				
        netcdf.putAtt(nc, quality_control_ids(i), 'valid_min',     min(flagvalues));
        netcdf.putAtt(nc, quality_control_ids(i), 'valid_max',     max(flagvalues));
        netcdf.putAtt(nc, quality_control_ids(i), 'flag_values',   flagvalues);
        netcdf.putAtt(nc, quality_control_ids(i), 'flag_meanings', flagmeaning);
    end
    
    netcdf.endDef(nc)
    
    %Data values for each variable
    Urad(iNanUrad) = paramFillValue;
    Vrad(iNanVrad) = paramFillValue;
    UsdRad(iNanUsdRad) = paramFillValue;
    VsdRad(iNanVsdRad) = paramFillValue;
    dataGDOP(iNanDataGDOP) = paramFillValue;
    
    QCrad(iNanQCrad) = flagFillValue;
    rad_qc     = int8(QCrad);
    
    netcdf.putVar(nc, TIME_id, 0, 1, timenc);
    netcdf.putVar(nc, LATITUDE_id,   Y');
    netcdf.putVar(nc, LONGITUDE_id,  X');
    
    netcdf.putVar(nc, UCUR_id,      single(Urad'));
    netcdf.putVar(nc, VCUR_id,      single(Vrad'));
    netcdf.putVar(nc, UCURsd_id,    single(UsdRad'));
    netcdf.putVar(nc, VCURsd_id,    single(VsdRad'));
    if ~isempty(dataGDOP)
        netcdf.putVar(nc, GDOP_id,  single(dataGDOP'));
    end
    
    netcdf.putVar(nc, UCUR_quality_control_id,  rad_qc');
    netcdf.putVar(nc, VCUR_quality_control_id,  rad_qc');
    
    %Close the NetCDF file
    netcdf.close(nc);
catch e
    %Close the NetCDF file
    netcdf.close(nc);
    
    throw(e);
end

end

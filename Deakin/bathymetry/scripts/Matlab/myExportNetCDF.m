function myExportNetCDF( netCDF, filename, compressionLevel )

% test if file already exist, if so then delete it.
if exist(filename, 'file'), delete(filename); end

% fid = netcdf.create(filename, 'NC_CLOBBER');
fid = netcdf.create(filename, 'NETCDF4');
if fid == -1, error(['could not create ' filename]); end

dateFmt = 'yyyy-mm-ddTHH:MM:SSZ';

try
    % we don't want the API to automatically pre-fill with FillValue, we're
    % taking care of it ourselves and avoid 2 times writting on disk
    netcdf.setFill(fid, 'NC_NOFILL');

    %
    % the file is created in the following order
    %
    % 1. global attributes
    % 2. dimensions / coordinate variables
    % 3. variable definitions
    % 4. data
    %
    globConst = netcdf.getConstant('NC_GLOBAL');
    
    %
    % global attributes
    %
    globAtts = netCDF;
    globAtts = rmfield(globAtts, 'variables');
    globAtts = rmfield(globAtts, 'dimensions');
    
    putAtts(fid, globConst, globAtts, 'global', dateFmt);
    
    %
    % dimension and coordinate variable definitions
    %
    dims = netCDF.dimensions;
    for m = 1:length(dims)
        
        dimAtts = dims{m};
        dimAtts = rmfield(dimAtts, 'data');
        
        % create dimension
        did = netcdf.defDim(fid, upper(dims{m}.name), length(dims{m}.data));
        
        % create coordinate variable and attributes
        vid = netcdf.defVar(fid, upper(dims{m}.name), matlabToNetcdf3Type(class(dims{m}.data)), did);
        putAtts(fid, vid, dimAtts, lower(dims{m}.name), dateFmt);
        
        % save the netcdf dimension and variable IDs
        % in the dimension struct for later reference
        netCDF.dimensions{m}.did   = did;
        netCDF.dimensions{m}.vid   = vid;
    end
    
    
    %
    % variable definitions
    %
    dims = netCDF.dimensions;
    vars = netCDF.variables;
    for m = 1:length(vars)
        
        varname = vars{m}.name;
        
        % get the dimensions for this variable
        dimIdxs = vars{m}.dimensions;
        nDim = length(dimIdxs);
        dids = NaN(1, nDim);
        dimLen = NaN(1, nDim);
        for n = 1:nDim
            dids(n) = dims{dimIdxs(n)}.did; 
            dimLen(n) = length(dims{dimIdxs(n)}.data);
        end
        
        % reverse dimension order - matlab netcdf.defvar requires
        % dimensions in order of fastest changing to slowest changing.
        % The time dimension is always first in the variable.dimensions
        % list, and is always the slowest changing.
        dids = fliplr(dids);
        dimLen = fliplr(dimLen);
        
        % create the variable
        vid = netcdf.defVar(fid, varname, matlabToNetcdf3Type(class(vars{m}.data)), dids);
        
        % setting the chunks as big as possible is optimum for all use case,
        % but in our case optimum access for ncWMS is when the chunks are
        % the size of the geographic areas in the file for any Z and TIME
        if nDim == 4
            dimLen([true false false true]) = 1;
        elseif nDim == 3
            dimLen([true false false]) = 1;
        end
        netcdf.defVarChunking(fid, vid, 'CHUNKED', dimLen);
        
        netcdf.defVarDeflate(fid, vid, true, true, compressionLevel);
        
        varAtts = vars{m};
        varAtts = rmfield(varAtts, 'data');
        varAtts = rmfield(varAtts, 'dimensions');
        
        % add the attributes
        putAtts(fid, vid, varAtts, 'variable', dateFmt);
        
        % save variable IDs for later reference
        netCDF.variables{m}.vid   = vid;
    end
    
    % we're finished defining dimensions/attributes/variables
    netcdf.endDef(fid);
    
    %
    % coordinate variable data
    %
    dims = netCDF.dimensions;
    
    for m = 1:length(dims)
        
        % variable data
        vid     = dims{m}.vid;
        data    = dims{m}.data;
        
        % replace NaN's with fill value
        if isfield(dims{m}, 'FillValue_')
            data(isnan(data)) = dims{m}.FillValue_;
        end
        
        netcdf.putVar(fid, vid, data);
    end
    
    %
    % variable data
    %
    vars = netCDF.variables;
    for m = 1:length(vars)
        
        % variable data
        data    = vars{m}.data;
        vid     = vars{m}.vid;
        
        % replace NaN's with fill value
        data(isnan(data)) = vars{m}.FillValue_;
        
        % transpose required for multi-dimensional data, as matlab
        % requires the fastest changing dimension to be first.
        % of more than two dimensions.
        nDims = length(vars{m}.dimensions);
        if nDims > 1, data = permute(data, nDims:-1:1); end
        
        netcdf.putVar(fid, vid, data);
    end
    
    %
    % and we're done
    %
    netcdf.close(fid);
    
    % ensure that the file is closed in the event of an error
catch e
    try netcdf.close(fid); catch ex, end
    if exist(filename, 'file'), delete(filename); end
    rethrow(e);
end
end

function putAtts(fid, vid, template, templateFile, dateFmt)
%PUTATTS Puts all the attributes from the given template into the given NetCDF
% variable.
%
% This code is repeated a number of times, so it made sense to enclose it in a
% separate function. Takes all the fields from the given template struct, and
% writes them to the NetCDF file specified by fid, in the variable specified by
% vid.
%
% Inputs:
%   fid          - NetCDF file identifier
%   vid          - NetCDF variable identifier
%   template     - Struct containing attribute names/values.
%   templateFile - name of the template file from where the attributes
%                  originated.
%   dateFmt      - format to use for writing date attributes.
%

% each att is a struct field
atts = fieldnames(template);
for k = 1:length(atts)
    
    name = atts{k};
    val  = template.(name);
    
    if isempty(val), continue; end;
    
    type = 'S';
    try 
        type = templateType(name, templateFile);
    catch e
    end
    
    switch type
        case 'D', val = datestr(val, dateFmt);
    end
    
    % matlab-no-support-leading-underscore kludge
    if name(end) == '_', name = ['_' name(1:end-1)]; end
    
    % add the attribute
    %disp(['  ' name ': ' val]);
    if strcmpi(name, '_FillValue')
        netcdf.defVarFill(fid, vid, false, val); % false means noFillMode == false
    else
        netcdf.putAtt(fid, vid, name, val);
    end
end
end
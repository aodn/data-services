function ncid = export_binned_netcdf(bin_filename,global_attributes,dimensions,variable_cell,anc_variable_cell)
% Called within eyeballbinCTD
% Take a cell of result matrices from binning operations, and use to populate
% variables, ancillary variables etc. in new netcdf file

% Inputs:
% input_filename - string, name of input netCDF file
% bin_filename - string, name of netCDF file to be created
% global_attributes  - 1 x 1 struct, which has fields that are the global
%                              attributes of orig file. 
% dimensions -          3 x 1 cell, each cell containing 1 x 1 struct, which contains the dimensions fields,
%                       modified where appropriate
% variable_cell - (len_vars)x1 cell,    where len_vars is number of variables in
%                                   original dataset.
%                                   Each cell contains a struct containing
%                                   the modified variable attributes.
% anc_variable_cell - (len_vars*len_a)x 1 cell, where len_a is num of
%                                   ancillary variables. Ancillaries are
%                                   eg. num of points each burst included,
%                                   num excluded, burst SD, min, max

local_time_offset=-10;           % offset to apply to creation local time to get UTC (GMT)
                                 % in hours. eg. Hobart non-daylight saving, subtract
                                 % 10 hours. Offset = -10
                                 % offset to apply to time_coverage_start
                                 % might be different. Currently using same

filename= bin_filename;  
compressionLevel = 1; % it seems the compression level 1 gives the best ration size/cpu
ncid = netcdf.create(filename ,'NETCDF4');
dimtimeID = netcdf.defDim(ncid,'TIME',netcdf.getConstant('NC_UNLIMITED'));  
dimlatID=netcdf.defDim(ncid,'LATITUDE',1);
dimlongID=netcdf.defDim(ncid,'LONGITUDE',1);
FillValue=999999;

% To calculate time_coverage for Glob Attribs
timedata = dimensions{3,1}.data;  n=length(timedata);
 
%% GLOBAL ATTRIBUTES, changes.
abstract_string_suffix=[' Data '...
            'from bursts have been cleaned and averaged to create data products. ' ...
            'This file is one such product.'];
if isfield(global_attributes,'abstract')
    input_abstract=global_attributes.abstract; 
    abstract_string=strcat(input_abstract,abstract_string_suffix);
else
    abstract_string=abstract_string_suffix;
end
lineage_string=['The data array in this file has been created by binning (averaging) raw burst data. '... 
                 'Each array value is the arithmetic mean of a burst.  Out-of-water data is excised before binning. '...
                 ' Points flagged by IMOS QC as 4 are excluded from the burst average:' ...
                 'this includes data values outside of a valid range,' ...
                    'data depth outside of a valid range,  '...
                    'and data values in a series of consecutive identical values '...
                    'whose length exceeds a maximum. Burst means are calculated' ...
                    ' from remaining points. Any bursts with no remaining good '...
                    'points after exclusions are assigned FillValue (see variable attributes for '...
                    ' value of FillValue).']; 
                % The following lines were removed from lineage, because
                % CTD global attribs don't include burst info:
% Length and frequency ' ...
    %             'of the underlying bursts are declared in the global attributes instrument_burst_duration' ...
     %            ' and instrument_burst_interval respectively.                
global_attributes=setfield(global_attributes,'file_version','Level 2 - Derived Products');
global_attributes=setfield(global_attributes,'abstract',abstract_string);
global_attributes=setfield(global_attributes,'author','Breslin, Monique');
global_attribute_names=fieldnames(global_attributes);
 
% Newly created attributes that should go at
% the top of the netcdf file, should be 'putAtt'-ed first. 
if isfield(global_attributes,'site_code')
    deployment_location=global_attributes.site_code;
else
    fprintf('Missing site name in attributes.\n')
    deployment_location='site name?';
end
title_string=['Burst-averaged moored CTD measurements at',' ',deployment_location];
netcdf.putAtt(ncid,netcdf.getConstant('NC_GLOBAL'),'title',title_string);

for i=1:length(global_attribute_names)
    if ~strcmp(global_attribute_names{i},'title')              % it appears that putAtt overwrites previous values if you do it >1 times
        netcdf.putAtt(ncid,netcdf.getConstant('NC_GLOBAL'),global_attribute_names{i},global_attributes.(global_attribute_names{i}));
        if strcmp(global_attribute_names{i},'comment')             % insert after the comment:
           netcdf.putAtt(ncid,netcdf.getConstant('NC_GLOBAL'),'lineage',lineage_string);
        elseif strcmp(global_attribute_names{i},'naming_authority')
            product_sample_interval=round(24*60*60*mode(diff(timedata)));
            netcdf.putAtt(ncid,netcdf.getConstant('NC_GLOBAL'),'product_sample_interval',product_sample_interval);
        elseif strcmp(global_attribute_names{i},'author')
            netcdf.putAtt(ncid,netcdf.getConstant('NC_GLOBAL'),'author_email','monique.breslin@utas.edu.au');
        end
    end
end


%% DIMENSION attributes

 % TIME
    TIME_attributes=dimensions{3};
    if isfield(TIME_attributes,'CoordinateAxisType')
        TIME_attributes=rmfield(TIME_attributes,'CoordinateAxisType');
    end
    TIME_names=fieldnames(TIME_attributes);
    TIMEvarid=netcdf.defVar(ncid,TIME_attributes.name,'NC_DOUBLE',dimtimeID);
    for j=1:length(TIME_names)
        if ~strcmp(TIME_names{j},'data')
            if strcmp(TIME_names{j},'FillValue')
%                 netcdf.putAtt(ncid,TIMEvarid,'_FillValue',double(TIME_attributes.(TIME_names{j})));
                netcdf.defVarFill(ncid,TIMEvarid,false,double(TIME_attributes.(TIME_names{j}))); % false means noFillMode == false
             else
                netcdf.putAtt(ncid,TIMEvarid,TIME_names{j},TIME_attributes.(TIME_names{j}));
            end
        end
    end   
% LATITUDE                            
    LAT_attributes=dimensions{1};
    fields_to_remove={'CoordinateAxisType','ancillary_variables','quality_control_set'...
                                    'quality_control_indicator'};
    for k=1:length(fields_to_remove)
        if isfield(LAT_attributes,fields_to_remove{k})
            LAT_attributes=rmfield(LAT_attributes,fields_to_remove{k});
        end
    end
    LAT_names=fieldnames(LAT_attributes);
    LATvarid=netcdf.defVar(ncid,LAT_attributes.name,'NC_DOUBLE',dimlatID);
    for j=1:length(LAT_names)
        if ~strcmp(LAT_names{j},'data')
            if strcmp(LAT_names{j},'FillValue')
%                 netcdf.putAtt(ncid,LATvarid,'_FillValue',LAT_attributes.(LAT_names{j}));
                netcdf.defVarFill(ncid,LATvarid,false,double(LAT_attributes.(LAT_names{j}))); % false means noFillMode == false
            else
                netcdf.putAtt(ncid,LATvarid,LAT_names{j},LAT_attributes.(LAT_names{j}));
            end
        end
    end
% LONGITUDE
    LONG_attributes=dimensions{2};
    fields_to_remove={'CoordinateAxisType','ancillary_variables','quality_control_set'...
                                    'quality_control_indicator'};
    for k=1:length(fields_to_remove)
        if isfield(LONG_attributes,fields_to_remove{k})
            LONG_attributes=rmfield(LONG_attributes,fields_to_remove{k});
        end
    end
    LONG_names=fieldnames(LONG_attributes);
    LONGvarid=netcdf.defVar(ncid,LONG_attributes.name,'NC_DOUBLE',dimlongID);
    for j=1:length(LONG_names)
        if ~strcmp(LONG_names{j},'data')
            if strcmp(LONG_names{j},'FillValue')
%                 netcdf.putAtt(ncid,LONGvarid,'_FillValue',LONG_attributes.(LONG_names{j}));
                netcdf.defVarFill(ncid,LONGvarid,false,double(LONG_attributes.(LONG_names{j}))); % false means noFillMode == false
            else
                netcdf.putAtt(ncid,LONGvarid,LONG_names{j},LONG_attributes.(LONG_names{j}));
            end
        end
    end

    %% -----------  VARIABLES -------------

num_vars=length(variable_cell);
% calculate number of ancillary variables from num_vars and
% length(anc_variable_cell)
num_ancs=length(anc_variable_cell)/num_vars;
varidstring=cell(num_vars,1);
% current list of ancs: num_obs, burst_sd, burst_min, burst_max
anc_cell_methods={'','standard_deviation','minimum','maximum'};
for i=1:num_vars
    variablei_attributes=variable_cell{i,1};
    vari_fieldnames=fieldnames(variablei_attributes);
    var_name=variablei_attributes.name;
    varidstring{i}=strcat(lower(variablei_attributes.name),'id');   % id string, to link with defVar output 
    
      idnumber=netcdf.defVar(ncid,var_name,'NC_FLOAT',[dimlatID dimlongID dimtimeID ]);
      netcdf.defVarChunking(ncid, idnumber, 'CHUNKED', [1 1 n]); % n is the number of records
      netcdf.defVarDeflate(ncid, idnumber, true, true, compressionLevel);
        eval(strcat(varidstring{i},'=idnumber;'))
         % so have a cell of names (strings), and a corresponding
         % list of variables with those names with the id number
    netcdf.putAtt(ncid,idnumber,'cell_methods','TIME: mean');
    for j=1:length(vari_fieldnames)
        if ~any(strcmp(vari_fieldnames{j},{'name', 'data', 'ChunkSize'})) % These ones don't go in putAtt
                
            if iscell(variablei_attributes.(vari_fieldnames{j}))  % putAtt does not accept cells
                C=variablei_attributes.(vari_fieldnames{j}); sep=',';    % extracting cell contents into 1 string
                add_sep=strcat(C,sep)'; s=[add_sep{:}];
                if strcmp(s(end-length(char(sep))+1:end),sep)
                    s=s(1:end-length(char(sep)));           % chop off end comma
                end
                s=strrep(s, sep, ' '); % replace comma by space (CF)
                netcdf.putAtt(ncid,idnumber,vari_fieldnames{j},s);
            elseif strcmp(vari_fieldnames{j},'FillValue')
%                 netcdf.putAtt(ncid,idnumber,'_FillValue',single(variablei_attributes.(vari_fieldnames{j})));
                netcdf.defVarFill(ncid,idnumber,false,single(variablei_attributes.(vari_fieldnames{j}))); % false means noFillMode == false
            else
               netcdf.putAtt(ncid,idnumber,vari_fieldnames{j},variablei_attributes.(vari_fieldnames{j}));    
            end
        end
    end
    % continue with that variable, putting the ancillary variable here, so
    % ancillaries appear with parent variable in finished file
    for k=1:num_ancs
        anc_variablek_attributes=anc_variable_cell{(i-1)*num_ancs+k,1};
        ancvark_fieldnames=fieldnames(anc_variablek_attributes);
        ancvar_name=anc_variablek_attributes.name;
        ancvaridstring{(i-1)*num_ancs+k}=strcat(lower(anc_variablek_attributes.name),'_id');
                                                % id string, to link with defVar output 
        if strcmp(ancvar_name(end-2:end),'obs')
            idnumber_anc=netcdf.defVar(ncid,ancvar_name,'NC_INT',[dimlatID dimlongID dimtimeID ]);
            eval(strcat(ancvaridstring{(i-1)*num_ancs+k},'=idnumber_anc;'))
            % so have a cell of names (strings), and a corresponding
            % list of variables with those names with an integer value
            netcdf.putAtt(ncid,idnumber_anc,'standard_name',[var_name,' number_of_observations']);
            % CF 1.6: standard_name followed by one or more blanks then a
            % standard name modifier, which can be number_of_observations
        else
            idnumber_anc=netcdf.defVar(ncid,ancvar_name,'NC_FLOAT',[dimlatID dimlongID dimtimeID ]);
            eval(strcat(ancvaridstring{(i-1)*num_ancs+k},'=idnumber_anc;'))
            netcdf.putAtt(ncid,idnumber_anc,'cell_methods',['TIME: ' anc_cell_methods{k}]);
        end
        netcdf.defVarChunking(ncid, idnumber_anc, 'CHUNKED', [1 1 n]); % n is the number of records
        netcdf.defVarDeflate(ncid, idnumber_anc, true, true, compressionLevel);
        
        for j=1:length(ancvark_fieldnames)
            if ~any(strcmp(ancvark_fieldnames{j},{'name', 'data', 'ChunkSize'})) % These ones don't go in putAtt
                if iscell(anc_variablek_attributes.(ancvark_fieldnames{j}))  % putAtt does not accept cells
                    C=anc_variablek_attributes.(ancvark_fieldnames{j}); sep=',';    % extracting cell contents into 1 string
                    add_sep=strcat(C,sep)'; s=[add_sep{:}];
                    if strmatch(s(end-length(char(sep))+1:end),sep)
                        s=s(1:end-length(char(sep)));           % chop off end comma
                    end
                    s=strrep(s, sep, ' '); % replace comma by space (CF)
                    netcdf.putAtt(ncid,idnumber_anc,ancvark_fieldnames{j},s);
                elseif strcmp(ancvark_fieldnames{j},'FillValue')
                     [varname,xtype,dimids,natts] = netcdf.inqVar(ncid,idnumber_anc);
                     if xtype==4
%                         netcdf.putAtt(ncid,idnumber_anc,'_FillValue',int32(anc_variablek_attributes.(ancvark_fieldnames{j})));
                        netcdf.defVarFill(ncid,idnumber_anc,false,int32(anc_variablek_attributes.(ancvark_fieldnames{j}))); % false means noFillMode == false
                     elseif xtype==5
%                          netcdf.putAtt(ncid,idnumber_anc,'_FillValue',single(anc_variablek_attributes.(ancvark_fieldnames{j})));
                         netcdf.defVarFill(ncid,idnumber_anc,false,single(anc_variablek_attributes.(ancvark_fieldnames{j}))); % false means noFillMode == false
                     else                   % xtype = 6, ie. double
%                          netcdf.putAtt(ncid,idnumber_anc,'_FillValue',double(anc_variablek_attributes.(ancvark_fieldnames{j})));
                         netcdf.defVarFill(ncid,idnumber_anc,false,double(anc_variablek_attributes.(ancvark_fieldnames{j}))); % false means noFillMode == false
                     end
                else
                   netcdf.putAtt(ncid,idnumber_anc,ancvark_fieldnames{j},anc_variablek_attributes.(ancvark_fieldnames{j}));
                end
            end
        end
    end
 end

   
netcdf.endDef(ncid)             % End define mode, enter data mode. netcdf.create opened the file in define mode.
%%

timedata = timedata - datenum('1 jan 1950');        % netcdf time - days since 1 Jan 1950

latitudedata=dimensions{1,1}.data;
longitudedata=dimensions{2,1}.data;

netcdf.putVar(ncid,TIMEvarid,0,n,timedata); 
netcdf.putVar(ncid,LATvarid,latitudedata);
netcdf.putVar(ncid,LONGvarid,longitudedata);

for i = 1:num_vars
    variablei_attributes=variable_cell{i,1};
     % varidstring{i}=strcat(lower(variablei_attributes.name),'id');
    % already calculated in previous loop
    eval(strcat('idnumber=',varidstring{i},';'))
    netcdf.putVar(ncid,idnumber,[0 0 0],[ 1 1 n],variablei_attributes.data)
    for k=1:num_ancs
        anc_variablek_attributes=anc_variable_cell{(i-1)*num_ancs+k,1};
        % varidstring{i}=strcat(lower(variablei_attributes.name),'id');
        % already calculated in previous loop
        eval(strcat('idnumber_anc=',ancvaridstring{(i-1)*num_ancs+k},';'))
        ancdata=anc_variablek_attributes.data;
        netcdf.putVar(ncid,idnumber_anc,[0 0 0],[ 1 1 n],ancdata)
    end
    
end

netcdf.close(ncid)

end
    


function outputFile = singleWQMburstavproduct(inputFile, destDir)
%SINGLEWQMBURSTAVPRODUCT produces a burst averaged version of inputFile in
%destDir and provides with this outputFile full path.
%
% Inputs:
% inputFile       - string containing either url, or path to input FVO1 file
%                   for input for user code library parser. Input file 
%                   is any WQM netcdf file. eg.
%                   Note: Filename must be in format of current IMOS netcdf WQM
%                   files. ie.: dateformats, FVO1.
%  
% destDir         - string containing directory/path where output file is to be
%                   created.
% 
% Outputs: 
% outputFile      - string that is path to output file.

[inputPath, inputFilename, ~] = fileparts(inputFile);

% Check that input file contains WQM in inputFilename. If not, abort.
if isempty(strfind(inputFilename, 'WQM'))
    error('Input file %s is not a WQM data file.', inputFilename)
end

fprintf('Parsing raw file from opendap -')
dataset=ncParse(inputFile);          % User Code Library Parser
fprintf('Success. \n')
if isfield(dataset.variables,'CNDC')
    dataset.variables=rmfield(dataset.variables,'CNDC');
end


%% Impossible date test, and negative time difference test
%  (rare: so far only one data file, MaIs mid 2008 90m. ncParse does not parse in TIME QC flags)
% The outside deployment test here should be covered by the toolbox out-of-water test.
% Perhaps it's redundant, but no harm.
earliestdatestr=dataset.metadata.time_deployment_start; % in yyyy-mm-ddTHH:MM:SSZ format
earliestdate=datenum(str2double(earliestdatestr(1:4)),str2double(earliestdatestr(6:7)),str2double(earliestdatestr(9:10)));  
latestdatestr=dataset.metadata.time_deployment_end; % in yyyy-mm-ddTHH:MM:SSZ format
latestdate=datenum(str2double(latestdatestr(1:4)),str2double(latestdatestr(6:7)),str2double(latestdatestr(9:10))); 
 inputtime=dataset.dimensions.TIME.data;
outsidedeppoints=find(inputtime<earliestdate | inputtime>latestdate);
diffinputtime=diff(inputtime);negdifftimes=find(diffinputtime<0);   % eg. MaIs apr08 90m
num_outside_dep=length(outsidedeppoints);num_neg_diff=length(negdifftimes);
if num_outside_dep>0 fprintf('Num of timestamps outside deployment: %8.0f \n',num_outside_dep);end
if num_neg_diff>0 fprintf('Num of ''backward'' timestamps: %8.0f \n',num_neg_diff);end
impossiblepoints=union(outsidedeppoints,negdifftimes);
dataset.dimensions.TIME.data(impossiblepoints)=[];
% The reason we're deleting the point with the same index as negdiff is
% it's the second point of the diff pair. After lots of eyeballing, the
% only obvious false timestamps seem to be stamps ahead in time instead of
% behind - so a negative diff is a sign of one of those. And only in MaIs?
% Note that problem means that dataset is non-compliant
inputtime=dataset.dimensions.TIME.data;
% excised from time variable: so the time dimension won't match the
% co-ordinate variables - but excise them as well at first opportunity
%%
FillValue=999999;		% for filling the product variables
variable_names=fieldnames(dataset.variables);        % a len_vars x 1 cell of strings
len_vars=length(variable_names);
if isfield(dataset.metadata,'instrument_burst_duration')
    burst_duration=dataset.metadata.instrument_burst_duration;
else
    burst_duration=60;          % a guess
end
% Message about highflags, and excising any data corresponding to impossiblepoints above
for i=1:length(fieldnames(dataset.variables))
    dataset.variables.(variable_names{i}).data(impossiblepoints)=[];
   dataset.variables.(variable_names{i}).flag(impossiblepoints)=[];
    flagsi=dataset.variables.(variable_names{i}).flag;
    highflags=find(flagsi>=3);
    if length(highflags)/length(flagsi)>0.5         % arbitrary! Probably want product to have even greater prop of good
        fprintf('%s has more than 50%% high flags. Check raw file.\r',variable_names{i})
        
    end
end
    %% MAIS SALINITY: call out to script for use on Maria Island salinity
    % This excludes extra points using the Historical Percentile Rate of Change algorithm,
    % because of the known spiky behaviour of MaIs Salinity WQM data 2008-2013, confirmed by
    % Ken Ridgeway
if ~isempty(strfind(inputFile,'NRSMAI'))
    inputsal=dataset.variables.PSAL.data;
    instrument_depth=dataset.metadata.instrument_nominal_depth;     % may not be exactly 20 or 90
    toolboxflagsPSAL=dataset.variables.PSAL.flag;
    ResultTableSal=maisSalinity(inputFilename,inputsal,inputtime,instrument_depth,toolboxflagsPSAL);
    % ( ResultTableSal=[aggregatedT aggregatedSal numIncludedSal SDBurstSal rangeBurstSal] )
end

%% Bin all other variables

% -------- Core of product: calls aggregate.m, passing in which points to exclude.   ----
% aggregate.m identifies the bursts, and calculates burst variables.
% aggregatedVariables is a len_vars x 1 cell with each cell member containing the ResultTable data array
aggregatedVariables=cell(len_vars,1);
for i=1:len_vars
    if ~isempty(strfind(inputFile,'NRSMAI'))
        if ~strcmp(variable_names{i},'PSAL')        % Maria Island, variables other than psal
            variabledatai=dataset.variables.(variable_names{i}).data;
            inputtime=dataset.dimensions.TIME.data;
            % remove any points with toolbox flags
            toolboxflagsi=dataset.variables.(variable_names{i}).flag;
            flags34=find(toolboxflagsi>=3);       % exclude flags of 3, which are mostly RoC flags. Flag 4 includes out-of-water
            flags4=find(toolboxflagsi>=4);          % for FLNTU data, don't apply spike test, because unsure of validity
            if strcmp(variable_names{i},{'TURB','FLU2','CPHL','CHLR','CHLU','CHLF'})
                [aggregatedTi,aggregatedvi,numIncludedvi,SDBurstvi,rangeBurstvi]=aggregate(inputtime,variabledatai,burst_duration,flags4);
            else
                [aggregatedTi,aggregatedvi,numIncludedvi,SDBurstvi,rangeBurstvi]=aggregate(inputtime,variabledatai,burst_duration,flags34);
            end
            ResultTablevi=[aggregatedTi aggregatedvi numIncludedvi SDBurstvi rangeBurstvi];
            aggregatedVariables{i}=ResultTablevi;
            
        else
            aggregatedVariables{i}=ResultTableSal;
            
        end
    else                                            % Not Maria Island, all variables
            variabledatai=dataset.variables.(variable_names{i}).data;
            % remove any points with toolbox flags
            toolboxflagsi=dataset.variables.(variable_names{i}).flag;
            flags34=find(toolboxflagsi>=3);       % exclude flags of 3, which are mostly RoC flags. Flag 4 includes out-of-water
            flags4=find(toolboxflagsi>=4);          % for FLNTU data, don't apply spike test, because unsure of validity
            if strcmp(variable_names{i},{'TURB','FLU2','CPHL','CHLR','CHLU','CHLF'})
                [aggregatedTi,aggregatedvi,numIncludedvi,SDBurstvi,rangeBurstvi]=aggregate(inputtime,variabledatai,burst_duration,flags4);
            else
                [aggregatedTi,aggregatedvi,numIncludedvi,SDBurstvi,rangeBurstvi]=aggregate(inputtime,variabledatai,burst_duration,flags34);
            end
            
            ResultTablevi=[aggregatedTi aggregatedvi  numIncludedvi SDBurstvi rangeBurstvi];
            aggregatedVariables{i}=ResultTablevi;
            
    end
    aggregatedVariables{i}(find(isnan(aggregatedVariables{i})))=FillValue;
    
    % Any NaN's produced by matlab are converted to FillValues, as
    % prescribed by CF conventions. Any software that handles netCDF files, deals with FillValues
end
%% Put variable and acillary attributes into 2 separate cells

ancillary_suffix_list={'_num_obs';'_burst_sd';'_burst_min';'_burst_max'};
len_a=length(ancillary_suffix_list);

% Assign relevant variable attributes.

variable_cell=cell(len_vars,1);     % container for variable attribs
anc_variable_cell=cell(len_vars*len_a,1);  % separate container for ancillary variable attributes, for simpler indices
anc_variable_names=cell(len_vars*len_a,1);
anc_long_names={'Number of observations in burst included in burst average';...
                'Standard deviation of values in burst, after rejection of flagged data'; ...
                'Minimum data value in burst, after rejection of flagged data';...
                'Maximum data value in burst, after rejection of flagged data'};


for i=1:len_vars
    % extract only relevant attribs: eg. leave out QC stuff
    variable_attributes_i=dataset.variables.(variable_names{i});        % set of attributes for variable i
    fields_to_remove={'quality_control_set','quality_control_indicator', ...
         'flag_meanings','flag_values','flag','flag_quality_control_conventions','dimensions'};
     for k=1:length(fields_to_remove)
         if isfield(variable_attributes_i,fields_to_remove{k})
             variable_attributes_i=rmfield(variable_attributes_i,fields_to_remove{k});
         end
     end
     % create new variables, which are the ancillary variables 
    variable_prefix=repmat([variable_names{i}],len_a,1);
    ancillary_variable_namesi=strcat(variable_prefix,ancillary_suffix_list)';
    variable_attributes_i=setfield(variable_attributes_i,'ancillary_variables',ancillary_variable_namesi);
    variable_attributes_i=setfield(variable_attributes_i,'data',aggregatedVariables{i}(:,2));
    prev_long_name=variable_attributes_i.long_name;
    
    new_long_name=['Mean of ' prev_long_name ' values in burst, after rejection of flagged data'];
    variable_attributes_i=setfield(variable_attributes_i,'long_name',new_long_name);
    variable_cell{i,1}=variable_attributes_i;
    % For each i, create a series of len_a new variables that are the ancillary burst information
    % variables associated with variable_names{i} :
    for j=1:len_a
        anc_variable_attributes_j=variable_attributes_i;    % same attributes as parent variable, except we'll change some
        anc_variable_names{(i-1)*j+j}=strcat(variable_names{i},ancillary_suffix_list{j});
                                    % standard_name not always present:
                           
            fields_to_remove={'comment','standard_name','valid_min','valid_max','ancillary_variables',...
                'axis','positive','reference_datum'};
            for k=1:length(fields_to_remove)
                if isfield(anc_variable_attributes_j,fields_to_remove{k})
                    anc_variable_attributes_j=rmfield(anc_variable_attributes_j,fields_to_remove{k});
                end
            end
            if strcmp(ancillary_suffix_list{j},'_num_obs') 
                if isfield(variable_attributes_i,'standard_name')
                    prev_stand_name=variable_attributes_i.standard_name;
                    anc_variable_attributes_j=setfield(anc_variable_attributes_j,'standard_name',[prev_stand_name ' number of observations']);
                else
                    anc_variable_attributes_j=setfield(anc_variable_attributes_j,'standard_name',[prev_long_name ' number of observations']);
                end
            end      
        anc_variable_attributes_j=setfield(anc_variable_attributes_j,'name',anc_variable_names{(i-1)*j+j});
        anc_variable_attributes_j=setfield(anc_variable_attributes_j,'long_name',anc_long_names{j});
        if strcmp(ancillary_suffix_list{j},'_num_obs')                        
           anc_variable_attributes_j=rmfield(anc_variable_attributes_j,'units');    % no units
        end
        anc_variable_attributes_j=setfield(anc_variable_attributes_j,'data',aggregatedVariables{i}(:,j+2));
        anc_variable_cell{(i-1)*len_a + j,1}=anc_variable_attributes_j; 
    end
end

% Add binned time data to bottom of variable_cell:
time_attributes=dataset.dimensions.TIME;
fields_to_remove={'ancillary_variables','quality_control_set','quality_control_indicator'};
for k=1:length(fields_to_remove)
    if isfield(time_attributes,fields_to_remove{k})
        time_attributes=rmfield(time_attributes,fields_to_remove{k});
    end
end
%% Data attributes

% feed data into data attribute:
time_attributes.data=aggregatedTi;                  % time and aggregated time is identical for each variable
dimensions{1,1}=dataset.dimensions.LATITUDE;        % leave unchanged
dimensions{2,1}=dataset.dimensions.LONGITUDE;
dimensions{3,1}=time_attributes;
timedata = dimensions{3,1}.data;
%% Global attributes

global_attributes=dataset.metadata;         % a 1 x 1 struct, which has fields that are the global
%                                             attributes of orig file
% Add the attribute of input file here, to save passing another variable to
% export_binned_WQM_netcdf.m. First, remove assorted irrelevant glob attribs
fields_to_remove={'toolbox_input_file','file_version_quality_control',...
                'quality_control_set','history','CoordSysBuilder_','netcdf_filename','metadata'};
for k=1:length(fields_to_remove)
    if isfield(global_attributes,fields_to_remove{k})
        global_attributes=rmfield(global_attributes,fields_to_remove{k});
    end
end

thredds_path='http://thredds.aodn.org.au/thredds/catalog/IMOS/ANMN/';
start_location_part=strfind(inputPath,'/ANMN/');
location_string=inputPath(start_location_part+6:end);
total_input_file=strcat(thredds_path,location_string,'/','catalog.html?dataset=IMOS/ANMN/',location_string,'/',inputFilename,'.nc');
global_attributes=setfield(global_attributes,'input_file',total_input_file);
global_attributes=setfield(global_attributes,'standard_name_vocabulary','CF-1.6');

todays_date=UTCstringfromlocal(clock,-10);  % (includes rounding down mins)
global_attributes=setfield(global_attributes,'date_created',todays_date);
orig_keyword_string=global_attributes.keywords;
orig_keyword_string=strcat(orig_keyword_string,', AVERAGED, BINNED');
% global_attributes=setfield(global_attributes,'keywords',strrep(orig_keyword_string,' DOX1_1,',''));
global_attributes=setfield(global_attributes,'featureType','timeSeries');
global_attributes=setfield(global_attributes,'geospatial_vertical_positive','down');

% *********
time_coverage_start=min(timedata);time_coverage_end=max(timedata);
% round down minutes to be consistent with FV01 files:
vecdate=datevec(time_coverage_start);vecdate(6)=0;time_coverage_start=datenum(vecdate);
vecdate=datevec(time_coverage_end);vecdate(6)=0;time_coverage_end=datenum(vecdate);

time_coverage_start_UTC=UTCstringfromlocal(time_coverage_start,-10);
time_coverage_end_UTC=UTCstringfromlocal(time_coverage_end,-10);
global_attributes=setfield(global_attributes,'time_coverage_start',time_coverage_start_UTC);
global_attributes=setfield(global_attributes,'time_coverage_end',time_coverage_end_UTC);

% Force input file to be first in glob attribs:
global_attribute_names=fieldnames(global_attributes);
strfindresult=strfind(global_attribute_names,'input_file');k=find(~cellfun('isempty',strfindresult)); 
shuffled_glob_attrib_names=[global_attribute_names(k); global_attribute_names(1:k-1);global_attribute_names(k+1:end)];
global_attributes=orderfields(global_attributes,shuffled_glob_attrib_names);

%% generate new filename from input filename:

bin_filename=inputFilename;
% 1. Replace deployment start date with product start date:
time_cov_start_file_string=strcat(datestr(time_coverage_start,'yyyymmddTHHMMSS'),'Z');
len_date=length(time_cov_start_file_string);        % (same format for start, end, creation)
startindex=regexp(inputFilename,'20');     % startindex will have length>1. First occurrence is start date
bin_filename(startindex(1):startindex(1)-1+len_date)=time_cov_start_file_string;
% 2. Replace file version
bin_filename=strrep(bin_filename,'FV01','FV02');
% 4. Replace deployment end date with product end date:
time_cov_end_file_string=strcat(datestr(time_coverage_end,'yyyymmddTHHMMSS'),'Z');
startindex=strfind(bin_filename,'END');
bin_filename(startindex+4:startindex+3+len_date)=time_cov_end_file_string;
% 5. Insert the suffix '_averaged' at the end of <Product-Type>
bin_filename=strcat(bin_filename(1:startindex-2),'-burst-averaged',bin_filename(startindex-1:end));
% 6. Replace date created with product date created:
nowvec=datevec(now);nowvec(6)=0;nowvec=nowvec+[0 0 0 -10 0 0];
creation_file_string=strcat(datestr(nowvec,'yyyymmddTHHMMSS'),'Z');
startindex=strfind(bin_filename,'_C-');
bin_filename(startindex+3:startindex+2+len_date)=creation_file_string;
bin_filename=strcat(bin_filename,'.nc');

%% Call netcdf creation function
% This deals with netCDF tasks, creation and filling in metadata fields
outputFile = fullfile(destDir,bin_filename);
testncid = export_binned_WQM_netcdf(outputFile,global_attributes,dimensions,variable_cell,anc_variable_cell);
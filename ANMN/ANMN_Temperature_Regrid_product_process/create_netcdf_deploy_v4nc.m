function [] = create_netcdf_deploy_v4nc(flist,filename,varname,val,...
    TimeVar,DepthVar,LatVar,LonVar,freq,nst_av)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%% 
% FUNCTION TO WRITE THE REGRIDDED PRODUCT IN AN NETCDF 
% INPUT:	- path2file :path to data file
%	 		- flist 			: structucre containing list of target data file
% 		 	- filename    		: name of the output file
%			- varname       	: name of variable 
%			- val 				: variable value
%			- TimeVar,DepthVar,LatVar,LonVar  
%			- Site, deployment 	: site id, deployment id
%
% 
% BPasquer July 2014
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
ncid = netcdf.create(filename, 'NETCDF4');
% DEFINITION MODE
TdimID = netcdf.defDim(ncid,'TIME',netcdf.getConstant('NC_UNLIMITED'));
DdimID 	=  netcdf.defDim(ncid,'DEPTH',length(DepthVar));
LatdimID =  netcdf.defDim(ncid,'LATITUDE',length(LatVar));
LondimID =  netcdf.defDim(ncid,'LONGITUDE',length(LonVar));

% READ ATTRIBUTE OF PREEXISTING VARIABLE FROM ORIGINAL FILE
varNamelist = {'TIME','DEPTH','LATITUDE','LONGITUDE',varname};

timeid = netcdf.defVar(ncid, 'TIME','double', TdimID);
netcdf.defVarFill(ncid,timeid,false,999999.);
depthid = netcdf.defVar(ncid, 'DEPTH','float', DdimID);
netcdf.defVarFill(ncid,depthid,false,999999.);
latid = netcdf.defVar(ncid, 'LATITUDE','double', LatdimID);
netcdf.defVarFill(ncid,latid,false,999999.);
lonid = netcdf.defVar(ncid, 'LONGITUDE','double', LondimID);
netcdf.defVarFill(ncid,lonid,false,999999.);
varid = netcdf.defVar(ncid,varname,'float', [ LondimID LatdimID DdimID TdimID]);
netcdf.defVarFill(ncid,varid,false,999999.);

varIDlist = {timeid,depthid,latid,lonid,varid};

for i = 1:length(varNamelist)
    varnm = varNamelist{i};
% USE ONLY ONE ORIGINAL FILE TO GET VARIABLE ATTRIBUTE
	[attlist,attval,gattlist] = get_VarInfo(fullfile(flist.path2file,flist.name),varNamelist{i});
    
    for natt = 1:length(attlist)

% ATTRIBUTE NOT RELEVANT DELETED 	
        switch varnm
            case 'DEPTH'
                if strcmp(attlist{natt},'ancillary_variables') || strcmp(attlist{natt},'quality_control_set')
                    continue
                end
            otherwise
                if strcmp(attlist{natt},'ancillary_variables') || strcmp(attlist{natt},'quality_control_set')|| strcmp(attlist{natt},'comment')
                    continue
                end
        end
 % MAKE SURE ATTRIBUTE DATA TYPE CONSISTENT WITH VARIABLE DATATYPE 
        vatt2match = {'valid_min', 'valid_max'};
        switch varnm
             case {'TIME','LATITUDE', 'LONGITUDE'}
                 if ismember(attlist{natt},vatt2match)    
                    netcdf.putAtt(ncid,varIDlist{i},attlist{natt},double(attval{natt}));
                 elseif ~strcmp(attlist{natt},'_FillValue')
                    netcdf.putAtt(ncid,varIDlist{i},attlist{natt},attval{natt});
                 end

             case {'DEPTH',varname}
                if ismember(attlist{natt},vatt2match)    
                    netcdf.putAtt(ncid,varIDlist{i},attlist{natt},single(attval{natt})); %single
                 elseif ~strcmp(attlist{natt},'_FillValue')
                    netcdf.putAtt(ncid,varIDlist{i},attlist{natt},attval{natt});
                end
        end
    end
end

% GLOBAL ATTRIBUTES
% DELETE ATTRIBUTE NOT RELEVANT TO PRODUCT

gatt2del ={'toolbox_input_file','toolbox_version','comment' ,...
    'instrument_sample_interval','instrument_serial_number',...
    'history','instrument_nominal_height','instrument_nominal_depth',...
    'time_deployment_start','time_deployment_end' ,...
    'principal_investigator','principal_investigator_email',...
    'quality_control_set'};

[lia,locb] = ismember(gatt2del,gattlist(:,1));
gattlist(locb(lia==1),:) = []; 

% CREATE TITLE
netcdf.putAtt(ncid,netcdf.getConstant('NC_GLOBAL'),'title',...
    [flist.node '-' flist.site ' mooring, gridded temperature product']);

% ADD LIST OF ORIGINAL ATTRIBUTES
for ngatt = 1: size(gattlist,1)
    if isnumeric(gattlist{ngatt,2})
		netcdf.putAtt(ncid,netcdf.getConstant('NC_GLOBAL'),char(gattlist(ngatt,1)),...
		gattlist{ngatt,2})
	else
			netcdf.putAtt(ncid,netcdf.getConstant('NC_GLOBAL'),char(gattlist(ngatt,1)),...
		char(gattlist(ngatt,2)))
    end 
end

% MODIFICATION OF EXISTING ATTRIBUTES / ADDITION OF NEW ATTRIBUTES
% ABSTRACT
nomdpth =  scan_filename(flist.flistDeploy,'nomdepth');
netcdf.putAtt(ncid,netcdf.getConstant('NC_GLOBAL'),'abstract',...
    ['This product aggregates Temperature logger data collected at these nominal depths (', strtrim(num2str(sort(unique(nomdpth)),'%g,')) ,') on the mooring line during the ' flist.id ' deployment by averaging them temporally and interpolating them vertically on a common grid. The grid covers from ' datestr(min(TimeVar),'yyyy-mm-ddTHH:MM:SSZ') ' to ' datestr(max(TimeVar),'yyyy-mm-ddTHH:MM:SSZ') ' temporally and from 0 to ' num2str(max(DepthVar)) ' metres vertically. A cell is ' num2str(freq) ' minutes wide and 1 metre high']);

% COMMENT
flisting = cell(1,length(flist)); %Listing of input file for the product
[ flisting{1:length(flist)}] = flist.flistDeploy.name;
phrase = {'The following files have been used to generate the gridded product: '};
full_comment =[phrase flisting];
netcdf.putAtt(ncid,netcdf.getConstant('NC_GLOBAL'),'comment',...
sprintf('%s\n', full_comment{:}));

% INSTRUMENT ATTRIBUTE :LIST OF T LOGGERS ON THE MOORING LINE
% SAME FOR KEYWORDS: GET LIST OF KEYWORDS ACCORDING TYO WHAT'S IN ORIGINAL
% FILES BUT LIMITING REDUNDANCY
% INSTRUMENT(S)

% CHECK FOR MULTIPLE INSTRUMENTS. ADAPT GLOBAL ATTRIBUTES 'INTRUMENT' AND 'KEYWORDS'
% ACCORDING TO NUMBER OF INSTRUMENT ON MOORING LINE 

[nm,ind_l] = scan_filename(flist.flistDeploy,'inst_name');
ind_nm = length(ind_l); 
kwd = cell(ind_nm); %length is arbitrary

for ninst = 1:ind_nm    
    % INSTRUMENT
    instnm{ninst} = get_globalAttributes('file',fullfile(flist.path2file,flist.flistDeploy(ninst).name),'instrument');
    % KEYWORDS
    k{ninst} = get_globalAttributes('file',fullfile(flist.path2file,flist.flistDeploy(ninst).name),'keywords');  
    kwd{ninst} = regexp(k{ninst},', ','split');     
    if ninst > 1        
        kwd{ninst} = union(kwd{ninst-1},kwd{ninst}); 
    end
end    
% NEED TO CONVERT CELL 2 STRUCT FOR TEXT OUTPUT
instrmt =  cell2struct(instnm,'name');
netcdf.putAtt(ncid,netcdf.getConstant('NC_GLOBAL'),'instrument',...
        sprintf('%s; ',instrmt.name))  ;

% KEYWORDS : IF MULTIPLE FILE , EXTRACT ONE INSTANCE OF KEYWORDS 
%LAST CELL OF KWD_UN CONTAINS SINGLE INSTANCE OF EVERY KEYWORDS
keywd =  cell2struct(kwd{ind_nm},'list'); 
netcdf.putAtt(ncid,netcdf.getConstant('NC_GLOBAL'),'keywords',...
        sprintf('%s; ','Gridded product',keywd.list)) ;    
    
% NETCDF VERSION 
netcdf.putAtt(ncid,netcdf.getConstant('NC_GLOBAL'),'netcdf_version', num2str(4)) ;
% CREATION DATE     	
netcdf.putAtt(ncid,netcdf.getConstant('NC_GLOBAL'),'date_created',...
   local_time_to_utc(now,30))  ; 
 % FEATURETYPE
netcdf.putAtt(ncid,netcdf.getConstant('NC_GLOBAL'),'featureType', ...
     'timeSeriesProfile')  ; 
% TEMPORAL_RESOLUTION
 netcdf.putAtt(ncid,netcdf.getConstant('NC_GLOBAL'),'temporal_resolution',...
     num2str(freq))
% VERTICAL_RESOLUTION
 netcdf.putAtt(ncid,netcdf.getConstant('NC_GLOBAL'),'vertical_resolution',...
     num2str(1))
% VERTICAL_RESOLUTION
netcdf.putAtt(ncid,netcdf.getConstant('NC_GLOBAL'),'instrument_nominal_depth',...
     strtrim(num2str(nomdpth,'%g,')))
% TIME_COVERAGE_START
netcdf.putAtt(ncid,netcdf.getConstant('NC_GLOBAL'),'time_coverage_start',...
    datestr(min(TimeVar),'yyyy-mm-ddTHH:MM:SSZ'))
% TIME_COVERAGE_END
netcdf.putAtt(ncid,netcdf.getConstant('NC_GLOBAL'),'time_coverage_end' , ...
      datestr(max(TimeVar),'yyyy-mm-ddTHH:MM:SSZ')) 
% GEOSPATIAL_VERTICAL_MIN
netcdf.putAtt(ncid,netcdf.getConstant('NC_GLOBAL'),'geospatial_vertical_min' ,...
    min(DepthVar))
% GEOSPATIAL_VERTICAL_MAX
netcdf.putAtt(ncid,netcdf.getConstant('NC_GLOBAL'),'geospatial_vertical_max' ,...
max(DepthVar))
% AUTHOR_EMAIL
netcdf.putAtt(ncid,netcdf.getConstant('NC_GLOBAL'),'author_email',...
'benedicte.pasquer@utas.edu.au');
% AUTHOR
netcdf.putAtt(ncid,netcdf.getConstant('NC_GLOBAL'),'author',...
'Pasquer, Benedicte')
% FILE_VERSION
netcdf.putAtt(ncid,netcdf.getConstant('NC_GLOBAL'),'file_version', ...
     'Level 2- Derived Products')  ;
% FILE_VERSION_QUALITY_CONTROL     
netcdf.putAtt(ncid,netcdf.getConstant('NC_GLOBAL'),'file_version_quality_control', ...
     'Derived products require scientific and technical interpretation. Normally these will be defined by the community that collects or utilises the data.') ;

%%%%%%%%%%%%LINEAGE
 
text_bit{1} = 'The following steps have been carried out to generate this product:';
text_bit{2} = '1- Only Temperature and Depth data with QC flags 1 and 2 (good and probably good data) are considered.';
text_bit{3} = ['2- Every single time-series data collected at different nominal depths has been aggregated into a profile time-series by averaging their data temporally at every ', num2str(freq) , ' minute time periods for each of them. A minimum of ', num2str(nst_av) , ' data values per time period is required for the computation of the mean value. If this condition is not met, a fillvalue of 999999 is given.'];
text_bit{4} = '3- For every time period previously defined, averaged values are then linearly interpolated over the required vertical grid based on the averaged depth values. Cells falling outside of the measured depth range are provided with a fillvalue of 999999.';

netcdf.putAtt(ncid,netcdf.getConstant('NC_GLOBAL'),'lineage',sprintf('%s\n',text_bit{:})); 

%% LEAVE DEFINE MODE AND ENTER DATA MODE TO WRITE DATA.
netcdf.defVarChunking(ncid, varid, 'CHUNKED', [1 1 length(DepthVar) length(TimeVar)]);
netcdf.defVarDeflate(ncid, varid, true, true, 1);
netcdf.endDef(ncid) 

TimeVar = TimeVar - datenum('01-01-1950 00:00:00');  % IMOS time format
netcdf.putVar(ncid,timeid,0,length(TimeVar),TimeVar); 
netcdf.putVar(ncid,depthid,0,length (DepthVar),DepthVar);
netcdf.putVar(ncid,latid,LatVar);
netcdf.putVar(ncid,lonid,LonVar);
netcdf.putVar(ncid,varid,[0 0 0 0 ], [1 1 length(DepthVar) length(TimeVar)] ,val);

netcdf.close(ncid)

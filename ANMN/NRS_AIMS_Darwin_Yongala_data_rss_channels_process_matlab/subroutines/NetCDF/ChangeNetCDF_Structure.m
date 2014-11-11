function [FilenameModified]=ChangeNetCDF_Structure(ncFileName,Path,long,lat)
%% ChangeNetCDF_Structure
% Modifies the structure of the original NetCDF files downloaded from AIMS
% web service to be used better by IDV and RAMMADA. This work was made with
% suggestions from Mathias Bonnet.
%
% Inputs:   ncFileName  - the name of the NetCDF files
%           Path   - path of the file ncFileName
%           long   - longitude from the RSS
%           lat    - latitude from the RSS
%
% Outputs:  FilenameModified    - name of the new NetCDF file
%          
% See also:downloadChannelNRS,NRS_processLevel
% 
% Author: Laurent Besnard, IMOS/eMII
% email: laurent.besnard@utas.edu.au
% Website: http://imos.org.au/  http://froggyscripts.blogspot.com
% Aug 2012; Last revision: 04-Dec-2012

global dataWIP;


%% modify filename date
try
    nc = netcdf.open(fullfile(Path,ncFileName),'NC_WRITE');
    skip = 0;
catch
    Corrupted = ncFileName;
    skip = 1;
    fprintf('%s - ERROR: "%s" could not be open\n',datestr(now),char(fullfile(Path,Corrupted)))
    
    dirPathCorrupted = strcat(dataWIP,filesep,'corrupted_files');
    if exist(dirPathCorrupted,'dir') == 0
        mkpath(dirPathCorrupted);
    end
    if exist(fullfile(dirPathCorrupted,ncFileCorruptedName),'file') == 2
        delete (fullfile(dirPathCorrupted,ncFileCorruptedName))
    else
        movefile(fullfile(Path,ncFileCorruptedName),dirPathCorrupted)
    end
end

if skip==0
    %% list all the Variables
    [VARNAME,VARATTS]=listVarNC(nc);
    
    %% we grab the date dimension
    idxTIME = strcmpi(VARNAME,'TIME')==1;
    TimeVarName = VARNAME{idxTIME};
    varidTIME = netcdf.inqDimID(nc,TimeVarName);
    [~, dimlenTIME] = netcdf.inqDim(nc,varidTIME);
    
    
    if dimlenTIME >0
        VarIdTIME = netcdf.inqVarID(nc,TimeVarName);
        
        CreationDateStr=regexp( ncFileName,'_C-(\d+)','tokens' );
        indexCreationDate=strfind(ncFileName,char(CreationDateStr{1}));
        
        localTimeZoneComputer=10;
        CreationDate=datestr(now+datenum(0,0,0,0,0,60)-datenum(0,0,0,localTimeZoneComputer,0,0),'yyyymmddTHHMMSS');%add 3 seconds in case the programm is to fast and add the same filename
        
        filenameNew=fullfile(Path,ncFileName);
        filenameNew(length(Path)+indexCreationDate:length(Path)+indexCreationDate-1+length(CreationDate))=CreationDate;
        
        ExprToRead=strcat('Z\+');%in case there is a Z we remove it. Cannot have a Z (UTC time) and a local time zone +10, so we remove it in case AIMS does not do it
        filenameNew=regexprep(filenameNew, ExprToRead, '+','ignorecase');
        
        ExprToRead=strcat('\+[\d.]+_');
        filenameNew=regexprep(filenameNew, ExprToRead, '_','ignorecase'); % if there is a + , it is incoherent.


		%% Create a NEW netCDF file.
		[pathstr, name, ext] = fileparts(filenameNew);
		ncid_NEW = netcdf.create(strcat(pathstr,filesep,name,ext),'NOCLOBBER');
		
    
		%% Write Global Attributes
		[ ~, ~, natts ,~] = netcdf.inq(nc);
		for aa=0:natts-1
		    gattname = netcdf.inqAttName(nc,netcdf.getConstant('NC_GLOBAL'),aa);
		    gattval = netcdf.getAtt(nc,netcdf.getConstant('NC_GLOBAL'),gattname);
		    netcdf.putAtt(ncid_NEW,netcdf.getConstant('NC_GLOBAL'),gattname, gattval);
		end
		
		%% Geospatiatal values
		netcdf.putAtt(ncid_NEW,netcdf.getConstant('NC_GLOBAL'),'geospatial_lat_min',lat);
		netcdf.putAtt(ncid_NEW,netcdf.getConstant('NC_GLOBAL'),'geospatial_lat_max',lat);
		
		netcdf.putAtt(ncid_NEW,netcdf.getConstant('NC_GLOBAL'),'geospatial_lon_min',long);
		netcdf.putAtt(ncid_NEW,netcdf.getConstant('NC_GLOBAL'),'geospatial_lon_max',long);
    
    
    
    %%  Creation of the DIMENSION LON LAT TIME DEPTH
    LAT_VARNAME='LATITUDE';
    LON_VARNAME='LONGITUDE';
    TIME_VARNAME='TIME';
    DEPTH_VARNAME='DEPTH'; %to remove
    try
        VarIdDEPTH=netcdf.inqVarID(nc,'depth');
        DepthExist=1;
        DepthSingleValue=netcdf.getVar(nc,VarIdDEPTH);
        netcdf.putAtt(ncid_NEW,netcdf.getConstant('NC_GLOBAL'),'geospatial_vertical_reference_datum','Lowest Astronomical Tide');
        netcdf.putAtt(ncid_NEW,netcdf.getConstant('NC_GLOBAL'),'geospatial_vertical_positive','up');
        netcdf.putAtt(ncid_NEW,netcdf.getConstant('NC_GLOBAL'),'geospatial_vertical_units','meters');
        netcdf.putAtt(ncid_NEW,netcdf.getConstant('NC_GLOBAL'),'geospatial_vertical_min',DepthSingleValue)
        netcdf.putAtt(ncid_NEW,netcdf.getConstant('NC_GLOBAL'),'geospatial_vertical_max',DepthSingleValue)
    catch
        DepthExist=0;
        
    end
    varDepthName='depth';
    
    TIME_dimid = netcdf.defDim(ncid_NEW,char(TIME_VARNAME),dimlenTIME);
    
    
    LAT_dimid = netcdf.defDim(ncid_NEW,char(LAT_VARNAME),1);
    LON_dimid = netcdf.defDim(ncid_NEW,char(LON_VARNAME),1);
    
    
    
    %% create index vector 'ttt' for non TIME and TIME_QC, to
    %% be used in FOR loop
    idxTIME= strcmpi(VARNAME,TimeVarName)==1; %idx to remove from tt
    idxDEPTH= strcmp(VARNAME,'depth')==1; %idx to remove from tt . wraning there could be 'depth' which is now a single, and 'DEPTH' which is basically the tidal variable.
    
    
    idxLAT= strcmpi(VARNAME,'latitude')==1; %idx to remove from tt
    idxLATqc= strcmpi(VARNAME,'latitude_quality_control')==1; %idx to remove from tt
    
    idxLON= strcmpi(VARNAME,'longitude')==1; %idx to remove from tt
    idxLONqc= strcmpi(VARNAME,'longitude_quality_control')==1; %idx to remove from tt
    
    
    
    tttt=1:length(VARNAME);
    ttt=tttt(setdiff(1:length(tttt),[tttt(idxTIME),tttt(idxLAT),...
        tttt(idxLATqc),tttt(idxLON),tttt(idxLONqc),tttt(idxLONqc),tttt(idxDEPTH)]));
    
    
    
    %% Creation of the 'standard' VARIABLES
    TIME_id = netcdf.defVar(ncid_NEW,TIME_VARNAME,'float',TIME_dimid);
    LAT_id = netcdf.defVar(ncid_NEW,LAT_VARNAME,'float',LAT_dimid);
    LON_id = netcdf.defVar(ncid_NEW,LON_VARNAME,'float',LON_dimid);

    %% creation of the rest of variables
    for ii=ttt
        if strfind(char(VARNAME(ii)),'_quality_control')~=0
            VAR_ID_NEW = netcdf.defVar(ncid_NEW,VARNAME{ii},'byte',[LON_dimid,LAT_dimid,TIME_dimid]);
        else
            VAR_ID_NEW = netcdf.defVar(ncid_NEW,VARNAME{ii},'float',[LON_dimid,LAT_dimid,TIME_dimid]);
        end
        VAR_ID_NEW_LIST{ii}=VAR_ID_NEW;
    end
    
    %% creation of varQC variable
    idxTIMEqc= strcmpi(VARNAME,strcat(TimeVarName,'_quality_control'))==1; %idx to remove from tt
    for ii=tttt(idxTIMEqc)
        VAR_ID_TIMEqc = netcdf.defVar(ncid_NEW,VARNAME{ii},'byte',[TIME_dimid]);
    end
   
    netcdf.endDef(ncid_NEW)
    
    %% Creation ATTRIBUTES of variables in ttt vector
    netcdf.reDef(ncid_NEW)
    for ii=ttt
        VAR_ID= netcdf.inqVarID(nc,char(VARNAME(ii)));
        for aa=0:VARATTS{ii}-1
            attname = netcdf.inqAttName(nc,VAR_ID,aa);
            attval = netcdf.getAtt(nc,VAR_ID,attname);
            
            if isnumeric( attval)
                attval=double(attval);
            end
            
            netcdf.putAtt(ncid_NEW,VAR_ID_NEW_LIST{ii},attname,attval);
        end
        
        netcdf.putAtt(ncid_NEW,VAR_ID_NEW_LIST{ii},'coordinates',...
            char(strcat(TIME_VARNAME,[{' '}],LAT_VARNAME,[{' '}],LON_VARNAME)));
    end
    
    %% creation of Time attributes
    WhereIsTIME=tttt(idxTIME);
    for aa=0:VARATTS{WhereIsTIME}-1 %bug _FILLvalue
        attname = netcdf.inqAttName(nc,VarIdTIME,aa);
        attval = netcdf.getAtt(nc,VarIdTIME,attname);
        
        if strcmpi(attname,'units')
            if ~isempty(strfind(attval,'days'))
                attval(length('days since ')+length('yyyy-mm-ddT'))=' ';%we replace T by blank
            elseif ~isempty(strfind(attval,'seconds'))
                attval(length('seconds since ')+length('yyyy-mm-ddT'))=' ';    
            end     
        end
        
        
        if isnumeric( attval)
            attval=double(attval);
        end
        
        netcdf.putAtt(ncid_NEW,TIME_id,attname,attval);
    end
    
    
    %% creation of longitude attributes
    WhereIsLON=tttt(idxLON);
    LONVarName=VARNAME{idxLON};
    varidLON=netcdf.inqVarID(nc,LONVarName);
    for aa=0:VARATTS{WhereIsLON}-1 %bug _FILLvalue
        attname = netcdf.inqAttName(nc,varidLON,aa);
        attval = netcdf.getAtt(nc,varidLON,attname);
        
        if isnumeric( attval)
            attval=double(attval);
        end
        
        netcdf.putAtt(ncid_NEW,LON_id,attname,attval);
    end
    
    
    %% creation of latitude attributes
    WhereIsLAT=tttt(idxLAT);
    LATVarName=VARNAME{idxLAT};
    varidLAT=netcdf.inqVarID(nc,LATVarName);
    for aa=0:VARATTS{WhereIsLAT}-1 %bug _FILLvalue
        attname = netcdf.inqAttName(nc,varidLAT,aa);
        attval = netcdf.getAtt(nc,varidLAT,attname);
        
        if isnumeric( attval)
            attval=double(attval);
        end
        
        netcdf.putAtt(ncid_NEW,LAT_id,attname,attval);
    end
    
    netcdf.endDef(ncid_NEW)
    
    %% write DimensionId data
    time=netcdf.getVar(nc,VarIdTIME);
    
    netcdf.putVar(ncid_NEW,TIME_id,time);
    netcdf.putVar(ncid_NEW,LAT_id,lat);
    netcdf.putVar(ncid_NEW,LON_id,long);
    
    
    
    %% write standards variables
    for ii=ttt
        VAR_ID= netcdf.inqVarID(nc,char(VARNAME(ii)));
        if strfind(char(VARNAME(ii)),'_quality_control')~=0
            VAR=int8(netcdf.getVar(nc,VAR_ID));
        else
            VAR=(netcdf.getVar(nc,VAR_ID));
        end
        netcdf.putVar(ncid_NEW,VAR_ID_NEW_LIST{ii},[0,0,0],[1,1,dimlenTIME],VAR);%3 dimensions
    end
    
    
    netcdf.close(ncid_NEW);
    netcdf.close(nc);
    
        delete(fullfile(Path,ncFileName))

        [~, FilenameModified, ~] = fileparts(filenameNew);
        FilenameModified=strcat(FilenameModified,ext);
    else
        FilenameModified=[];
    end
else
    FilenameModified=[];
    
end
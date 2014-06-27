function [FilenameModified]=ChangeNetCDF_StructureWithDepth(Names,Path,long,lat)
%% INI

format long

    
    
    %% modify filename date
    try
        nc = netcdf.open(fullfile(Path,Names),'NC_WRITE');
        skip=0;
    catch
        Corrupted=Names;
        skip=1;
    end
    
    if skip==0
        %% Geospatiatal values
        geospatial_lat=netcdf.getAtt(nc,netcdf.getConstant('NC_GLOBAL'),'geospatial_lat_min');
        geospatial_lon=netcdf.getAtt(nc,netcdf.getConstant('NC_GLOBAL'),'geospatial_lon_min');
        
        
        
        
        
        %% list all the Variables
        ii=1;
        Bool=1;
        while  Bool==1
            try
                [varname, ~, ~, varatts] = netcdf.inqVar(nc,ii-1);
                VARNAME{ii}=varname;
                VARATTS{ii}=varatts;
                ii=ii+1;
                Bool=1;
            catch
                Bool=0;
            end
        end
        
        
        
        %% we grab the date dimension
        idxTIME= strcmpi(VARNAME,'TIME')==1;
        TimeVarName=VARNAME{idxTIME};
        varidTIME=netcdf.inqDimID(nc,TimeVarName);
        [~, dimlenTIME] = netcdf.inqDim(nc,varidTIME);
        
        
        if dimlenTIME >0
            VarIdTIME=netcdf.inqVarID(nc,TimeVarName);
            
            CreationDateStr=regexp( Names,'_C-(\d+)','tokens' );
            indexCreationDate=strfind(Names,char(CreationDateStr{1}));
            
            CreationDate=datestr(now+datenum(0,0,0,0,0,1),'yyyymmddTHHMMSS');%add one second in case the programm is to fast and add the same filename
            
            filenameNew=fullfile(Path,Names);
            filenameNew(length(Path)+indexCreationDate:length(Path)+indexCreationDate-1+length(CreationDate))=CreationDate;
            
        end
        
        %% Create a NEW netCDF file.
        [pathstr, name, ext, ~] = fileparts(filenameNew);
        ncid_NEW = netcdf.create(strcat(pathstr,filesep,name,ext),'NC_NOCLOBBER');
%         ncid_NEW =
%         netcdf.create(strcat(pathstr,filesep,name,ext),'NC_64BIT_OFFSET');
        
        %% Write Global Attributes
        [ ~, ~, natts ,~] = netcdf.inq(nc);
        for aa=0:natts-1
            gattname = netcdf.inqAttName(nc,netcdf.getConstant('NC_GLOBAL'),aa);
            gattval = netcdf.getAtt(nc,netcdf.getConstant('NC_GLOBAL'),gattname);
            netcdf.putAtt(ncid_NEW,netcdf.getConstant('NC_GLOBAL'),gattname, gattval);
        end
        
        %%  Creation of the DIMENSION LON LAT TIME DEPTH
        LAT_VARNAME='LATITUDE';
        LON_VARNAME='LONGITUDE';
        DEPTH_VARNAME='DEPTH';
        TIME_VARNAME='TIME';
        
        TIME_dimid = netcdf.defDim(ncid_NEW,char(TIME_VARNAME),dimlenTIME);
        
        try
            VarIdDEPTH=netcdf.inqVarID(nc,'depth');
            DepthExist=1;
            
        catch
            DepthExist=0;
            
        end
        varDepthName='depth';
        
        
        DEPTH_dimid = netcdf.defDim(ncid_NEW,char(DEPTH_VARNAME),1);
        LAT_dimid = netcdf.defDim(ncid_NEW,char(LAT_VARNAME),1);
        LON_dimid = netcdf.defDim(ncid_NEW,char(LON_VARNAME),1);
        
        
        
        %% create index vector 'ttt' for non TIME and TIME_QC, to
        %% be used in FOR loop
        idxTIME= strcmpi(VARNAME,TimeVarName)==1; %idx to remove from tt
        
        
        idxLAT= strcmpi(VARNAME,'latitude')==1; %idx to remove from tt
        idxLATqc= strcmpi(VARNAME,'latitude_quality_control')==1; %idx to remove from tt
        
        idxLON= strcmpi(VARNAME,'longitude')==1; %idx to remove from tt
        idxLONqc= strcmpi(VARNAME,'longitude_quality_control')==1; %idx to remove from tt
        
        idxDEPTH= strcmpi(VARNAME,'depth')==1; %idx to remove from tt
        
        
        tttt=1:length(VARNAME);
        ttt=tttt(setdiff(1:length(tttt),[tttt(idxTIME),tttt(idxLAT),...
            tttt(idxLATqc),tttt(idxLON),tttt(idxLONqc),tttt(idxDEPTH)]));
        
        
        
        %% Creation of the 'standard' VARIABLES
        TIME_id = netcdf.defVar(ncid_NEW,TIME_VARNAME,'double',TIME_dimid);
        
        DEPTH_id = netcdf.defVar(ncid_NEW,DEPTH_VARNAME,'double',DEPTH_dimid);
        
        LAT_id = netcdf.defVar(ncid_NEW,LAT_VARNAME,'double',LAT_dimid);
        LON_id = netcdf.defVar(ncid_NEW,LON_VARNAME,'double',LON_dimid);
        
        
        
        
        
        %% creation of the rest of variables
        for ii=ttt
            if strfind(char(VARNAME(ii)),'_quality_control')~=0
                VAR_ID_NEW = netcdf.defVar(ncid_NEW,VARNAME{ii},'byte',[LON_dimid,LAT_dimid,DEPTH_dimid,TIME_dimid]);
            else
                VAR_ID_NEW = netcdf.defVar(ncid_NEW,VARNAME{ii},'double',[LON_dimid,LAT_dimid,DEPTH_dimid,TIME_dimid]);
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
                char(strcat(TIME_VARNAME,[{' '}],DEPTH_VARNAME,[{' '}],LAT_VARNAME,[{' '}],LON_VARNAME)));
        end
        
        %% creation of Time attributes
        WhereIsTIME=tttt(idxTIME);
        for aa=0:VARATTS{WhereIsTIME}-1 %bug _FILLvalue
            attname = netcdf.inqAttName(nc,VarIdTIME,aa);
            attval = netcdf.getAtt(nc,VarIdTIME,attname);
            
            if isnumeric( attval)
                attval=double(attval);
            end
            
            netcdf.putAtt(ncid_NEW,TIME_id,attname,attval);
        end
        %                 netcdf.putAtt(ncid_NEW,TIME_id,'units',char(TimeOffset));
        
        
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
        
        %% creation of depth attributes
        
        if sum(strcmpi('depth',VARNAME)) == 0 %if depth does not already exist
            %depth
            netcdf.putAtt(ncid_NEW,DEPTH_id,'long_name','depth');
            netcdf.putAtt(ncid_NEW,DEPTH_id,'standard_name','depth below sea surface');
            netcdf.putAtt(ncid_NEW,DEPTH_id,'units','meters');
            netcdf.putAtt(ncid_NEW,DEPTH_id,'axis','Z');
            netcdf.putAtt(ncid_NEW,DEPTH_id,'positive','down');
            netcdf.putAtt(ncid_NEW,DEPTH_id,'valid_min','0');
            netcdf.putAtt(ncid_NEW,DEPTH_id,'valid_max','12000');
            netcdf.putAtt(ncid_NEW,DEPTH_id,'_FillValue','-99999.0');
            netcdf.putAtt(ncid_NEW,DEPTH_id,'reference_datum','geographical coordinates, WGS84 projection');
        else
            
            
            WhereIsDEPTH=tttt(idxDEPTH);
            DEPTHVarName=VARNAME{idxDEPTH};
            varidDEPTH=netcdf.inqVarID(nc,DEPTHVarName);
            for aa=0:VARATTS{WhereIsDEPTH}-1 %bug _FILLvalue
                attname = netcdf.inqAttName(nc,varidDEPTH,aa);
                attval = netcdf.getAtt(nc,varidDEPTH,attname);
                
                if isnumeric( attval)
                    attval=double(attval);
                end
                
                netcdf.putAtt(ncid_NEW,DEPTH_id,attname,attval);
            end
        end
        
        
        netcdf.endDef(ncid_NEW)
        
        %% write DimensionId data
        
        time=netcdf.getVar(nc,VarIdTIME);
        netcdf.putVar(ncid_NEW,TIME_id,time);
        
        netcdf.putVar(ncid_NEW,LAT_id,lat);
        
        netcdf.putVar(ncid_NEW,LON_id,long);
        
        if sum(strcmpi('depth',VARNAME)) == 0
            depth=0;
        else
            depth=netcdf.getVar(nc,VarIdDEPTH);
        end
        netcdf.putVar(ncid_NEW,DEPTH_id,depth);
        
        
        
        %% write standards variables
        for ii=ttt
            VAR_ID= netcdf.inqVarID(nc,char(VARNAME(ii)));
            if strfind(char(VARNAME(ii)),'_quality_control')~=0
                VAR=int8(netcdf.getVar(nc,VAR_ID));
                VAR(VAR==0)=1;
            else
                VAR=(netcdf.getVar(nc,VAR_ID));
                VAR(VAR==0)=1;
            end
            
            
            netcdf.putVar(ncid_NEW,VAR_ID_NEW_LIST{ii},[0,0,0,0],[1,1,1,dimlenTIME],VAR);%4 dimensions
            
        end
        
        
        netcdf.close(ncid_NEW);
        netcdf.close(nc);
        
        delete(fullfile(Path,Names))
    end
    [~, FilenameModified, ~, ~] = fileparts(filenameNew);
    FilenameModified=strcat(FilenameModified,ext);
    
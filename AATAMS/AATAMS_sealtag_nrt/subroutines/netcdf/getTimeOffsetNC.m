function [numOffset,strOffset,firstDate,LastDate]= getTimeOffsetNC(nc,allVarnames)
%% we grab the date dimension
idxTIME= strcmpi(allVarnames,'TIME')==1;
TimeVarName=allVarnames{idxTIME};
date_var_id=netcdf.inqVarID(nc,TimeVarName);

try
    date_dim_id=netcdf.inqDimID(nc,TimeVarName);
    [~, dimlen] = netcdf.inqDim(nc,date_dim_id);
catch
    %if TIME is not a dimension
    [~, dimlen] = netcdf.inqVar(nc,date_var_id);
end


if dimlen >0
    firstDate = netcdf.getVar(nc,date_var_id,0);
    if dimlen==1
        LastDate = netcdf.getVar(nc,date_var_id,0);
    else
        LastDate = netcdf.getVar(nc,date_var_id,dimlen-1);
    end
    
    %read time offset from nc
    strOffset=netcdf.getAtt(nc,date_var_id,'units');
    indexT_inStr=regexp(strOffset,'\d{4}-\d{2}-\d{2}T\d{2}','once','end');
    if ~isempty(strfind(strOffset,'days')) && isempty(indexT_inStr)
        numOffset=datenum(strOffset(length('days since '):length('days since ')+length('yyyy-mm-dd HH:MM:SS')),'yyyy-mm-dd HH:MM:SS');
        %days
        [Y_off, M_off, D_off, H_off, MN_off, S_off]=datevec(numOffset);
        firstDate=datenum([Y_off, M_off, double((D_off+firstDate)), H_off, MN_off, S_off]);
        LastDate=datenum([Y_off, M_off, double((D_off+LastDate)), H_off, MN_off, S_off]);
    elseif ~isempty(strfind(strOffset,'seconds')) && isempty(indexT_inStr)
        numOffset=datenum(strOffset(length('seconds since '):length('seconds since ')+length('yyyy-mm-dd HH:MM:SS')),'yyyy-mm-dd HH:MM:SS');
        %seconds
        [Y_off, M_off, D_off, H_off, MN_off, S_off]=datevec(numOffset);
        firstDate=datenum([Y_off, M_off, D_off, H_off, MN_off, double((S_off+firstDate))]);
        LastDate=datenum([Y_off, M_off, D_off, H_off, MN_off, double(S_off+LastDate)]);
    elseif ~isempty(strfind(strOffset,'days')) && ~isempty(indexT_inStr)
        numOffset=datenum(strOffset(length('days since '):length('days since ')+length('yyyy-mm-dd HH:MM:SS')),'yyyy-mm-ddTHH:MM:SS');
        % change time attribute because the letter T should not be present.No CF
        % and bugs some softwares
        strOffset(indexT_inStr-2)=' ';
        %days
        [Y_off, M_off, D_off, H_off, MN_off, S_off]=datevec(numOffset);
        firstDate=datenum([Y_off, M_off, double((D_off+firstDate)), H_off, MN_off, S_off]);
        LastDate=datenum([Y_off, M_off, double((D_off+LastDate)), H_off, MN_off, S_off]);
    elseif ~isempty(strfind(strOffset,'seconds')) && ~isempty(indexT_inStr)
        numOffset=datenum(strOffset(length('seconds since '):length('seconds since ')+length('yyyy-mm-dd HH:MM:SS')),'yyyy-mm-ddTHH:MM:SS');
        % change time attribute because the letter T should not be present.No CF
        % and bugs some softwares
        strOffset(indexT_inStr-2)=' ';
        %seconds
        [Y_off, M_off, D_off, H_off, MN_off, S_off]=datevec(numOffset);
        firstDate=datenum([Y_off, M_off, D_off, H_off, MN_off, double((S_off+firstDate))]);
        LastDate=datenum([Y_off, M_off, D_off, H_off, MN_off, double(S_off+LastDate)]);
    end
    
elseif dimlen ==0
    disp('File is corrupted, or variable Time is badly spelled')
    numOffset=[];
    strOffset=[];
    firstDate=[];
    LastDate=[];
end

end

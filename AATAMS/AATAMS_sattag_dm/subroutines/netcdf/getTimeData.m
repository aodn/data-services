function [DATA]= getTimeData(nc,allVarnames)
%% we grab the date dimension
idxTIME     = strcmpi(allVarnames,'TIME')==1;
TimeVarName = allVarnames{idxTIME};

date_var_id = netcdf.inqVarID(nc,TimeVarName);

try
    date_dim_id = netcdf.inqDimID(nc,TimeVarName);
    [~, dimlen] = netcdf.inqDim(nc,date_dim_id);
catch
    %if TIME is not a dimension
    [~, dimlen] = netcdf.inqVar(nc,date_var_id);
end



DATA = [];
if dimlen >0
    preDATA      = netcdf.getVar(nc,date_var_id);
    %read time offset from nc
    strOffset    = netcdf.getAtt(nc,date_var_id,'units');
    indexT_inStr = regexp(strOffset,'\d{4}-\d{2}-\d{2}T\d{2}','once','end');
    
    if ~isempty(strfind(strOffset,'days')) && isempty(indexT_inStr)
        numOffset                                   = datenum(strOffset(length('days since '):length('days since ')+length('yyyy-mm-dd HH:MM:SS')),'yyyy-mm-dd HH:MM:SS');
        %days
        [Y_off, M_off, D_off, H_off, MN_off, S_off] = datevec(numOffset);
        NumDay                                      = double(D_off+preDATA);
        preDATA                                     = datenum(Y_off, M_off, NumDay, H_off, MN_off, S_off);
        DATA                                        = [DATA;preDATA];

    elseif ~isempty(strfind(strOffset,'seconds')) && isempty(indexT_inStr)
        numOffset                                   = datenum(strOffset(length('seconds since '):length('seconds since ')+length('yyyy-mm-dd HH:MM:SS')),'yyyy-mm-dd HH:MM:SS');
        %seconds
        [Y_off, M_off, D_off, H_off, MN_off, S_off] = datevec(numOffset);
        NumSec                                      = double(S_off+preDATA);
        preDATA                                     = datenum(Y_off, M_off, D_off, H_off, MN_off, NumSec);
        DATA                                        = [DATA;preDATA];
        
    elseif ~isempty(strfind(strOffset,'days')) && ~isempty(indexT_inStr)
        numOffset                                   = datenum(strOffset(length('days since '):length('days since ')+length('yyyy-mm-dd HH:MM:SS')),'yyyy-mm-ddTHH:MM:SS');
        %days
        [Y_off, M_off, D_off, H_off, MN_off, S_off] = datevec(numOffset);
        NumDay                                      = double(D_off+preDATA);
        preDATA                                     = datenum(Y_off, M_off, NumDay, H_off, MN_off, S_off);
        DATA                                        = [DATA;preDATA];

    elseif ~isempty(strfind(strOffset,'seconds')) && ~isempty(indexT_inStr)
        numOffset                                   = datenum(strOffset(length('seconds since '):length('seconds since ')+length('yyyy-mm-dd HH:MM:SS')),'yyyy-mm-ddTHH:MM:SS');
        %seconds
        [Y_off, M_off, D_off, H_off, MN_off, S_off] = datevec(numOffset);
        NumSec                                      = double(S_off+preDATA);
        preDATA                                     = datenum(Y_off, M_off, D_off, H_off, MN_off, NumSec);
        DATA                                        = [DATA;preDATA];
    end
    
elseif dimlen == 0
    frpintf('File is corrupted, or variable Time is badly spelled\n')
    DATA = [];
end

end
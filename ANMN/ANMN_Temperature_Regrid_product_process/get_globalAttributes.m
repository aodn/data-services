function [GlobAtt] = get_globalAttributes(param1,param2,varargin)
% This function extract global attribute(s) from a netcdf file.
%
% param1 :      source: either 'NC-id' if source file already open or 'file' if
%               new file
% param2 :      param1 value
% varargin{1} : attribute name  'all' for full list  
%
% Example : gatt = get_globalAttributes('file','out.nc','all')
%
switch param1
    case 'NC_id'

        [ndims,nvars,ngatts,unlimdimid] = netcdf.inq(param2);
         
        if strcmp(varargin,'all')
            
            GlobAtt = cell(ngatts,2);

            for  gatt = 1:ngatts

                attname = netcdf.inqAttName(param2,netcdf.getConstant('NC_GLOBAL'),gatt-1);
                GlobAtt{gatt,1} = attname;
                GlobAtt{gatt,2} = netcdf.getAtt(param2,netcdf.getConstant('NC_GLOBAL'),attname);

            end
        else 
                GlobAtt = netcdf.getAtt(param2,netcdf.getConstant('NC_GLOBAL'),varargin{1});
        end
        
    case 'file'
        
        ncid = netcdf.open(param2);
       [ndims,nvars,ngatts,unlimdimid] = netcdf.inq(ncid);
      
        if strcmp(varargin{1},'all')
             strcmp(varargin{1},'all')
             
            GlobAtt = cell(ngatts,2);

            for  gatt = 1:ngatts

                attname = netcdf.inqAttName(ncid,netcdf.getConstant('NC_GLOBAL'),gatt-1);
                GlobAtt{gatt,1} = attname;
                GlobAtt{gatt,2} = netcdf.getAtt(ncid,netcdf.getConstant('NC_GLOBAL'),attname);

            end
        else 
                GlobAtt = netcdf.getAtt(ncid,netcdf.getConstant('NC_GLOBAL'),varargin{1});
        end
end

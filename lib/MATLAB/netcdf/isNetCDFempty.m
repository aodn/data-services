function bool = isNetCDFempty (filename)
% TestFileSize checks that a file is not empty
%
% Inputs:
%   filename    -filename to test
%
% Outputs:
%   bool        -boolean , 1 if file is empty, otherwise 0
%
% Author: Laurent Besnard, IMOS/eMII
% email: laurent.besnard@utas.edu.au
% Website: http://imos.org.au/  http://froggyscripts.blogspot.com
% Oct 2012; Last revision: 30-Oct-2012
%% Copyright 2012 IMOS
% The script is distributed under the terms of the GNU General Public License




nc = netcdf.open(filename,'NC_WRITE');
[dimname, dimlen] = netcdf.inqDim(nc,0);

if strcmp(dimname,'time') && dimlen==0
    bool=1;
elseif strcmp(dimname,'time') && dimlen>1
    bool=0;
else bool=0;
end

netcdf.close(nc);
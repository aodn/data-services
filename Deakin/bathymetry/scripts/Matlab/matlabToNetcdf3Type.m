function [ netcdfType ] = matlabToNetcdf3Type( matlabType )
%MATLABTONETCDF3TYPE gives the equivalent NetCDF3 type to the given Matlab
%type.
%
% This function translates any Matlab data type into the equivalent
% NetCDF 3.6.0 C data type. 
% See http://www.unidata.ucar.edu/software/netcdf/docs/netcdf-c/Variable-Types.html#Variable-Types
% and http://www.unidata.ucar.edu/software/netcdf/old_docs/docs_3_6_2/netcdf/netCDF-external-data-types.html
% for more information.
%
% Inputs:
%   matlabType  - a Matlab data type expressed in a String. Values can be 'char', 'int8',
%               'int16', 'int32', 'single' or 'double'
%
% Outputs:
%   netcdfType  - a netCDF 3.6.0 C data type expressed in a String.
%
% Author: Guillaume Galibert <guillaume.galibert@utas.edu.au>
%

%
% Copyright (c) 2009, eMarine Information Infrastructure (eMII) and Integrated 
% Marine Observing System (IMOS).
% All rights reserved.
% 
% Redistribution and use in source and binary forms, with or without 
% modification, are permitted provided that the following conditions are met:
% 
%     * Redistributions of source code must retain the above copyright notice, 
%       this list of conditions and the following disclaimer.
%     * Redistributions in binary form must reproduce the above copyright 
%       notice, this list of conditions and the following disclaimer in the 
%       documentation and/or other materials provided with the distribution.
%     * Neither the name of the eMII/IMOS nor the names of its contributors 
%       may be used to endorse or promote products derived from this software 
%       without specific prior written permission.
% 
% THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" 
% AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE 
% IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE 
% ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE 
% LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR 
% CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF 
% SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS 
% INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN 
% CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) 
% ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE 
% POSSIBILITY OF SUCH DAMAGE.
%
error(nargchk(1,1,nargin));

if ~ischar(matlabType),        error('matlabType must be a string');  end

% see http://www.unidata.ucar.edu/software/netcdf/docs/netcdf-c/Variable-Types.html#Variable-Types
matlabPossibleValues = {'char', 'int8', 'int16', 'int32', 'single', 'double'};
if ~any(strcmpi(matlabType, matlabPossibleValues))
    error(['matlabType must be any of these values : ' cellCons(matlabPossibleValues, ', ') '.']);
end

% see http://www.unidata.ucar.edu/software/netcdf/old_docs/docs_3_6_2/netcdf/netCDF-external-data-types.html
switch matlabType
    case 'char',    netcdfType = 'char';
    case 'int8',    netcdfType = 'byte';
    case 'int16',   netcdfType = 'short';
    case 'int32',   netcdfType = 'int';
    case 'single',  netcdfType = 'float';
    case 'double',  netcdfType = 'double';
end

end


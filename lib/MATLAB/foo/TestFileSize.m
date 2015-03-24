function bool = TestFileSize (filename)
% TestFileSize checks that a file is not empty and delete otherwise
%
% Inputs:
%   filename    -filename to test
%
% Outputs:
%   bool        -boolean , 0 if file is empty, otherwise 1
%
% Author: Laurent Besnard <laurent.besnard@utas,edu,au>
%
%
% Copyright (c) 2010, eMarine Information Infrastructure (eMII) and Integrated
% Marine Observing System (IMOS).
% All rights reserved.


s=dir(filename);
if  s.bytes==0
    delete(filename);
    bool=0;
else
    bool=1;
end

function [header, data] = csvload(file)
% CSVLOAD Load data from an ASCII file containing a text header.
%
% Inputs:
%   file        - filename of the ASCII file to process.
%
% Outputs:
%   header        - cell array containing the header of the file.
%   data          - cell array containing the data.
%
% Author: Laurent Besnard <laurent.besnard@utas,edu,au>
%
%
% Copyright (c) 2010, eMarine Information Infrastructure (eMII) and Integrated
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

% check number and type of arguments
if nargin < 1
    error('Function requires one input argument');
elseif ~isstr(file)
    error('Input must be a string representing a filename');
end


% Open the file.  If this returns a -1, we did not open the file
% successfully.
fid = fopen(file);
if fid==-1
    error('File not found or permission denied');
end


% Initialize loop variables
% We store the number of lines in the header, and the maximum
% length of any one line in the header.  These are used later
% in assigning the 'header' output variable.
no_lines = 0;
max_line = 0;


% We also store the number of columns in the data we read.  This
% way we can compute the size of the output based on the number
% of columns and the total number of data points.
ncols = 0;


% Finally, we initialize the data to [].
data = [];

% Start processing.
line = fgetl(fid);
while isempty(regexp(line,'year,month,day,hour'))
    line = fgetl(fid);
end
% while ~isempty(line)
%     line = fgetl(fid);
% end
NumberOfColumns=length(strfind(line,','))+1;
if NumberOfColumns==18
    format= '%n %n %n %n %n %f %f %f %f %f %f %f %f %f %f %s %s %n';
    ClusterTagExist=1;
elseif NumberOfColumns==17
    format= '%n %n %n %n %n %f %f %f %f %f %f %f %f %f %f %s %s';
    ClusterTagExist=0;
else
    disp('CSV track file has a none commun number of columns') 
end

if ~ischar(line)
    disp('Warning: file contains no header and no data')
end;
[myData] = textscan(line,format, 'Delimiter', ',');


while isempty(myData{1})
    no_lines = no_lines+1;
    max_line = max([max_line, length(line)]);
    % Create unique variable to hold this line of text information.
    % Store the last-read line in this variable.
    eval(['line', num2str(no_lines), '=line;']);
    line = fgetl(fid);
    if isempty(line)
        no_lines = no_lines+1;
        max_line = max([max_line, length(line)]);
        
        eval(['line', num2str(no_lines), '=line;']);
        line = fgetl(fid);
        line = fgetl(fid);
    end;
    
    myData = textscan(line, format,'CollectOutput', 1,'treatAsEmpty', {'NA', 'na'}, 'Delimiter', ',');
    
end
data{1,1}(1,:) = myData{1,1};
data{1,2}(1,:) = myData{1,2};
if ClusterTagExist
    data{1,3}(1,:) =myData{1,3};
end

ncols=NumberOfColumns;

%% read the rest of the data.
k=2;
while ~isempty(line)
    line = fgetl(fid);
    if line==-1
        break
    end;
    myData = textscan(line, format,'CollectOutput', 1,'treatAsEmpty', {'NA', 'na'}, 'Delimiter', ',');
    data{1,1}(k,:) = myData{1,1};
    data{1,2}(k,:) = myData{1,2};
    if ClusterTagExist
        data{1,3}(k,:) = myData{1,3};
    end
    k=k+1;
end
fclose(fid);



% Create header output from line information. The number of lines
% and the maximum line length are stored explicitly, and each
% line is stored in a unique variable using the 'eval' statement
% within the loop. Note that, if we knew a priori that the
% headers were 10 lines or less, we could use the STR2MAT
% function and save some work. First, initialize the header to an
% array of spaces.
header = setstr(' '*ones(no_lines, max_line));
for i = 1:no_lines
    varname = ['line' num2str(i)];
    % Note that we only assign this line variable to a subset of
    % this row of the header array.  We thus ensure that the matrix
    % sizes in the assignment are equal. We also consider blank
    % header lines using the following IF statement.
    if eval(['length(' varname ')~=0'])
        eval(['header(i, 1:length(' varname ')) = ' varname ';']);
    end
end % for


% Resize output data, based on the number of columns (as returned
% from the sscanf of the first line of data) and the total number
% of data elements. Since the data was read in row-wise, and
% MATLAB stores data in columnwise format, we have to reverse the
% size arguments and then transpose the data.  If we read in
% irregularly spaced data, then the division we are about to do
% will not work. Therefore, we will trap the error with an EVAL
% call; if the reshape fails, we will just return the data as is.
eval('data = reshape(data, ncols, length(data)/ncols)'';', '');

function [b,m,n]=uunique(A)
% UUNIQUE set unique and sort.
% B = UNIQUE(A) for the array A returns the same values as in A but
% with no repetitions. B will also be sorted. A can be a cell array of
% strings.
%
% UUNIQUE(A,'rows') for the matrix A returns the unique rows of A.
%
% See also unique,unique_no_sort
% Author: Laurent Besnard, IMOS/eMII
% email: laurent.besnard@utas.edu.au
% Website: http://imos.org.au/  http://froggyscripts.blogspot.com
% Aug 2012; Last revision: 09-Aug-2012

[~, m1,n1]=unique(A,'first');
b=A(sort(m1));
m=sort(m1);
n=sort(n1);
end
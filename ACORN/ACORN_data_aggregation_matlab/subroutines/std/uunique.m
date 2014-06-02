function [b,m,n]=uunique(A)
[~, m1,n1]=unique(A,'first');
b=A(sort(m1));
m=sort(m1);
n=sort(n1);
end
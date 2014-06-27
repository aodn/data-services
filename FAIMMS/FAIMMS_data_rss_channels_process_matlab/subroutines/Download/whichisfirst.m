function indexfirst=whichisfirst(fromDate_bis)

T=size(fromDate_bis,2);

WER=[];
for u=1:T
    WER(u) = datenum(fromDate_bis(u),'yyyy-mm-ddTHH:MM:SS');
end

[~,IX]=sort(WER);

indexfirst=IX(1);
end
function indexlast = whichislast(thruDate_bis)
T=size(thruDate_bis,2);

WER=[];
bool=0;
for u=1:T
    if strcmpi(thruDate_bis(u),'On Going')
        indexlast=u;
        bool=1;
    else
        WER(u) = datenum(thruDate_bis(u),'yyyy-mm-ddTHH:MM:SS');
    end
    
end

if ~bool==1
    [~,IX]=sort(WER);
    indexlast=IX(end);
end

end
function plotddots(thedat,dtime,ddepth,miv,mav)
%plot colour coded 3D points
     delete(gca);
     set(gcf,'PaperUnits','inches','PaperPosition',[0 0 25 10]);
        map=colormap;
        if nargin<4
        miv=min(thedat);
        mav=max(thedat);
        end
 %       
        clrstep = (mav-miv)/size(map,1) ;
        hold on
        for nc=1:size(map,1)
            iv = find(thedat>miv+(nc-1)*clrstep & thedat<=miv+nc*clrstep) ;
            plot3(dtime(iv),ddepth(iv),thedat(iv),'.','color',map(nc,:),'markerfacecolor',map(nc,:));
        end
        % fix colorbar
        h=colorbar;
        set(h,'ylim',[1 length(map)]);
        yal=linspace(1,length(map),10);
        set(h,'ytick',yal);
        % Create the yticklabels
        ytl=linspace(miv,mav,10);
        s=char(10,4);
        for i=1:10
            if min(abs(ytl)) >= 0.001
                B=sprintf('%-4.3f',ytl(i));
            else
                B=sprintf('%-3.1E',ytl(i));
            end
            s(i,1:length(B))=B;
        end
        set(h,'yticklabel',s);
        grid on
        view(2);
        shg
%
 %       %plot sea-bed
  %      a=axis;
   %     patch([xdata',xdata(length(xdata)),xdata(1),xdata(1)],[data(:,sensor_lookup.i_water_depth)',a(4),a(4),data(1,sensor_lookup.i_water_depth)],[.5,.5,.5])
        axis([min(dtime) max(dtime) 0 max(ddepth)]);
        axis ij;
        datetick('x','dd/mm','keeplimits');
    %    xlabel(xlabtxt)
    %    ylabel('depth m')
    %    title([handles.InputFileName(1:26),': ',handles.ftitletxt])
%        axis tight
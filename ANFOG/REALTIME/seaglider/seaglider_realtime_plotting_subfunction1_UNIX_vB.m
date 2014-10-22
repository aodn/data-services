function [status] = seaglider_realtime_plotting_subfunction1_UNIX_vB(fileinput,deployment)
%this files reads either config.txt or configPLOT.txt file: set parameter range for plotting
%purposes. 
%%OUTPUT DIRECTORY
outputdir = readConfig('output_dir');
plottingdir = readConfig('plotting_dir');
%Data Fabric public directory
dfpublicdir  = readConfig('dfpublic_dir');
%
ncinfo = dir(fullfile(fileinput,deployment,'IMOS_ANFOG_*.nc'));  %struct of all .nc filenames in directory
%
ncastfiles = size(ncinfo,1); %count no of files available for processing
%
if (ncastfiles == 0);
    status = 1;
else
    status = 2;
%Create varname bvar and bvar_quality_control and initialize to [];
	varlist = {'TIME','LATITUDE','LONGITUDE','DEPTH','TEMP','CDOM','DOXY','FLU2','PSAL','VBSC','CNDC'};
	QCvarlist = strcat(varlist, '_quality_control');
	bvarlist = strcat('b', varlist);
	bQCvarlist = strcat(bvarlist,'_quality_control');
	varlist_all = [varlist, QCvarlist];
	bvarlist_all = [bvarlist, bQCvarlist];
%
for nvar = 1 : length(bvarlist_all)
    nm = genvarname(cell2mat(bvarlist_all(nvar)));
    eval([nm '= [];']);
end
%
%
%OPEN ALL NETCDF FILES OF A PARTICULAR DEPLOYMENT
for i=1:ncastfiles
    fclose('all');
    fname = strcat(fullfile(fileinput,deployment,ncinfo(i).name));
    nc = netcdf.open(fname,'NC_NOWRITE');
    for nvar = 1:length(varlist_all)
        nm2 = genvarname(cell2mat(varlist_all(nvar)));
        eval(['temp_varid = netcdf.inqVarID(nc,''' cell2mat(varlist_all(nvar)) ''');']);
        eval('temp = netcdf.getVar(nc,temp_varid);');
        eval([ nm2 '= temp(:);']);
        nm = genvarname(cell2mat(bvarlist_all(nvar)));
        eval([nm '= [' nm ';' nm2 '];'])  ;      
    end
%
    divetemp = textscan(netcdf.getAtt(nc,netcdf.getConstant('GLOBAL'),'title'),'%s','delimiter',' ');
    nbdive(i,1) = str2num(divetemp{1}{7});
    timetemp = netcdf.getAtt(nc,netcdf.getConstant('GLOBAL'),'time_coverage_end');
    nbdive(i,2) = datenum(timetemp,'yyyy-mm-ddTHH:MM:SS')-datenum('01-01-1950 00:00:00');
%
    netcdf.close(nc);
%
end
%
%
% %PLOT COLOUR TRANSECTS FOR EACH TYPE OF DATA
var2plot = cell(1,length(varlist(5:9)));
[var2plot{1:end}] = bvarlist{5:9} ; %'TEMP','CDOM','DOXY','FLU2','PSAL' %,'VBSC','CNDC'
for nvar = 1:length(var2plot)
% GET YAXIS MIN AND MAX VALUES
    dmin = get_param4var(var2plot{nvar},'Yaxismin',deployment); 
    dmax = get_param4var(var2plot{nvar},'Yaxismax',deployment); 
    %CREATE FIGURE
	figure(nvar);
	bvar = genvarname(var2plot{nvar});
	bvar_qc = genvarname(strcat(var2plot{nvar},'_quality_control'));
	eval(['ok = find(' bvar_qc '== 1);']);
	if(~isempty(ok) && length(ok)>10);
		zz = ceil(length(ok)/200000);
		eval(['plotddots(' bvar '(ok(1:zz:end)),bTIME(ok(1:zz:end)),bDEPTH(ok(1:zz:end)),dmin,dmax) ;']);
	titre = get_param4var(var2plot{nvar},'ftitle',deployment); 
	title(titre,'FontSize',20);
	ylabel('depth (m)','FontSize',20);
%	
	stepdive = floor(max(nbdive(:,1))/5);
    strlegend0 = strcat('Dive-',num2str(nbdive(1,1)));
	strlegend1 = strcat('Dive-',num2str(nbdive(1+stepdive,1)));
	strlegend2 = strcat('Dive-',num2str(nbdive(1+2*stepdive,1)));
	strlegend3 = strcat('Dive-',num2str(nbdive(1+3*stepdive,1)));
	strlegend4 = strcat('Dive-',num2str(nbdive(1+4*stepdive,1)));
	strlegend5 = strcat('Dive-',num2str(max(nbdive(:,1))));
%
	if (max(bDEPTH(ok)) < 200);
		 maxbdepth = -2;
		elseif (max(bDEPTH(ok)) > 200 && max(bDEPTH(ok)) < 400);
		 maxbdepth = -4;
		elseif (max(bDEPTH(ok)) > 400 && max(bDEPTH(ok)) < 600);
		 maxbdepth = -4;
		elseif (max(bDEPTH(ok)) > 600 && max(bDEPTH(ok)) < 800);
		 maxbdepth = -6;
		elseif (max(bDEPTH(ok)) > 800 && max(bDEPTH(ok)) < 1000);
		 maxbdepth = -8;
		elseif (max(bDEPTH(ok)) > 1000 );
		 maxbdepth = -10;
    end    
    text(min(bTIME(ok)),maxbdepth -4,strlegend0,'HorizontalAlignment','Center');
%	text(min(bTIME(ok)),maxbdepth+2,'Dive-1','HorizontalAlignment','Center');
	text(nbdive(1+stepdive,2),maxbdepth-2,strlegend1,'HorizontalAlignment','Center');
	text(nbdive(1+2*stepdive,2),maxbdepth-4,strlegend2,'HorizontalAlignment','Center');
	text(nbdive(1+3*stepdive,2),maxbdepth-4,strlegend3,'HorizontalAlignment','Center');
	text(nbdive(1+4*stepdive,2),maxbdepth-4,strlegend4,'HorizontalAlignment','Center');
	if (max(bTIME(ok)) > nbdive(end-10,2));
		text(max(bTIME(ok)),maxbdepth,strlegend5,'HorizontalAlignment','Center');
	end
	suffix = get_param4var(var2plot{nvar},'suffix',deployment);  
	fileoutput = fullfile(outputdir,plottingdir,deployment,strcat(deployment,suffix));
	print (nvar,'-djpeg',fileoutput);
%	
	filejpeg1 = fullfile(outputdir,plottingdir,deployment,strcat(deployment,suffix));
	filejpeg2 = fullfile(dfpublicdir,deployment,strcat(deployment,suffix));
	if exist( filejpeg2,'file');%get rid of existing file  
        delete(filejpeg2);
    end               
	copyfile(filejpeg1,filejpeg2);
%
	close(nvar);
	end
end
% shg
end

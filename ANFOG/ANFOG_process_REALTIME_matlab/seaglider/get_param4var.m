function [val] = get_param4var(varname,param,deploy)
%DEFINITION OF THE MIN AND MAX TOBE USED FOR PLOTTING FOR EACH DEPLOYMENT
%The parameter values should be set in the configPLOT.txt file
config = readConfigPlot;
lg = find(strcmp(config.deployid,deploy)==1); %find name of current deployment
%Standard Param value-pairs:
        doxymax =5;
        doxymin =2;
%        vbscmax =0.001;
%        vbscmin =0;
%        cndcmax =10;
%        cndcmin =0;
        flu2max =2;
        flu2min =0;
        psalmin =34;
        psalmax =37;
        cdommax =2;
        cdommin =0;
        tempmax =26;
        tempmin =5;
% 
% if standard =FALSE assign customised value-pairs    
if strcmp(config.standard(lg),'FALSE'),      
	if ~isempty(config.vp1{lg}), eval([config.vp1{lg,1} '=config.vp1{lg,2};']),end
	if ~isempty(config.vp2{lg}), eval([config.vp2{lg,1} '=config.vp2{lg,2};']),end
	if ~isempty(config.vp3{lg}), eval([config.vp3{lg,1} '=config.vp3{lg,2};']),end
	if ~isempty(config.vp4{lg}), eval([config.vp4{lg,1} '=config.vp4{lg,2};']),end
	if ~isempty(config.vp5{lg}), eval([config.vp5{lg,1} '=config.vp5{lg,2};']),end
end
%
switch varname
	case 'bDOXY'
%		if strcmp(param,'var') ==1 
%			val = 'bDOXY';
        switch param
            case 'QC'
                val = 'bDOXY_quality_control';
            case 'Yaxismin'
                val =  doxymin;
            case 'Yaxismax'
                val = doxymax;
            case 'ftitle'
                val = 'Oxygen Concentration (ml/L)';
            case 'suffix'
			val = '_DOXY.jpg';
		end
	case 'bTEMP'
%		if strcmp(param,'var') ==1
%			val = 'bTEMP';
        switch param
            case 'QC'
            	val = 'bTEMP_quality_control';
            case 'Yaxismin' 
                val =  tempmin;
            case 'Yaxismax'
                val = tempmax;
            case 'ftitle'
                val = 'Temperature (Deg C)';
            case 'suffix'
                val = '_temperature.jpg';
        end
	case 'bCDOM'	
%		if strcmp(param,'var')  ==1
%			val = 'bCDOM';
		switch param
            case 'QC'
                val = 'bCDOM_quality_control';
            case 'Yaxismin' 
                val =  cdommin;
            case 'Yaxismax'
                val = cdommax;
            case 'ftitle'
                val = 'CDOM (ppb)';
            case 'suffix'
                val = '_CDOM.jpg';
		end
	case 'bPSAL'	
%		if strcmp(param,'var')  ==1
%			val = 'bPSAL';
        switch param
            case 'QC'
                val = 'bPSAL_quality_control';
            case 'Yaxismin' 
                val =  psalmin;
            case 'Yaxismax'
                val = psalmax;
            case 'ftitle'
                val = 'Salinity (PSU)';
            case 'suffix'
                val = '_salinity.jpg';
        end
	case 'bFLU2'	
%		if strcmp(param,'var')  ==1
%			val = 'bFLU2';
		switch param
            case 'QC'
                val = 'bFLU2_quality_control';
            case 'Yaxismin'
                val =  flu2min;
            case 'Yaxismax'
                val = flu2max;
            case 'ftitle'
                val = 'Chlorophyll-a (um/L)';
            case 'suffix'
                val = '_chlorophyll.jpg';
		end

end



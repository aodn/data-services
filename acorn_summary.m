function acorn_summary(radarTech, isQC, site, dmStart, dmEnd)
%Run the main program for each WERA/CODAR radar site
%
% example of function call:
%
% 	acorn_summary('WERA', true, {'CBG', 'SAG', 'ROT', 'COF'}, '20120626T073000', '20120626T083000')
%
% runs QC'd hourly averaged product generation for all WERA sites in delayed mode from 20120626T073000 to 20120626T083000.
%
% 	acorn_summary('CODAR', false, {'BONC'}, '', '')
%
% runs non QC'd hourly averaged product generation for BONC CODAR site from the last generated product to the latest available radials.

%               WERA sites
% Capricorn bunker Group (CBG) Radar Site
% South Australia Gulf   (SAG) Radar Site
% Rottnest Shelf         (ROT) Radar Site
% Coffs Harbour          (COF) Radar Site

%               CODAR sites
% Turquoise Coast       (TURQ) Radar Site
% Bonney Coast          (BONC) Radar Site

%Creation of a log file
global delayedModeStart
global delayedModeEnd
global delayedMode
global datadir
global logfile

radarTech = upper(radarTech);
if isQC
    suffixQC = 'QC';
else
    suffixQC = 'nonQC';
end

delayedModeStart    = dmStart;
delayedModeEnd      = dmEnd;

delayedMode = false;
if ~isempty(delayedModeStart) && ~isempty(delayedModeEnd)
    delayedMode = true;
end

datadir = readConfig(['data' radarTech '.path']);
logfile = fullfile(datadir, readConfig(['logfile' radarTech suffixQC '.name']));

if isempty(site), return; end
lenSite = length(site);

for i=1:lenSite
    try
    		funcName = ['radar_' radarTech '_main'];
        hFunc = str2func(funcName);
        if delayedMode
            processingText = ['Processing ' suffixQC ' ' radarTech ' data for site ' site{i} ...
                ' in delayed mode from ' delayedModeStart ' to ' delayedModeEnd ' :'];
        else
            processingText = ['Processing ' suffixQC ' ' radarTech ' data for site ' site{i} ' :'];
        end
        disp(processingText);
        hFunc(site{i}, isQC);
        disp(' ');
    catch e
				titleErrorFormat = ['%s PROBLEM in ' funcName ' to PROCESS DATA FOR THE RADAR SITE %s :\r\n'];
				messageErrorFormat = '%s\r\n';
				stackErrorFormat = '\t%s\t(%s: %i)\r\n';
        clockStr = datestr(clock);

				% print error to logfile and console
        fid_w = fopen(logfile, 'a');        
        fprintf(fid_w, titleErrorFormat, clockStr, site{i});
        fprintf(titleErrorFormat, clockStr, site{i});
        fprintf(fid_w, messageErrorFormat, e.message);
        fprintf(messageErrorFormat, e.message);
        s = e.stack;
        for k=1:length(s)
            fprintf(fid_w, stackErrorFormat, s(k).name, s(k).file, s(k).line);
            fprintf(stackErrorFormat, s(k).name, s(k).file, s(k).line);
        end
        fclose(fid_w);
        disp(' ');
    end
end

end

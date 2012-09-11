function acorn_summary(radarTech, isQC)
%Run the main program for each WERA/CODAR radar site
%
%example of function call
%acorn_summary('WERA', false)

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

delayedModeStart    = readConfig('delayedModeStart');
delayedModeEnd      = readConfig('delayedModeEnd');

delayedMode = false;
if ~isempty(delayedModeStart) && ~isempty(delayedModeEnd)
    delayedMode = true;
end

datadir = readConfig(['data' radarTech '.path']);
logfile = fullfile(datadir, readConfig(['logfile' radarTech suffixQC '.name']));

site = textscan(readConfig([radarTech '.site']), '%s');
site = site{1};
lenSite = length(site);

for i=1:lenSite
    try
        hFunc = str2func(['radar_' radarTech '_main']);
        if delayedMode
            processingText = ['Processing ' suffixQC ' ' radarTech ' data for site ' site{i} ...
                ' in delayed mode after ' delayedModeStart ' until ' delayedModeEnd ' :'];
        else
            processingText = ['Processing ' suffixQC ' ' radarTech ' data for site ' site{i} ' :'];
        end
        disp(' ');
        disp(processingText);
        hFunc(site{i}, isQC);
    catch e
        fid_w = fopen(logfile, 'a');
        fprintf(fid_w, '%s PROBLEM to PROCESS DATA FOR THE RADAR SITE %s :\r\n', datestr(clock), site{i});
        fprintf(fid_w, '%s\r\n', e.message);
        s = e.stack;
        for k=1:length(s)
            fprintf(fid_w, '\t%s\t(%s: %i)\r\n', s(k).name, s(k).file, s(k).line);
        end
        fclose(fid_w);
    end
end

end
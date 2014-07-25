function NL_1Hz_PSD_with_plots4eMII(Cal_file, CNL, HS, start_times_file_name, number_days, Rec_period)
% NL_1Hz_PSD_with_plots4eMII is a modified version 
% of NL_PSD. 
% Similarly to NL_PSD, It calculates PSD of sea noise data for each 
% recording section and stores in MAT-files grouping the resulting PSD 
% by the number of recording days (number_days). 
% The absolute start times of each time window for PSD calculation are 
% also stored.
% start_times_file_name is the MAT-file name containing start time data
% for all data files in the current directory, calculated after running
% NL_read_all_start_times.m
% NL_1Hz_PSD_with_plots4eMII also creates images of the waveform and 
% spectrogram of each recording and a MAT-file with a long-term average 
% spectrogram calculated on a logarithmic frequency grid to display 
% at the eMII data portal. All images and the MAT file are stored 
% in subfolder \images

tic;

narginchk(0,6);

w = pwd;

try
    if isempty(Cal_file)
        [Cal_file_name, Cal_file_path] = uigetfile('*.DAT', 'Load calibration data file');
        Cal_file = fullfile(Cal_file_name, Cal_file_path);
    end
    
    [~, Cal_sig, Fsamp, ~] = NL_load_logger_data_new(Cal_file);
    
    [Cal_spec, Cal_freq] = pwelch(Cal_sig, Fsamp, 0, Fsamp, Fsamp);
    clear Cal_sig
    
    if isempty(CNL)
        disp(' ')
        CNL = input('Specify calibration noise level (dB re V^2/Hz): ');
        if isempty(CNL)
            CNL = -110; % for IMOS
        end
    end
    Cal_spec = Cal_spec / 10^(CNL/10);
    
    % Despike the measured channel transfer function using a median filter of 51-st order:
    % (this removes spectral peaks due to AC and other external sources of
    % noise from the calibration transfer function:
    Cal_spec2 = medfilt1(Cal_spec,51); % Change the filter order if the calibration curve is not smooth enough
    
    h = figure;
    semilogx(Cal_freq,10*log10(Cal_spec),Cal_freq,10*log10(Cal_spec2),'.-r');
    xlabel('Frequency, Hz')
    ylabel('Gain, dB')
    grid,
    % pause
    close(h);
    Cal_spec = Cal_spec2;
    
    if isempty(HS)
        disp(' ')
        HS = input('Specify hydrophone sensitivity (dB re V/uPa): ');
        if isempty(HS)
            HS = -197.8; %for IMOS
        end
    end
    Cal_spec = Cal_spec * 10^(HS/10);
    
    if isempty(start_times_file_name)
        start_times_file_name = uigetfile('*.mat', 'Open mat-file with recording start times');
    end
    load (start_times_file_name);
    
    N_start_rec = 1;
    
    if isempty(number_days)
        disp(' ')
        number_days = input('Specify number of days with calculated PSD to store in each output mat-file (default 5): ');
        if isempty(number_days)
            number_days = 5;
        end
    end
    
    if isempty(Rec_period)
        disp(' ')
        Rec_period = input('Specify programmed repetition period of recordins in seconds (900 s for IMOS) ');
        if isempty(Rec_period)
            Rec_period = 900;
        end
    end
    
    t = Start_times.time;
    t0 = t(N_start_rec);
    t = t(N_start_rec:end) - t0;
    file_names = Start_times.file_name(N_start_rec:end);
    
    Nfiles = length(t);
    Nrec = ceil(number_days/Rec_period*3600*24); % number of recordings processed in each output file
    Nmatfiles = ceil(length(t)/Nrec); % number of output mat files
    
    filename = [file_names{1},'.DAT'];
    [~, Sig, Fsample, ~] = NL_load_logger_data_new(filename); % read data file with one recording
    Nsamp = length(Sig);
    clear Sig
    time_window = Nsamp/Fsample;
    
    Nfrsamp = Fsample*time_window; % number of samples used to calculate each PSD
    Nframes = ceil(Nsamp/Nfrsamp); % Number of frames in the recording to calculate PSD
    
    [b,a] = butter(6,5/Fsample*2,'high'); % high-pass filter to suppress noise below 5 Hz
    
    if length(Cal_freq) > Fsample/2+1
        Cal_spec = interp1(Cal_freq,Cal_spec,(0:Fsample/2)');
    elseif length(Cal_freq) < Fsample/2+1
        error('Calibration data have the frequency band narrower than  that of sea noise data')
    end
    
    % Calculate frequency grid and allocate memory for long-term average
    % spectrogram to be displayed at the eMII data portal:
    Fl = log10(Fsample/2);
    dfl = Fl/(Fsample/20);
    FL = (0:dfl:Fl)';
    Frequency = 10.^(FL);
    Freq = (0:Fsample/2)'; % ignore frequencies < 5Hz
    nFL = length(FL);
    NFlog = NaN(nFL, 1);
    for n = 1:nFL
        [~, NFlog(n)] = min(abs(Freq-Frequency(n)));
    end
    
    % ignore frequencies < 5Hz:
    iNF = Frequency >= 5;
    Frequency   = Frequency(iNF);
    NFlog       = NFlog(iNF);
    
    Spectrum        = zeros(length(NFlog), Nfiles);
    File_name       = char(zeros(Nfiles, 8));
    Start_time_day  = zeros(1, Nfiles);
    
    % Create folder for images and the MAT file with long-term average
    % spectrogram:
    sdir = fullfile(w, 'images');
    [~, ~, ~] = mkdir(sdir);
    
    set(0,'Units','pixels')
    screen = get(0, 'ScreenSize');
    
    h1 = figure;
    a1 = axes;
    set(a1, 'fontsize', 8, 'NextPlot', 'replacechildren');
    
    h2 = figure;
    a2 = axes;
    c2 = colorbar('fontsize', 9);
    Fgrid = [10, 20, 50, 100, 200, 500, 1000, 2000];
    set(a2, 'fontsize', 8, 'NextPlot', 'replacechildren', 'TickDir', 'out', ...
        'YScale', 'log', 'Ytick', Fgrid, 'YTickLabel', Fgrid, 'TickLength', [0.003 0.003]);
    
    h1_pos = [0.01*screen(3) 0.05*screen(4) 600 300];
    h2_pos = [0.51*screen(3) 0.05*screen(4) 600 300];
    set(h1,'Units','pixels','position',h1_pos,'NumberTitle','Off','color',[1 1 1]);
    set(h2,'Units','pixels','position',h2_pos,'NumberTitle','Off','color',[1 1 1]);
    
    hx1 = xlabel(a1, 'Time, s');
    hy1 = ylabel(a1, 'Acoustic pressure,  Pa');
    ht1 = title(a1, 'Signal waveform: start time: ');
    set([hx1, hy1, ht1], 'fontsize', 9);
    
    hx2 = xlabel(a2, 'Time, s');
    hy2 = ylabel(a2, 'Frequency, Hz');
    ht2 = title(a2, 'Power spectrum density, dB re 1$\mu$Pa$^2$/Hz; Start time: ');
    set([hx2, hy2, ht2], 'fontsize', 9);
    
    for nmf = 1:Nmatfiles
        if nmf < Nmatfiles
            ndf = (Nrec*(nmf-1)+1 : Nrec*nmf);
        else
            ndf = (Nrec*(nmf-1)+1 : length(t));
        end
        NDF = length(ndf);
        Spectr = zeros(Fsample/2 + 1, NDF); % allocate space for output data (PSD)
        Frame_time = NaN*zeros(1, NDF);
        for nf = 1:NDF
            try
                filename = [file_names{ndf(nf),:}, '.DAT'];
                [~, Sig, Fsamp, ~] = NL_load_logger_data_new(filename);
                Nsamp = length(Sig);
                Sig = Sig - mean(Sig);
                Sig = filter(b, a, Sig); % high-pass filter
                
                % Calculate PSDs for long-term average spectrogram to display at
                % eMII data portal
                
%                 [y, Freq] = psd(Sig, Fsamp, Fsamp, Fsamp, 0);  %#ok<FDEPR>
%                 y = y/Fsamp*2;
%                 y(1) = y(1)/2;

                [y, Freq] = pwelch(Sig, Fsamp, 0, Fsamp, Fsamp); 
                y = y ./ Cal_spec; % correct for logger calibration data
                S = y(NFlog);
                
                % Old        Spectrum(:,NDF*(nmf-1)+nf) = S;
                Spectrum(:, ndf(nf)) = 10*log10(S); % New
                
                File_name(ndf(nf), :) = filename(1:end-4);
                Start_time_day(ndf(nf)) = Start_times.time(ndf(nf));
                
                % New revision: to create spectrogram and waveform plots for each recording
                FFTsamples = Fsamp;
                FFToverlap = 50;
                Spec = fft(Sig);
                df = Fsamp/(Nsamp);
                Fr_fft = (0:df:Fsamp/2)';
                Cal_spec_int = interp1(Cal_freq, Cal_spec, Fr_fft);
                % Ignore calibration values below 5 Hz to avoid inadequate correction
                iN5Hz = (Fr_fft <= 5);
                clear Fr_fft
                Cal_spec_int_ignored = Cal_spec_int(iN5Hz);
                Cal_spec_int(iN5Hz) = Cal_spec_int_ignored(end);
                % waveform correction for frequency response
                if floor(Nsamp/2) == Nsamp/2
                    SigN = ifft(Spec./sqrt([Cal_spec_int(1:end-1); Cal_spec_int(end:-1:2)]));
                else
                    SigN = ifft(Spec./sqrt([Cal_spec_int; Cal_spec_int(end:-1:2)]));
                end
                clear Spec Cal_spec_int
                [Sp, F, T] = specgram_correct(Sig, FFTsamples, Fsamp, FFTsamples, floor(FFTsamples*FFToverlap/100));
                clear Sig
                
                % plot waveform
                plot(a1, (0:Nsamp - 1)/Fsamp, SigN/1000000);
                clear SigN
                title(a1, ['Signal waveform: start time: ', ...
                    datestr(Start_times.time(ndf(nf)))], 'fontsize', 9);
                figfilename = [filename(1:end-4), 'WF.png'];
                
                set(h1, 'PaperPositionMode', 'auto');
                imwrite(hardcopy(h1, '-dzbuffer', '-r90'), fullfile(sdir, figfilename), 'png');
                
                % plot spectrogram
                iNf = (F > 5);
                PowerSp = 10*log10(abs(Sp(iNf,:)));
                clear Sp
                caxMax = max(max(PowerSp));
                pcolor(a2, T, F(iNf), PowerSp);
                clear PowerSp
                shading(a2, 'flat');
                if isfinite(caxMax)
                    caxis([caxMax-60, caxMax]);
                else
                    disp(['Warning: ' filename ' is dodgy.']);
                end
                set(c2, 'fontsize', 9);
                title(a2, ['Power spectrum density, dB re 1$\mu$Pa$^2$/Hz; Start time: ', ...
                    datestr(Start_times.time(ndf(nf)))], 'fontsize', 9);
                figfilename = [filename(1:end-4), 'SP.png'];
                
                set(h2, 'PaperPositionMode', 'auto');
                imwrite(hardcopy(h2, '-dzbuffer', '-r90'), fullfile(sdir, figfilename), 'png');
                
                % Calculate PSD and normalize it by sampling frequency:
                Spectr(1:length(y),nf) = y; % correct for logger calibration data
                Frame_time(nf) = t(ndf(nf)) + t0; % start time of each frame
            catch e
                fprintf('%s\n',   ['Error : NL_1Hz_PSD_with_plots4eMII failed on processing ' filename]);
                errorString = getErrorString(e);
                fprintf('%s\n',   ['Error says : ' errorString]);
            end
        end
        % Save output file:
        File_names = file_names(ndf,:);
        tt = Frame_time(:) - t0 + 1;
        save([start_times_file_name(1:5), '_days_', num2str(floor(tt(1))), '_', num2str(floor(tt(end)))], ...
            'Spectr', 'Frame_time', 'Freq', 'File_names');
        clear Spectr Frame_time File_names;
    end
    clear Freq
    close all
    % save long-term average spectrogram for entire deployment to display at eMII data portal:
    matfname = [start_times_file_name(1:5), '_longterm_spectrogram'];
    save(fullfile(sdir, matfname), 'Spectrum', 'File_name', 'Frequency', 'Start_time_day');
    clear Spectrum File_name Frequency Start_time_day
    
    % Convert calibration data into dB
    Calibration_PSD = 10*log10(Cal_spec);
    Calibration_frequency = Cal_freq;
    % Changed ADC unit/uPa to V/uPa in Calibration_info
    Calibration_info = 'Frequency response (power spectrum density) in dB re ADC unit/uPa';
    matfname = [start_times_file_name(1:5), '_calibration'];
    save(fullfile(w, matfname), 'Calibration_PSD', 'Calibration_frequency', 'Calibration_info');
    % New lines to save calibration data in a CSV file (for eMII data portal)
    CSV_cal_file_name = [start_times_file_name(1:5), '_calibration', '.csv'];
    % Write calibration data in dB re V^2/Pa^2
    csvwrite(fullfile(w, CSV_cal_file_name), [Calibration_frequency, Calibration_PSD]);
    clear Calibration_PSD Calibration_frequency Calibration_info Cal_spec Cal_freq
catch e
    fprintf('%s\n',   ['Error : NL_1Hz_PSD_with_plots4eMII failed on preparing ' w]);
    errorString = getErrorString(e);
    fprintf('%s\n',   ['Error says : ' errorString]);
end

fprintf(' %-30s ..... ','NL_1Hz_PSD_with_plots4eMII');
fprintf('%3.3f %s\n',toc,'sec')

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

[Cal_file_name, Cal_file_path] = uigetfile('*.DAT', 'Load calibration data file');
[Header, Cal_sig, Fsamp, Schedule] = NL_load_logger_data_new([Cal_file_path,Cal_file_name]);
[Cal_spec,Cal_freq] = psd(Cal_sig,Fsamp,Fsamp,Fsamp,0);
Cal_spec = Cal_spec*2/Fsamp;
Cal_spec(1) = Cal_spec(1)/2;

disp(' ')
CNL = input('Specify calibration noise level (dB re V^2/Hz): ');
if isempty(CNL)
   CNL = -110; % for IMOS
end
Cal_spec = Cal_spec / 10^(CNL/10);

% Despike the measured channel transfer function using a median filter of 51-st order:
% (this removes spectral peaks due to AC and other external sources of
% noise from the calibration transfer function:
Cal_spec2 = medfilt1(Cal_spec,51); % Change the filter order if the calibration curve is not smooth enough

figure(2 ), semilogx(Cal_freq,10*log10(Cal_spec),Cal_freq,10*log10(Cal_spec2),'.-r'); 
xlabel('Frequency, Hz')
ylabel('Gain, dB')
grid, 
pause
Cal_spec = Cal_spec2;

disp(' ')
HS = input('Specify hydrophone sensitivity (dB re V/uPa): ');
if isempty(HS)
    HS = -197.8; %for IMOS
end
Cal_spec = Cal_spec * 10^(HS/10);
disp(' ')

start_times_file_name = uigetfile('*.mat', 'Open mat-file with recording start times');
load (start_times_file_name);

Cal_file_name = [start_times_file_name(1:5),'calib_data'];
Info = 'Logger calibration data Cal_spec [V^2/uPa^2] at frequencies Cal_freq';
strcal = ['save ',Cal_file_name,' Cal_spec Cal_freq Info'];
eval(strcal);
N_start_rec = 1;

number_days = input('Specify number of days with calculated PSD to store in each output mat-file (default 5): ');
if isempty(number_days)
    number_days = 5;
end; 
disp(' ')

Rec_period = input('Specify programmed repetition period of recordins in seconds (900 s for IMOS) ');
if isempty(Rec_period)
    Rec_period = 900;
end
disp(' ')

t = Start_times.time;
t0 = t(N_start_rec);
t = t(N_start_rec:end) - t0;
file_names = Start_times.file_name(N_start_rec:end,:);

Nfiles = length(t);
Nrec = ceil(number_days/Rec_period*3600*24); % number of recordings processed in each output file 
Nmatfiles = ceil(length(t)/Nrec); % number of output mat files

filename = [file_names(1,:),'.DAT'];
[Header, Sig, Fsample, Start_time] = NL_load_logger_data_new(filename); % read data file with one recording
Nsamp = length(Sig);
time_window = Nsamp/Fsample;

Nfrsamp = Fsample*time_window; % number of samples used to calculate each PSD
Nframes = ceil(Nsamp/Nfrsamp); % Number of frames in the recording to calculate PSD

[b,a] = butter(6,5/Fsample*2,'high'); % high-pass filter to suppress noise below 5 Hz

if length(Cal_freq) > Fsample/2+1
    Cal_spec = interp1(Cal_freq,Cal_spec,[0:Fsample/2]');
elseif length(Cal_freq) < Fsample/2+1
    error('Calibration data have the frequency band narrower than  that of sea noise data')
end

% Calculate frequency grid and allocate memory for long-term average
% spectrogram to be displayed at the eMII data portal:
Fl = log10(Fsample/2);
dfl = Fl/(Fsample/20);
FL = [0:dfl:Fl]';
Frequency = 10.^(FL);
Freq = [0:Fsample/2]'; % ignore frequencies < 5Hz
for n = 1:length(FL);
    [df,NFlog(n)] = min(abs(Freq-Frequency(n)));
end
% ignore frequencies < 5Hz:
NF = find(Frequency >= 5);
Frequency = Frequency(NF);
NFlog = NFlog(NF);
Spectrum = zeros(length(NFlog),Nfiles);
File_name = char(zeros(Nfiles,8));
Start_time_day = zeros(1,Nfiles);
% Create folder for images and the MAT file with long-term avearage
% spectrogram:
sdir = [pwd,'/images/'];
mkdir(sdir)

for nmf = 1:Nmatfiles
    if nmf < Nmatfiles
        ndf = [Nrec*(nmf-1)+1 : Nrec*nmf];
    else
        ndf = [Nrec*(nmf-1)+1 : length(t)];
    end
    NDF = length(ndf);
    Spectr = zeros(Fsample/2+1,NDF); % allocate space for output data (PSD)
    Frame_time = NaN*zeros(1,NDF);
    for nf = 1:NDF
        filename = [file_names(ndf(nf),:),'.DAT'];
        [Header, Sig, Fsamp, Start_time] = NL_load_logger_data_new(filename);
        Sig = Sig - mean(Sig);
        Sig = filter(b,a,Sig); % high-pass filter  
 
        % Calculate PSDs for long-term average spectrogram to display at
        % eMII data portal
        [y, Freq] = psd(Sig,Fsamp,Fsamp,Fsamp,0); 
        y = y/Fsamp*2;
        y(1) = y(1)/2;
        y = y ./ Cal_spec; % correct for logger calibration data 
        S = y(NFlog);
        Spectrum(:,NDF*(nmf-1)+nf) = S;
        File_name(NDF*(nmf-1)+nf,:) = filename(1:end-4);
        Start_time_day(NDF*(nmf-1)+nf) = Start_times.time(NDF*(nmf-1)+nf);

        % New revision: to create spectrogram and waveform plots for each recording
        FFTsamples = Fsamp;
        FFToverlap = 50;
        Spec = fft(Sig);
        df = Fsamp/(length(Sig));
        Fr_fft = [0:df:Fsamp/2]';
        Cal_spec_int = interp1(Cal_freq,Cal_spec,Fr_fft);
        % Ignore calibration values below 5 Hz to avoid inadequate correction
        N5Hz = find(Fr_fft <= 5);
        Cal_spec_int(N5Hz) = Cal_spec_int(N5Hz(end));  
        % waveform correction for frequency response
        if floor(length(Sig)/2) == length(Sig)/2
            SigN = ifft(Spec./sqrt([Cal_spec_int(1:end-1);Cal_spec_int(end:-1:2)]));
        else
            SigN = ifft(Spec./sqrt([Cal_spec_int;Cal_spec_int(end:-1:2)]));
        end
        [Sp,F,T] = specgram_correct(Sig,FFTsamples,Fsamp,FFTsamples,floor(FFTsamples*FFToverlap/100));

        set(0,'Units','pixels')
        screen = get(0, 'ScreenSize');
        % plot waveform
        h1 = figure(1);
        figure_pos = [0.01*screen(3) 0.05*screen(4) 600 300];
        set(h1,'Units','pixels','position',figure_pos,'NumberTitle','Off','color',[1 1 1]);
        plot([0:length(Sig)-1]/Fsamp, SigN/1000000);
        ch1 = get(h1,'children');
        set(ch1,'fontsize',8);
        hx = xlabel('Time, s');
        hy = ylabel('Acoustic pressure,  Pa');
        ht = title(['Signal waveform: start time: ',datestr(Start_times.time(ndf(nf)))]);
        set(hx,'fontsize',9)
        set(hy,'fontsize',9)
        set(ht,'fontsize',9)
        figfilename = [filename(1:end-4),'WF.png'];
        figfilename2 = [filename(1:end-4),'WF2.png'];
        shg
        I = getframe(1);
        imwrite(I.cdata, [sdir,figfilename])

        % plot spectrogram
        Nf = find(F > 5);
        h2 = figure(2);
        figure_pos = [0.51*screen(3) 0.05*screen(4) 600 300];
        set(h2,'Units','pixels','position',figure_pos,'NumberTitle','Off','color',[1 1 1]);
        pcolor(T,F(Nf),10*log10(abs(Sp(Nf,:)))), 
        shading flat
        ch2 = get(h2,'children');
        set(ch2,'tickdir','out','fontsize',8);
        Fgrid = [10,20,50,100,200,500,1000,2000];
        set(ch2,'yscale','log')
        set(ch2,'Ytick',Fgrid)
        set(ch2,'Yticklabel',Fgrid)
        set(ch2,'ticklength',[0.003 0.003])
        hx = xlabel('Time, s');
        hy = ylabel('Frequency, Hz');
        ht = title(['Power spectrum density, dB re 1\muPa^2/Hz; Start time: ',datestr(Start_times.time(ndf(nf)))]);
        set(hx,'fontsize',9)
        set(hy,'fontsize',9)
        set(ht,'fontsize',9)
        set(ch2,'yscale','log')
        cax = caxis;
        caxis([cax(2)-60, cax(2)]);
        colorbar
        figfilename = [filename(1:end-4),'SP.png'];
        shg
        I = getframe(2);
        imwrite(I.cdata, [sdir,figfilename])

        % Calculate PSD and normalize it by sampling frequency:
        Spectr(1:length(y),nf) = y; % correct for logger calibration data 
        Frame_time(nf) = t(ndf(nf)) + t0; % start time of each frame
    end
    % Save output file:
    File_names = file_names(ndf,:);
    tt = Frame_time(:) - t0 + 1;
    s1 = ['save ',start_times_file_name(1:5),'_days_',num2str(floor(tt(1))),'_',num2str(floor(tt(end)))];
    s2 = ' Spectr Frame_time Freq File_names';
    s = [s1,s2];
    eval(s);
end
% save long-term average spectrogram for entire deployment to display at eMII data portal: 
matfname = [start_times_file_name(1:5),'_longterm_spectrogram'];
s = ['save ',sdir,matfname,' Spectrum File_name Frequency Start_time_day'];
eval(s);



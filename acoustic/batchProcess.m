warning('off', 'MATLAB:HandleGraphics:noJVM');

% 6193 files ~ 7728s ~ 2.15h
disp('Processing PAPCA/2802');
cd '/media/Seagate Expansion Drive/archive/PAPCA/2802'
myNL_read_all_start_times(2802)
myNL_1Hz_PSD_with_plots4eMII('../../cal/t2802_Calibration.DAT', -110, -197.6, 't2802_start_times.mat', 5, 900)

% 18595 files ~ 51901s ~ 14.4h
disp('Processing PAPCA/2823');
cd '/media/Seagate Expansion Drive/archive/PAPCA/2823'
myNL_read_all_start_times(2823)
myNL_1Hz_PSD_with_plots4eMII('../../cal/t2823_Calibration.DAT', -110, -197.6, 't2823_start_times.mat', 5, 900)

% 26339 files ~ 62734s ~ 17.4h
disp('Processing PAPCA/2962');
cd '/media/Seagate Expansion Drive/archive/PAPCA/2962'
myNL_read_all_start_times(2962)
myNL_1Hz_PSD_with_plots4eMII('../../cal/t2962_Calibration.DAT', -90, -197.9, 't2962_start_times.mat', 5, 900)

%  files ~ h
% disp('Processing PAPCA/3004');
% cd '/media/Seagate Expansion Drive/archive/PAPCA/3004'
% myNL_read_all_start_times(3004)
% myNL_1Hz_PSD_with_plots4eMII('../../cal/t3004_Calibration.DAT', -90, -197.9, 't3004_start_times.mat', 5, 900)

% 21982 files ~ 63438s ~ 17.6h
disp('Processing PAPOR/2846');
cd '/media/Seagate Expansion Drive/archive/PAPOR/2846'
myNL_read_all_start_times(2846)
myNL_1Hz_PSD_with_plots4eMII('../../cal/t2846_Calibration.DAT', -90, -197.9, 't2846_start_times.mat', 5, 900)

%  files ~ h
% disp('Processing PAPOR/3102');
% cd '/media/Seagate Expansion Drive/archive/PAPOR/3102'
% myNL_read_all_start_times(3102)
% myNL_1Hz_PSD_with_plots4eMII('../../cal/t3102_Calibration.DAT', -90, -196.9, 't3102_start_times.mat', 5, 900)

%  files ~ h
% disp('Processing PASYD/2947');
% cd '/media/Seagate Expansion Drive/archive/PASYD/2947'
% myNL_read_all_start_times(2947)
% myNL_1Hz_PSD_with_plots4eMII('../../cal/t2947_Calibration.DAT', -90, -197.7, 't2947_start_times.mat', 5, 900)

%  files ~ h
% disp('Processing PASYD/3142');
% cd '/media/Seagate Expansion Drive/archive/PASYD/3142'
% myNL_read_all_start_times(3142)
% myNL_1Hz_PSD_with_plots4eMII('../../cal/t3142_Calibration.DAT', -90, -197.9, 't3142_start_times.mat', 5, 900)

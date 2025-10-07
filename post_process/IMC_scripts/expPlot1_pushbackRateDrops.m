%% Parameters
clear;

% Define experiment and application codes
expCode = '0417';
appCode = '1744753467';

% Moving average window size for packet delay
window_size = 10;
% Bin sizes 
bin_sz_phy = 50;  % PHY data bin size (ms)
bin_sz_wrapper = 50; % Bin size for capacity comparison (ms)
enb2sfu_delay = 8.0;

% Define relative plot period
relative_plot_period = [226001, 230000];

% Load data
[ulData, dlData, config] = loadWebRTCData(expCode, appCode, enb2sfu_delay);

%% Process data for time period
% Calculate DL plot period based on DL data start time
dl_start_time = floor(dlData.data_packets(1,14));
dl_plot_period = [dl_start_time + relative_plot_period(1), dl_start_time + relative_plot_period(2)];

% Calculate UL plot period based on UL data start time
ul_start_time = floor(ulData.data_packets(1,14));
ul_plot_period = [ul_start_time + relative_plot_period(1), ul_start_time + relative_plot_period(2)];

% Process data with appropriate direction parameters
dlData = processDataForTimePeriod(dlData, dl_plot_period, config, 'DL');
ulData = processDataForTimePeriod(ulData, ul_plot_period, config, 'UL');

%% Create main figure
figure;
set(gcf, 'Position', [100, 100, 1200, 1600]);  % Increase height to accommodate more subplots

% 1. Downlink average PRB
ax1 = subplot(8, 1, 1);
plotPhyPrbAllocation(dlData, bin_sz_phy, config.slot_duration, config.duplex_mode);
title('Downlink Average PRB Allocation');

% 2. Downlink TBS vs Packet data vs GCC target bitrate (UEs of interest only, Server-based)
ax2 = subplot(8, 1, 2);
plotCapacityComparison(dlData, bin_sz_phy, true, 'server');  % true = UEs of interest only, server-based
title('Downlink Capacity: TBS vs Packet vs Target Bitrate (Server-based, UEs of Interest Only)');

% 3. Downlink packet delay (Server-based)
ax3 = subplot(8, 1, 3);
plotPacketDelay(dlData, window_size, 'server');
% Title is set within the plotPacketDelay function

% 4. Downlink packet delay (UE-based)
ax4 = subplot(8, 1, 4);
plotPacketDelay(dlData, window_size, 'ue');
% Title is set within the plotPacketDelay function

% 5. Uplink Outstanding Bytes
ax5 = subplot(8, 1, 5);
plotGccOutstandingBytes(ulData);
title('Uplink Outstanding Bytes');

% 6. Uplink Data Window Bytes
ax6 = subplot(8, 1, 6);
plotGccWindowBytes(ulData);
title('Uplink Data Window Bytes');

% 7. Uplink GCC metrics
ax7 = subplot(8, 1, 7);
plotGccTargetRates(ulData);
title('Uplink GCC Bitrate Estimates');

% 8. Uplink outbound resolution and framerate
ax8 = subplot(8, 1, 8);
plotAppResoluFr(ulData, 'out');
title('Uplink Outbound Resolution and Framerate');

% Link x-axes
linkaxes([ax1, ax2, ax3, ax4, ax5, ax6, ax7, ax8], 'x');

% Add overall title
sgtitle('WebRTC Pushback Rate Feedback Loop', 'FontSize', 14);
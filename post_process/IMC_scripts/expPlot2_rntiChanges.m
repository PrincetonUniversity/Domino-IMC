%% Parameters
clear;close all

% Define experiment and application codes
expCode = '0417';
appCode = '1744753467';
linktype = 'U'; % 'U' for uplink, 'D' for downlink

% Moving average window size for packet delay
window_size = 10;
% Bin sizes
bin_sz_phy = 50;  % PHY data bin size (ms)
bin_sz_wrapper = 50; % Bin size for capacity comparison (ms)
enb2sfu_delay = 8.0;

% Define relative plot period
relative_plot_period = [098001, 107000];

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

% Determine which data to use based on linktype
if strcmp(linktype, 'U')
    data = ulData;
    direction_label = 'Uplink';
else % 'D'
    data = dlData;
    direction_label = 'Downlink';
end

% 1. Average PRB allocation
ax1 = subplot(9, 1, 1);
plotPhyPrbAllocation(data, bin_sz_phy, config.slot_duration, config.duplex_mode);
title([direction_label ' Average PRB Allocation']);

% 2. TBS by RNTI
ax2 = subplot(9, 1, 2);
plotPhyTbsByRnti(data, bin_sz_phy, config.RNTIs_of_interest);
title([direction_label ' TBS by RNTI (UEs of Interest)']);

% 3. TBS vs Packet data vs GCC target bitrate (UEs of interest only)
ax3 = subplot(9, 1, 3);
% Choose data source based on linktype
if strcmp(linktype, 'U')
    plotCapacityComparison(data, bin_sz_phy, true, 'ue');  % Use UE-based for uplink
    title([direction_label ' Capacity: TBS vs Packet vs Target Bitrate (UE-based, UEs of Interest Only)']);
else % 'D'
    plotCapacityComparison(data, bin_sz_phy, true, 'server');  % Use Server-based for downlink
    title([direction_label ' Capacity: TBS vs Packet vs Target Bitrate (Server-based, UEs of Interest Only)']);
end

% 4. Packet delay
ax4 = subplot(9, 1, 4);
% Choose data source based on linktype
if strcmp(linktype, 'U')
    plotPacketDelay(data, window_size, 'ue');  % Use UE-based for uplink
    title([direction_label ' Packet Delay (UE-based)']);
else % 'D'
    plotPacketDelay(data, window_size, 'server');  % Use Server-based for downlink
    title([direction_label ' Packet Delay (Server-based)']);
end

% 5. GCC modified trend vs adaptive threshold
ax5 = subplot(9, 1, 5);
plotGccTrendVsThreshold(data);
title([direction_label ' Modified Trend vs. Adaptive Threshold']);

% 6. GCC bandwidth state
ax6 = subplot(9, 1, 6);
plotGccBandwidthState(data);
title([direction_label ' Bandwidth State']);

% 7. Outstanding Bytes
ax7 = subplot(9, 1,7);
plotGccOutstandingBytes(data);
title([direction_label ' Outstanding Bytes']);

% 8. GCC metrics
ax8 = subplot(9, 1, 8);
plotGccTargetRates(data);
title([direction_label ' GCC Bitrate Estimates']);

% 9. Outbound resolution and framerate
ax9 = subplot(9, 1, 9);
plotAppResoluFr(data, 'out');
title([direction_label ' Outbound Resolution and Framerate']);

% Link x-axes
linkaxes([ax1, ax2, ax3, ax4, ax5, ax6, ax7, ax8, ax9], 'x');

% Add overall title
sgtitle(['WebRTC RNTI Changes Analysis - ' direction_label], 'FontSize', 14);
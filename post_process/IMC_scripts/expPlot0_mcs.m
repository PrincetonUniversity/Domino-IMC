%% Parameters
clear;close all

% Define experiment and application codes
expCode = '0421';
appCode = '1745693934';
linktype = 'U'; % 'U' for uplink, 'D' for downlink

% Moving average window size for packet delay
window_size = 100;
% Bin sizes
bin_sz_phy = 100;  % PRB data bin size (ms)
bin_sz_mcs = 100;  % MCS data bin size (ms)
enb2sfu_delay = 0.0; % ms

% Define relative plot period
relative_plot_period = [000000, 100000];

% Load data
tic
[ulData, dlData, config] = loadWebRTCData(expCode, appCode, enb2sfu_delay);
toc
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
set(gcf, 'Position', [100, 100, 1200, 2000]);  % Increase height to accommodate more subplots

% Create array to store axes handles for linking
ax = cell(11, 1);

% Determine which data to use based on linktype
if strcmp(linktype, 'U')
    data = ulData;
    opposite_data = dlData;
    direction_label = 'Uplink';
    opposite_direction_label = 'Downlink';
else % 'D'
    data = dlData;
    opposite_data = ulData;
    direction_label = 'Downlink';
    opposite_direction_label = 'Uplink';
end

% 1. Average PRB allocation
ax{1} = subplot(11, 1, 1);
plotPhyPrbAllocation(data, bin_sz_phy, config.slot_duration, config.duplex_mode);
title([direction_label ' Average PRB Allocation']);

% 2. MCS box plot
ax{2} = subplot(11, 1, 2);
plotPhyMcsBoxPlot(data, bin_sz_mcs);
title([direction_label ' MCS Distribution']);

% 3. TBS vs Packet data vs GCC target bitrate (UEs of interest only)
ax{3} = subplot(11, 1, 3);
% Choose data source based on linktype
if strcmp(linktype, 'U')
    plotCapacityComparison(data, bin_sz_phy, true, 'ue');  % Use UE-based for uplink
    title([direction_label ' Capacity: TBS vs Packet vs Target Bitrate (UE-based, UEs of Interest Only)']);
else % 'D'
    plotCapacityComparison(data, bin_sz_phy, true, 'server');  % Use Server-based for downlink
    title([direction_label ' Capacity: TBS vs Packet vs Target Bitrate (Server-based, UEs of Interest Only)']);
end

% 4. BSR
ax{4} = subplot(11, 1, 4);
plotPhyBSR(data);

% 5. Packet delay (Server-based)
ax{5} = subplot(11, 1, 5);
plotPacketDelay(data, window_size, 'server');
title([direction_label ' Packet Delay (Server-based)']);

% 6. Packet delay (UE-based)
ax{6} = subplot(11, 1, 6);
plotPacketDelay(data, window_size, 'ue');
title([direction_label ' Packet Delay (UE-based)']);

% 7. GCC bandwidth state
ax{7} = subplot(11, 1, 7);
plotGccBandwidthState(data);
title([direction_label ' Bandwidth State']);

% 8. Outstanding Bytes
ax{8} = subplot(11, 1, 8);
plotGccOutstandingBytes(data);
title([direction_label ' Outstanding Bytes']);

% 9. GCC metrics
ax{9} = subplot(11, 1, 9);
plotGccTargetRates(data);
title([direction_label ' GCC Bitrate Estimates']);

% 10. Outbound resolution and framerate
ax{10} = subplot(11, 1, 10);
plotAppResoluFr(data, 'out');
title([direction_label ' Outbound Resolution and Framerate']);

% 11. Inbound resolution and framerate (using opposite data)
ax{11} = subplot(11, 1, 11);
plotAppResoluFr(data, 'in');
title([direction_label ' Inbound Resolution and Framerate']);

% Link x-axes
linkaxes([ax{:}], 'x');

% Add overall title
sgtitle(['WebRTC Channel Changes Analysis - ' direction_label], 'FontSize', 14);
%% Data preparation
clear;close all

% Define parameters
expCode = '0402';
appCode = '1744073933'; % 0312:1741828975  0313:1744136903  0402:1744073933  0403:1744069889
experiment_name = ['webrtc-' expCode];
enb2sfu_delay = 0.0;
time_drifting = 1; % 1ms
header_len = 34; % 34 bytes

% read packets data
pktname = ['../data_webrtc/data_exp' expCode '/' experiment_name '-join-pkts-up.csv'];
headers = readcell(pktname, 'Range', '1:1');  % Read only the first row
data_packets = readmatrix(pktname, 'Range', 2);  % Skip the first row
ts_pktOffset = data_packets(1, 1)*1000;

% read PHY data
phyname = ['../data_webrtc/data_exp' expCode '/UL_tbs_delay_' expCode '.mat'];
load(phyname);
ts_dcilog = [dci_log.ts] - ts_pktOffset - time_drifting; % in unit of ms, dci0/pusch timing is 4ms

% read webrtc app log
appout = ['../data_webrtc/data_exp' expCode '/' appCode '-out-rtp-2.csv'];
appin = ['../data_webrtc/data_exp' expCode '/' appCode '-in-rtp-1.csv'];
apppc = ['../data_webrtc/data_exp' expCode '/' appCode '-pc-2.csv'];

% Read app-out
outheaders = readcell(appout, 'Range', '1:1');
% Read the full data and create a temporary table to help with filtering
opts = detectImportOptions(appout);
opts.VariableNamesLine = 1;
temp_table = readtable(appout, opts);
% Create index for video rows (assuming 8th column is named 'kind')
video_idx = strcmp(temp_table.kind, 'video');
% Read the numeric data and filter for video rows
file_appout = readmatrix(appout);
file_appout = file_appout(video_idx, :);
% Adjust timestamps for video rows only
ts_appout = file_appout(:, 1) - file_appout(1, 1) + data_packets(1, 14);
% Read table and filter for video rows
data_table_appout = temp_table(video_idx, :);
% Get quality limitation reasons for video rows only
quality_cell = data_table_appout.quality_limitation_reason;


% Read app-in
inheaders = readcell(appin, 'Range', '1:1');
% First create a temporary table to help with filtering
opts = detectImportOptions(appin);
opts.VariableNamesLine = 1;
temp_table = readtable(appin, opts);
% Create index for video rows
video_idx = strcmp(temp_table.kind, 'video');
% Read numeric data and filter for video rows
file_appin = readmatrix(appin, 'Range', 2);
file_appin = file_appin(video_idx, :);
% Calculate timestamps using filtered data
ts_appin = file_appin(:, 1) - file_appin(1, 1) + data_packets(1, 14);

% Read pc
pcheaders = readcell(apppc, 'Range', '1:1');
file_apppc = readmatrix(apppc, 'Range', 2);
ts_apppc = file_apppc(:, 1) - file_apppc(1, 1) + data_packets(1, 14);

%% Parameters
ts_ue_st = floor(data_packets(1,14));
plot_period = [ts_ue_st+100001, ts_ue_st+200000];
% plot_period = [ts_ue_st+150001, ts_ue_st+165000]; % exp0403
% plot_period = [ts_ue_st+110001, ts_ue_st+140000]; % exp0312
% plot_period = [ts_ue_st+180001, ts_ue_st+190000]; % exp0110 not because of loop


% PHY bin size: ms 
bin_sz_phy = 100;  % Default 1000ms (1s), can be changed as needed
% APP Bytes bin size: ms
bin_sz_app = 100;
%
bin_sz_wrap = 1000;
% Packet delay moving average window: number of data points
window_size = 100;

% obtaining PHY data
% idx within plot_period
phy_st = find(ts_dcilog > plot_period(1), 1, 'first');
phy_ed = find(ts_dcilog < plot_period(2), 1, 'last');

ts_physync = ts_dcilog(phy_st:phy_ed);
tbs_physync = [dci_log(phy_st:phy_ed).tbs];
mcs_physync = [dci_log(phy_st:phy_ed).mcs]; 
prb_physync = [dci_log(phy_st:phy_ed).prb_count]; % Renamed from prb to prb_count
prb_st_physync = [dci_log(phy_st:phy_ed).prb_st]; % Get the PRB start positions
bsrlow_physync = [dci_log(phy_st:phy_ed).bsr_low];
bsrhigh_physync = [dci_log(phy_st:phy_ed).bsr_high];
delay_physync = [dci_log(phy_st:phy_ed).delay];


% obtaining packets data
pkt_st = find(data_packets(:, 14) > plot_period(1), 1, 'first');
pkt_ed = find(data_packets(:, 14) < plot_period(2), 1, 'last');

pkt_size = data_packets(pkt_st:pkt_ed, 8);
ts_ue = data_packets(pkt_st:pkt_ed, 14);
ts_server = data_packets(pkt_st:pkt_ed, 15);
delay_pkt = data_packets(pkt_st:pkt_ed, 16);


% obtaining app-out data
appout_st = find(ts_appout > plot_period(1), 1, 'first');
appout_ed = find(ts_appout < plot_period(2), 1, 'last');
ts_appout_range = ts_appout(appout_st:appout_ed);
data_appout = file_appout(appout_st:appout_ed, :);
quality_data = quality_cell(appout_st:appout_ed); 

% obtaining app-in data
appin_st = find(ts_appin > plot_period(1), 1, 'first');
appin_ed = find(ts_appin < plot_period(2), 1, 'last');
ts_appin_range = ts_appin(appin_st:appin_ed);
data_appin = file_appin(appin_st:appin_ed, :);

% obtaining app-pc data
apppc_st = find(ts_apppc > plot_period(1), 1, 'first');
apppc_ed = find(ts_apppc < plot_period(2), 1, 'last');
ts_apppc_range = ts_apppc(apppc_st:apppc_ed);
data_apppc = file_apppc(apppc_st:apppc_ed, :);

%% plot app out
% Create the main figure with increased height
figure(1);
set(gcf, 'Position', [100, 100, 1200, 1500]);  % Increased height to 1500
num_plots = 10;  % Original number of plots
% Create an array to store all subplot axes
ax = zeros(num_plots,1);  % Array to store 10 subplot axes

% Convert quality_limitation_reason to numeric
quality_numeric = zeros(size(quality_data));
quality_numeric(strcmp(quality_data, 'bandwidth')) = 1;

% Create subplot layout
subplot_heights = [1 1 1 1 1 1 1 1 1 1];  % Original plots
total_height = sum(subplot_heights);
bottom_margin = 0.05;
top_margin = 0.02;
plot_region = 1 - bottom_margin - top_margin;

% Process time data to start from 0
time_offset = ts_appout_range(1);
app_time = (ts_appout_range - time_offset) / 1000;  % Convert to seconds

% Plot 1: Target Bitrate
curr_pos = 1;
ax(curr_pos) = subplot('Position', [0.1, 1 - top_margin - curr_pos*(plot_region/num_plots), 0.8, (plot_region/num_plots)*0.9]);
plot(app_time, data_appout(:, 14)/1e6, 'LineWidth', 1.5);
ylabel('Target Bitrate (Mbps)')
grid on
title('Application Layer Metrics (Outbound)')

% Plot 2: Resolution
curr_pos = 2;
ax(curr_pos) = subplot('Position', [0.1, 1 - top_margin - curr_pos*(plot_region/num_plots), 0.8, (plot_region/num_plots)*0.9]);
plot(app_time, data_appout(:, 20), 'LineWidth', 1.5)
ylabel('Resolution')
grid on

% Plot 3: Framerate
curr_pos = 3;
ax(curr_pos) = subplot('Position', [0.1, 1 - top_margin - curr_pos*(plot_region/num_plots), 0.8, (plot_region/num_plots)*0.9]);
plot(app_time, data_appout(:, 21), 'LineWidth', 1.5)
ylabel('Framerate (fps)')
grid on

% Plot 4: Quality Limitation
curr_pos = 4;
ax(curr_pos) = subplot('Position', [0.1, 1 - top_margin - curr_pos*(plot_region/num_plots), 0.8, (plot_region/num_plots)*0.9]);
plot(app_time, quality_numeric, 'LineWidth', 1.5)
ylabel('Quality Limitation')
yticks([0 1])
yticklabels({'CPU', 'Bandwidth'})
grid on

% Plot 5: Packet Delay with Moving Average
curr_pos = 5;
ax(curr_pos) = subplot('Position', [0.1, 1 - top_margin - curr_pos*(plot_region/num_plots), 0.8, (plot_region/num_plots)*0.9]);

% Calculate moving average and standard deviation
mov_avg = movmean(delay_pkt, window_size);
mov_std = movstd(delay_pkt, window_size);

% Plot shaded area for fluctuation
ts_pkt = (ts_ue - min(ts_ue))/1000;
fill([ts_pkt; flipud(ts_pkt)], ...
     [mov_avg-mov_std; flipud(mov_avg+mov_std)], ...
     'b', 'FaceAlpha', 0.2, 'EdgeColor', 'none')
hold on
plot(ts_pkt, mov_avg, 'b', 'LineWidth', 1.5)
ylabel('Packet Delay (ms)')
grid on
title('Network Layer Metrics')

% Plot 6: PRB with Bars
curr_pos = 6;
ax(curr_pos) = subplot('Position', [0.1, 1 - top_margin - curr_pos*(plot_region/num_plots), 0.8, (plot_region/num_plots)*0.9]);
% Group PRB data by bin_size
ts_binned = floor((ts_physync - min(ts_physync))/bin_sz_phy);
unique_bins = unique(ts_binned);
prb_sum = zeros(size(unique_bins));
for i = 1:length(unique_bins)
    idx = ts_binned == unique_bins(i);
    prb_sum(i) = sum(prb_physync(idx)) / sum(idx);
end
% Convert bin indices to seconds for x-axis
time_bins = unique_bins * (bin_sz_phy/1000);

% Plot bars instead of errorbar
bar(time_bins, prb_sum)
ylabel('Average PRB')
grid on
title('Physical Layer Metrics')

% Plot 7: TBS with Bars
curr_pos = 7;
ax(curr_pos) = subplot('Position', [0.1, 1 - top_margin - curr_pos*(plot_region/num_plots), 0.8, (plot_region/num_plots)*0.9]);
% Group TBS data using the same bins
tbs_sum = zeros(size(unique_bins));
for i = 1:length(unique_bins)
    idx = ts_binned == unique_bins(i);
    % Convert to MBits/second: divide by bin_size(ms) and multiply by 1000(ms/s), then divide by 1000 for K to M
    tbs_sum(i) = (sum(tbs_physync(idx))/bin_sz_phy) * (1000/1e6);
end

bar(time_bins, tbs_sum, 'b')
ylabel('TBS (Mbps)')
grid on

% Plot 8: MCS (raw values) vs Time - REPLACED TBS/PRB plot
curr_pos = 8;
ax(curr_pos) = subplot('Position', [0.1, 1 - top_margin - curr_pos*(plot_region/num_plots), 0.8, (plot_region/num_plots)*0.9]);
% Convert timestamps to seconds for x-axis
ts_phy_seconds = (ts_physync - min(ts_physync))/1000;  % Convert to seconds
% Plot raw MCS values
plot(ts_phy_seconds, mcs_physync, 'g.', 'MarkerSize', 4)  % Using dots for better visibility of individual points
ylabel('MCS')
grid on


% Plot 9: BSR vertical lines
curr_pos = 9;
ax(curr_pos) = subplot('Position', [0.1, 1 - top_margin - curr_pos*(plot_region/num_plots), 0.8, (plot_region/num_plots)*0.9]);

valid_bsr = bsrhigh_physync > 0;
ts_bsr = ts_physync(valid_bsr);
bsr_low_array = bsrlow_physync(valid_bsr)/1e6;
bsr_high_array = bsrhigh_physync(valid_bsr)/1e6;

ts_bsr = (ts_bsr - min(ts_physync))/1000;
hold on;
for i = 1:length(ts_bsr)
    plot([ts_bsr(i) ts_bsr(i)], ...
         [bsr_low_array(i) bsr_high_array(i)], ...
         'r-', 'LineWidth', 1)
end
ylabel('BSR (MBits)')
grid on

% Plot 10: PHY Retransmission Delay
curr_pos = 10;
ax(curr_pos) = subplot('Position', [0.1, 1 - top_margin - curr_pos*(plot_region/num_plots), 0.8, (plot_region/num_plots)*0.9]);

% Plot raw delay_physync data
ts_phy = (ts_physync - min(ts_physync))/1000;  % Convert to seconds
plot(ts_phy, delay_physync, 'LineWidth', 1.5)
ylabel('PHY Retx Delay (ms)')
xlabel('Time (s)')
grid on

% After all plots are created, link their x-axes
% linkaxes(ax, 'x');

% Adjust overall figure appearance
set(gcf, 'Color', 'w');
set(gcf, 'PaperUnits', 'inches');
set(gcf, 'PaperSize', [12 15]);  % Increased height
set(gcf, 'PaperPosition', [0 0 12 15]);  % Increased height


%% plot app in
% Create the second figure with increased height
figure(2);
set(gcf, 'Position', [150, 150, 1200, 1500]);  % Increased height to 1500
num_plots = 10; 
% Create an array to store all subplot axes
ax1 = zeros(num_plots,1);  % Array to store 10 subplot axes

% Create subplot layout
subplot_heights = [1 1 1 1 1 1 1 1 1 1];  % Equal heights for all plots
total_height = sum(subplot_heights);
bottom_margin = 0.05;
top_margin = 0.02;
plot_region = 1 - bottom_margin - top_margin;

% Process time data to start from 0
time_offset = ts_appin_range(1);
app_time = (ts_appin_range - time_offset) / 1000;  % Convert to seconds

% Calculate per-frame jitter buffer metrics
jb_delay_diff = [0; diff(data_appin(:, 18))];
jb_target_diff = [0; diff(data_appin(:, 19))];
jb_min_diff = [0; diff(data_appin(:, 20))];
jb_emitted_diff = [0; diff(data_appin(:, 21))];

% Calculate per-frame metrics (avoiding division by zero)
valid_idx = jb_emitted_diff > 0;
jb_delay_per_frame = zeros(size(jb_delay_diff));
jb_target_per_frame = zeros(size(jb_target_diff));
jb_min_per_frame = zeros(size(jb_min_diff));

jb_delay_per_frame(valid_idx) = jb_delay_diff(valid_idx) ./ jb_emitted_diff(valid_idx) * 1000;
jb_target_per_frame(valid_idx) = jb_target_diff(valid_idx) ./ jb_emitted_diff(valid_idx) * 1000;
jb_min_per_frame(valid_idx) = jb_min_diff(valid_idx) ./ jb_emitted_diff(valid_idx) * 1000;

% Plot 1: Jitter Buffer Metrics
curr_pos = 1;
ax1(curr_pos) = subplot('Position', [0.1, 1 - top_margin - curr_pos*(plot_region/num_plots), 0.8, (plot_region/num_plots)*0.9]);
plot(app_time, jb_delay_per_frame, 'LineWidth', 1.5, 'DisplayName', 'Current Delay')
hold on
plot(app_time, jb_target_per_frame, 'LineWidth', 1.5, 'DisplayName', 'Target Delay')
plot(app_time, jb_min_per_frame, 'LineWidth', 1.5, 'DisplayName', 'Minimum Delay')
ylabel('Jitter Buffer Delay per Frame (ms)')
grid on
legend('show')
title('Application Layer Metrics (Inbound)')

% Plot 2: Resolution
curr_pos = 2;
ax1(curr_pos) = subplot('Position', [0.1, 1 - top_margin - curr_pos*(plot_region/num_plots), 0.8, (plot_region/num_plots)*0.9]);
plot(app_time, data_appin(:, 33), 'LineWidth', 1.5)
ylabel('Resolution')
grid on

% Plot 3: Framerate
curr_pos = 3;
ax1(curr_pos) = subplot('Position', [0.1, 1 - top_margin - curr_pos*(plot_region/num_plots), 0.8, (plot_region/num_plots)*0.9]);
plot(app_time, data_appin(:, 34), 'LineWidth', 1.5)
ylabel('Framerate (fps)')
grid on

% Plot 4: Freeze Count
curr_pos = 4;
ax1(curr_pos) = subplot('Position', [0.1, 1 - top_margin - curr_pos*(plot_region/num_plots), 0.8, (plot_region/num_plots)*0.9]);
plot(app_time, data_appin(:, 46), 'LineWidth', 1.5)
ylabel('Freeze Count')
grid on

% Plot 5: Packet Delay with Moving Average
curr_pos = 5;
ax1(curr_pos) = subplot('Position', [0.1, 1 - top_margin - curr_pos*(plot_region/num_plots), 0.8, (plot_region/num_plots)*0.9]);
mov_avg = movmean(delay_pkt, window_size);
mov_std = movstd(delay_pkt, window_size);
ts_pkt = (ts_ue - min(ts_ue))/1000;
fill([ts_pkt; flipud(ts_pkt)], ...
     [mov_avg-mov_std; flipud(mov_avg+mov_std)], ...
     'b', 'FaceAlpha', 0.2, 'EdgeColor', 'none')
hold on
plot(ts_pkt, mov_avg, 'b', 'LineWidth', 1.5)
ylabel('Packet Delay (ms)')
grid on
title('Network Layer Metrics')

% Plot 6: PRB with Bars
curr_pos = 6;
ax1(curr_pos) = subplot('Position', [0.1, 1 - top_margin - curr_pos*(plot_region/num_plots), 0.8, (plot_region/num_plots)*0.9]);
% Group PRB data by bin_size
ts_binned = floor((ts_physync - min(ts_physync))/bin_sz_phy);
unique_bins = unique(ts_binned);
prb_sum = zeros(size(unique_bins));
for i = 1:length(unique_bins)
    idx = ts_binned == unique_bins(i);
    prb_sum(i) = sum(prb_physync(idx)) / sum(idx);
end
% Convert bin indices to seconds for x-axis
time_bins = unique_bins * (bin_sz_phy/1000);

% Plot bars instead of errorbar
bar(time_bins, prb_sum)
ylabel('Average PRB')
grid on
title('Physical Layer Metrics')

% Plot 7: TBS with Bars
curr_pos = 7;
ax1(curr_pos) = subplot('Position', [0.1, 1 - top_margin - curr_pos*(plot_region/num_plots), 0.8, (plot_region/num_plots)*0.9]);
% Group TBS data using the same bins
tbs_sum = zeros(size(unique_bins));
for i = 1:length(unique_bins)
    idx = ts_binned == unique_bins(i);
    % Convert to MBits/second: divide by bin_size(ms) and multiply by 1000(ms/s), then divide by 1000 for K to M
    tbs_sum(i) = (sum(tbs_physync(idx))/bin_sz_phy) * (1000/1e6);
end

bar(time_bins, tbs_sum, 'b')
ylabel('TBS (Mbps)')
grid on

% Plot 8: MCS (raw values) vs Time - REPLACED TBS/PRB plot
curr_pos = 8;
ax1(curr_pos) = subplot('Position', [0.1, 1 - top_margin - curr_pos*(plot_region/num_plots), 0.8, (plot_region/num_plots)*0.9]);
% Convert timestamps to seconds for x-axis
ts_phy_seconds = (ts_physync - min(ts_physync))/1000;  % Convert to seconds
% Plot raw MCS values
plot(ts_phy_seconds, mcs_physync, 'g.', 'MarkerSize', 4)  % Using dots for better visibility of individual points
ylabel('MCS')
grid on


% Plot 9: BSR
curr_pos = 9;
ax1(curr_pos) = subplot('Position', [0.1, 1 - top_margin - curr_pos*(plot_region/num_plots), 0.8, (plot_region/num_plots)*0.9]);
valid_bsr = bsrhigh_physync > 0;
ts_bsr = ts_physync(valid_bsr);
bsr_low_array = bsrlow_physync(valid_bsr)/1e6;
bsr_high_array = bsrhigh_physync(valid_bsr)/1e6;
ts_bsr = (ts_bsr - min(ts_physync))/1000;

for i = 1:length(ts_bsr)
    plot([ts_bsr(i) ts_bsr(i)], ...
         [bsr_low_array(i) bsr_high_array(i)], ...
         'r-', 'LineWidth', 1)
    hold on
end
ylabel('BSR (MBits)')
grid on

% New Plot 10: PHY Retransmission Delay
curr_pos = 10;
ax1(curr_pos) = subplot('Position', [0.1, 1 - top_margin - curr_pos*(plot_region/num_plots), 0.8, (plot_region/num_plots)*0.9]);

% Plot raw delay_physync data
ts_phy = (ts_physync - min(ts_physync))/1000;  % Convert to seconds
plot(ts_phy, delay_physync, 'LineWidth', 1.5)
ylabel('PHY Retx Delay (ms)')
xlabel('Time (s)')
grid on

% linkaxes(ax1, 'x');

% Adjust overall figure appearance
set(gcf, 'Color', 'w');
set(gcf, 'PaperUnits', 'inches');
set(gcf, 'PaperSize', [12 15]);  % Increased height
set(gcf, 'PaperPosition', [0 0 12 15]);  % Increased height


%% plot app pc
% Create the third figure with increased height
figure(3);
set(gcf, 'Position', [200, 200, 1200, 1800]);  % Increased height for 9 subplots
num_plots = 10;
% Create an array to store all subplot axes
ax2 = zeros(10,1);

% Create subplot layout
subplot_heights = [1 1 1 1 1 1 1 1 1 1];  % Equal heights for all plots
total_height = sum(subplot_heights);
bottom_margin = 0.05;
top_margin = 0.02;
plot_region = 1 - bottom_margin - top_margin;

% Process time data to start from 0
time_offset = ts_apppc_range(1);
app_time = (ts_apppc_range - time_offset) / 1000;  % Convert to seconds

% Plot 1: Current Round Trip Time
curr_pos = 1;
ax2(curr_pos) = subplot('Position', [0.1, 1 - top_margin - curr_pos*(plot_region/num_plots), 0.8, (plot_region/num_plots)*0.9]);
plot(app_time, data_apppc(:, 14)*1000, 'LineWidth', 1.5)
ylabel('RTT (ms)')
grid on
title('PeerConnection Metrics')

% Plot 2: Available Outgoing Bitrate
curr_pos = 2;
ax2(curr_pos) = subplot('Position', [0.1, 1 - top_margin - curr_pos*(plot_region/num_plots), 0.8, (plot_region/num_plots)*0.9]);
plot(app_time, data_apppc(:, 15)/1e6, 'b-', 'LineWidth', 1.5)
ylabel('Available Outgoing Bitrate (Mbps)')
grid on

% Plot 3: Bytes Sent Per Window
curr_pos = 3;
ax2(curr_pos) = subplot('Position', [0.1, 1 - top_margin - curr_pos*(plot_region/num_plots), 0.8, (plot_region/num_plots)*0.9]);
% Group bytes_sent by window_size windows and calculate difference
ts_bytes = floor((ts_apppc_range - time_offset)/bin_sz_app);
unique_windows_bytes = unique(ts_bytes);
bytes_per_window = zeros(size(unique_windows_bytes));

for i = 1:length(unique_windows_bytes)
    idx = ts_bytes == unique_windows_bytes(i);
    if any(idx)
        % Get the last value in each window
        bytes_per_window(i) = data_apppc(find(idx, 1, 'last'), 11);
    end
end
% Calculate difference between consecutive values
bytes_diff = [bytes_per_window(1); diff(bytes_per_window)];
% Convert window indices to seconds for x-axis
time_windows = unique_windows_bytes * (bin_sz_app/1000);  % Convert to seconds

bytes_diff(1) = bytes_diff(2);
bits_diff = (bytes_diff/bin_sz_app)*8*1000/1e6; % Convert to Mbps
bar(time_windows, bits_diff, 'FaceAlpha', 0.6) 
ylabel('Bytes Sent per Window (Mbps)')
grid on

% Plot 4: Packet Delay with Moving Average
curr_pos = 4;
ax2(curr_pos) = subplot('Position', [0.1, 1 - top_margin - curr_pos*(plot_region/num_plots), 0.8, (plot_region/num_plots)*0.9]);
mov_avg = movmean(delay_pkt, window_size);
mov_std = movstd(delay_pkt, window_size);
ts_pkt = (ts_ue - min(ts_ue))/1000;
fill([ts_pkt; flipud(ts_pkt)], ...
    [mov_avg-mov_std; flipud(mov_avg+mov_std)], ...
    'b', 'FaceAlpha', 0.2, 'EdgeColor', 'none')
hold on
plot(ts_pkt, mov_avg, 'b', 'LineWidth', 1.5)
ylabel('Packet Delay (ms)')
grid on
title('Network Layer Metrics')

% Plot 5: PRB with Bars
curr_pos = 5;
ax2(curr_pos) = subplot('Position', [0.1, 1 - top_margin - curr_pos*(plot_region/num_plots), 0.8, (plot_region/num_plots)*0.9]);
% Group PRB data by bin_size
ts_binned = floor((ts_physync - min(ts_physync))/bin_sz_phy);
unique_bins = unique(ts_binned);
prb_sum = zeros(size(unique_bins));
for i = 1:length(unique_bins)
    idx = ts_binned == unique_bins(i);
    prb_sum(i) = sum(prb_physync(idx)) / sum(idx);
end
% Convert bin indices to seconds for x-axis
time_bins = unique_bins * (bin_sz_phy/1000);

% Plot bars instead of errorbar
bar(time_bins, prb_sum)
ylabel('Average PRB')
grid on
title('Physical Layer Metrics')

% Plot 6: TBS with Bars
curr_pos = 6;
ax2(curr_pos) = subplot('Position', [0.1, 1 - top_margin - curr_pos*(plot_region/num_plots), 0.8, (plot_region/num_plots)*0.9]);
% Group TBS data using the same bins
tbs_sum = zeros(size(unique_bins));
for i = 1:length(unique_bins)
    idx = ts_binned == unique_bins(i);
    % Convert to MBits/second: divide by bin_size(ms) and multiply by 1000(ms/s), then divide by 1000 for K to M
    tbs_sum(i) = (sum(tbs_physync(idx))/bin_sz_phy) * (1000/1e6);
end

bar(time_bins, tbs_sum, 'b')
ylabel('TBS (Mbps)')
grid on


% Plot 7: MCS (raw values) vs Time - REPLACED TBS/PRB plot
curr_pos = 7;
ax2(curr_pos) = subplot('Position', [0.1, 1 - top_margin - curr_pos*(plot_region/num_plots), 0.8, (plot_region/num_plots)*0.9]);
% Convert timestamps to seconds for x-axis
ts_phy_seconds = (ts_physync - min(ts_physync))/1000;  % Convert to seconds
% Plot raw MCS values
plot(ts_phy_seconds, mcs_physync, 'g.', 'MarkerSize', 4)  % Using dots for better visibility of individual points
ylabel('MCS')
grid on

% Plot 8: BSR
curr_pos = 8;
ax2(curr_pos) = subplot('Position', [0.1, 1 - top_margin - curr_pos*(plot_region/num_plots), 0.8, (plot_region/num_plots)*0.9]);
valid_bsr = bsrhigh_physync > 0;
ts_bsr = ts_physync(valid_bsr);
bsr_low_array = bsrlow_physync(valid_bsr)/1e6;
bsr_high_array = bsrhigh_physync(valid_bsr)/1e6;
ts_bsr = (ts_bsr - min(ts_physync))/1000;

for i = 1:length(ts_bsr)
    plot([ts_bsr(i) ts_bsr(i)], ...
        [bsr_low_array(i) bsr_high_array(i)], ...
        'r-', 'LineWidth', 1)
    hold on
end
ylabel('BSR (MBits)')
grid on

% Plot 9: PHY Retransmission Delay
curr_pos = 9;
ax2(curr_pos) = subplot('Position', [0.1, 1 - top_margin - curr_pos*(plot_region/num_plots), 0.8, (plot_region/num_plots)*0.9]);

% Plot raw delay_physync data
ts_phy = (ts_physync - min(ts_physync))/1000;  % Convert to seconds
plot(ts_phy, delay_physync, 'LineWidth', 1.5)
ylabel('PHY Retx Delay (ms)')
xlabel('Time (s)')
grid on

% Plot 10: Compare
curr_pos = 10;
ax2(curr_pos) = subplot('Position', [0.1, 1 - top_margin - curr_pos*(plot_region/num_plots), 0.8, (plot_region/num_plots)*0.9]);

ts_app_binned = floor((ts_apppc_range - min(ts_apppc_range))/bin_sz_wrap);
ts_phy_binned = floor((ts_physync - min(ts_physync))/bin_sz_wrap);

unique_bins_app = unique(ts_app_binned);
unique_bins_phy = unique(ts_phy_binned);

% Initialize arrays to store all bin data
all_app_curves = cell(length(unique_bins_app), 1);
all_phy_curves = cell(length(unique_bins_phy), 1);
max_points = 0;  % To track the maximum number of points in any bin

% Process APP layer data (data_apppc)
for i = 1:length(unique_bins_app)
    idx = ts_app_binned == unique_bins_app(i);
    if any(idx)
        % Get the byte values in this bin and convert to bits
        bytes_in_bin = data_apppc(idx, 11);
        % Calculate differences within this bin
        bytes_diff = bytes_in_bin - bytes_in_bin(1);
        % Convert to bits
        bits_in_bin = bytes_diff * 8;
        all_app_curves{i} = bits_in_bin;
        max_points = max(max_points, length(bits_in_bin));
    end
end

% Process PHY layer data (tbs_physync)
for i = 1:length(unique_bins_phy)
    idx = ts_phy_binned == unique_bins_phy(i);
    if any(idx)
        % Get TBS values in this bin
        tbs_in_bin = tbs_physync(idx) * 0.88;
        % Calculate cumulative sum within this bin
        cumsum_tbs = cumsum(tbs_in_bin);
        all_phy_curves{i} = cumsum_tbs;
        max_points = max(max_points, length(cumsum_tbs));
    end
end

% Plot curves for each bin
hold on
for i = 1:length(unique_bins_app)
    if ~isempty(all_app_curves{i})
        app_curve = all_app_curves{i};
        time_points = linspace(unique_bins_app(i), unique_bins_app(i) + 1, length(app_curve));
        plot(time_points, app_curve, 'b-', 'LineWidth', 1.5)
    end
end

for i = 1:length(unique_bins_phy)
    if ~isempty(all_phy_curves{i})
        phy_curve = all_phy_curves{i};
        time_points = linspace(unique_bins_phy(i), unique_bins_phy(i) + 1, length(phy_curve));
        plot(time_points, phy_curve, 'r--', 'LineWidth', 1.5)
    end
end

ylabel('Cumulative Bits within Bin')
xlabel('Time (s)')
grid on
% Create invisible lines just for legend
h1 = plot(NaN,NaN, 'b-', 'LineWidth', 1.5);
h2 = plot(NaN,NaN, 'r--', 'LineWidth', 1.5);
legend([h1, h2], 'APP Layer', 'PHY Layer', 'Location', 'northwest')
title('APP vs PHY Layer Cumulative Bits Comparison (Per Bin)')


% linkaxes(ax2, 'x');

% Adjust figure appearance
set(gcf, 'Color', 'w');
set(gcf, 'PaperUnits', 'inches');
set(gcf, 'PaperSize', [12 18]);  % Increased height
set(gcf, 'PaperPosition', [0 0 12 18]);  % Increased height

%% figure 4 & 5: GCC trendline estimator
% hPlotGCC_RFC(ts_ue, ts_server, delay_pkt);
hPlotGCC_Sim(ts_ue-min(ts_ue), ts_server-min(ts_ue), pkt_size);
hPlotGCC_Src(plot_period(1), plot_period(2), expCode, appCode, data_packets(1, 14));



%% Create Figure 6 using the hPlotPRB function
% Call the PRB Allocation plotting function
% hPlotPRB(plot_period(1), plot_period(2), ts_physync, prb_st_physync, prb_physync);


%% Figure 7: the capacity comparison plot function

% Define bin size for figure 7
bin_size_fig7 = 100; % 1000ms (1s) bin size
% Get target bitrate data within plot period
appout_idx = (ts_appout_range >= plot_period(1)) & (ts_appout_range <= plot_period(2));
target_bitrate = data_appout(appout_idx, 14)/1e6; % Convert to Mbps
ts_target = ts_appout_range(appout_idx);

% Call the function with the appropriate parameters
hPlot_CapComp(plot_period(1), plot_period(2), ts_physync, tbs_physync, ts_ue, pkt_size, ts_target, target_bitrate, bin_size_fig7);

%% Create Figure 6: PRB Allocation Visualization
% figure(6);
% set(gcf, 'Position', [150, 150, 1200, 600]);  % Set appropriate figure size for PRB allocation
% 
% % Convert to seconds for x-axis
% ts_prb_allocation = (ts_physync - min(ts_physync))/1000;
% 
% % Set up the axes
% hold on;
% max_prb_idx = 51; % Assuming total of 51 PRBs as mentioned
% 
% % Draw horizontal grid lines for PRB indices
% for i = 0:5:max_prb_idx
%     plot([min(ts_prb_allocation), max(ts_prb_allocation)], [i, i], 'Color', [0.8 0.8 0.8], 'LineWidth', 0.5);
% end
% 
% % Plot each PRB allocation as a vertical line/bar
% for i = 1:length(ts_prb_allocation)
%     % Only plot if we have valid PRB data
%     if ~isnan(prb_st_physync(i)) && ~isnan(prb_physync(i)) && prb_physync(i) > 0
%         % Plot a vertical line from prb_st to prb_st + prb_count
%         line([ts_prb_allocation(i), ts_prb_allocation(i)], ...
%              [prb_st_physync(i), prb_st_physync(i) + prb_physync(i)], ...
%              'Color', 'b', 'LineWidth', 2);
%     end
% end
% 
% % Add colorbar with proper labels
% % Set axis properties
% ylim([0 max_prb_idx]);
% xlabel('Time (s)');
% ylabel('PRB Index');
% title('PRB Allocation Over Time');
% grid on;
% 
% % Adjust figure appearance
% set(gcf, 'Color', 'w');
% set(gcf, 'PaperUnits', 'inches');
% set(gcf, 'PaperSize', [12 6]);
% set(gcf, 'PaperPosition', [0 0 12 6]);

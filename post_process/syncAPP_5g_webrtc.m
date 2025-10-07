%% Data preparation
clear;close all

% Define parameters
expCode = '0420';
linktype = 'U';  % 'U' for uplink, 'D' for downlink
% 0312:1741828975  0404:1743896452  0405:1744043707  0406:1743908842
% 0407:1744134301  0408:1744159523
appCode = '1745461047'; 
experiment_name = ['webrtc-' expCode];
enb2sfu_delay = 0.0;
time_drifting = 1; % 1ms
header_len = 34; % 34 bytes
amarisoft = {'0420'};
scs30k = {'0404', '0407', '0412', '0413', '0419', '0420'};
scs15k = {'0406', '0405', '0414', '0416', '0417', '0418'};

% Set direction-specific parameters based on linktype
if strcmp(linktype, 'U')
    dir_prefix = 'UL';
    pkts_file_suffix = '-join-pkts-up.csv';
    appout_rtp = '-out-rtp-2.csv';
    appin_rtp = '-in-rtp-1.csv';
    apppc_file = '-pc-2.csv';
    direction_title = 'Uplink';
elseif strcmp(linktype, 'D')
    dir_prefix = 'DL';
    pkts_file_suffix = '-join-pkts-down.csv';
    appout_rtp = '-out-rtp-1.csv';
    appin_rtp = '-in-rtp-2.csv';
    apppc_file = '-pc-1.csv';
    direction_title = 'Downlink';
else
    error('Invalid linktype. Must be ''U'' or ''D''.');
end

% Check if expCode is a member of either array
if ismember(expCode, scs30k)
    slot_duration = 0.5; % SCS: 30KHz
elseif ismember(expCode, scs15k)
    slot_duration = 1; % SCS: 15KHz
else
    % Default value or error handling if needed
    warning('Unknown expCode: %s. Using default slot_duration.', expCode);
    slot_duration = NaN; % or some default value
end

% read RNTIs from file using readmatrix
rnti_file_path = ['../data_webrtc/data_exp' expCode '/rnti.txt'];
RNTIs_of_interest = readmatrix(rnti_file_path);

% read packets data
pktname = ['../data_webrtc/data_exp' expCode '/' experiment_name pkts_file_suffix];
headers = readcell(pktname, 'Range', '1:1');  % Read only the first row
data_packets = readmatrix(pktname, 'Range', 2);  % Skip the first row
ts_pktOffset = data_packets(1, 1)*1000;

% read PHY data
phyname = ['../data_webrtc/data_exp' expCode '/' dir_prefix '_tbs_delay_' expCode '.mat'];
load(phyname);
ts_dcilog = [dci_log.ts] - ts_pktOffset + [dci_log.k]*slot_duration - time_drifting; % in unit of ms, dci0/pusch timing is 4ms


% read webrtc app log
appout = ['../data_webrtc/data_exp' expCode '/' appCode appout_rtp];
appin = ['../data_webrtc/data_exp' expCode '/' appCode appin_rtp];
apppc = ['../data_webrtc/data_exp' expCode '/' appCode apppc_file];

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
plot_period = [ts_ue_st+133001, ts_ue_st+143000]; % 
% plot_period = [ts_ue_st+075001, ts_ue_st+085001]; % exp0405
% plot_period = [ts_ue_st+080001, ts_ue_st+120000]; % exp0404
% plot_period = [ts_ue_st+110001, ts_ue_st+140000]; % exp0312
% plot_period = [ts_ue_st+180001, ts_ue_st+190000]; % exp0110 not because of loop


% PHY bin size: ms 
bin_sz_phy = 20;  % Default 1000ms (1s), can be changed as needed
% Packet bin size: ms
bin_sz_app = 10;
% Fig 3
bin_sz_wrap = 100;
% Packet moving average window: number of data points
window_size = 10;

% obtaining PHY data
% idx within plot_period
phy_st = find(ts_dcilog > plot_period(1), 1, 'first');
phy_ed = find(ts_dcilog < plot_period(2), 1, 'last');

ts_physync = ts_dcilog(phy_st:phy_ed);
tbs_physync = [dci_log(phy_st:phy_ed).tbs];
mcs_physync = [dci_log(phy_st:phy_ed).mcs]; 
prb_physync = [dci_log(phy_st:phy_ed).prb_count]; % Renamed from prb to prb_count
prb_st_physync = [dci_log(phy_st:phy_ed).prb_st]; % Get the PRB start positions
delay_physync = [dci_log(phy_st:phy_ed).delay];
rntis_physync = [dci_log(phy_st:phy_ed).rnti]; % Extract RNTIs for the selected time range

% Filter data for UEs of interest
is_interest_ue = ismember(rntis_physync, RNTIs_of_interest);

% Create filtered data arrays for UEs of interest
ts_physync_interest = ts_physync(is_interest_ue);
tbs_physync_interest = tbs_physync(is_interest_ue);
mcs_physync_interest = mcs_physync(is_interest_ue);
prb_physync_interest = prb_physync(is_interest_ue);
delay_physync_interest = delay_physync(is_interest_ue);

% Create filtered data arrays for other UEs (for comparison if needed)
ts_physync_others = ts_physync(~is_interest_ue);
tbs_physync_others = tbs_physync(~is_interest_ue);
mcs_physync_others = mcs_physync(~is_interest_ue);
prb_physync_others = prb_physync(~is_interest_ue);
delay_physync_others = delay_physync(~is_interest_ue);


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
num_plots = 9;  % Reduced from 10 to 9 (removed BSR plot)
% Create an array to store all subplot axes
ax = zeros(num_plots,1);  % Array to store subplot axes

% Convert quality_limitation_reason to numeric
quality_numeric = zeros(size(quality_data));
quality_numeric(strcmp(quality_data, 'bandwidth')) = 1;

% Create subplot layout
subplot_heights = ones(1, num_plots);  % Equal heights for all plots
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
title(['Application Layer Metrics (Outbound)' direction_title])

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

% Plot 6: PRB with Stacked Bars for different UEs
curr_pos = 6;
ax(curr_pos) = subplot('Position', [0.1, 1 - top_margin - curr_pos*(plot_region/num_plots), 0.8, (plot_region/num_plots)*0.9]);

% Group PRB data by bin_size
ts_binned = floor((ts_physync - min(ts_physync))/bin_sz_phy);
unique_bins = unique(ts_binned);

% Initialize arrays for UEs of interest and other UEs
prb_sum_interest = zeros(size(unique_bins));
prb_sum_others = zeros(size(unique_bins));

% Process each time bin
for i = 1:length(unique_bins)
    bin_indices = find(ts_binned == unique_bins(i));
    
    % Get which entries in this bin belong to UEs of interest
    bin_is_interest = is_interest_ue(bin_indices);
    
    % Calculate average PRB for UEs of interest in this bin
    if any(bin_is_interest)
        interest_indices = bin_indices(bin_is_interest);
        prb_sum_interest(i) = sum(prb_physync(interest_indices)) / length(bin_indices);
    end
    
    % Calculate average PRB for other UEs in this bin
    if any(~bin_is_interest)
        other_indices = bin_indices(~bin_is_interest);
        prb_sum_others(i) = sum(prb_physync(other_indices)) / length(bin_indices);
    end
end

% Convert bin indices to seconds for x-axis
time_bins = unique_bins * (bin_sz_phy/1000);

% Create stacked bar chart
b = bar(time_bins, [prb_sum_interest' prb_sum_others'], 'stacked');
b(1).FaceColor = 'b'; % UEs of interest in blue
b(2).FaceColor = 'r'; % Other UEs in red

ylabel('Average PRB')
grid on
title('Physical Layer Metrics')
legend('UEs of interest', 'Other UEs', 'Location', 'NorthEast')

% Plot 7: TBS with Bars by RNTI (UEs of interest only)
curr_pos = 7;
ax(curr_pos) = subplot('Position', [0.1, 1 - top_margin - curr_pos*(plot_region/num_plots), 0.8, (plot_region/num_plots)*0.9]);

% Fixed color array for up to 8 RNTIs
colors = [
    0    0.4470 0.7410; % Blue
    0.8500 0.3250 0.0980; % Orange
    0.9290 0.6940 0.1250; % Yellow
    0.4940 0.1840 0.5560; % Purple
    0.4660 0.6740 0.1880; % Green
    0.3010 0.7450 0.9330; % Light blue
    0.6350 0.0780 0.1840; % Dark red
    0    0.75   0.75  ; % Teal
];

% Get unique RNTIs of interest
unique_RNTIs = RNTIs_of_interest;
num_RNTIs = length(unique_RNTIs);

% Group TBS data by bin_size
ts_binned = floor((ts_physync - min(ts_physync))/bin_sz_phy);
unique_bins = unique(ts_binned);
tbs_by_rnti = zeros(length(unique_bins), num_RNTIs);

% Calculate TBS for each RNTI in each time bin
for r = 1:num_RNTIs
    % Get current RNTI
    current_rnti = unique_RNTIs(r);
    
    % Find all data points for this RNTI
    idx_rnti = find(rntis_physync == current_rnti);
    
    if ~isempty(idx_rnti)
        % Get timestamps and TBS values for this RNTI
        ts_this_rnti = ts_physync(idx_rnti);
        tbs_this_rnti = tbs_physync(idx_rnti);
        
        % Bin the data for this RNTI
        ts_bins_this_rnti = floor((ts_this_rnti - min(ts_physync))/bin_sz_phy);
        
        % Calculate TBS for each bin
        for i = 1:length(unique_bins)
            bin_idx = ts_bins_this_rnti == unique_bins(i);
            if any(bin_idx)
                % Convert to Mbps
                tbs_by_rnti(i, r) = (sum(tbs_this_rnti(bin_idx))/bin_sz_phy) * (1000/1e6);
            end
        end
    end
end

% Convert bin indices to seconds for x-axis
time_bins = unique_bins * (bin_sz_phy/1000);

% Create stacked bar chart
b = bar(time_bins, tbs_by_rnti, 'stacked');

% Set colors for each RNTI (handle case with more than 8 RNTIs)
for r = 1:min(num_RNTIs, 8)
    b(r).FaceColor = colors(r,:);
end

% If there are more than 8 RNTIs (unlikely but handle it)
if num_RNTIs > 8
    % Generate additional colors using HSV colorspace
    for r = 9:num_RNTIs
        b(r).FaceColor = hsv2rgb([(r-1)/num_RNTIs, 0.8, 0.9]);
    end
end

% Create legend labels
legend_text = cell(1, num_RNTIs);
for r = 1:num_RNTIs
    legend_text{r} = ['RNTI ' num2str(unique_RNTIs(r))];
end

ylabel('TBS (Mbps)')
title('TBS by RNTI (UEs of Interest)')
grid on
legend(legend_text, 'Location', 'NorthEast')

% Plot 8: MCS (raw values) vs Time (UEs of interest only)
curr_pos = 8;
ax(curr_pos) = subplot('Position', [0.1, 1 - top_margin - curr_pos*(plot_region/num_plots), 0.8, (plot_region/num_plots)*0.9]);

% Convert timestamps to seconds for x-axis (UEs of interest)
ts_phy_seconds_interest = (ts_physync_interest - min(ts_physync))/1000;  % Convert to seconds

% Plot raw MCS values for UEs of interest
plot(ts_phy_seconds_interest, mcs_physync_interest, 'g.', 'MarkerSize', 4)  % Blue dots for UEs of interest
ylabel('MCS')
title('UEs of Interest Only')
grid on

% Plot 9: PHY Retransmission Delay (UEs of interest only)
curr_pos = 9;
ax(curr_pos) = subplot('Position', [0.1, 1 - top_margin - curr_pos*(plot_region/num_plots), 0.8, (plot_region/num_plots)*0.9]);

% Plot raw delay_physync data for UEs of interest
ts_phy_interest = (ts_physync_interest - min(ts_physync))/1000;  % Convert to seconds
plot(ts_phy_interest, delay_physync_interest, 'b', 'LineWidth', 1.5)
ylabel('PHY Retx Delay (ms)')
title('UEs of Interest Only')
xlabel('Time (s)')
grid on

% Adjust overall figure appearance
set(gcf, 'Color', 'w');
set(gcf, 'PaperUnits', 'inches');
set(gcf, 'PaperSize', [12 15]);  % Increased height
set(gcf, 'PaperPosition', [0 0 12 15]);  % Increased height


%% plot app in
% Create the second figure with increased height
figure(2);
set(gcf, 'Position', [150, 150, 1200, 1500]);  % Increased height to 1500
num_plots = 5; 
% Create an array to store all subplot axes
ax1 = zeros(num_plots,1);  % Array to store subplot axes

% Create subplot layout
subplot_heights = ones(1, num_plots);  % Equal heights for all plots
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


% Adjust overall figure appearance
set(gcf, 'Color', 'w');
set(gcf, 'PaperUnits', 'inches');
set(gcf, 'PaperSize', [12 15]);
set(gcf, 'PaperPosition', [0 0 12 15]);


%% plot app pc
% Create the third figure with increased height
figure(3);
set(gcf, 'Position', [200, 200, 1200, 1500]);  % Adjusted height for 9 subplots
num_plots = 9;  % Reduced from 10 to 9 (removed BSR plot)
% Create an array to store all subplot axes
ax2 = zeros(num_plots,1);

% Create subplot layout
subplot_heights = ones(1, num_plots);  % Equal heights for all plots
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

% Plot 5: PRB with Stacked Bars (UEs of interest vs Others)
curr_pos = 5;
ax2(curr_pos) = subplot('Position', [0.1, 1 - top_margin - curr_pos*(plot_region/num_plots), 0.8, (plot_region/num_plots)*0.9]);

% Group PRB data by bin_size
ts_binned = floor((ts_physync - min(ts_physync))/bin_sz_phy);
unique_bins = unique(ts_binned);

% Initialize arrays for UEs of interest and other UEs
prb_sum_interest = zeros(size(unique_bins));
prb_sum_others = zeros(size(unique_bins));

% Process each time bin
for i = 1:length(unique_bins)
    bin_indices = find(ts_binned == unique_bins(i));
    
    % Get which entries in this bin belong to UEs of interest
    bin_is_interest = is_interest_ue(bin_indices);
    
    % Calculate average PRB for UEs of interest in this bin
    if any(bin_is_interest)
        interest_indices = bin_indices(bin_is_interest);
        prb_sum_interest(i) = sum(prb_physync(interest_indices)) / length(bin_indices);
    end
    
    % Calculate average PRB for other UEs in this bin
    if any(~bin_is_interest)
        other_indices = bin_indices(~bin_is_interest);
        prb_sum_others(i) = sum(prb_physync(other_indices)) / length(bin_indices);
    end
end

% Convert bin indices to seconds for x-axis
time_bins = unique_bins * (bin_sz_phy/1000);

% Create stacked bar chart
b = bar(time_bins, [prb_sum_interest' prb_sum_others'], 'stacked');
b(1).FaceColor = 'b'; % UEs of interest in blue
b(2).FaceColor = 'r'; % Other UEs in red

ylabel('Average PRB')
grid on
title('Physical Layer Metrics')
legend('UEs of interest', 'Other UEs', 'Location', 'NorthEast')

% Plot 6: TBS with Bars (UEs of interest only)
curr_pos = 6;
ax2(curr_pos) = subplot('Position', [0.1, 1 - top_margin - curr_pos*(plot_region/num_plots), 0.8, (plot_region/num_plots)*0.9]);

% Group TBS data by bin_size for UEs of interest
ts_binned_interest = floor((ts_physync_interest - min(ts_physync))/bin_sz_phy);
unique_bins_interest = unique(ts_binned); % Use same bins as original for consistency
tbs_sum_interest = zeros(size(unique_bins_interest));

% Calculate TBS sum for UEs of interest for each bin
for i = 1:length(unique_bins_interest)
    idx = find(ts_binned_interest == unique_bins_interest(i));
    if ~isempty(idx)
        % Convert to MBits/second: divide by bin_size(ms) and multiply by 1000(ms/s), then divide by 1000 for K to M
        tbs_sum_interest(i) = (sum(tbs_physync_interest(idx))/bin_sz_phy) * (1000/1e6);
    end
end

% Plot TBS for UEs of interest
time_bins = unique_bins_interest * (bin_sz_phy/1000);
bar(time_bins, tbs_sum_interest, 'b')
ylabel('TBS (Mbps)')
title('UEs of Interest Only')
grid on

% Plot 7: MCS (raw values) vs Time (UEs of interest only)
curr_pos = 7;
ax2(curr_pos) = subplot('Position', [0.1, 1 - top_margin - curr_pos*(plot_region/num_plots), 0.8, (plot_region/num_plots)*0.9]);

% Convert timestamps to seconds for x-axis (UEs of interest)
ts_phy_seconds_interest = (ts_physync_interest - min(ts_physync))/1000;  % Convert to seconds

% Plot raw MCS values for UEs of interest
plot(ts_phy_seconds_interest, mcs_physync_interest, 'g.', 'MarkerSize', 4)  % Blue dots for UEs of interest
ylabel('MCS')
title('UEs of Interest Only')
grid on

% Plot 8: PHY Retransmission Delay (UEs of interest only)
curr_pos = 8;
ax2(curr_pos) = subplot('Position', [0.1, 1 - top_margin - curr_pos*(plot_region/num_plots), 0.8, (plot_region/num_plots)*0.9]);

% Plot raw delay_physync data for UEs of interest
ts_phy_interest = (ts_physync_interest - min(ts_physync))/1000;  % Convert to seconds
plot(ts_phy_interest, delay_physync_interest, 'b', 'LineWidth', 1.5)
ylabel('PHY Retx Delay (ms)')
title('UEs of Interest Only')
grid on

% Plot 9: Compare (APP vs PHY Layer Cumulative Bits for UEs of interest only)
curr_pos = 9;
ax2(curr_pos) = subplot('Position', [0.1, 1 - top_margin - curr_pos*(plot_region/num_plots), 0.8, (plot_region/num_plots)*0.9]);

ts_app_binned = floor((ts_apppc_range - min(ts_apppc_range))/bin_sz_wrap);
ts_phy_binned_interest = floor((ts_physync_interest - min(ts_physync))/bin_sz_wrap);

unique_bins_app = unique(ts_app_binned);
unique_bins_phy_interest = unique(ts_phy_binned_interest);

% Initialize arrays to store all bin data
all_app_curves = cell(length(unique_bins_app), 1);
all_phy_curves = cell(length(unique_bins_phy_interest), 1);
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

% Process PHY layer data (tbs_physync_interest) - UEs of interest only
for i = 1:length(unique_bins_phy_interest)
    idx = ts_phy_binned_interest == unique_bins_phy_interest(i);
    if any(idx)
        % Get TBS values in this bin (UEs of interest only)
        tbs_in_bin = tbs_physync_interest(idx) * 0.88;
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

for i = 1:length(unique_bins_phy_interest)
    if ~isempty(all_phy_curves{i})
        phy_curve = all_phy_curves{i};
        time_points = linspace(unique_bins_phy_interest(i), unique_bins_phy_interest(i) + 1, length(phy_curve));
        plot(time_points, phy_curve, 'r--', 'LineWidth', 1.5)
    end
end

ylabel('Cumulative Bits within Bin')
xlabel('Time (s)')
grid on
% Create invisible lines just for legend
h1 = plot(NaN,NaN, 'b-', 'LineWidth', 1.5);
h2 = plot(NaN,NaN, 'r--', 'LineWidth', 1.5);
legend([h1, h2], 'APP Layer', 'PHY Layer (UEs of Interest)', 'Location', 'northwest')
title('APP vs PHY Layer Cumulative Bits Comparison (UEs of Interest)')


% linkaxes(ax2, 'x');

% Adjust figure appearance
set(gcf, 'Color', 'w');
set(gcf, 'PaperUnits', 'inches');
set(gcf, 'PaperSize', [12 18]);  % Increased height
set(gcf, 'PaperPosition', [0 0 12 18]);  % Increased height

%% figure 4 & 5 & 6: GCC trendline estimator
% hPlotGCC_RFC(ts_ue, ts_server, delay_pkt);
hPlotGCC_Sim(ts_ue-min(ts_ue), ts_server-min(ts_ue), pkt_size);
hPlotGCC_Src(plot_period(1), plot_period(2), expCode, appCode, data_packets(1, 14), 'U');
hPlotGCC_Src(plot_period(1), plot_period(2), expCode, appCode, data_packets(1, 14), 'D');


%% Figure 7: the capacity comparison plot function

% Define bin size for figure 7
bin_size_fig7 = 100; % 1000ms (1s) bin size
% Get target bitrate data within plot period
appout_idx = (ts_appout_range >= plot_period(1)) & (ts_appout_range <= plot_period(2));
target_bitrate = data_appout(appout_idx, 14)/1e6; % Convert to Mbps
ts_target = ts_appout_range(appout_idx);

% Call the function with the appropriate parameters
hPlot_CapComp(plot_period(1), plot_period(2), ts_physync, tbs_physync, ts_ue, pkt_size, ts_target, target_bitrate, bin_size_fig7);

%% Figure 8: bsr
if ismember(expCode, amarisoft) && strcmp(linktype, 'U')
    figure(8);
    bsrlow_physync = [dci_log(phy_st:phy_ed).bsr_low];
    bsrhigh_physync = [dci_log(phy_st:phy_ed).bsr_high];    

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
end

%% Create Figure 8 using the hPlotPRB function
% Call the PRB Allocation plotting function
% hPlotPRB(plot_period(1), plot_period(2), ts_physync, prb_st_physync, prb_physync);

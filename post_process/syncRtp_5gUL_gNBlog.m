%% Data preparation
clear;close all

% Define parameters
expCode = '0110';
experiment_name = ['webrtc-' expCode];
enb2sfu_delay = 0.0;
time_drifting = 1; % 1ms
header_len = 34; % 34 bytes

% read packets data
filename = ['../data_webrtc/data_exp' expCode '/' experiment_name '-join-pkts-up.csv'];
headers = readcell(filename, 'Range', '1:1');  % Read only the first row
data_packets = readmatrix(filename, 'Range', 2);  % Skip the first row
ts_pktOffset = data_packets(1, 1)*1000;

% read PHY data
savePath = ['../data_webrtc/data_exp' expCode '/UL_tbs_delay_' expCode '.mat'];
load(savePath);
ts_dcilog = [dci_log.ts] - ts_pktOffset - time_drifting; % in unit of ms, dci0/pusch timing is 4ms



%% Thrpt/Delay Analysis
ts_ue_st = floor(data_packets(1,12));
plot_period = [ts_ue_st+100001, ts_ue_st+200000]; 

% obtaining PHY data
% idx within plot_period
phy_st = find(ts_dcilog > plot_period(1), 1, 'first');
phy_ed = find(ts_dcilog < plot_period(2), 1, 'last');

ts_physync = ts_dcilog(phy_st:phy_ed);
delay_physync = [dci_log(phy_st:phy_ed).delay];
tbs_physync = [dci_log(phy_st:phy_ed).tbs];

n_tx_physync = [dci_log(phy_st:phy_ed).n_tx];
valid_idx = n_tx_physync > 0;
ts_physync = ts_physync(valid_idx);
delay_physync = delay_physync(valid_idx);
tbs_physync = tbs_physync(valid_idx);

% obtaining packets data
pkt_st = find(data_packets(:, 13) > plot_period(1), 1, 'first');
pkt_ed = find(data_packets(:, 13) < plot_period(2), 1, 'last');

ts_ue = data_packets(pkt_st:pkt_ed, 12);
ts_core = data_packets(pkt_st:pkt_ed, 13);
delay_core = data_packets(pkt_st:pkt_ed, 14);
pkt_len = data_packets(pkt_st:pkt_ed, 7)*8; % in bits

% Calculate pkt data into bins
binEdges = plot_period(1):0.5:plot_period(2); % Define bin edges, 0.5ms width
binMidpoints = (binEdges(1:end-1) + binEdges(2:end)) / 2;
bins = discretize(ts_core, binEdges); % Assign each core timestamp to a bin
numPacketsPerBin = zeros(length(binEdges)-1, 1); % Initialize arrays to store results
totalBitsPerBin = zeros(length(binEdges)-1, 1);
minDelayPerBin = zeros(length(binEdges)-1, 1);
maxDelayPerBin = zeros(length(binEdges)-1, 1);
% Calculate metrics for each bin
for i = 1:length(binEdges)-1
    idx = (bins == i); % Logical index of packets in the current bin
    if any(idx)
        numPacketsPerBin(i) = sum(idx);
        totalBitsPerBin(i) = sum(pkt_len(idx));
        minDelayPerBin(i) = min(delay_core(idx));
        maxDelayPerBin(i) = max(delay_core(idx));
    else
        numPacketsPerBin(i) = 0;
        totalBitsPerBin(i) = 0;
        minDelayPerBin(i) = -1;
        maxDelayPerBin(i) = -1;
    end
end


figure(1);
p1 = plot(ts_physync, tbs_physync, '-o', 'MarkerSize', 4, 'MarkerEdgeColor', 'blue');hold on
p2 = plot(binMidpoints, totalBitsPerBin);hold on
title('Bits delivered/PHY TBS (in 0.5ms bins)');
xlabel('Timestamp (ms)', 'FontSize', 20);
ylabel('Bits delivered', 'FontSize', 20);
legend('PHY','Packet');
set(gca, 'FontSize', 20);

figure(2);
d1 = plot(ts_physync, delay_physync);hold on
d2 = plot(ts_core, delay_core, '-d');hold on
title('Packet delay/PHY Retransmission');
xlabel('Timestamp (ms)', 'FontSize', 20);
ylabel('Delay', 'FontSize', 20);
legend('PHY ReTX','Delay UE-SFU');
set(gca, 'FontSize', 20);


%% CDF of packet delays with and without PHY layer retransmissions
ts_ue_st = floor(data_packets(1,12));
plot_period = [ts_ue_st+100001, ts_ue_st+200000]; 

% obtaining PHY data
phy_st = find(ts_dcilog > plot_period(1), 1, 'first');
phy_ed = find(ts_dcilog < plot_period(2), 1, 'last');

ts_physync = ts_dcilog(phy_st:phy_ed);
delay_physync = [dci_log(phy_st:phy_ed).delay];
ntx_physync = [dci_log(phy_st:phy_ed).n_tx];

% obtaining packets data
pkt_st = find(data_packets(:, 13) > plot_period(1), 1, 'first');
pkt_ed = find(data_packets(:, 13) < plot_period(2), 1, 'last');

ts_core = data_packets(pkt_st:pkt_ed, 13);
delay_core = data_packets(pkt_st:pkt_ed, 14);


% Define range left and right for classifying packets
left = 0; 
right = 5;  

% Identify retransmission events
retx_idx = find(ntx_physync > 1);

% Calculate retransmission end times
retx_end_times = ts_physync(retx_idx);

% Define the range for proximity check
range_start = retx_end_times + left;
range_end = retx_end_times + right;

% Initialize logical arrays for packet classification
with_retx_logical = false(size(ts_core));
without_retx_logical = true(size(ts_core));

% Check packet timestamps against all retransmission ranges
for i = 1:length(range_start)
    with_retx_logical = with_retx_logical | (ts_core >= range_start(i) & ts_core <= range_end(i));
end

% Update without_retx_logical array
without_retx_logical = ~with_retx_logical;

% Extract delays for the two categories
with_retx_delays = delay_core(with_retx_logical);
without_retx_delays = delay_core(without_retx_logical);

% Calculate and plot the CDF
% figure(3);
% cdfplot(with_retx_delays); hold on;
% cdfplot(without_retx_delays);
% title('CDF of Packet Delays with and without PHY Retransmissions');
% xlabel('Delay (ms)', 'FontSize', 20);
% ylabel('CDF', 'FontSize', 20);
% legend('With PHY ReTX', 'Without PHY ReTX');
% set(gca, 'FontSize', 20);



%% Sync Plot: scheduling
ts_ue_st = floor(data_packets(1,12));
% 
plot_period = [169494, 169694]; 
% obtaining PHY data
phy_st = find(ts_dcilog > plot_period(1), 1, 'first');
phy_ed = find(ts_dcilog < plot_period(2), 1, 'last');

ts_physync = ts_dcilog(phy_st:phy_ed)-plot_period(1);
delay_physync = [dci_log(phy_st:phy_ed).delay];
tbs_physync = [dci_log(phy_st:phy_ed).tbs];
bsr_low_sync = [dci_log(phy_st:phy_ed).bsr_low];
bsr_high_sync = [dci_log(phy_st:phy_ed).bsr_high];

n_tx_physync = [dci_log(phy_st:phy_ed).n_tx];
valid_idx = n_tx_physync >= 1;
ts_valid = ts_physync(valid_idx);

ts_1tx = ts_physync(n_tx_physync == 1);
tbs_1tx = tbs_physync(n_tx_physync == 1);

ts_retx = ts_physync(n_tx_physync > 1);
delay_retx = delay_physync(n_tx_physync > 1);
tbs_retx = tbs_physync(n_tx_physync > 1);

ts_failed = ts_retx - delay_retx;
tbs_failed = tbs_retx;

% obtaining packets data
pkt_st = find(data_packets(:, 12) > plot_period(1), 1, 'first');
pkt_ed = find(data_packets(:, 12) < plot_period(2), 1, 'last');

ts_ue = data_packets(pkt_st:pkt_ed, 12);
ts_core = data_packets(pkt_st:pkt_ed, 13);
delay_core = data_packets(pkt_st:pkt_ed, 14);
pkt_len = data_packets(pkt_st:pkt_ed, 7)*8;

format long g
figure(3);

% Packet plot (top)
ax1 = subplot(3, 1, 1); 
hold on;

% Bar plot
% Obtaining packet/phy data
bar_pkt = data_packets(pkt_st:pkt_ed, :);
bar_pkt(:,12) = bar_pkt(:,12)-plot_period(1);
bar_pkt(:,13) = bar_pkt(:,13)-plot_period(1);
bar_phy = [ts_dcilog(phy_st:phy_ed); [dci_log(phy_st:phy_ed).tbs]]';

% Sync pkt to phy
ts_phy_sync = zeros(size(bar_pkt,1), 1);
% Loop through each row in bar_data
for i = 1:size(bar_pkt, 1)
    temp_ts_enb = bar_pkt(i, 13)-enb2sfu_delay;
    temp_idx_phy = find(ts_valid < temp_ts_enb, 1, 'last');

    ts_phy_sync(i,1) = ts_valid(temp_idx_phy);
end

% Define the stream IDs, ssrc
streams = unique(bar_pkt(:, 3));
% Define a custom colormap with distinct colors
colors = [
    114, 147, 203; % Light Blue
    204,  37,  41; % Red
    237, 177,  32; % Yellow
    126,  47, 142; % Purple
    132, 186,  91; % Green
    171, 104,  87; % Brown
]./255;
if numel(streams) > size(colors, 1)
    error('Not enough colors defined for the number of streams.');
end

% Initialize a vector to store the handles for the legend
hLegend = zeros(numel(streams), 1);
% Loop through each packet
for i = 1:size(bar_pkt, 1)
    % Find the index of the stream for the current packet
    streamIndex = find(streams == bar_pkt(i, 3));
    % Get the bar start and end positions and the y-axis position
    xStart = bar_pkt(i, 12);
    xEnd = bar_pkt(i, 13);
    yPos = bar_pkt(i, 15);  
    % Draw the line for the packet
    hLine = line([xStart, xEnd], [yPos, yPos], 'Color', colors(streamIndex, :), 'LineWidth', 2);
    hLegend(streamIndex) = hLine;
    % Draw the first vertical line at packet_sync(i, 1)
    xV1 = ts_phy_sync(i, 1);
    line([xV1, xV1], [yPos - 0.6, yPos + 0.6], 'Color', colors(streamIndex, :), 'LineWidth', 2);
end

% Add legend
legend(hLegend, arrayfun(@(x) ['Stream ', num2str(x)], streams, 'UniformOutput', false));
% Set the axes labels
xlabel('Time (ms)', 'FontName', 'Times New Roman', 'FontSize', 24);
ylabel('RTP Packet Index', 'FontName', 'Times New Roman', 'FontSize', 24);
set(gca, 'FontName', 'Times New Roman', 'FontSize', 24);
hold off;

% PHY plot (middle)
ax2 = subplot(3, 1, 2); 
% Create bar plots
bar(ts_1tx, tbs_1tx, 'FaceColor', [0 0.4470 0.7410], 'EdgeColor', [0 0.4470 0.7410], 'BarWidth', 0.8); hold on
bar(ts_failed, tbs_failed, 'FaceColor', 'red', 'EdgeColor', 'red', 'BarWidth', 0.8); hold on
bar(ts_retx, tbs_retx, 'FaceColor', [0.4940 0.1840 0.5560], 'EdgeColor', [0.4940 0.1840 0.5560], 'BarWidth', 0.8); hold on
xlabel('Time (ms)', 'FontName', 'Times New Roman', 'FontSize', 24);
ylabel('TBS (bits)', 'FontName', 'Times New Roman', 'FontSize', 24);
legend('TB', 'TB Failed', 'TB RTX');
ylim([0,20000]);
set(gca, 'FontName', 'Times New Roman', 'FontSize', 24);

% BSR plot (bottom)
ax3 = subplot(3, 1, 3);
hold on;

% Plot BSR ranges where bsr_high is non-zero
for i = 1:length(ts_physync)
    if bsr_high_sync(i) > 0
        % Plot vertical line
        line([ts_physync(i) ts_physync(i)], [bsr_low_sync(i) bsr_high_sync(i)], ...
            'Color', 'blue', 'LineWidth', 2);
        % Plot horizontal lines at ends
        line([ts_physync(i)-0.2 ts_physync(i)+0.2], [bsr_low_sync(i) bsr_low_sync(i)], ...
            'Color', 'blue', 'LineWidth', 2);
        line([ts_physync(i)-0.2 ts_physync(i)+0.2], [bsr_high_sync(i) bsr_high_sync(i)], ...
            'Color', 'blue', 'LineWidth', 2);
    end
end

xlabel('Time (ms)', 'FontName', 'Times New Roman', 'FontSize', 24);
ylabel('BSR Range (bytes)', 'FontName', 'Times New Roman', 'FontSize', 24);
set(gca, 'FontName', 'Times New Roman', 'FontSize', 24);
hold off;

% Link x-axes of all three subplots
linkaxes([ax1, ax2, ax3], 'x');

% Adjust the paper size and subplot spacing
% Define the paper size (in inches)
paperWidth = 30;
paperHeight = 25; % Increased to accommodate third subplot
set(gcf, 'PaperSize', [paperWidth paperHeight]);

% Adjust spacing between subplots
set(gcf, 'Position', [100, 100, 1200, 900]); % Adjust figure size
spacing = 0.08; % Adjust this value to change spacing between subplots
height = 0.25; % Height of each subplot

% Position subplots
set(ax1, 'Position', [0.1, 0.7, 0.8, height]);
set(ax2, 'Position', [0.1, 0.4, 0.8, height]);
set(ax3, 'Position', [0.1, 0.1, 0.8, height]);
%% Data preparation
clear;

% Define parameters
expCode = '0625_1';
experiment_name = ['zoom-' expCode];
enb2sfu_delay = 0.0;
time_drifting = -2; % 1ms
header_len = 34; % 34 bytes

% read packets data
filename = ['../data_zoom/data_exp' expCode '/' experiment_name '-join-pkts-up.csv'];
headers = readcell(filename, 'Range', '1:1');  % Read only the first row
data_packets = readmatrix(filename, 'Range', 2);  % Skip the first row
ts_pktOffset = data_packets(1, 1)*1000;

% read PHY data
savePath = ['../data_zoom/data_exp' expCode '/UL_tbs_delay_' expCode '.mat'];
load(savePath);
ts_dcilog = [dci_log.ts] - ts_pktOffset + [dci_log.k]/2 - time_drifting; % in unit of ms, dci0/pusch timing is 4ms



%% Thrpt/Delay Analysis
ts_ue_st = floor(data_packets(1,12));
% plot_period = [data_packets(1, 13), data_packets(end, 13)]; 
plot_period = [data_packets(1, 13)+750001, data_packets(1, 13)+900000]; 

% obtaining PHY data
% idx within plot_period
phy_st = find(ts_dcilog > plot_period(1), 1, 'first');
phy_ed = find(ts_dcilog < plot_period(2), 1, 'last');

ts_physync = ts_dcilog(phy_st:phy_ed);
mcs_physync = [dci_log(phy_st:phy_ed).mcs];
prb_physync = [dci_log(phy_st:phy_ed).prb];
delay_physync = [dci_log(phy_st:phy_ed).delay]; 
tbs_physync = [dci_log(phy_st:phy_ed).tbs];

n_tx_physync = [dci_log(phy_st:phy_ed).n_tx];
valid_idx = n_tx_physync > 0;
ts_physync = ts_physync(valid_idx);
mcs_physync = mcs_physync(valid_idx);
prb_physync = prb_physync(valid_idx);
delay_physync = delay_physync(valid_idx); 
tbs_physync = tbs_physync(valid_idx);

% obtaining packets data
pkt_st = find(data_packets(:, 13) > plot_period(1), 1, 'first');
pkt_ed = find(data_packets(:, 13) < plot_period(2), 1, 'last');

ts_ue = data_packets(pkt_st:pkt_ed, 12);
ts_core = data_packets(pkt_st:pkt_ed, 13);
delay_core = data_packets(pkt_st:pkt_ed, 14);
pkt_len = (data_packets(pkt_st:pkt_ed, 7)+header_len)*8;

% % Calculate pkt data into bins
% binEdges = plot_period(1):0.5:plot_period(2); % Define bin edges, 0.5ms width
% binMidpoints = (binEdges(1:end-1) + binEdges(2:end)) / 2;
% bins = discretize(ts_core, binEdges); % Assign each core timestamp to a bin
% numPacketsPerBin = zeros(length(binEdges)-1, 1); % Initialize arrays to store results
% totalBitsPerBin = zeros(length(binEdges)-1, 1);
% minDelayPerBin = zeros(length(binEdges)-1, 1);
% maxDelayPerBin = zeros(length(binEdges)-1, 1);
% % Calculate metrics for each bin
% for i = 1:length(binEdges)-1
%     idx = (bins == i); % Logical index of packets in the current bin
%     if any(idx)
%         numPacketsPerBin(i) = sum(idx);
%         totalBitsPerBin(i) = sum(pkt_len(idx));
%         minDelayPerBin(i) = min(delay_core(idx));
%         maxDelayPerBin(i) = max(delay_core(idx));
%     else
%         numPacketsPerBin(i) = 0;
%         totalBitsPerBin(i) = 0;
%         minDelayPerBin(i) = -1;
%         maxDelayPerBin(i) = -1;
%     end
% end


% figure(1);
% p1 = plot(ts_physync, tbs_physync, '-o', 'MarkerSize', 4, 'MarkerEdgeColor', 'blue');hold on
% p2 = plot(binMidpoints, totalBitsPerBin);hold on
% title('Bits delivered/PHY TBS (in 0.5ms bins)');
% xlabel('Timestamp (ms)', 'FontSize', 20);
% ylabel('Bits delivered', 'FontSize', 20);
% legend('PHY','Packet');
% set(gca, 'FontSize', 20);
% 
% figure(2);
% d1 = plot(ts_physync, delay_physync);hold on
% d2 = plot(ts_core, delay_core, '-d');hold on
% title('Packet delay/PHY Retransmission');
% xlabel('Timestamp (ms)', 'FontSize', 20);
% ylabel('Delay', 'FontSize', 20);
% legend('PHY ReTX','Delay UE-SFU');
% set(gca, 'FontSize', 20);


%% bin tbs
% Find the start and end times
start_time = floor(min(ts_physync)/100)*100;  % Round down to nearest 100ms
end_time = ceil(max(ts_physync)/100)*100;     % Round up to nearest 100ms

% Create bin edges (100ms intervals)
bin_edges = start_time:100:end_time;

% Use histcounts to get the binning indices
[~, ~, bin_indices] = histcounts(ts_physync, bin_edges);

% Create ts_bin (center of each bin)
ts_bin = (bin_edges(1:end-1) + bin_edges(2:end))/2;

% Sum tbs values for each bin
tbs_bin = zeros(1, length(ts_bin));
for i = 1:length(ts_bin)
    tbs_bin(i) = sum(tbs_physync(bin_indices == i));
end

% Remove empty bins if desired
non_empty = tbs_bin > 0;
ts_bin = ts_bin(non_empty);
tbs_bin = tbs_bin(non_empty);


% Create the header
headers = {'ts', 'mcs', 'prb', 'tbs', 'ReTX_delay'};
% Combine all arrays into a matrix
data_matrix = [ts_physync', mcs_physync', prb_physync', tbs_physync', delay_physync'];
% Create a table with headers
T = array2table(data_matrix, 'VariableNames', headers);
% Write to CSV file
raw_file_name = ['../data_zoom/data_exp' expCode '/raw_tbs.csv'];
writetable(T, raw_file_name);

% Create the header
headers = {'ts_bin', 'tbs_bin'};
% Combine all arrays into a matrix
data_matrix = [ts_bin', tbs_bin'];
% Create a table with headers
T2 = array2table(data_matrix, 'VariableNames', headers);
% Write to CSV file
bin_file_name = ['../data_zoom/data_exp' expCode '/bin_tbs.csv'];
writetable(T2, bin_file_name);


figure(3);
subplot(4,1,1);
plot(ts_core, delay_core);
xlabel('Timestamp (ms)', 'FontSize', 20);
ylabel('Overall Delay(ms)', 'FontSize', 20);
set(gca, 'FontSize', 20);
set(gca, 'YScale', 'log');  % Set y-axis to log scale
set(gca, 'YTick', [10 100 1000]);  % Set specific tick values
xlim(plot_period);

subplot(4,1,2);
plot(ts_physync, mcs_physync);
xlabel('Time (ms)', 'FontSize', 20);
ylabel('MCS', 'FontSize', 20);
set(gca, 'FontSize', 20);
xlim(plot_period);

subplot(4,1,3);
plot(ts_physync, prb_physync);
xlabel('Time (ms)', 'FontSize', 20);
ylabel('Number of PRB', 'FontSize', 20);
set(gca, 'FontSize', 20);
xlim(plot_period);

% subplot(5,1,4);
% plot(ts_bin, tbs_bin);
% xlabel('Time (ms)', 'FontSize', 20);
% ylabel('TBS', 'FontSize', 20);
% set(gca, 'FontSize', 20);
% xlim(plot_period);

subplot(4,1,4);
plot(ts_physync, delay_physync);
xlabel('Time (ms)', 'FontSize', 20);
ylabel('ReTX Delay(ms)', 'FontSize', 20);
set(gca, 'FontSize', 20);
xlim(plot_period);

%% CDF of packet delays with and without PHY layer retransmissions
ts_ue_st = floor(data_packets(1,12));
plot_period = [ts_ue_st+400001, ts_ue_st+500000]; 

% obtaining PHY data
phy_st = find(ts_dcilog > plot_period(1), 1, 'first');
phy_ed = find(ts_dcilog < plot_period(2), 1, 'last');

ts_physync = ts_dcilog(phy_st:phy_ed);
delay_physync = [dci_log(phy_st:phy_ed).delay];
ntx_physync = [dci_log(phy_st:phy_ed).n_tx];

% obtaining packets data
pkt_st = find(data_packets(:, 13) > plot_period(1), 1, 'first');
pkt_ed = find(data_packets(:, 13) < plot_period(2), 1, 'last');

ts_ue = data_packets(pkt_st:pkt_ed, 12);
delay_core = data_packets(pkt_st:pkt_ed, 14);


% Define range left and right for classifying packets
left = -1; 
right = 3;  

% Identify retransmission events
retx_idx = find(ntx_physync > 1);

% Calculate retransmission start times
retx_start_times = ts_physync(retx_idx) - [delay_physync(retx_idx)];

% Define the range for proximity check
range_start = retx_start_times + left;
range_end = retx_start_times + right;

% Initialize logical arrays for packet classification
with_retx_logical = false(size(ts_ue));
without_retx_logical = true(size(ts_ue));

% Check packet timestamps against all retransmission ranges
for i = 1:length(range_start)
    with_retx_logical = with_retx_logical | (ts_ue >= range_start(i) & ts_ue <= range_end(i));
end

% Update without_retx_logical array
without_retx_logical = ~with_retx_logical;

% Extract delays for the two categories
with_retx_delays = delay_core(with_retx_logical);
without_retx_delays = delay_core(without_retx_logical);

% Calculate and plot the CDF
figure(3);
cdfplot(with_retx_delays); hold on;
cdfplot(without_retx_delays);
title('CDF of Packet Delays with and without PHY Retransmissions');
xlabel('Delay (ms)', 'FontSize', 20);
ylabel('CDF', 'FontSize', 20);
legend('With PHY ReTX', 'Without PHY ReTX');
set(gca, 'FontSize', 20);


%% Sync Plot: scheduling
ts_ue_st = floor(data_packets(1,12));
% scheduling for paper e.g.: [16499, 16631] 
% scheduling for review e.g.: [ts_ue_st+014001, ts_ue_st+019000]
% retx for review e.g.: [ts_ue_st+400001, ts_ue_st+405000], 404190
plot_period = [16499, 16631]; 
% obtaining PHY data
phy_st = find(ts_dcilog > plot_period(1), 1, 'first');
phy_ed = find(ts_dcilog < plot_period(2), 1, 'last');

ts_physync = ts_dcilog(phy_st:phy_ed)-plot_period(1);
delay_physync = [dci_log(phy_st:phy_ed).delay];
tbs_physync = [dci_log(phy_st:phy_ed).tbs];

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
pkt_len = (data_packets(pkt_st:pkt_ed, 7)+header_len)*8;

format long g
figure(3);
% phy plot
ax1 = subplot(2, 1, 2); 
% Create bar plots
bar(ts_1tx, tbs_1tx, 'FaceColor', [0 0.4470 0.7410], 'EdgeColor', [0 0.4470 0.7410], 'BarWidth', 0.8); hold on
bar(ts_failed, tbs_failed, 'FaceColor', 'red', 'EdgeColor', 'red', 'BarWidth', 0.8); hold on
bar(ts_retx, tbs_retx, 'FaceColor', [0.4940 0.1840 0.5560], 'EdgeColor', [0.4940 0.1840 0.5560], 'BarWidth', 0.8); hold on
xlabel('Timestamp (ms)', 'FontName', 'Times New Roman', 'FontSize', 24);
ylabel('TBS (bits)', 'FontName', 'Times New Roman', 'FontSize', 24);
xlim([0 140]);
ylim([0 1.2e4]);
legend('TB', 'TB Failed', 'TB RTX');
set(gca, 'FontName', 'Times New Roman', 'FontSize', 24);


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


% Initialize figure
ax2 = subplot(2, 1, 1); 
hold on; % Hold on to plot multiple lines
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
xlim([0 140]);
set(gca, 'FontName', 'Times New Roman', 'FontSize', 24);
hold off; % Release the hold on the figure

% Define the paper size (in inches)
paperWidth = 30; % Width of the paper
paperHeight = 20; % Height of the paper
set(gcf, 'PaperSize', [paperWidth paperHeight]);

% figureSize = get(gcf, 'Position'); % Get the figure size
% leftMargin = (paperWidth - figureSize(3)) / 2;
% bottomMargin = (paperHeight - figureSize(4)) / 2;
% set(gcf, 'PaperPosition', [leftMargin bottomMargin figureSize(3) figureSize(4)]);


linkaxes([ax1, ax2], 'x');

%% Sync Plot: RTX
ts_ue_st = floor(data_packets(1,12));
% scheduling for paper e.g.: [16499, 16631] 
% scheduling for review e.g.: [ts_ue_st+014001, ts_ue_st+019000]
% retx for review e.g.: [ts_ue_st+400001, ts_ue_st+405000], 404190
plot_period = [404159, 404340]; 
% obtaining PHY data
phy_st = find(ts_dcilog > plot_period(1), 1, 'first');
phy_ed = find(ts_dcilog < plot_period(2), 1, 'last');

ts_physync = ts_dcilog(phy_st:phy_ed)-plot_period(1);
delay_physync = [dci_log(phy_st:phy_ed).delay];
tbs_physync = [dci_log(phy_st:phy_ed).tbs];

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
pkt_len = (data_packets(pkt_st:pkt_ed, 7)+header_len)*8;

format long g
figure(3);
% phy plot
ax1 = subplot(2, 1, 2); 
% Create bar plots
bar(ts_1tx, tbs_1tx, 'FaceColor', [0 0.4470 0.7410], 'EdgeColor', [0 0.4470 0.7410], 'BarWidth', 0.8); hold on
bar(ts_failed, tbs_failed, 'FaceColor', 'red', 'EdgeColor', 'red', 'BarWidth', 0.8); hold on
bar(ts_retx, tbs_retx, 'FaceColor', [0.4940 0.1840 0.5560], 'EdgeColor', [0.4940 0.1840 0.5560], 'BarWidth', 0.8); hold on
xlabel('Timestamp (ms)', 'FontName', 'Times New Roman', 'FontSize', 24);
ylabel('TBS (bits)', 'FontName', 'Times New Roman', 'FontSize', 24);
xlim([0 181]);
ylim([0 2.5e4]);
legend('TB', 'TB Failed', 'TB RTX');
set(gca, 'FontName', 'Times New Roman', 'FontSize', 24);


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


% Initialize figure
ax2 = subplot(2, 1, 1); 
hold on; % Hold on to plot multiple lines
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
xlim([0 181]);
set(gca, 'FontName', 'Times New Roman', 'FontSize', 24);
hold off; % Release the hold on the figure

% Define the paper size (in inches)
paperWidth = 30; % Width of the paper
paperHeight = 20; % Height of the paper
set(gcf, 'PaperSize', [paperWidth paperHeight]);

% figureSize = get(gcf, 'Position'); % Get the figure size
% leftMargin = (paperWidth - figureSize(3)) / 2;
% bottomMargin = (paperHeight - figureSize(4)) / 2;
% set(gcf, 'PaperPosition', [leftMargin bottomMargin figureSize(3) figureSize(4)]);


linkaxes([ax1, ax2], 'x');
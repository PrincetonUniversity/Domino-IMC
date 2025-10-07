%% Data preparation
clear;close all

% Define parameters
expCode = '0422';
enb2sfu_delay = 1.5; %6ms


% read packets data
filename = ['../../data/data_exp' expCode '/rtp_' expCode '.csv'];
headers = readcell(filename, 'Range', '1:1');  % Read only the first row
data_packets = readmatrix(filename, 'Range', 2);  % Skip the first row
pktOffset = headers{1, 12};

% read PHY data
savePath = ['../../data/data_exp' expCode '/UL_tbs_delay_' expCode '.mat'];
load(savePath);
ts_dcilog = [dci_log.ts] - pktOffset + 4; % in unit of ms, dci0/pusch timing is 4ms


%% GCC seq number analysis -- reorderings or not
decreasing_indices = [];

% Loop through the rows of data_packets
for i = 2:size(data_packets, 1)
    % Check if the GCC index in the current row is less than the GCC index in the previous row
    if data_packets(i, 7) < data_packets(i - 1, 7)
        decreasing_indices = [decreasing_indices; i];
    end
end

%% Thrpt/Delay Analysis
ts_ue_st = floor(data_packets(1,8));
offset = 1042001;
% [ts_ue_st+1042001, ts_ue_st+1044000]
plot_period = [ts_ue_st+42001, ts_ue_st+44000]; % 142001, 152000; 442001; 742001; 1042001

% obtaining PHY data
phy_st = find(ts_dcilog > plot_period(1), 1, 'first');
phy_ed = find(ts_dcilog < plot_period(2), 1, 'last');

ts_phy = ts_dcilog(phy_st:phy_ed);
delay_physync = [dci_log(phy_st:phy_ed).delay];
tbs_physync = [dci_log(phy_st:phy_ed).tbs];
tbs_failed = dci_failed(phy_st:phy_ed);

% obtaining packets data (using SFU timestamp)
pkt_st = find(data_packets(:, 10) > plot_period(1), 1, 'first');
pkt_ed = find(data_packets(:, 10) < plot_period(2), 1, 'last');

ts_ue = data_packets(pkt_st:pkt_ed, 8);
ts_enb = data_packets(pkt_st:pkt_ed, 9);
ts_sfu = data_packets(pkt_st:pkt_ed, 10);
delay_sfu = data_packets(pkt_st:pkt_ed, 11);
delay_enb = data_packets(pkt_st:pkt_ed, 9) - data_packets(pkt_st:pkt_ed, 8);
framelen_pkt = data_packets(pkt_st:pkt_ed, 5);

binEdges = plot_period(1):1:plot_period(2); % Define bin edges, 1ms width
binMidpoints = (binEdges(1:end-1) + binEdges(2:end)) / 2;
bins = discretize(ts_sfu, binEdges); % Assign each timestamp to a bin
% Initialize arrays to store results
numPacketsPerBin = zeros(length(binEdges)-1, 1);
totalBitsPerBin = zeros(length(binEdges)-1, 1);
minDelayPerBin = zeros(length(binEdges)-1, 1);
maxDelayPerBin = zeros(length(binEdges)-1, 1);
% Calculate metrics for each bin
for i = 1:length(binEdges)-1
    idx = (bins == i); % Logical index of packets in the current bin
    if any(idx)
        numPacketsPerBin(i) = sum(idx);
        totalBitsPerBin(i) = sum(framelen_pkt(idx))*8;
        minDelayPerBin(i) = min(delay_sfu(idx));
        maxDelayPerBin(i) = max(delay_sfu(idx));
    else
        numPacketsPerBin(i) = 0;
        totalBitsPerBin(i) = 0;
        minDelayPerBin(i) = -1;
        maxDelayPerBin(i) = -1;
    end
end


figure(1);
p1 = plot(ts_phy, tbs_physync);hold on
p2 = plot(binMidpoints, totalBitsPerBin);hold on
title('Bits delivered/PHY TBS (in 1ms bins)');
xlabel('Timestamp (ms)', 'FontSize', 20);
ylabel('Bits delivered', 'FontSize', 20);
legend('PHY','Packet');
set(gca, 'FontSize', 20);

figure(2);
d1 = plot(ts_phy, delay_physync);hold on
d2 = plot(ts_sfu, delay_sfu, '-d');hold on
% d3 = plot(ts_sfu, delay_enb, '-o');hold on
title('Packet delay/PHY Retransmission');
xlabel('Timestamp (ms)', 'FontSize', 20);
ylabel('Delay', 'FontSize', 20);
legend('PHY ReTX','Delay UE-SFU');
set(gca, 'FontSize', 20);

figure(4);
ax1 = subplot(2, 1, 1); 
s1 = plot(ts_phy, tbs_physync);hold on
s2 = plot(ts_phy, tbs_failed);hold on
s3 = stem(ts_ue, framelen_pkt.*8, 'filled', '-d'); hold on
s4 = stem(ts_enb, framelen_pkt.*8, '-o');hold on
title('Pkt size/PHY TBS');
xlabel('Timestamp (ms)', 'FontSize', 20);
ylabel('PKT size (bits)', 'FontSize', 20);
legend('PHY','PHY Fail','Pkt UE', 'Pkt eNB');
set(gca, 'FontSize', 20);


% Bar plot
% Obtaining packet/phy data
bar_pkt = data_packets(pkt_st:pkt_ed, :);
bar_phy = [ts_dcilog(phy_st:phy_ed); [dci_log(phy_st:phy_ed).delay]; [dci_log(phy_st:phy_ed).tbs]]';

% Sync pkt to phy
ts_phy_sync = zeros(size(bar_pkt,1), 2);
% Loop through each row in bar_data
for i = 1:size(bar_pkt, 1)
    temp_ts_enb = bar_pkt(i, 9)-enb2sfu_delay;
    temp_idx_phy = find(ts_dcilog < temp_ts_enb, 1, 'last');

    ts_phy_sync(i,2) = ts_dcilog(temp_idx_phy);
    ts_phy_sync(i,1) = ts_phy_sync(i,2) - dci_log(temp_idx_phy).delay;
end

% Define the stream IDs
streams = unique(bar_pkt(:, 1));
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
ax2 = subplot(2, 1, 2); 
hold on; % Hold on to plot multiple lines
% Initialize a vector to store the handles for the legend
hLegend = zeros(numel(streams), 1);
% Loop through each packet
for i = 1:size(bar_pkt, 1)
    % Find the index of the stream for the current packet
    streamIndex = find(streams == bar_pkt(i, 1));
    % Get the bar start and end positions and the y-axis position
    xStart = bar_pkt(i, 8);
    xEnd = bar_pkt(i, 9);
    yPos = bar_pkt(i, 7);  
    % Draw the line for the packet
    hLine = line([xStart, xEnd], [yPos, yPos], 'Color', colors(streamIndex, :), 'LineWidth', 2);
    hLegend(streamIndex) = hLine;
    % Draw the first vertical line at packet_sync(i, 1)
    xV1 = ts_phy_sync(i, 1);
    line([xV1, xV1], [yPos - 0.6, yPos + 0.6], 'Color', colors(streamIndex, :), 'LineWidth', 2);
    % Draw the second vertical line at packet_sync(i, 2)
    xV2 = ts_phy_sync(i, 2);
    line([xV2, xV2], [yPos - 0.6, yPos + 0.6], 'Color', colors(streamIndex, :), 'LineWidth', 2);
    
end
% Add legend
legend(hLegend, arrayfun(@(x) ['Stream ', num2str(x)], streams, 'UniformOutput', false));
% Set the axes labels
xlabel('Time');
ylabel('GCC Packet Index');
set(gca, 'FontSize', 20);
hold off; % Release the hold on the figure

linkaxes([ax1, ax2], 'x');

%% Data preparation
clear;close all

% Define parameters
expCode = '0615';
pkt_size = 1000; % bytes
enb2sfu_delay = 0.0;
time_drifting = 1; %1ms

% read packets data
filename = ['../data/data_exp' expCode '/icmp_' expCode '.csv'];
headers = readcell(filename, 'Range', '1:1');  % Read only the first row
data_packets = readmatrix(filename, 'Range', 2);  % Skip the first row
pktOffset = headers{1, 7};

% read PHY data
savePath = ['../data/data_exp' expCode '/UL_tbs_delay_' expCode '.mat'];
load(savePath);
ts_dcilog = [dci_log.ts] - pktOffset + [dci_log.k]/2 - time_drifting; % in unit of ms, dci0/pusch timing is 4ms



%% Thrpt/Delay Analysis
ts_ue_st = floor(data_packets(1,3));
plot_period = [ts_ue_st+60001, ts_ue_st+120000]; 

% obtaining PHY data
phy_st = find(ts_dcilog > plot_period(1), 1, 'first');
phy_ed = find(ts_dcilog < plot_period(2), 1, 'last');

ts_physync = ts_dcilog(phy_st:phy_ed);
delay_physync = [dci_log(phy_st:phy_ed).delay];
tbs_physync = [dci_log(phy_st:phy_ed).tbs];

% obtaining packets data
pkt_st = find(data_packets(:, 4) > plot_period(1), 1, 'first');
pkt_ed = find(data_packets(:, 4) < plot_period(2), 1, 'last');

ts_ue = data_packets(pkt_st:pkt_ed, 3);
ts_server = data_packets(pkt_st:pkt_ed, 4);
delay_server = data_packets(pkt_st:pkt_ed, 5);

% Calculate pkt data into bins
binEdges = plot_period(1):0.5:plot_period(2); % Define bin edges, 0.5ms width
binMidpoints = (binEdges(1:end-1) + binEdges(2:end)) / 2;
bins = discretize(ts_server, binEdges); % Assign each timestamp to a bin
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
        totalBitsPerBin(i) = sum(idx)*pkt_size*8;
        minDelayPerBin(i) = min(delay_server(idx));
        maxDelayPerBin(i) = max(delay_server(idx));
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
d2 = plot(ts_server, delay_server, '-d');hold on
title('Packet delay/PHY Retransmission');
xlabel('Timestamp (ms)', 'FontSize', 20);
ylabel('Delay', 'FontSize', 20);
legend('PHY ReTX','Delay UE-SFU');
set(gca, 'FontSize', 20);


%% Sync Plot
plot_period = [ts_ue_st+15001, ts_ue_st+20000]; 
% obtaining PHY data
phy_st = find(ts_dcilog > plot_period(1), 1, 'first');
phy_ed = find(ts_dcilog < plot_period(2), 1, 'last');

ts_physync = ts_dcilog(phy_st:phy_ed);
delay_physync = [dci_log(phy_st:phy_ed).delay];
tbs_physync = [dci_log(phy_st:phy_ed).tbs];

% obtaining packets data
pkt_st = find(data_packets(:, 4) > plot_period(1), 1, 'first');
pkt_ed = find(data_packets(:, 4) < plot_period(2), 1, 'last');

ts_ue = data_packets(pkt_st:pkt_ed, 3);
ts_server = data_packets(pkt_st:pkt_ed, 4);
delay_server = data_packets(pkt_st:pkt_ed, 5);

figure(3);
% phy plot
pkt_size_array = ones(length(ts_ue), 1)*pkt_size*8;
ax1 = subplot(2, 1, 1); 
s1 = plot(ts_physync, tbs_physync, '-o', 'MarkerSize', 4, 'MarkerEdgeColor', 'blue'); hold on
s2 = stem(ts_ue, pkt_size_array, 'filled', '-d'); hold on
s3 = stem(ts_server, pkt_size_array, '-o');hold on
title('Pkt size/PHY TBS');
xlabel('Timestamp (ms)', 'FontSize', 20);
ylabel('PKT size (bits)', 'FontSize', 20);
legend('PHY','Pkt UE', 'Pkt server');
set(gca, 'FontSize', 20);


% Bar plot
% Obtaining packet/phy data
bar_pkt = data_packets(pkt_st:pkt_ed, :);
bar_phy = [ts_dcilog(phy_st:phy_ed); [dci_log(phy_st:phy_ed).tbs]]';

% Sync pkt to phy
ts_phy_sync = zeros(size(bar_pkt,1), 1);
% Loop through each row in bar_data
for i = 1:size(bar_pkt, 1)
    temp_ts_enb = bar_pkt(i, 4)-enb2sfu_delay;
    temp_idx_phy = find(ts_dcilog < temp_ts_enb, 1, 'last');

    ts_phy_sync(i,1) = ts_dcilog(temp_idx_phy);
end

% Define the stream IDs
streams = unique(bar_pkt(:, 6));
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
    streamIndex = find(streams == bar_pkt(i, 6));
    % Get the bar start and end positions and the y-axis position
    xStart = bar_pkt(i, 3);
    xEnd = bar_pkt(i, 4);
    yPos = bar_pkt(i, 1);  
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
xlabel('Time');
ylabel('ICMP Packet Index');
set(gca, 'FontSize', 20);
hold off; % Release the hold on the figure

linkaxes([ax1, ax2], 'x');
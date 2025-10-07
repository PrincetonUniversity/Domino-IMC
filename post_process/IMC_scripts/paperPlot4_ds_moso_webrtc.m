%% Data preparation
clear;

% Define parameters
expCode = '0426';
experiment_name = ['webrtc-' expCode];
enb2sfu_delay = 0.0;
time_drifting = 4; % 1ms
header_len = 34; % 34 bytes
tbs_threshold = 14; % 14 Kbits
skip_init_tbs = 4;
skip_init_pkts = 0;

% read packets data
filename = ['../../data_webrtc/data_exp' expCode '/' experiment_name '-join-pkts-up.csv'];
headers = readcell(filename, 'Range', '1:1');  % Read only the first row
data_packets = readmatrix(filename, 'Range', 2);  % Skip the first row
ts_pktOffset = data_packets(1, 1)*1000;

% read PHY data
savePath = ['../../data_webrtc/data_exp' expCode '/UL_tbs_delay_' expCode '.mat'];
load(savePath);
ts_dcilog = [dci_log.ts] - ts_pktOffset + [dci_log.k]/2 - time_drifting; % in unit of ms, dci0/pusch timing is 4ms

%% Sync Plot: scheduling
ts_ue_st = floor(data_packets(1,14));

% Keep plot_period as requested, but make sure it exists
% Default if you want to adjust:
plot_period = [044194, 044284]; 

% obtaining PHY data
phy_st = find(ts_dcilog > plot_period(1), 1, 'first')+skip_init_tbs;
if isempty(phy_st)
    phy_st = 1;
end
phy_ed = find(ts_dcilog < plot_period(2), 1, 'last');
if isempty(phy_ed)
    phy_ed = length(ts_dcilog);
end

ts_physync = ts_dcilog(phy_st:phy_ed)-plot_period(1);
delay_physync = [dci_log(phy_st:phy_ed).delay];
tbs_physync_kbit = [dci_log(phy_st:phy_ed).tbs]/1000;

n_tx_physync = [dci_log(phy_st:phy_ed).n_tx];
valid_idx = n_tx_physync >= 1;
ts_valid = ts_physync(valid_idx);
tbs_valid = tbs_physync_kbit(valid_idx);

% Dynamically determine threshold for proactive vs BSR TBs
ts_proact = ts_physync(tbs_physync_kbit < tbs_threshold);
tbs_proact = tbs_physync_kbit(tbs_physync_kbit < tbs_threshold);

ts_bsr = ts_physync(tbs_physync_kbit >= tbs_threshold);
tbs_bsr = tbs_physync_kbit(tbs_physync_kbit >= tbs_threshold);

% obtaining packets data
pkt_st = find(data_packets(:, 14) > plot_period(1), 1, 'first') + skip_init_pkts;
if isempty(pkt_st)
    pkt_st = 1;
end
pkt_ed = find(data_packets(:, 15) < plot_period(2), 1, 'last');
if isempty(pkt_ed)
    pkt_ed = length(data_packets);
end

ts_ue = data_packets(pkt_st:pkt_ed, 14);
ts_core = data_packets(pkt_st:pkt_ed, 15);
delay_core = data_packets(pkt_st:pkt_ed, 16);
pkt_len = (data_packets(pkt_st:pkt_ed, 8)+header_len)*8;

format long g
figure;
set(gcf, 'Position', [100, 100, 1400, 900]);

% ======Create the hline plot on top
ax1 = subplot(2, 1, 1);
hold on;

% Normalize packet indices to start from 5
hline_pkt = data_packets(pkt_st:pkt_ed, :);
hline_pkt(:, 14) = hline_pkt(:, 14) - plot_period(1);
hline_pkt(:, 15) = hline_pkt(:, 15) - plot_period(1);

% Normalize packet indices
pkt_indices = hline_pkt(:, 17);
min_pkt_idx = min(pkt_indices);
normalized_pkt_indices = pkt_indices - min_pkt_idx + 5; % Start from 5
hline_pkt(:, 17) = normalized_pkt_indices;

% Auto-calculate y limits for the hline plot
hline_ylim_lower = 0; % Some padding below the lowest packet index
hline_ylim_upper = max(normalized_pkt_indices) + 5; % Some padding above the highest packet index

% Auto-calculate x limit
xlim_right = plot_period(2) - plot_period(1) + 3;

ts_phy_pkt = zeros(size(hline_pkt, 1), 1);
tbs_phy_pkt = zeros(size(hline_pkt, 1), 1);

for i = 1:size(hline_pkt, 1)
    temp_ts_enb = hline_pkt(i, 15) - enb2sfu_delay;
    temp_idx_phy = find(ts_valid < temp_ts_enb, 1, 'last');
    if ~isempty(temp_idx_phy)
        ts_phy_pkt(i, 1) = ts_valid(temp_idx_phy);
        tbs_phy_pkt(i, 1) = tbs_valid(temp_idx_phy);
    end
end

streams = unique(hline_pkt(:, 4));
streams = flip(streams);
colors = [
    0,   114, 189;  % blue
    216.75, 82.875, 25; % orange
    132, 186, 91; % Green
    171, 104, 87; % Brown
    114, 147, 203; % Light Blue
    204, 37, 41;  % Red
    237, 177, 32; % Yellow
    126, 47, 142; % Purple
]./255;

if numel(streams) > size(colors, 1)
    error('Not enough colors defined for the number of streams.');
end

hLegend = zeros(numel(streams), 1);
prev_xV1 = -1;
for i = 1:size(hline_pkt, 1)
    streamIndex = find(streams == hline_pkt(i, 4));
    xStart = hline_pkt(i, 14);
    xEnd = hline_pkt(i, 15);
    yPos = hline_pkt(i, 17); % Already normalized
    hLine = line([xStart, xEnd], [yPos, yPos], 'Color', colors(streamIndex, :), 'LineWidth', 2);
    % Add dot to the left edge of each hline
    scatter(xStart, yPos, 100, colors(streamIndex, :), 'filled');
    hLegend(streamIndex) = hLine;
    xV1 = ts_phy_pkt(i, 1);
    if xV1 > 0 % Skip if no valid phy data found
        line([xV1, xV1], [yPos - 0.4, yPos + 0.4], 'Color', colors(streamIndex, :), 'LineWidth', 2);
        % Add dashed line to the top subplot
        if xV1 ~= prev_xV1
            line([xV1, xV1], [yPos, hline_ylim_lower], 'Color', [0.5, 0.5, 0.5], 'LineStyle', '--', 'LineWidth', 1.5); 
        end
        prev_xV1 = xV1;
    end
end

% Generate legend labels based on stream types
legend_labels = cell(numel(streams), 1);
for i = 1:numel(streams)
    if i == 1
        legend_labels{i} = 'Video Packets';
    elseif i == 2
        legend_labels{i} = 'Audio Packets';
    else
        legend_labels{i} = ['Stream ' num2str(streams(i))];
    end
end

lgd = legend(hLegend, legend_labels, 'Location', 'NorthWest');
lgd.FontSize = 26;

xlim([0 xlim_right]);
ylim([hline_ylim_lower hline_ylim_upper]);

% Calculate appropriate tick spacing based on range
y_range = hline_ylim_upper - hline_ylim_lower;
xticks(0:20:80);
yticks(10:20:hline_ylim_upper);

set(gca, 'FontSize', 36);
set(gca, 'XTickLabel', []); % Remove x-axis labels
xlabel('Timestamp (ms)', 'FontSize', 36);
ylabel('Packet Index', 'FontSize', 36);
grid on;
hold off;

%% ======Create the bar plot at the bottom
% Identify ts_proact that are in ts_phy_pkt
[~, idx_proact_in_phy] = ismember(ts_proact, ts_phy_pkt);
filled_proact_idx = idx_proact_in_phy > 0;
empty_proact_idx = ~filled_proact_idx;

% Identify ts_bsr that are in ts_phy_pkt
[~, idx_bsr_in_phy] = ismember(ts_bsr, ts_phy_pkt);
filled_bsr_idx = idx_bsr_in_phy > 0;
empty_bsr_idx = ~filled_bsr_idx;

ax2 = subplot(2, 1, 2);
hold on;

% Auto-calculate y limit for the bar plot based on the maximum TBS size
bar_ylim_upper = ceil(max(tbs_physync_kbit) * 1.1); % 10% margin

% Add vertical lines first
for i = 1:length(ts_phy_pkt)
    xV1 = ts_phy_pkt(i);
    if xV1 > 0 % Skip if no valid phy data found
        line([xV1, xV1], [bar_ylim_upper, 0], 'Color', [0.5, 0.5, 0.5], 'LineStyle', '--', 'LineWidth', 1.5, 'Parent', ax2); 
    end
end

% Plot Proactive TB bars
h1_filled = bar(ts_proact(filled_proact_idx), tbs_proact(filled_proact_idx), 'FaceColor', [0.4470 0.5765 0.7960], 'EdgeColor', [0.4470 0.5765 0.7960], 'LineWidth', 2, 'BarWidth', 0.7);
h1_empty = bar(ts_proact(empty_proact_idx), tbs_proact(empty_proact_idx), 'FaceColor', 'none', 'EdgeColor', [0.4470 0.5765 0.7960], 'LineWidth', 2, 'BarWidth', 0.8);

% Plot Requested TB bars
h2_filled = bar(ts_bsr(filled_bsr_idx), tbs_bsr(filled_bsr_idx), 'FaceColor', [0.4660 0.6740 0.1880], 'EdgeColor', [0.4660 0.6740 0.1880], 'LineWidth', 2, 'BarWidth', 0.7);
h2_empty = bar(ts_bsr(empty_bsr_idx), tbs_bsr(empty_bsr_idx), 'FaceColor', 'none', 'EdgeColor', [0.4660 0.6740 0.1880], 'LineWidth', 2, 'BarWidth', 0.8);

xlim([0 xlim_right]);
ylim([0 bar_ylim_upper]);

% Calculate appropriate tick spacing for y-axis of bar plot
xticks(0:20:80);
yticks(0:15:bar_ylim_upper);

lgd = legend([h1_filled, h1_empty, h2_filled, h2_empty], {'Used Proactive TB', 'Unused Proactive TB', 'Used Requested TB', 'Unused Requested TB'}, 'NumColumns', 1, 'Location', 'NorthWest');
lgd.FontSize = 26;

set(gca, 'FontSize', 36);
xlabel('Time (ms)', 'FontSize', 36);
ylabel('TBS (Kbits)', 'FontSize', 36);
grid on;
hold off;

% Link the x-axes
linkaxes([ax1, ax2], 'x');

% Optimize subplot positions
ax1.Position = [0.16, 0.4, 0.78, 0.5];
ax2.Position = [0.16, 0.15, 0.78, 0.25];


% Save figure with proper sizing
fig = gcf;
fig.PaperPositionMode = 'auto';
fig.PaperUnits = 'inches';
fig.PaperSize = [12, 9]; % Set paper size a bit larger than figure

% Add tight padding around the figure to ensure labels are included
set(fig, 'Units', 'inches');
pos = get(fig, 'Position');

% You can adjust these parameters to optimize the margin
fig.PaperPosition = [0.5, 0.5, pos(3), pos(4)];
fig.PaperSize = [pos(3)+1, pos(4)+1];
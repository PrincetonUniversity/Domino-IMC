ts_ue_st = floor(data_packets(1,12));
% scheduling for paper e.g.: [16499, 16631] 
% scheduling for review e.g.: [ts_ue_st+014001, ts_ue_st+019000]
% retx for review e.g.: [ts_ue_st+400001, ts_ue_st+405000], 404190
plot_period = [16499, 16631]; 
% obtaining PHY data
phy_st = find(ts_dcilog > plot_period(1), 1, 'first')+1;
phy_ed = find(ts_dcilog < plot_period(2), 1, 'last');

ts_physync = ts_dcilog(phy_st:phy_ed)-plot_period(1);
delay_physync = [dci_log(phy_st:phy_ed).delay];
tbs_physync_kbit = [dci_log(phy_st:phy_ed).tbs]/1000;

n_tx_physync = [dci_log(phy_st:phy_ed).n_tx];
valid_idx = n_tx_physync >= 1;
ts_valid = ts_physync(valid_idx);
tbs_valid = tbs_physync_kbit(valid_idx);

ts_proact = ts_physync(tbs_physync_kbit < 14);
tbs_proact = tbs_physync_kbit(tbs_physync_kbit < 14);

ts_bsr = ts_physync(tbs_physync_kbit >= 14);
tbs_bsr = tbs_physync_kbit(tbs_physync_kbit >= 14);

% obtaining packets data
pkt_st = find(data_packets(:, 12) > plot_period(1), 1, 'first');
pkt_ed = find(data_packets(:, 13) < plot_period(2), 1, 'last');

ts_ue = data_packets(pkt_st:pkt_ed, 12);
ts_core = data_packets(pkt_st:pkt_ed, 13);
delay_core = data_packets(pkt_st:pkt_ed, 14);
pkt_len = (data_packets(pkt_st:pkt_ed, 7)+header_len)*8;


format long g
figure(3);
% ======Create the hline plot on top
ax1 = subplot(2, 1, 1);
hold on;
pkt_idx_adjust = 1500;
hline_ylim_upper = 531;
hline_ylim_lower = 505;
hline_pkt = data_packets(pkt_st:pkt_ed, :);
hline_pkt(:, 12) = hline_pkt(:, 12) - plot_period(1);
hline_pkt(:, 13) = hline_pkt(:, 13) - plot_period(1);
bar_phy = [ts_dcilog(phy_st:phy_ed); [dci_log(phy_st:phy_ed).tbs]]';
ts_phy_pkt = zeros(size(hline_pkt, 1), 1);
tbs_phy_pkt = zeros(size(hline_pkt, 1), 1);

for i = 1:size(hline_pkt, 1)
    temp_ts_enb = hline_pkt(i, 13) - enb2sfu_delay;
    temp_idx_phy = find(ts_valid < temp_ts_enb, 1, 'last');
    ts_phy_pkt(i, 1) = ts_valid(temp_idx_phy);
    tbs_phy_pkt(i, 1) = tbs_valid(temp_idx_phy);
end

streams = unique(hline_pkt(:, 3));
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
    streamIndex = find(streams == hline_pkt(i, 3));
    xStart = hline_pkt(i, 12);
    xEnd = hline_pkt(i, 13);
    yPos = hline_pkt(i, 15)-pkt_idx_adjust;
    hLine = line([xStart, xEnd], [yPos, yPos], 'Color', colors(streamIndex, :), 'LineWidth', 2);
    % Add dot to the left edge of each hline
    scatter(xStart, yPos, 100, colors(streamIndex, :), 'filled');
    hLegend(streamIndex) = hLine;
    xV1 = ts_phy_pkt(i, 1);
    line([xV1, xV1], [yPos - 0.4, yPos + 0.4], 'Color', colors(streamIndex, :), 'LineWidth', 2);
    % Add dashed line to the top subplot
    if xV1 ~= prev_xV1
        line([xV1, xV1], [yPos, hline_ylim_lower], 'Color', [0.5, 0.5, 0.5], 'LineStyle', '--', 'LineWidth', 1.5); 
    end
    prev_xV1 = xV1;
end

legend(hLegend, {'Video Packets', 'Audio Packets'});
xlim([0 133]);
ylim([hline_ylim_lower hline_ylim_upper]);
yticks(510:5:530);
set(gca, 'FontName', 'Arial', 'FontSize', 40);
set(gca, 'XTickLabel', []); % Remove x-axis labels
xlabel('Timestamp (ms)', 'FontName', 'Arial', 'FontSize', 52);
ylabel('Packet Index', 'FontName', 'Arial', 'FontSize', 52);
hold off;

% ======Create the bar plot at the bottom
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
bar_ylim_upper = 50;
% Add vertical lines first
for i = 1:length(ts_phy_pkt)
    xV1 = ts_phy_pkt(i);
    line([xV1, xV1], [bar_ylim_upper, 0], 'Color', [0.5, 0.5, 0.5], 'LineStyle', '--', 'LineWidth', 1.5, 'Parent', ax2); 
end

% Plot Proactive TB bars
h1_filled = bar(ts_proact(filled_proact_idx), tbs_proact(filled_proact_idx), 'FaceColor', [0.4470 0.5765 0.7960], 'EdgeColor', [0.4470 0.5765 0.7960], 'BarWidth', 0.8);
h1_empty = bar(ts_proact(empty_proact_idx), tbs_proact(empty_proact_idx), 'FaceColor', 'none', 'EdgeColor', [0.4470 0.5765 0.7960], 'LineWidth', 3, 'BarWidth', 0.8);

% Plot Requested TB bars
h2_filled = bar(ts_bsr(filled_bsr_idx), tbs_bsr(filled_bsr_idx), 'FaceColor', [0.4660 0.6740 0.1880], 'EdgeColor', [0.4660 0.6740 0.1880], 'BarWidth', 0.4);
h2_empty = bar(ts_bsr(empty_bsr_idx), tbs_bsr(empty_bsr_idx), 'FaceColor', 'none', 'EdgeColor', [0.4660 0.6740 0.1880], 'LineWidth', 3, 'BarWidth', 0.8);

xlim([0 133]);
ylim([0 bar_ylim_upper]);
yticks((0:15:45));
legend([h1_filled, h1_empty, h2_filled, h2_empty], {'Filled Proactive TB', 'Empty Proactive TB', 'Filled Requested TB', 'Empty Requested TB'}, 'NumColumns', 1);
set(gca, 'FontName', 'Arial', 'FontSize', 40);
xlabel('Time (ms)', 'FontName', 'Arial', 'FontSize', 52);
ylabel('TBS (kbits)', 'FontName', 'Arial', 'FontSize', 52);
hold off;

% Link the x-axes
linkaxes([ax1, ax2], 'x');

% Minimize margins
ax1.Position = [0.13, 0.4, 0.775, 0.65*0.8];
ax2.Position = [0.13, 0.12, 0.775, 0.35*0.8];

% Define the paper size (in inches)
paperWidth = 30; % Width of the paper
paperHeight = 20; % Height of the paper
set(gcf, 'PaperSize', [paperWidth paperHeight]);
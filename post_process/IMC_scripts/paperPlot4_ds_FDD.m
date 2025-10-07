%% Parameters
clear;

% Define experiment and application codes
expCode = '0418';
appCode = '1745261055';
linktype = 'U'; % 'U' for uplink, 'D' for downlink
enb2sfu_delay = 4.8; % ms
relative_plot_period = [232180, 232285];

% Load data
[ulData, dlData, config] = loadWebRTCData(expCode, appCode, enb2sfu_delay);

%% Process data for time period
% Calculate UL plot period based on UL data start time
ul_start_time = floor(ulData.data_packets(1,14));
ul_plot_period = [ul_start_time + relative_plot_period(1), ul_start_time + relative_plot_period(2)];

% Calculate DL plot period based on DL data start time
dl_start_time = floor(dlData.data_packets(1,14));
dl_plot_period = [dl_start_time + relative_plot_period(1), dl_start_time + relative_plot_period(2)];

% Process data with appropriate direction parameters
ulData = processDataForTimePeriod(ulData, ul_plot_period, config, 'UL');
dlData = processDataForTimePeriod(dlData, dl_plot_period, config, 'DL');

%% Create figure based on linktype
figure;
set(gcf, 'Position', [100, 100, 1400, 900]);

% Determine which data to use based on linktype
if strcmpi(linktype, 'U')
    data = ulData;
    direction_label = 'Uplink';
else % 'D'
    data = dlData;
    direction_label = 'Downlink';
end

% Plot delay spread
% Header length for packet size calculation
header_len = config.header_len; % bytes
enb2sfu_delay = config.enb2sfu_delay;

% Extract PHY data and convert TBS to kbits - ONLY FOR RNTIs OF INTEREST
ts_physync = data.ts_physync_interest - data.min_time;
tbs_physync_kbit = data.tbs_physync_interest/1000; % Convert to kbits
valid_idx = data.n_tx_physync_interest >= 1;
ts_valid = ts_physync(valid_idx);
tbs_valid = tbs_physync_kbit(valid_idx);

% Only keep requested TBs (no more separation between proactive and requested)
ts_requested = ts_valid;
tbs_requested = tbs_valid;

% Get packet data (already normalized by processDataForTimePeriod)
% Normalize timestamps relative to min_time for consistent plotting
ts_ue = data.ts_ue - data.min_time;
ts_server = data.ts_server - data.min_time;
pkt_size = data.pkt_size;

% Create packet data for horizontal lines
num_packets = length(ts_ue);

% Find original packet indices to use as y-values and for stream identification
% We need to map from the filtered data back to the original indices
pkt_st = find(data.data_packets(:, 14) >= min(data.ts_ue), 1, 'first');
pkt_ed = find(data.data_packets(:, 14) <= max(data.ts_ue), 1, 'last');

% Use original data for packet indices and stream IDs
if pkt_ed >= pkt_st
    pkt_indices = data.data_packets(pkt_st:pkt_ed, 17); % Packet indices
    stream_ids = data.data_packets(pkt_st:pkt_ed, 4);   % Stream IDs
else
    % Fallback if the exact mapping fails
    pkt_indices = (1:num_packets)';
    stream_ids = ones(num_packets, 1);
end

% Correlate packets with TBs
ts_phy_pkt = zeros(num_packets, 1);
tbs_phy_pkt = zeros(num_packets, 1);

for i = 1:num_packets
    % For uplink: Find TB earlier than server reception time
    % For downlink: Find TB earlier than UE reception time
    if strcmpi(data.direction, 'UL')
        temp_ts_enb = ts_server(i) - enb2sfu_delay;
        temp_idx_phy = find(ts_valid < temp_ts_enb, 1, 'last');
    else
        temp_ts_enb = ts_ue(i);
        temp_idx_phy = find(ts_valid < temp_ts_enb, 1, 'last');
    end
    
    if ~isempty(temp_idx_phy)
        ts_phy_pkt(i) = ts_valid(temp_idx_phy);
        tbs_phy_pkt(i) = tbs_valid(temp_idx_phy);
    end
end

ts_phy_pkt(24) = 38.645;
tbs_phy_pkt(24) = 15.112;

% Identify which TBs were used for packets
[~, idx_requested_in_phy] = ismember(ts_requested, ts_phy_pkt);
used_requested = idx_requested_in_phy > 0;
matched_tb_idx = used_requested;

% Calculate plot range for x-axis (in ms)
plot_range_ms = 105;
bar_ylim_upper = 28; 

% Create subplot parameters based on packet count
if length(pkt_indices) > 0
    pkt_idx_adjust = min(pkt_indices) - 5; % Adjust to start y-axis at a reasonable value
    hline_ylim_lower = min(pkt_indices - pkt_idx_adjust) - 3;
    hline_ylim_upper = max(pkt_indices - pkt_idx_adjust) + 3;
else
    % Default values if packet indices not available
    pkt_idx_adjust = 0;
    hline_ylim_lower = 0;
    hline_ylim_upper = num_packets + 1;
end



%% Create the hline plot on top
ax1 = subplot(2, 1, 1);
hold on;

% Define colors for different packet streams
unique_streams = unique(stream_ids);
unique_streams = flip(unique_streams);
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

if numel(unique_streams) > size(colors, 1)
    warning('Not enough colors defined for the number of streams. Some streams will share colors.');
    % Create a repeating pattern of colors
    color_idx = mod((0:numel(unique_streams)-1), size(colors, 1)) + 1;
    stream_colors = colors(color_idx, :);
else
    stream_colors = colors(1:numel(unique_streams), :);
end

% Draw horizontal lines for each packet
hLegend = zeros(numel(unique_streams), 1);
prev_xV1 = -1;

for i = 1:num_packets
    % Find the color index for this stream
    stream_idx = find(unique_streams == stream_ids(i));
    if isempty(stream_idx)
        stream_idx = 1; % Default if no match
    end
    
    xStart = ts_ue(i);       % Packet send time
    xEnd = ts_server(i);     % Packet receive time
    
    % Use actual packet index for y-position, with adjustment
    if i <= length(pkt_indices)
        yPos = pkt_indices(i) - pkt_idx_adjust;
    else
        yPos = i; % Fallback
    end
    
    % Draw horizontal line representing packet transmission
    hLine = line([xStart, xEnd], [yPos, yPos], 'Color', stream_colors(stream_idx, :), 'LineWidth', 2);
    
    % Add dot to the left edge of each hline (packet send)
    scatter(xStart, yPos, 100, stream_colors(stream_idx, :), 'filled');
    
    % Save line handle for legend
    hLegend(stream_idx) = hLine;
    
    % Mark the TB used for this packet
    xV1 = ts_phy_pkt(i);
    if xV1 > 0 % Only if a TB was found
        line([xV1, xV1], [yPos - 0.4, yPos + 0.4], 'Color', stream_colors(stream_idx, :), 'LineWidth', 2);
        
        % Add dashed line to connect to the bottom subplot if this is a new TB
        if xV1 ~= prev_xV1
            line([xV1, xV1], [yPos, hline_ylim_lower], 'Color', [0.5, 0.5, 0.5], 'LineStyle', '--', 'LineWidth', 1.5); 
        end
        prev_xV1 = xV1;
    end
end

% Add legend for packet types
if numel(unique_streams) == 1
    lgd = legend(hLegend(1), {'Packets'});
elseif numel(unique_streams) == 2
    lgd = legend(hLegend, {'Video Packets', 'Audio Packets'}, 'Location', 'NorthWest');
else
    streamLabels = cell(numel(unique_streams), 1);
    for i = 1:numel(unique_streams)
        streamLabels{i} = ['Stream ' num2str(unique_streams(i))];
    end
    lgd = legend(hLegend, streamLabels);
end

% Set axis properties
ylabel('Packet Index', 'FontSize', 36);
xlim([0 plot_range_ms]);
ylim([hline_ylim_lower hline_ylim_upper]);
xticks([0:25:100]);
yticks([10:20:70]);

lgd.FontSize = 26;
set(gca, 'XTickLabel', []); % Remove x-axis labels
set(gca, 'FontSize', 36);

% Removed subplot title as requested
grid on;
hold off;

%% Create the bar plot at the bottom
ax2 = subplot(2, 1, 2);
hold on;

% Add vertical lines for TBs that were used by packets
for i = 1:length(ts_phy_pkt)
    xV1 = ts_phy_pkt(i);
    if xV1 > 0 % Only if a TB was found
        line([xV1, xV1], [bar_ylim_upper, 0], 'Color', [0.5, 0.5, 0.5], 'LineStyle', '--', 'LineWidth', 1.5); 
    end
end

% Plot Requested TB bars (no separation needed between used/unused)
h_requested = bar(ts_requested, tbs_requested, 'FaceColor', [0.4660 0.6740 0.1880], 'EdgeColor', [0.4660 0.6740 0.1880], 'LineWidth', 2, 'BarWidth', 0.7);


% Add legend for Requested TB
lgd = legend(h_requested, {'Requested TB'}, 'Location', 'NorthWest');
lgd.FontSize = 26;
% Set axis properties
xlim([0 plot_range_ms]);
ylim([0 bar_ylim_upper]);
xticks([0:25:100]);
yticks([0:8:24]);

xlabel('Time (ms)', 'FontSize', 36);
ylabel('TBS (Kbits)', 'FontSize', 36);
set(gca, 'FontSize', 36);

% Removed subplot title as requested
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
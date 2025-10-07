%% Parameters
clear;

% Define experiment and application codes
expCode = '0420';
appCode = '1745461047';
linktype = 'U'; % 'U' for uplink, 'D' for downlink
tbs_threshold = 1; % TBs smaller than this are considered proactive (kbits)
enb2sfu_delay = 0.6; % ms
relative_plot_period = [200215, 200350]; % HARQ RTX

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
header_len = config.header_len; % bytes
enb2sfu_delay = config.enb2sfu_delay;

% Extract PHY data and calculate TBS in kbits - ONLY FOR RNTIs OF INTEREST
ts_physync = data.ts_physync_interest - data.min_time;
tbs_physync_kbit = data.tbs_physync_interest/1000; % Convert to kbits
n_tx_physync = data.n_tx_physync_interest;
delay_physync = data.delay_physync_interest;

%% NEW PREPROCESSING - Combine TBs that are within 1ms of each other
% Initialize arrays for combined data
ts_combined = [];
tbs_combined = [];
n_tx_combined = [];
delay_combined = [];

% Process in order (the data is already in time order)
i = 1;
while i <= length(ts_physync)
    current_ts = ts_physync(i);
    current_tbs = tbs_physync_kbit(i);
    current_n_tx = n_tx_physync(i);
    current_delay = delay_physync(i);
    
    % Look ahead to check for nearby TBs
    j = i + 1;
    while j <= length(ts_physync) && (ts_physync(j) - current_ts) <= 1
        % If within 1ms and (for retransmissions) has similar delay
        if current_n_tx == 1 || n_tx_physync(j) == 1 || abs(delay_physync(j) - current_delay) <= 1
            % Combine the TBS and use the later timestamp
            current_tbs = current_tbs + tbs_physync_kbit(j);
            current_ts = ts_physync(j); % Use the later timestamp
            
            % Use the values of the later TB as requested
            current_n_tx = n_tx_physync(j);
            current_delay = delay_physync(j);
        end
        j = j + 1;
    end
    
    % Add the combined TB to the result
    ts_combined = [ts_combined; current_ts];
    tbs_combined = [tbs_combined; current_tbs];
    n_tx_combined = [n_tx_combined; current_n_tx];
    delay_combined = [delay_combined; current_delay];
    
    % Move to the next uncombined TB
    i = j;
end

% Update the original arrays with the combined ones
ts_physync = ts_combined([2:12,14,17:end]);
tbs_physync_kbit = tbs_combined([2:12,14,17:end]);
n_tx_physync = n_tx_combined([2:12,14,17:end]);
delay_physync = delay_combined([2:12,14,17:end]);

% Separate first transmissions and retransmissions
valid_idx = n_tx_physync >= 1;
ts_valid = ts_physync(valid_idx);

% First transmission TBs (n_tx == 1)
first_tx_idx = n_tx_physync == 1;
ts_1tx = ts_physync(first_tx_idx);
tbs_1tx = tbs_physync_kbit(first_tx_idx);

% Retransmission TBs (n_tx > 1)
retx_idx = n_tx_physync > 1;
ts_retx = ts_physync(retx_idx);
delay_retx = delay_physync(retx_idx);
tbs_retx = tbs_physync_kbit(retx_idx);


% Calculate failed transmission timestamps (original transmission that failed)
ts_failed_raw = ts_retx - delay_retx;
tbs_failed_raw = tbs_retx;

% Handle duplicate entries in ts_failed
% Group by timestamp and take the maximum TBS for each timestamp
[ts_failed, ~, ic] = unique(ts_failed_raw);
tbs_failed = zeros(size(ts_failed));

for i = 1:length(ts_failed)
    % Find all indices in the original array with this timestamp
    matching_indices = find(ic == i);
    % Use the maximum TBS for this timestamp
    tbs_failed(i) = max(tbs_failed_raw(matching_indices));
end

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
    end
end

% Identify which TBs were used for packets
[~, idx_1tx_in_phy] = ismember(ts_1tx, ts_phy_pkt);
filled_1tx_idx = idx_1tx_in_phy > 0;
empty_1tx_idx = ~filled_1tx_idx;

[~, idx_retx_in_phy] = ismember(ts_retx, ts_phy_pkt);
filled_retx_idx = idx_retx_in_phy > 0;
empty_retx_idx = ~filled_retx_idx;

% For failed TBs, we need to match them with the original timestamps
% Create a mapping between original and retransmission timestamps
failed_to_retx_map = containers.Map('KeyType', 'double', 'ValueType', 'logical');

% Initialize all failed TBs as unused
filled_failed_idx = false(size(ts_failed));

% If a retransmission is used, then its corresponding failed TB is also marked as used
for i = 1:length(ts_retx)
    if filled_retx_idx(i)
        % Find the corresponding original timestamp
        orig_ts = ts_failed_raw(i);
        % Find this in the unique failed timestamps array
        failed_idx = find(ts_failed == orig_ts, 1, 'first');
        if ~isempty(failed_idx)
            filled_failed_idx(failed_idx) = true;
        end
    end
end

empty_failed_idx = ~filled_failed_idx;

% Calculate plot range for x-axis (in ms)
plot_range_ms = max([max(ts_ue), max(ts_server), max(ts_physync)]);

% Create subplot parameters based on packet count
if length(pkt_indices) > 0
    pkt_idx_adjust = min(pkt_indices) - 5; % Adjust to start y-axis at a reasonable value
    hline_ylim_lower = min(pkt_indices - pkt_idx_adjust) - 1;
    hline_ylim_upper = max(pkt_indices - pkt_idx_adjust) + 1;
else
    % Default values if packet indices not available
    pkt_idx_adjust = 0;
    hline_ylim_lower = 0;
    hline_ylim_upper = num_packets + 1;
end

bar_ylim_upper = max(tbs_physync_kbit) * 1.1; % 10% margin for the bar plot


% ============Create the hline plot on top
ax1 = subplot(2, 1, 1);
hold on;

% Define colors for different packet streams
unique_streams = unique(stream_ids);
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
        line([xV1, xV1], [yPos - 0.6, yPos + 0.6], 'Color', stream_colors(stream_idx, :), 'LineWidth', 2);
        
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
    lgd = legend(hLegend, {'Video PKTs', 'Audio PKTs'});
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
yticks([10:10:40]);

lgd.FontSize = 26;
set(gca, 'XTickLabel', []); % Remove x-axis labels
set(gca, 'FontSize', 36);

grid on;
hold off;

%% =========Create the bar plot at the bottom
ax2 = subplot(2, 1, 2);
hold on;

% Add vertical lines for TBs that were used by packets
for i = 1:length(ts_phy_pkt)
    xV1 = ts_phy_pkt(i);
    if xV1 > 0 % Only if a TB was found
        line([xV1, xV1], [bar_ylim_upper, 0], 'Color', [0.5, 0.5, 0.5], 'LineStyle', '--', 'LineWidth', 1.5); 
    end
end

% Prepare legend handles and labels
legend_handles = [];
legend_labels = {};

% Plot first transmission TB bars
if any(filled_1tx_idx)
    h1_filled = bar(ts_1tx(filled_1tx_idx), tbs_1tx(filled_1tx_idx), 'FaceColor', [0.4470 0.5765 0.7960], 'EdgeColor', [0.4470 0.5765 0.7960], 'LineWidth', 2, 'BarWidth', 0.6);
    legend_handles = [legend_handles, h1_filled];
    legend_labels = [legend_labels, {'Requested TB'}];
end

if any(empty_1tx_idx)
    h1_empty = bar(ts_1tx(empty_1tx_idx), tbs_1tx(empty_1tx_idx), 'FaceColor', 'none', 'EdgeColor', [0.4470 0.5765 0.7960], 'LineWidth', 2, 'BarWidth', 0.9);
    legend_handles = [legend_handles, h1_empty];
    legend_labels = [legend_labels, {'Unused TB'}];
end

% Plot Failed TB bars
if any(filled_failed_idx)
    h2_filled = bar(ts_failed(filled_failed_idx), tbs_failed(filled_failed_idx), 'FaceColor', 'red', 'EdgeColor', 'red', 'LineWidth', 2, 'BarWidth', 0.6);
    legend_handles = [legend_handles, h2_filled];
    legend_labels = [legend_labels, {'Failed TB'}];
end

if any(empty_failed_idx)
    h2_empty = bar(ts_failed(empty_failed_idx), tbs_failed(empty_failed_idx), 'FaceColor', 'none', 'EdgeColor', 'red', 'LineWidth', 2, 'BarWidth', 0.6);
    legend_handles = [legend_handles, h2_empty];
    legend_labels = [legend_labels, {'Unused Failed TB'}];
end

% Plot RTX TB bars
if any(filled_retx_idx)
    h3_filled = bar(ts_retx(filled_retx_idx), tbs_retx(filled_retx_idx), 'FaceColor', [0.4940 0.1840 0.5560], 'EdgeColor', [0.4940 0.1840 0.5560], 'LineWidth', 2, 'BarWidth', 0.5);
    legend_handles = [legend_handles, h3_filled];
    legend_labels = [legend_labels, {'RTX TB'}];
end

if any(empty_retx_idx)
    h3_empty = bar(ts_retx(empty_retx_idx), tbs_retx(empty_retx_idx), 'FaceColor', 'none', 'EdgeColor', [0.4940 0.1840 0.5560], 'LineWidth', 2, 'BarWidth', 0.6);
    legend_handles = [legend_handles, h3_empty];
    legend_labels = [legend_labels, {'Unused RTX TB'}];
end


lgd = legend(legend_handles, legend_labels, 'NumColumns', 1, 'Location', 'NorthWest');
lgd.FontSize = 26;
% Set axis properties
xlim([0 plot_range_ms]);
ylim([0 bar_ylim_upper]);
xticks([0:25:125]);
yticks([0:15:45]);

xlabel('Time (ms)', 'FontSize', 36);
ylabel('TBS (Kbits)', 'FontSize', 36);
set(gca, 'FontSize', 36);

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
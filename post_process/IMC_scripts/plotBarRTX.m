function plotBarRTX(data, config)
% PLOTBARRTX Plots packet transmission with retransmission data
%   PLOTBARRTX(data, config) plots packet transmission data with
%   correlation to retransmission events in PHY layer
%
%   Input:
%   - data: Structure with processed data (UL or DL) that has already been
%     processed with processDataForTimePeriod
%   - config: Structure with configuration parameters including:
%     - header_len: Header length for packet size calculation (bytes)
%     - enb2sfu_delay: Network delay between eNB and SFU (ms)
%
%   The function creates two subplots:
%   1. Top: Horizontal bars showing packet transmission times
%       - x-axis: Time
%       - y-axis: Packet index
%       - Left end: Packet sent time
%       - Right end: Packet receive time
%   2. Bottom: TBS allocations over time, categorized by:
%       - First transmission TBs
%       - Failed TBs (unsuccessful transmission)
%       - Retransmission TBs (successful retransmission)

    % Extract parameters from config
    header_len = config.header_len; % bytes
    enb2sfu_delay = config.enb2sfu_delay;
    
    % Extract PHY data and calculate TBS in kbits - ONLY FOR RNTIs OF INTEREST
    ts_physync = data.ts_physync_interest - data.min_time;
    tbs_physync_kbit = data.tbs_physync_interest/1000; % Convert to kbits
    n_tx_physync = data.n_tx_physync_interest;
    delay_physync = data.delay_physync_interest;
    
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
    [ts_failed_unique, ~, ic] = unique(ts_failed_raw);
    tbs_failed_unique = zeros(size(ts_failed_unique));
    
    for i = 1:length(ts_failed_unique)
        % Find all indices in the original array with this timestamp
        matching_indices = find(ic == i);
        % Use the maximum TBS for this timestamp
        tbs_failed_unique(i) = max(tbs_failed_raw(matching_indices));
    end
    
    % Replace with de-duplicated arrays
    ts_failed = ts_failed_unique;
    tbs_failed = tbs_failed_unique;
    
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
        legend(hLegend(1), {'Packets'});
    elseif numel(unique_streams) == 2
        legend(hLegend, {'Video Packets', 'Audio Packets'});
    else
        streamLabels = cell(numel(unique_streams), 1);
        for i = 1:numel(unique_streams)
            streamLabels{i} = ['Stream ' num2str(unique_streams(i))];
        end
        legend(hLegend, streamLabels);
    end
    
    % Set axis properties
    xlim([0 plot_range_ms]);
    ylim([hline_ylim_lower hline_ylim_upper]);
    set(gca, 'FontName', 'Arial', 'FontSize', 12);
    set(gca, 'XTickLabel', []); % Remove x-axis labels
    xlabel('Time (ms)', 'FontName', 'Arial', 'FontSize', 14);
    ylabel('Packet Index', 'FontName', 'Arial', 'FontSize', 14);
    % title('Packet Transmission with Retransmission Events', 'FontName', 'Arial', 'FontSize', 14);
    hold off;
    
    % =========Create the bar plot at the bottom
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
        h1_filled = bar(ts_1tx(filled_1tx_idx), tbs_1tx(filled_1tx_idx), 'FaceColor', [0.4470 0.5765 0.7960], 'EdgeColor', [0.4470 0.5765 0.7960], 'LineWidth', 2, 'BarWidth', 0.8);
        legend_handles = [legend_handles, h1_filled];
        legend_labels = [legend_labels, {'Used TB'}];
    end
    
    if any(empty_1tx_idx)
        h1_empty = bar(ts_1tx(empty_1tx_idx), tbs_1tx(empty_1tx_idx), 'FaceColor', 'none', 'EdgeColor', [0.4470 0.5765 0.7960], 'LineWidth', 2, 'BarWidth', 0.85);
        legend_handles = [legend_handles, h1_empty];
        legend_labels = [legend_labels, {'Unused TB'}];
    end
    
    % Plot Failed TB bars
    if any(filled_failed_idx)
        h2_filled = bar(ts_failed(filled_failed_idx), tbs_failed(filled_failed_idx), 'FaceColor', 'red', 'EdgeColor', 'red', 'LineWidth', 2, 'BarWidth', 0.4);
        legend_handles = [legend_handles, h2_filled];
        legend_labels = [legend_labels, {'Used Failed TB'}];
    end
    
    if any(empty_failed_idx)
        h2_empty = bar(ts_failed(empty_failed_idx), tbs_failed(empty_failed_idx), 'FaceColor', 'none', 'EdgeColor', 'red', 'LineWidth', 2, 'BarWidth', 0.3);
        legend_handles = [legend_handles, h2_empty];
        legend_labels = [legend_labels, {'Unused Failed TB'}];
    end
    
    % Plot RTX TB bars
    if any(filled_retx_idx)
        h3_filled = bar(ts_retx(filled_retx_idx), tbs_retx(filled_retx_idx), 'FaceColor', [0.4940 0.1840 0.5560], 'EdgeColor', [0.4940 0.1840 0.5560], 'LineWidth', 2, 'BarWidth', 0.4);
        legend_handles = [legend_handles, h3_filled];
        legend_labels = [legend_labels, {'Used RTX TB'}];
    end
    
    if any(empty_retx_idx)
        h3_empty = bar(ts_retx(empty_retx_idx), tbs_retx(empty_retx_idx), 'FaceColor', 'none', 'EdgeColor', [0.4940 0.1840 0.5560], 'LineWidth', 2, 'BarWidth', 0.1);
        legend_handles = [legend_handles, h3_empty];
        legend_labels = [legend_labels, {'Unused RTX TB'}];
    end
    
    % Set axis properties
    xlim([0 plot_range_ms]);
    ylim([0 bar_ylim_upper]);
    yticks((0:round(bar_ylim_upper/3):round(bar_ylim_upper)));
    
    % Add legend if we have handles
    if ~isempty(legend_handles)
        legend(legend_handles, legend_labels, 'NumColumns', 1);
    end
    
    set(gca, 'FontName', 'Arial', 'FontSize', 12);
    xlabel('Time (ms)', 'FontName', 'Arial', 'FontSize', 14);
    ylabel('TBS (kbits)', 'FontName', 'Arial', 'FontSize', 14);
    title('Transport Block Size with Retransmissions (Target UEs Only)', 'FontName', 'Arial', 'FontSize', 14);
    grid on;
    hold off;
    
    % Link the x-axes
    linkaxes([ax1, ax2], 'x');
    
    % Optimize subplot positions
    ax1.Position = [0.16, 0.4, 0.78, 0.5];
    ax2.Position = [0.16, 0.15, 0.78, 0.25];
    
    % Define the paper size (in inches) if needed for publication
    if isfield(config, 'paperWidth') && isfield(config, 'paperHeight')
        set(gcf, 'PaperSize', [config.paperWidth config.paperHeight]);
    else
        % Default paper size for RTX plots
        paperWidth = 30; 
        paperHeight = 20;
        set(gcf, 'PaperSize', [paperWidth paperHeight]);
    end
end
function plotDelaySpread(data, tbs_threshold, config)
% PLOTDELAYSPREAD Plots packet delay spread and correlates with TBS allocations
%   PLOTDELAYSPREAD(data, tbs_threshold, config) plots
%   packet delay spread and correlates with TBS allocations
%
%   Input:
%   - data: Structure with processed data (UL or DL) that has already been
%     processed with processDataForTimePeriod
%   - tbs_threshold: Threshold to distinguish proactive vs requested TB (kbits)
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
%   2. Bottom: TBS allocations over time
%       - Proactive TBs (smaller than threshold)
%       - Requested TBs (larger than or equal to threshold)
%       - TBs are correlated with packets by timestamp comparison

    % Header length for packet size calculation
    header_len = config.header_len; % bytes
    enb2sfu_delay = config.enb2sfu_delay;
    
    % Extract PHY data and convert TBS to kbits - ONLY FOR RNTIs OF INTEREST
    ts_physync = data.ts_physync_interest - data.min_time;
    tbs_physync_kbit = data.tbs_physync_interest/1000; % Convert to kbits
    valid_idx = data.n_tx_physync_interest >= 1;
    ts_valid = ts_physync(valid_idx);
    tbs_valid = tbs_physync_kbit(valid_idx);
    
    % Separate proactive and requested TBs
    proact_idx = tbs_physync_kbit < tbs_threshold & valid_idx;
    ts_proact = ts_physync(proact_idx);
    tbs_proact = tbs_physync_kbit(proact_idx);
    
    bsr_idx = tbs_physync_kbit >= tbs_threshold & valid_idx;
    ts_bsr = ts_physync(bsr_idx);
    tbs_bsr = tbs_physync_kbit(bsr_idx);
    
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
    
    % Identify which proactive and requested TBs were used for packets
    [~, idx_proact_in_phy] = ismember(ts_proact, ts_phy_pkt);
    filled_proact_idx = idx_proact_in_phy > 0;
    empty_proact_idx = ~filled_proact_idx;
    
    [~, idx_bsr_in_phy] = ismember(ts_bsr, ts_phy_pkt);
    filled_bsr_idx = idx_bsr_in_phy > 0;
    empty_bsr_idx = ~filled_bsr_idx;
    
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
    
    % Create the hline plot on top
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
    title('Packet Transmission Timing (Target UEs Only)', 'FontName', 'Arial', 'FontSize', 14);
    hold off;
    
    % Create the bar plot at the bottom
    ax2 = subplot(2, 1, 2);
    hold on;
    
    % Add vertical lines for TBs that were used by packets
    for i = 1:length(ts_phy_pkt)
        xV1 = ts_phy_pkt(i);
        if xV1 > 0 % Only if a TB was found
            line([xV1, xV1], [bar_ylim_upper, 0], 'Color', [0.5, 0.5, 0.5], 'LineStyle', '--', 'LineWidth', 1.5); 
        end
    end
    
    % Plot Proactive TB bars
    if any(filled_proact_idx)
        h1_filled = bar(ts_proact(filled_proact_idx), tbs_proact(filled_proact_idx), 'FaceColor', [0.4470 0.5765 0.7960], 'EdgeColor', [0.4470 0.5765 0.7960], 'LineWidth', 2, 'BarWidth', 0.8);
    else
        h1_filled = [];
    end
    
    if any(empty_proact_idx)
        h1_empty = bar(ts_proact(empty_proact_idx), tbs_proact(empty_proact_idx), 'FaceColor', 'none', 'EdgeColor', [0.4470 0.5765 0.7960], 'LineWidth', 2, 'BarWidth', 0.8);
    else
        h1_empty = [];
    end
    
    % Plot Requested TB bars
    if any(filled_bsr_idx)
        h2_filled = bar(ts_bsr(filled_bsr_idx), tbs_bsr(filled_bsr_idx), 'FaceColor', [0.4660 0.6740 0.1880], 'EdgeColor', [0.4660 0.6740 0.1880], 'LineWidth', 2, 'BarWidth', 0.5);
    else
        h2_filled = [];
    end
    
    if any(empty_bsr_idx)
        h2_empty = bar(ts_bsr(empty_bsr_idx), tbs_bsr(empty_bsr_idx), 'FaceColor', 'none', 'EdgeColor', [0.4660 0.6740 0.1880], 'LineWidth', 2, 'BarWidth', 0.04);
    else
        h2_empty = [];
    end
    
    % Prepare legend handles and labels
    legend_handles = [];
    legend_labels = {};
    
    if ~isempty(h1_filled)
        legend_handles = [legend_handles, h1_filled];
        legend_labels = [legend_labels, {'Used Proactive TB'}];
    end
    
    if ~isempty(h1_empty)
        legend_handles = [legend_handles, h1_empty];
        legend_labels = [legend_labels, {'Unused Proactive TB'}];
    end
    
    if ~isempty(h2_filled)
        legend_handles = [legend_handles, h2_filled];
        legend_labels = [legend_labels, {'Used Requested TB'}];
    end
    
    if ~isempty(h2_empty)
        legend_handles = [legend_handles, h2_empty];
        legend_labels = [legend_labels, {'Unused Requested TB'}];
    end
    
    % Set axis properties
    xlim([0 plot_range_ms]);
    ylim([0 bar_ylim_upper]);
    
    % Add legend if we have handles
    if ~isempty(legend_handles)
        legend(legend_handles, legend_labels, 'NumColumns', 1);
    end
    
    set(gca, 'FontName', 'Arial', 'FontSize', 12);
    xlabel('Time (ms)', 'FontName', 'Arial', 'FontSize', 14);
    ylabel('TBS (kbits)', 'FontName', 'Arial', 'FontSize', 14);
    title('Transport Block Size Allocation (Target UEs Only)', 'FontName', 'Arial', 'FontSize', 14);
    grid on;
    hold off;
    
    % Link the x-axes
    linkaxes([ax1, ax2], 'x');
    
    % Optimize subplot positions
    ax1.Position = [0.16, 0.4, 0.78, 0.5];
    ax2.Position = [0.16, 0.15, 0.78, 0.25];

end
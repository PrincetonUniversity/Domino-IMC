function plotPhyTbsCapComp(data, bin_size, xaxis_base)
    % Convert packet size from bytes to bits
    pkt_size_bits = data.pkt_size * 8;
    
    % Normalize timestamps to start from 0 for plotting
    time_offset = data.min_time;
    ts_phy_norm = (data.ts_physync_interest - time_offset)/1000;  % Convert to seconds
    
    % Choose appropriate packet timestamps based on xaxis_base parameter
    if strcmpi(xaxis_base, 'server')
        % Use server timestamps
        ts_pkt_norm = (data.ts_server - time_offset)/1000;  % Convert to seconds
        base_label = 'Server-based';
    else % 'ue'
        % Use UE timestamps
        ts_pkt_norm = (data.ts_ue - time_offset)/1000;  % Convert to seconds
        base_label = 'UE-based';
    end
    
    % Create time bins for aggregation
    bin_size_sec = bin_size/1000;  % Convert ms to seconds
    plot_start = (min(data.ts_physync_interest) - time_offset)/1000;
    plot_end = (max(data.ts_physync_interest) - time_offset)/1000;
    time_bins = plot_start:bin_size_sec:plot_end;
    
    % Initialize arrays for binned data
    tbs_binned = zeros(length(time_bins)-1, 1);
    pkt_binned = zeros(length(time_bins)-1, 1);
    bin_centers = zeros(length(time_bins)-1, 1);
    
    % Aggregate data into bins
    for i = 1:length(time_bins)-1
        % Find PHY data points in this bin - now using ts_physync_interest directly
        phy_idx = (ts_phy_norm >= time_bins(i)) & (ts_phy_norm < time_bins(i+1));
        
        if any(phy_idx)
            tbs_binned(i) = sum(data.tbs_physync_interest(phy_idx));
        end
        
        % Find packet data points in this bin - using timestamp based on xaxis_base
        pkt_idx = (ts_pkt_norm >= time_bins(i)) & (ts_pkt_norm < time_bins(i+1));
        if any(pkt_idx)
            pkt_binned(i) = sum(pkt_size_bits(pkt_idx));
        end
        
        % Calculate bin center for x-axis
        bin_centers(i) = (time_bins(i) + time_bins(i+1))/2;
    end
    
    % Convert to Mbps (divide by bin size in seconds)
    tbs_mbps = tbs_binned / (bin_size/1000) / 1e6;
    pkt_mbps = pkt_binned / (bin_size/1000) / 1e6;
    
    % Calculate effective TBS (95% of TBS)
    tbs_effective_mbps = 0.95 * tbs_mbps;
    
    % Calculate bar positions and widths
    bar_width = 0.4; % Width of each bar is 0.4 of bin size
    pkt_centers = bin_centers - bin_size_sec * 0.2; % Left bar centered at 0.3 of bin size
    tbs_centers = bin_centers + bin_size_sec * 0.2; % Right bar centered at 0.7 of bin size
    
    % Plot data as bars
    hold on;
    bar(pkt_centers, pkt_mbps, bar_width, 'r', 'DisplayName', 'Packet Data');
    bar(tbs_centers, tbs_effective_mbps, bar_width, 'b', 'DisplayName', '95% TBS Capacity');
    hold off;
    
    grid on;
    xlabel('Time (s)');
    ylabel('Data Rate (Mbps)');
    legend('Location', 'best');
    
    % Add timestamp base to title if title is not already set
    if isempty(get(gca, 'Title'))
        title([data.direction ' Capacity: TBS vs Packet (' base_label ')']);
    end
end
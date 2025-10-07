function CapacityComparison(data, bin_size, ues_of_interest_only, xaxis_base, is_dl, datapath)
    % Convert packet size from bytes to bits
    pkt_size_bits = data.pkt_size * 8;
    
    % Normalize timestamps to start from 0 for plotting
    time_offset = data.min_time;
    ts_phy_norm = (data.ts_physync - time_offset)/1000;  % Convert to seconds
    
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
    
    ts_app_norm = (data.ts_appout_range - time_offset)/1000;  % Convert to seconds
    
    % Create time bins for aggregation
    bin_size_sec = bin_size/1000;  % Convert ms to seconds
    plot_start = (min(data.ts_physync) - time_offset)/1000;
    plot_end = (max(data.ts_physync) - time_offset)/1000;
    time_bins = plot_start:bin_size_sec:plot_end;
    
    % Initialize arrays for binned data
    tbs_binned = zeros(length(time_bins)-1, 1);
    pkt_binned = zeros(length(time_bins)-1, 1);
    bitrate_binned = zeros(length(time_bins)-1, 1);
    bin_centers = zeros(length(time_bins)-1, 1);
    
    % Aggregate data into bins
    for i = 1:length(time_bins)-1
        % Find PHY data points in this bin
        if ues_of_interest_only
            phy_idx = (ts_phy_norm >= time_bins(i)) & (ts_phy_norm < time_bins(i+1)) & data.is_interest_ue;
        else
            phy_idx = (ts_phy_norm >= time_bins(i)) & (ts_phy_norm < time_bins(i+1));
        end
        
        if any(phy_idx)
            tbs_binned(i) = sum(data.tbs_physync(phy_idx));
        end
        
        % Find packet data points in this bin - using timestamp based on xaxis_base
        pkt_idx = (ts_pkt_norm >= time_bins(i)) & (ts_pkt_norm < time_bins(i+1));
        if any(pkt_idx)
            pkt_binned(i) = sum(pkt_size_bits(pkt_idx));
        end
        
        % Find app target bitrate points in this bin
        app_idx = (ts_app_norm >= time_bins(i)) & (ts_app_norm < time_bins(i+1));
        if any(app_idx)
            % Get target bitrate (column 14 in appout data)
            bitrate_binned(i) = mean(data.data_appout(app_idx, 14))/1e6;  % Convert to Mbps
        elseif i > 1 && bitrate_binned(i-1) > 0
            % If no data in this bin, use the last known value
            bitrate_binned(i) = bitrate_binned(i-1);
        end
        
        % Calculate bin center for x-axis
        bin_centers(i) = (time_bins(i) + time_bins(i+1))/2;
    end
    
    % Convert to Mbps (divide by bin size in seconds)
    tbs_mbps = tbs_binned / (bin_size/1000) / 1e6;
    pkt_mbps = pkt_binned / (bin_size/1000) / 1e6;
    
    % Calculate effective TBS (95% of TBS)
    tbs_effective_mbps = 0.95 * tbs_mbps;
    
    if is_dl
        time_dl_tbs = [bin_centers'; tbs_mbps'];
        time_dl_tbs_effective = [bin_centers'; tbs_effective_mbps'];
        time_dl_pkt = [bin_centers'; pkt_mbps'];
        time_dl_bitrate = [bin_centers'; bitrate_binned'];
        save([datapath 'time_dl_tbs.mat'], "time_dl_tbs");
        save([datapath 'time_dl_tbs_effective.mat'], "time_dl_tbs_effective");
        save([datapath 'time_dl_pkt.mat'], "time_dl_pkt");
        save([datapath 'time_dl_bitrate.mat'], "time_dl_bitrate");
    else
        time_ul_tbs = [bin_centers'; tbs_mbps'];
        time_ul_tbs_effective = [bin_centers'; tbs_effective_mbps'];
        time_ul_pkt = [bin_centers'; pkt_mbps'];
        time_ul_bitrate = [bin_centers'; bitrate_binned'];
        save([datapath 'time_ul_tbs.mat'], "time_ul_tbs");
        save([datapath 'time_ul_tbs_effective.mat'], "time_ul_tbs_effective");
        save([datapath 'time_ul_pkt.mat'], "time_ul_pkt");
        save([datapath 'time_ul_bitrate.mat'], "time_ul_bitrate");
    end
end
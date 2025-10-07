function plotPhyTbsByRnti(data, bin_sz_tbs, RNTIs_of_interest)
    % Extract PHY data from the struct
    ts_physync = data.ts_physync;
    tbs_physync = data.tbs_physync;
    rntis_physync = data.rntis_physync;
    is_interest_ue = data.is_interest_ue;
    
    % Filter to only include UEs of interest
    ts_physync = ts_physync(is_interest_ue);
    tbs_physync = tbs_physync(is_interest_ue);
    rntis_physync = rntis_physync(is_interest_ue);
    
    % Fixed color array for up to 8 RNTIs
    colors = [
        0 0.4470 0.7410; % Blue
        0.8500 0.3250 0.0980; % Orange
        0.9290 0.6940 0.1250; % Yellow
        0.4940 0.1840 0.5560; % Purple
        0.4660 0.6740 0.1880; % Green
        0.3010 0.7450 0.9330; % Light blue
        0.6350 0.0780 0.1840; % Dark red
        0 0.75 0.75; % Teal
    ];
    
    % Sort RNTIs by first appearance time
    first_appearance = struct('rnti', {}, 'time', {});
    for i = 1:length(rntis_physync)
        rnti = rntis_physync(i);
        t = ts_physync(i);
        
        % Check if RNTI is already in the structure
        found = false;
        for j = 1:length(first_appearance)
            if first_appearance(j).rnti == rnti
                % If already exists, update time if this is earlier
                if t < first_appearance(j).time
                    first_appearance(j).time = t;
                end
                found = true;
                break;
            end
        end
        
        % If not found, add it
        if ~found
            first_appearance(end+1).rnti = rnti;
            first_appearance(end).time = t;
        end
    end
    
    % Sort the structure by time
    [~, idx] = sort([first_appearance.time]);
    first_appearance = first_appearance(idx);
    
    % Get ordered list of active RNTIs
    active_RNTIs = [first_appearance.rnti];
    num_active_RNTIs = length(active_RNTIs);
    
    % Create a map from active RNTI to index
    rnti_to_idx = containers.Map('KeyType', 'double', 'ValueType', 'double');
    for i = 1:num_active_RNTIs
        rnti_to_idx(active_RNTIs(i)) = i;
    end
    
    % Normalize timestamps to start from 0 for plotting - like in plotPhyTbsCapComp
    time_offset = data.min_time;
    ts_normalized = (ts_physync - time_offset)/1000;  % Convert to seconds
    
    % Convert bin size to seconds for consistency
    bin_size_sec = bin_sz_tbs/1000;  % Convert ms to seconds
    
    % Create time bins for aggregation similar to plotPhyTbsCapComp
    plot_start = min(ts_normalized);
    plot_end = max(ts_normalized);
    time_bins = plot_start:bin_size_sec:plot_end;
    
    % Check if we have enough bins
    if length(time_bins) <= 1
        warning('Not enough data for multiple bins.');
        return;
    end
    
    % Initialize array for binned data
    num_bins = length(time_bins) - 1;
    tbs_by_rnti = zeros(num_bins, num_active_RNTIs);
    bin_centers = zeros(num_bins, 1);
    
    % Process each time bin
    for i = 1:num_bins
        % Find data points in this bin - using same approach as plotPhyTbsCapComp
        bin_indices = (ts_normalized >= time_bins(i)) & (ts_normalized < time_bins(i+1));
        
        if any(bin_indices)
            % Get all data points in this bin
            bin_rntis = rntis_physync(bin_indices);
            bin_tbs = tbs_physync(bin_indices);
            
            % Aggregate TBS by RNTI for this bin
            for j = 1:length(bin_rntis)
                rnti_idx = rnti_to_idx(bin_rntis(j));
                tbs_by_rnti(i, rnti_idx) = tbs_by_rnti(i, rnti_idx) + bin_tbs(j);
            end
            
            % Convert to Mbps
            tbs_by_rnti(i, :) = (tbs_by_rnti(i, :)/bin_size_sec) / 1e6;
        end
        
        % Calculate bin center for x-axis (same as in plotPhyTbsCapComp)
        bin_centers(i) = (time_bins(i) + time_bins(i+1))/2;
    end
    
    % Create stacked bar chart
    b = bar(bin_centers, tbs_by_rnti, 'stacked');
    
    % Set colors for each RNTI
    for r = 1:num_active_RNTIs
        color_idx = mod(r-1, size(colors, 1)) + 1;  % Cycle through colors if more RNTIs than colors
        b(r).FaceColor = colors(color_idx, :);
    end
    
    % Create legend labels only for active RNTIs
    legend_text = cell(1, num_active_RNTIs);
    for r = 1:num_active_RNTIs
        legend_text{r} = ['RNTI ' num2str(active_RNTIs(r))];
    end
    
    % Set labels and grid
    ylabel('TBS (Mbps)')
    xlabel('Time (s)')
    grid on
    legend(legend_text, 'Location', 'NorthEast')
end
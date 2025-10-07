function plotPhyPrbAllocation(data, bin_sz_phy, slot_duration, duplex)
    % Check if duplex mode is supported
    if strcmpi(duplex, 'TDD')
        text(0.5, 0.5, 'TDD mode has specific slot structure for PRB allocation plotting', ...
            'HorizontalAlignment', 'center', 'FontSize', 14);
    end
    
    % Normalize timestamps to start from 0 for plotting
    time_offset = data.min_time;
    
    % Convert to seconds for consistency with plotPhyTbsCapComp
    bin_size_sec = bin_sz_phy/1000;  % Convert ms to seconds
    
    % Create time bins for aggregation similar to plotPhyTbsCapComp
    plot_start = (min(data.ts_physync) - time_offset)/1000;
    plot_end = (max(data.ts_physync) - time_offset)/1000;
    time_bins = plot_start:bin_size_sec:plot_end;
    bin_centers = zeros(length(time_bins)-1, 1);
    
    % Initialize arrays for binned data
    prb_sum_interest = zeros(length(time_bins)-1, 1);
    prb_sum_others = zeros(length(time_bins)-1, 1);
    
    % Normalize timestamps to seconds
    ts_physync_norm = (data.ts_physync - time_offset)/1000;
    
    % Process each time bin
    for i = 1:length(time_bins)-1
        % Find data points in this bin
        bin_indices = (ts_physync_norm >= time_bins(i)) & (ts_physync_norm < time_bins(i+1));
        
        if any(bin_indices)
            % Get which entries in this bin belong to UEs of interest
            bin_is_interest = data.is_interest_ue(bin_indices);
            
            % Get unique slots in this bin
            unique_slots = unique(data.ts_physync(bin_indices));
            
            % Count slots with UEs of interest
            interest_slots = unique(data.ts_physync(bin_indices & data.is_interest_ue));
            num_interest_slots = length(interest_slots);
            
            % Count slots with other UEs
            other_slots = unique(data.ts_physync(bin_indices & ~data.is_interest_ue));
            num_other_slots = length(other_slots);
            
            % Count slots with both types of UEs (intersection)
            both_slots = intersect(interest_slots, other_slots);
            num_either_slots = num_interest_slots + num_other_slots - length(both_slots);
            
            % Calculate average PRB for UEs of interest in this bin
            if any(bin_is_interest)
                interest_indices = bin_indices & data.is_interest_ue;
                if num_either_slots > 0
                    prb_sum_interest(i) = sum(data.prb_physync(interest_indices)) / num_either_slots;
                end
            end
            
            % Calculate average PRB for other UEs in this bin
            if any(~bin_is_interest)
                other_indices = bin_indices & ~data.is_interest_ue;
                if num_either_slots > 0
                    prb_sum_others(i) = sum(data.prb_physync(other_indices)) / num_either_slots;
                end
            end
        end
        
        % Calculate bin center for x-axis
        bin_centers(i) = (time_bins(i) + time_bins(i+1))/2;
    end
    
    % Create stacked bar chart
    b = bar(bin_centers, [prb_sum_interest prb_sum_others], 'stacked');
    b(1).FaceColor = 'b'; % UEs of interest in blue
    b(2).FaceColor = 'y'; % Other UEs in yellow
    
    xlabel('Time (s)');
    ylabel('Average PRB');
    grid on;
    legend('Target UE', 'Other UEs', 'Location', 'NorthEast');
    
    % Add duplex mode to title
    title(['Average PRB Allocation (' upper(duplex) ')']);
end
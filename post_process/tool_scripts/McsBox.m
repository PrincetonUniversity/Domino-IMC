function McsBox(data, bin_sz_phy, is_dl, datapath)
    % Plot MCS statistics in box plot format
    % First filter out MCS values > 28 and get only UEs of interest
    valid_mcs_indices = (data.mcs_physync <= 28) & data.is_interest_ue;
    
    % Check if we have valid MCS data
    if ~any(valid_mcs_indices)
        warning('No valid MCS data points (MCS ≤ 28) found for UEs of interest.');
        return;
    end
    
    % Extract valid MCS values and their timestamps
    mcs_values = data.mcs_physync(valid_mcs_indices);
    ts_values = data.ts_physync(valid_mcs_indices);
    
    % Normalize timestamps to start from 0
    ts_normalized = ts_values - data.min_time;
    
    % Group MCS data by time bins
    bin_indices = floor(ts_normalized / bin_sz_phy) + 1;
    if isempty(bin_indices)
        warning('No data points found after binning.');
        return;
    end
    
    max_bin = max(bin_indices);
    
    % Initialize arrays for percentiles
    p90 = nan(max_bin, 1);
    p75 = nan(max_bin, 1);
    p50 = nan(max_bin, 1);
    p25 = nan(max_bin, 1);
    p10 = nan(max_bin, 1);
    
    % Calculate bin centers for x-axis
    bin_centers = ((1:max_bin) - 0.5) * bin_sz_phy / 1000; % Convert to seconds
    
    % Calculate percentiles for each bin
    for bin = 1:max_bin
        bin_mcs = mcs_values(bin_indices == bin);
        
        if length(bin_mcs) >= 5 % Need at least 5 points for meaningful percentiles
            p90(bin) = prctile(bin_mcs, 90);
            p75(bin) = prctile(bin_mcs, 75);
            p50(bin) = prctile(bin_mcs, 50);
            p25(bin) = prctile(bin_mcs, 25);
            p10(bin) = prctile(bin_mcs, 10);
        end
    end

    if is_dl
        time_dl_90mcs = [bin_centers; p90'];
        time_dl_50mcs = [bin_centers; p50'];
        time_dl_10mcs = [bin_centers; p10'];
        save([datapath 'time_dl_90mcs.mat'], "time_dl_90mcs");
        save([datapath 'time_dl_50mcs.mat'], "time_dl_50mcs");
        save([datapath 'time_dl_10mcs.mat'], "time_dl_10mcs");
    else
        time_ul_90mcs = [bin_centers; p90'];
        time_ul_50mcs = [bin_centers; p50'];
        time_ul_10mcs = [bin_centers; p10'];
        save([datapath 'time_ul_90mcs.mat'], "time_ul_90mcs");
        save([datapath 'time_ul_50mcs.mat'], "time_ul_50mcs");
        save([datapath 'time_ul_10mcs.mat'], "time_ul_10mcs");
    end
end
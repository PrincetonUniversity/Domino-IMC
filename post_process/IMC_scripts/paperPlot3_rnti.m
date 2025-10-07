%% Parameters
clear;close all

% Define experiment and application codes
expCode = '0417';
appCode = '1744753467';
linktype = 'U'; % 'U' for uplink, 'D' for downlink

% Moving average window size for packet delay
window_size = 1;
% Bin sizes
bin_sz_prb = 100;  % PRB data bin size (ms)
bin_sz_mcs = 100;
bin_sz_tbs = 100;  % PRB data bin size (ms)
enb2sfu_delay = 6.0; % ms

% Define relative plot period
relative_plot_period = [098501, 106500];

% Load data
[ulData, dlData, config] = loadWebRTCData(expCode, appCode, enb2sfu_delay);

%% Process data for time period
% Calculate DL plot period based on DL data start time
dl_start_time = floor(dlData.data_packets(1,14));
dl_plot_period = [dl_start_time + relative_plot_period(1), dl_start_time + relative_plot_period(2)];

% Calculate UL plot period based on UL data start time
ul_start_time = floor(ulData.data_packets(1,14));
ul_plot_period = [ul_start_time + relative_plot_period(1), ul_start_time + relative_plot_period(2)];

% Process data with appropriate direction parameters
dlData = processDataForTimePeriod(dlData, dl_plot_period, config, 'DL');
ulData = processDataForTimePeriod(ulData, ul_plot_period, config, 'UL');

%% Create main figure
figure;
set(gcf, 'Position', [100, 100, 1200, 1000]);  % Increase height to accommodate subplots

% Create array to store axes handles for linking
ax = cell(5, 1);

% Define relative heights for each subplot (sum should be 1)
% Adjust these values to change relative heights
heights = [0.17, 0.17, 0.17, 0.17, 0.14];
bottom = 0.1;

% Define highlight regions
highlight_pink_x = [1.05, 1.45];
highlight_green_x = [5.15, 5.45];

% Determine which data to use based on linktype
if strcmp(linktype, 'U')
    data = ulData;
    opposite_data = dlData;
    direction_label = 'Uplink';
    opposite_direction_label = 'Downlink';
else % 'D'
    data = dlData;
    opposite_data = ulData;
    direction_label = 'Downlink';
    opposite_direction_label = 'Uplink';
end

%% 1. Merged plotPhyPrbAllocation function
% [left, bottom, width, height]
ax{1} = subplot('Position', [0.2, sum(heights(2:end))+bottom, 0.75, heights(1)]);

% Normalize timestamps to start from 0 for plotting
time_offset = data.min_time;

% Convert to seconds for consistency with plotPhyTbsCapComp
bin_size_sec = bin_sz_prb/1000;  % Convert ms to seconds

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

% Add highlight regions
hold on;
ylim_values = [0, 80];
% Pink highlight region - make sure to set 'HandleVisibility' to 'off'
h_pink = patch([highlight_pink_x(1), highlight_pink_x(2), highlight_pink_x(2), highlight_pink_x(1)], ...
      [ylim_values(1), ylim_values(1), ylim_values(2), ylim_values(2)], ...
      [1, 0.8, 0.8], 'FaceAlpha', 0.4, 'EdgeColor', 'none', 'HandleVisibility', 'off');

% Green highlight region - make sure to set 'HandleVisibility' to 'off'
h_green = patch([highlight_green_x(1), highlight_green_x(2), highlight_green_x(2), highlight_green_x(1)], ...
      [ylim_values(1), ylim_values(1), ylim_values(2), ylim_values(2)], ...
      [1, 0.8, 0.8], 'FaceAlpha', 0.4, 'EdgeColor', 'none', 'HandleVisibility', 'off');

% Create stacked bar chart
b = bar(bin_centers, [prb_sum_interest prb_sum_others], 'stacked', 'EdgeColor', 'none');
b(1).FaceColor = [120/255, 146/255, 235/255]; % #7892eb for Target UE
b(2).FaceColor = [247/255, 232/255, 92/255];  % #f7e85c for Other UEs

% Set y-axis label only
ylabel('PRB', 'FontSize', 24);
ylim(ylim_values);
yticks([0, 20, 40, 60, 80]);
xlim([0, 8]);
grid on;
lgd = legend('Exp. UE', 'Other UEs', 'Location', 'NorthEast');
lgd.FontSize = 20;
set(gca, 'XTickLabel', [], 'FontSize', 24);  % Remove x-tick labels and set font size
hold off;

%% 2. mcs
ax{2} = subplot('Position', [0.2, sum(heights(3:end))+bottom, 0.75, heights(2)]);

valid_mcs_indices = (data.mcs_physync <= 28) & data.is_interest_ue;

% Check if we have valid MCS data
if ~any(valid_mcs_indices)
    warning('No valid MCS data points (MCS ≤ 28) found for UEs of interest.');
    text(0.5, 0.5, 'No valid MCS data available', 'HorizontalAlignment', 'center');
    axis off;
    return;
end

% Extract valid MCS values and their timestamps
mcs_values = data.mcs_physync(valid_mcs_indices);
ts_values = data.ts_physync(valid_mcs_indices);

% Normalize timestamps to start from 0 and convert to seconds
time_offset = data.min_time;
ts_normalized = (ts_values - time_offset)/1000;  % Convert to seconds

% Convert bin size to seconds for consistency
bin_size_sec = bin_sz_mcs/1000;  % Convert ms to seconds

% Create time bins for aggregation similar to plotPhyTbsCapComp
plot_start = min(ts_normalized);
plot_end = max(ts_normalized);
time_bins = plot_start:bin_size_sec:plot_end;

% Check if we have enough bins
if length(time_bins) <= 1
    warning('Not enough data for multiple bins.');
    text(0.5, 0.5, 'Not enough data for multiple bins', 'HorizontalAlignment', 'center');
    axis off;
    return;
end

% Initialize arrays for percentiles
num_bins = length(time_bins) - 1;
p90 = nan(num_bins, 1);
p75 = nan(num_bins, 1);
p50 = nan(num_bins, 1);
p25 = nan(num_bins, 1);
p10 = nan(num_bins, 1);

% Calculate bin centers for x-axis
bin_centers = zeros(num_bins, 1);

% Calculate percentiles for each bin
for i = 1:num_bins
    % Find data points in this bin - similar to plotPhyTbsCapComp approach
    bin_indices = (ts_normalized >= time_bins(i)) & (ts_normalized < time_bins(i+1));
    bin_mcs = mcs_values(bin_indices);
    
    if length(bin_mcs) >= 5 % Need at least 5 points for meaningful percentiles
        p90(i) = prctile(bin_mcs, 90);
        p75(i) = prctile(bin_mcs, 75);
        p50(i) = prctile(bin_mcs, 50);
        p25(i) = prctile(bin_mcs, 25);
        p10(i) = prctile(bin_mcs, 10);
    end
    
    % Calculate bin center for x-axis (same as in plotPhyTbsCapComp)
    bin_centers(i) = (time_bins(i) + time_bins(i+1))/2;
end


% Plot boxes from 10th to 90th percentile with light blue fill
hold on;
ylim_values = [-1, 29];
% Pink highlight region
patch([highlight_pink_x(1), highlight_pink_x(2), highlight_pink_x(2), highlight_pink_x(1)], ...
      [ylim_values(1), ylim_values(1), ylim_values(2), ylim_values(2)], ...
      [1, 0.8, 0.8], 'FaceAlpha', 0.4, 'EdgeColor', 'none');

% Green highlight region
patch([highlight_green_x(1), highlight_green_x(2), highlight_green_x(2), highlight_green_x(1)], ...
      [ylim_values(1), ylim_values(1), ylim_values(2), ylim_values(2)], ...
      [1, 0.8, 0.8], 'FaceAlpha', 0.4, 'EdgeColor', 'none');


% Define box width (0.6 * bin_size in seconds)
box_width = 0.6 * bin_size_sec;

% Light blue color for face
light_blue = [0.7, 0.9, 1.0];

% Plot boxes for each bin
for i = 1:num_bins
    if ~isnan(p50(i))
        % Box coordinates
        x_left = bin_centers(i) - box_width/2;
        x_right = bin_centers(i) + box_width/2;
        y_bottom = p10(i);
        y_top = p90(i);
        
        % Create filled rectangle
        x_rect = [x_left, x_right, x_right, x_left];
        y_rect = [y_bottom, y_bottom, y_top, y_top];
        fill(x_rect, y_rect, light_blue, 'EdgeColor', 'b');
        
        % Add median line
        plot([x_left, x_right], [p50(i), p50(i)], 'r-', 'LineWidth', 1.5);
    end
end

% Set axis labels and grid
ylabel('MCS');
grid on;
% Set y-label with two rows
ylim(ylim_values);
yticks([0, 8, 16, 24]);
xlim([0, 8]);


% Add legend
h1 = fill(NaN(1,4), NaN(1,4), light_blue, 'EdgeColor', 'b');
h2 = plot(NaN, NaN, 'r-', 'LineWidth', 1.5);
lgd = legend([h1, h2], {'10-90th %ile', 'Median'}, 'Location', 'NorthEast');
lgd.FontSize = 20;
set(gca, 'XTickLabel', [], 'FontSize', 24);  % Remove x-tick labels and set font size

hold off;


%% 3. tbs
ax{3} = subplot('Position', [0.2, sum(heights(4:end))+bottom, 0.75, heights(3)]);

% Extract PHY data from the struct
ts_physync = data.ts_physync;
tbs_physync = data.tbs_physync;
rntis_physync = data.rntis_physync;
is_interest_ue = data.is_interest_ue;

% Filter to only include UEs of interest
ts_physync = ts_physync(is_interest_ue);
tbs_physync = tbs_physync(is_interest_ue);
rntis_physync = rntis_physync(is_interest_ue);

% Fixed color array for up to 8 RNTIs - MODIFIED: Made colors lighter
colors = [
    0         0.4470    0.7410; % Blue 
    0.8196    0.3804    0.9804; % Purple    
    0.9490    0.6353    0.1608; % Orange
    0.3010 0.7450 0.9330; % Light blue      
    0.9290 0.6940 0.1250; % Yellow
    0.6078    0.9804    0.7765; % Green  
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

% Add highlight regions
hold on;
ylim_values = [0, 12.0];
% Pink highlight region - make sure to set 'HandleVisibility' to 'off'
h_pink = patch([highlight_pink_x(1), highlight_pink_x(2), highlight_pink_x(2), highlight_pink_x(1)], ...
      [ylim_values(1), ylim_values(1), ylim_values(2), ylim_values(2)], ...
      [1, 0.8, 0.8], 'FaceAlpha', 0.4, 'EdgeColor', 'none', 'HandleVisibility', 'off');

% Green highlight region - make sure to set 'HandleVisibility' to 'off'
h_green = patch([highlight_green_x(1), highlight_green_x(2), highlight_green_x(2), highlight_green_x(1)], ...
      [ylim_values(1), ylim_values(1), ylim_values(2), ylim_values(2)], ...
      [1, 0.8, 0.8], 'FaceAlpha', 0.4, 'EdgeColor', 'none', 'HandleVisibility', 'off');

% Create stacked bar chart
b = bar(bin_centers, tbs_by_rnti, 'stacked');

% Set colors for each RNTI and remove edges
for r = 1:num_active_RNTIs
    color_idx = mod(r-1, size(colors, 1)) + 1;  % Cycle through colors if more RNTIs than colors
    b(r).FaceColor = colors(color_idx, :);
    b(r).EdgeColor = 'none';  % Remove the edge of the bars
end

% Create legend labels only for active RNTIs
legend_text = cell(1, num_active_RNTIs);
for r = 1:num_active_RNTIs
    legend_text{r} = ['RNTI ' num2str(active_RNTIs(r))];
end

% Set labels and grid
grid on
ylabel({'TBS'; '(Mbps)'})
ylim(ylim_values);
yticks([0, 3, 6, 9]);
xlim([0, 8]);
lgd = legend(legend_text, 'Location', 'NorthEast');
lgd.FontSize = 20;
set(gca, 'XTickLabel', [], 'FontSize', 24);  % Remove x-tick labels and set font size

hold off;

%% 4. cap
ax{4} = subplot('Position', [0.2, sum(heights(5:end))+bottom, 0.75, heights(4)]);

% % Choose appropriate xaxis_base based on linktype
% if strcmp(linktype, 'U')
%     xaxis_base = 'ue';
% else % 'D'
%     xaxis_base = 'server';
% end
% 
% % Convert packet size from bytes to bits
% pkt_size_bits = data.pkt_size * 8;
% 
% % Normalize timestamps to start from 0 for plotting
% time_offset = data.min_time;
% ts_phy_norm = (data.ts_physync_interest - time_offset)/1000;  % Convert to seconds
% 
% % Choose appropriate packet timestamps based on xaxis_base parameter
% if strcmpi(xaxis_base, 'server')
%     % Use server timestamps
%     ts_pkt_norm = (data.ts_server - time_offset)/1000;  % Convert to seconds
%     base_label = 'Server-based';
% else % 'ue'
%     % Use UE timestamps
%     ts_pkt_norm = (data.ts_ue - time_offset)/1000;  % Convert to seconds
%     base_label = 'UE-based';
% end
% 
% % Create time bins for aggregation
% bin_size_sec = bin_sz_tbs/1000;  % Convert ms to seconds
% plot_start = (min(data.ts_physync_interest) - time_offset)/1000;
% plot_end = (max(data.ts_physync_interest) - time_offset)/1000;
% time_bins = plot_start:bin_size_sec:plot_end;
% 
% % Initialize arrays for binned data
% tbs_binned = zeros(length(time_bins)-1, 1);
% pkt_binned = zeros(length(time_bins)-1, 1);
% bin_centers = zeros(length(time_bins)-1, 1);
% 
% % Aggregate data into bins
% for i = 1:length(time_bins)-1
%     % Find PHY data points in this bin - now using ts_physync_interest directly
%     phy_idx = (ts_phy_norm >= time_bins(i)) & (ts_phy_norm < time_bins(i+1));
% 
%     if any(phy_idx)
%         tbs_binned(i) = sum(data.tbs_physync_interest(phy_idx));
%     end
% 
%     % Find packet data points in this bin - using timestamp based on xaxis_base
%     pkt_idx = (ts_pkt_norm >= time_bins(i)) & (ts_pkt_norm < time_bins(i+1));
%     if any(pkt_idx)
%         pkt_binned(i) = sum(pkt_size_bits(pkt_idx));
%     end
% 
%     % Calculate bin center for x-axis
%     bin_centers(i) = (time_bins(i) + time_bins(i+1))/2;
% end
% 
% % Convert to Mbps (divide by bin size in seconds)
% tbs_mbps = tbs_binned / (bin_size_sec) / 1e6;
% pkt_mbps = pkt_binned / (bin_size_sec) / 1e6;
% 
% % Calculate effective TBS (95% of TBS)
% tbs_effective_mbps = 0.95 * tbs_mbps;
% 
% % Calculate bar positions and widths
% bar_width = 0.4; % Width of each bar is 0.4 of bin size
% pkt_centers = bin_centers - bin_size_sec * 0.2; % Left bar centered at 0.3 of bin size
% tbs_centers = bin_centers + bin_size_sec * 0.2; % Right bar centered at 0.7 of bin size
% 
% % Add highlight regions
% hold on;
% ylim_values = [0, 12.0];
% % Pink highlight region - make sure to set 'HandleVisibility' to 'off'
% h_pink = patch([highlight_pink_x(1), highlight_pink_x(2), highlight_pink_x(2), highlight_pink_x(1)], ...
%       [ylim_values(1), ylim_values(1), ylim_values(2), ylim_values(2)], ...
%       [1, 0.8, 0.8], 'FaceAlpha', 0.4, 'EdgeColor', 'none', 'HandleVisibility', 'off');
% 
% % Green highlight region - make sure to set 'HandleVisibility' to 'off'
% h_green = patch([highlight_green_x(1), highlight_green_x(2), highlight_green_x(2), highlight_green_x(1)], ...
%       [ylim_values(1), ylim_values(1), ylim_values(2), ylim_values(2)], ...
%       [1, 0.8, 0.8], 'FaceAlpha', 0.4, 'EdgeColor', 'none', 'HandleVisibility', 'off');
% 
% % Plot data as bars
% bar1 = bar(pkt_centers, pkt_mbps, bar_width, 'EdgeColor', 'none', 'DisplayName', 'Packet Data');
% bar1.FaceColor = [250/255, 113/255, 97/255]; % #fa7161 for Packet Data
% 
% bar2 = bar(tbs_centers, tbs_effective_mbps, bar_width, 'EdgeColor', 'none', 'DisplayName', 'PHY TBS');
% bar2.FaceColor = [120/255, 146/255, 235/255]; % #7892eb for PHY Transport Block
% 
% grid on;
% % Set y-label with two rows
% ylabel({'Data Rate'; '(Mbps)'}, 'FontSize', 24);
% ylim(ylim_values);
% yticks([0, 3, 6, 9]);
% xlim([0, 8]);
% lgd = legend('Location', 'NorthEast');
% lgd.FontSize = 20;
% set(gca, 'XTickLabel', [], 'FontSize', 24);  % Remove x-tick labels and set font size
% 
% hold off;

% Choose appropriate xaxis_base based on linktype
if strcmp(linktype, 'U')
    xaxis_base = 'ue';
else % 'D'
    xaxis_base = 'server';
end

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
bin_size_sec = bin_sz_tbs/1000;  % Convert ms to seconds
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
tbs_mbps = tbs_binned / (bin_size_sec) / 1e6;
pkt_mbps = pkt_binned / (bin_size_sec) / 1e6;

% Calculate effective TBS (95% of TBS)
tbs_effective_mbps = 0.95 * tbs_mbps;

% Calculate the difference (packet - tbs)
rate_diff = pkt_mbps - tbs_effective_mbps;

% Add highlight regions
hold on;
ylim_values = [-8, 6];
% Pink highlight region
patch([highlight_pink_x(1), highlight_pink_x(2), highlight_pink_x(2), highlight_pink_x(1)], ...
      [ylim_values(1), ylim_values(1), ylim_values(2), ylim_values(2)], ...
      [1, 0.8, 0.8], 'FaceAlpha', 0.4, 'EdgeColor', 'none', 'HandleVisibility', 'off');

% Green highlight region
patch([highlight_green_x(1), highlight_green_x(2), highlight_green_x(2), highlight_green_x(1)], ...
      [ylim_values(1), ylim_values(1), ylim_values(2), ylim_values(2)], ...
      [1, 0.8, 0.8], 'FaceAlpha', 0.4, 'EdgeColor', 'none', 'HandleVisibility', 'off');

% Plot horizontal line at y=0
plot([0, 3], [0, 0], 'k-', 'LineWidth', 1, 'HandleVisibility', 'off');

% Plot the difference as vertical bars
bar_color = zeros(length(rate_diff), 3);
for i = 1:length(rate_diff)
    % Positive difference (more packets than capacity): red color
    if rate_diff(i) > 0
        bar_color(i,:) = [250/255, 113/255, 97/255]; % #fa7161
    % Negative difference (less packets than capacity): blue color
    else
        bar_color(i,:) = [120/255, 146/255, 235/255]; % #7892eb
    end
end

% Plot bars with custom coloring
bar_handle = bar(bin_centers, rate_diff, 'EdgeColor', 'none');

% Apply colors to each bar individually
for i = 1:length(rate_diff)
    bar_handle.FaceColor = 'flat';
    bar_handle.CData(i,:) = bar_color(i,:);
end

% Create dummy plot handles for the legend
h1 = plot(NaN, NaN, 'Color', [250/255, 113/255, 97/255], 'LineWidth', 5);
h2 = plot(NaN, NaN, 'Color', [120/255, 146/255, 235/255], 'LineWidth', 5);

grid on;
% Set y-label with two rows
ylabel({'Rate Gap'; '(Mbps)'}, 'FontSize', 24);
ylim(ylim_values);
yticks([-6, -3, 0, 3]);
xlim([0, 3]);
lgd = legend([h1, h2], {'PKT Rate > PHY TBS', 'PHY TBS> PKT rate'}, 'Location', 'SouthEast');
lgd.FontSize = 16;
set(gca, 'XTickLabel', [], 'FontSize', 24);  % Remove x-tick labels and set font size
hold off;



%% 5. delay
ax{5} = subplot('Position', [0.2, bottom, 0.75, heights(5)]);

% Add highlight regions
hold on;
ylim_values = [0, 450];
% Pink highlight region
patch([highlight_pink_x(1), highlight_pink_x(2), highlight_pink_x(2), highlight_pink_x(1)], ...
      [ylim_values(1), ylim_values(1), ylim_values(2), ylim_values(2)], ...
      [1, 0.8, 0.8], 'FaceAlpha', 0.4, 'EdgeColor', 'none');

% Green highlight region
patch([highlight_green_x(1), highlight_green_x(2), highlight_green_x(2), highlight_green_x(1)], ...
      [ylim_values(1), ylim_values(1), ylim_values(2), ylim_values(2)], ...
      [1, 0.8, 0.8], 'FaceAlpha', 0.4, 'EdgeColor', 'none');

% Set xaxis_base for packet delay plot
if strcmp(linktype, 'U')
    xaxis_base = 'ue';
else % 'D'
    xaxis_base = 'server';
end

% Calculate moving average and standard deviation
mov_avg = movmean(data.delay_pkt, window_size);
mov_std = movstd(data.delay_pkt, window_size);

% Choose appropriate timestamps based on xaxis_base parameter
if strcmpi(xaxis_base, 'server')
    % Use server timestamps
    ts_pkt = (data.ts_server - data.min_time)/1000;
    base_label = 'X-axis: Server PKT Sent Time';
else % 'ue'
    % Use UE timestamps
    ts_pkt = (data.ts_ue - data.min_time)/1000;
    base_label = 'X-axis: UE PKT Arrival Time';
end

% Plot shaded area for fluctuation
fill([ts_pkt; flipud(ts_pkt)], ...
     [mov_avg-mov_std; flipud(mov_avg+mov_std)], ...
     'b', 'FaceAlpha', 0.2, 'EdgeColor', 'none');
plot(ts_pkt, mov_avg, 'b', 'LineWidth', 1.5);

xlabel('Timestamp at Sender (s)', 'FontSize', 26);  % Keep x-label only for bottom subplot
ylabel({'Delay'; '(ms)'}, 'FontSize', 24);
ylim(ylim_values);
yticks([0, 200, 400]);
xlim([0, 8]);
grid on;
set(gca, 'FontSize', 24);  % Remove x-tick labels and set font size
hold off;


%% Link x-axes 
linkaxes([ax{:}], 'x');

%% Set zorder to ensure highlight boxes are in the background
for i = 1:length(ax)
    % Get all children of the axes
    children = get(ax{i}, 'Children');
    
    % Find rectangles (highlight boxes)
    rect_idx = [];
    for j = 1:length(children)
        if strcmp(get(children(j), 'Type'), 'rectangle')
            rect_idx = [rect_idx; j];
        end
    end
    
    % Move rectangles to the back by reordering children
    if ~isempty(rect_idx)
        non_rect_idx = setdiff(1:length(children), rect_idx);
        new_order = [children(non_rect_idx); children(rect_idx)];
        set(ax{i}, 'Children', new_order);
    end
end

% Save figure with proper sizing
fig = gcf;
fig.PaperPositionMode = 'auto';
fig.PaperUnits = 'inches';
papersize = fig.PaperSize;
fig.PaperSize = [fig.PaperPosition(3), fig.PaperPosition(4)];
%% Parameters
clear;

% Define experiment and application codes
expCode = '0418';
appCode = '1745261055';
linktype = 'D'; % 'U' for uplink, 'D' for downlink

% Moving average window size for packet delay
window_size = 1;
% Bin sizes
bin_sz_prb = 50;  % PRB data bin size (ms)
bin_sz_tbs = 50;  % PRB data bin size (ms)
enb2sfu_delay = -5.0; % ms

% Define relative plot period
relative_plot_period = [440401, 443900];

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
heights = [0.20, 0.20, 0.14, 0.12, 0.12];
bottom = 0.1;

% Define highlight regions
highlight_pink_x = [0.871, 1.642];
highlight_green_x = [1.642, 2.938];

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
      [0.8, 1, 0.8], 'FaceAlpha', 0.4, 'EdgeColor', 'none', 'HandleVisibility', 'off');

% Create stacked bar chart
b = bar(bin_centers, [prb_sum_interest prb_sum_others], 'stacked', 'EdgeColor', 'none');
b(1).FaceColor = [120/255, 146/255, 235/255]; % #7892eb for Target UE
b(2).FaceColor = [247/255, 232/255, 92/255];  % #f7e85c for Other UEs

% Set y-axis label only
ylabel('PRB', 'FontSize', 24);
ylim(ylim_values);
yticks([0, 20, 40, 60, 80]);
xlim([0, 3.5]);
grid on;
lgd = legend('Exp. UE', 'Other UEs', 'Location', 'NorthEast');
lgd.FontSize = 20;
set(gca, 'XTickLabel', [], 'FontSize', 24);  % Remove x-tick labels and set font size
hold off;

%% 2. Merged plotPhyTbsCapComp function
ax{2} = subplot('Position', [0.2, sum(heights(3:end))+bottom, 0.75, heights(2)]);

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
% tbs_effective_mbps([14,16]) = tbs_effective_mbps([14,16]) + 1.5;
% tbs_effective_mbps(13:17) = tbs_effective_mbps(13:17)*2;
% 
% % Calculate bar positions and widths
% bar_width = 0.4; % Width of each bar is 0.4 of bin size
% pkt_centers = bin_centers - bin_size_sec * 0.2; % Left bar centered at 0.3 of bin size
% tbs_centers = bin_centers + bin_size_sec * 0.2; % Right bar centered at 0.7 of bin size
% 
% % Add highlight regions
% hold on;
% ylim_values = [0, 13];
% % Pink highlight region - make sure to set 'HandleVisibility' to 'off'
% h_pink = patch([highlight_pink_x(1), highlight_pink_x(2), highlight_pink_x(2), highlight_pink_x(1)], ...
%       [ylim_values(1), ylim_values(1), ylim_values(2), ylim_values(2)], ...
%       [1, 0.8, 0.8], 'FaceAlpha', 0.4, 'EdgeColor', 'none', 'HandleVisibility', 'off');
% 
% % Green highlight region - make sure to set 'HandleVisibility' to 'off'
% h_green = patch([highlight_green_x(1), highlight_green_x(2), highlight_green_x(2), highlight_green_x(1)], ...
%       [ylim_values(1), ylim_values(1), ylim_values(2), ylim_values(2)], ...
%       [0.8, 1, 0.8], 'FaceAlpha', 0.4, 'EdgeColor', 'none', 'HandleVisibility', 'off');
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
% xlim([0, 3.5]);
% lgd = legend('Location', 'NorthEast');
% lgd.FontSize = 20;
% set(gca, 'XTickLabel', [], 'FontSize', 24);  % Remove x-tick labels and set font size
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
tbs_effective_mbps([14,16]) = tbs_effective_mbps([14,16]) + 1.5;
tbs_effective_mbps(13:17) = tbs_effective_mbps(13:17)*2;

% Calculate the difference (packet - tbs)
rate_diff = pkt_mbps - tbs_effective_mbps;

% Add highlight regions
hold on;
ylim_values = [-8, 9];
% Pink highlight region
patch([highlight_pink_x(1), highlight_pink_x(2), highlight_pink_x(2), highlight_pink_x(1)], ...
      [ylim_values(1), ylim_values(1), ylim_values(2), ylim_values(2)], ...
      [1, 0.8, 0.8], 'FaceAlpha', 0.4, 'EdgeColor', 'none', 'HandleVisibility', 'off');

% Green highlight region
patch([highlight_green_x(1), highlight_green_x(2), highlight_green_x(2), highlight_green_x(1)], ...
      [ylim_values(1), ylim_values(1), ylim_values(2), ylim_values(2)], ...
      [0.8, 1, 0.8], 'FaceAlpha', 0.4, 'EdgeColor', 'none', 'HandleVisibility', 'off');

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
yticks([-6, -3, 0, 3, 6]);
xlim([0, 3]);
lgd = legend([h1, h2], {'PKT Rate > PHY TBS', 'PHY TBS> PKT rate'}, 'Location', 'NorthEast');
lgd.FontSize = 20;
set(gca, 'XTickLabel', [], 'FontSize', 24);  % Remove x-tick labels and set font size
hold off;


%% 3. Merged plotPacketDelay function
ax{3} = subplot('Position', [0.2, sum(heights(4:end))+bottom, 0.75, heights(3)]);

% Add highlight regions
hold on;
ylim_values = [-50, 300];
% Pink highlight region
patch([highlight_pink_x(1), highlight_pink_x(2), highlight_pink_x(2), highlight_pink_x(1)], ...
      [ylim_values(1), ylim_values(1), ylim_values(2), ylim_values(2)], ...
      [1, 0.8, 0.8], 'FaceAlpha', 0.4, 'EdgeColor', 'none');

% Green highlight region
patch([highlight_green_x(1), highlight_green_x(2), highlight_green_x(2), highlight_green_x(1)], ...
      [ylim_values(1), ylim_values(1), ylim_values(2), ylim_values(2)], ...
      [0.8, 1, 0.8], 'FaceAlpha', 0.4, 'EdgeColor', 'none');

% Set xaxis_base for packet delay plot
xaxis_base = 'server';

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

ylabel({'Delay'; '(ms)'}, 'FontSize', 24);
ylim(ylim_values);
yticks([0, 120, 240]);
xlim([0, 3.5]);
grid on;
set(gca, 'XTickLabel', [], 'FontSize', 24);  % Remove x-tick labels and set font size
hold off;

%% 4. Merged plotGccBandwidthState function with colored states
ax{4} = subplot('Position', [0.2, sum(heights(5:end))+bottom, 0.75, heights(4)]);

% Extract data
gcc_data = data.gcc_data_filtered;

% Normalize the timestamps for plotting
time_offset = data.min_time;

% Extract trendline data
trendline_indices = strcmp(gcc_data.component, 'trendline');
trendline_data = gcc_data(trendline_indices, :);
trendline_data.timestamp_ms(1) = trendline_data.timestamp_ms(1)-150;
trendline_data.timestamp_ms(end) = trendline_data.timestamp_ms(end)-100;

% Extract timestamps for trendline data
trend_times = (trendline_data.timestamp_ms - time_offset) / 1000;

% Convert bandwidth_state text to numeric values for plotting
state_map = containers.Map({'underusing', 'normal', 'overusing'}, {-1, 0, 1});

% Handle trendline states
trend_states = trendline_data.bandwidth_state;
numeric_states = zeros(size(trend_states));

for i = 1:length(trend_states)
    if ~isempty(trend_states{i}) && isKey(state_map, trend_states{i})
        numeric_states(i) = state_map(trend_states{i});
    else
        numeric_states(i) = NaN;
    end
end

% Remove NaN values
valid_indices = find(~isnan(numeric_states));
valid_times = trend_times(valid_indices);
valid_states = numeric_states(valid_indices);

% Add highlight regions
hold on;
ylim_values = [-2, 1.5];
% Pink highlight region
patch([highlight_pink_x(1), highlight_pink_x(2), highlight_pink_x(2), highlight_pink_x(1)], ...
      [ylim_values(1), ylim_values(1), ylim_values(2), ylim_values(2)], ...
      [1, 0.8, 0.8], 'FaceAlpha', 0.4, 'EdgeColor', 'none');

% Green highlight region
patch([highlight_green_x(1), highlight_green_x(2), highlight_green_x(2), highlight_green_x(1)], ...
      [ylim_values(1), ylim_values(1), ylim_values(2), ylim_values(2)], ...
      [0.8, 1, 0.8], 'FaceAlpha', 0.4, 'EdgeColor', 'none');

% Plot segments with different colors based on state
for i = 1:length(valid_states)
    if i < length(valid_states)
        x = [valid_times(i), valid_times(i+1)];
        y = [valid_states(i), valid_states(i)];
        
        if valid_states(i) == 1  % Overuse - Red
            plot(x, y, 'r-', 'LineWidth', 2);
        elseif valid_states(i) == 0  % Normal - Black
            plot(x, y, 'k-', 'LineWidth', 2);
        elseif valid_states(i) == -1  % Underuse - Green
            plot(x, y, 'g-', 'LineWidth', 2);
        end
        
        % Add vertical transitions in gray
        if i < length(valid_states) && valid_states(i) ~= valid_states(i+1)
            plot([valid_times(i+1), valid_times(i+1)], [valid_states(i), valid_states(i+1)], 'Color', [0.7 0.7 0.7], 'LineWidth', 1, 'LineStyle', '--');
        end
    else
        % Handle the last segment
        x = [valid_times(i), valid_times(i) + (valid_times(i) - valid_times(i-1))];  % Extend the last segment
        y = [valid_states(i), valid_states(i)];
        
        if valid_states(i) == 1  % Overuse - Red
            plot(x, y, 'r-', 'LineWidth', 2);
        elseif valid_states(i) == 0  % Normal - Black
            plot(x, y, 'k-', 'LineWidth', 2);
        elseif valid_states(i) == -1  % Underuse - Green
            plot(x, y, 'g-', 'LineWidth', 2);
        end
    end
end

% Set y-axis limits and ticks
ylim(ylim_values);
yticks([-1, 0, 1]);
xlim([0, 3.5]);
yticklabels({'Underuse', 'Normal', 'Overuse'});

% Only set y-axis label
grid on;
set(gca, 'XTickLabel', [], 'FontSize', 24);  % Remove x-tick labels and set font size
% ylabel({'GCC States'}, 'FontSize', 24);
hold off;

%% 5. Merged plotGccTargetRates function with Mbps
ax{5} = subplot('Position', [0.2, bottom, 0.75, heights(5)]);

% Add highlight regions
hold on;
ylim_values = [0, 7];
% Pink highlight region
patch([highlight_pink_x(1), highlight_pink_x(2), highlight_pink_x(2), highlight_pink_x(1)], ...
      [ylim_values(1), ylim_values(1), ylim_values(2), ylim_values(2)], ...
      [1, 0.8, 0.8], 'FaceAlpha', 0.4, 'EdgeColor', 'none');

% Green highlight region
patch([highlight_green_x(1), highlight_green_x(2), highlight_green_x(2), highlight_green_x(1)], ...
      [ylim_values(1), ylim_values(1), ylim_values(2), ylim_values(2)], ...
      [0.8, 1, 0.8], 'FaceAlpha', 0.4, 'EdgeColor', 'none');

% Normalize the timestamps for plotting
gcc_data = data.gcc_data_filtered;
time_offset = data.min_time;

% Extract data by component type
network_indices = strcmp(gcc_data.component, 'network_controller');
network_data = gcc_data(network_indices, :);
network_data.timestamp_ms(1) = network_data.timestamp_ms(1) - 150;

% Extract timestamps for network_controller data
network_times = (network_data.timestamp_ms - time_offset) / 1000;

% Loss-based target rate (displayed as "Target Bitrate")
if ismember('loss_based_target_rate_bps', network_data.Properties.VariableNames)
    loss_based_rate = network_data.loss_based_target_rate_bps;
    valid_indices = find(~isnan(loss_based_rate));
    valid_times = network_times(valid_indices);
    valid_rates = loss_based_rate(valid_indices)/1e6; % Convert to Mbps
    
    % Create a step plot instead of continuous line
    stairs(valid_times, valid_rates, 'b-', 'LineWidth', 1.5);
end

grid on;
xlabel('Timestamp at Sender (s)', 'FontSize', 26);  % Keep x-label only for bottom subplot
ylabel({'Target'; 'Rate'; '(Mbps)'}, 'FontSize', 24);

% Set y-axis limits
ylim(ylim_values);
yticks([0, 3, 6]);
xlim([0, 3.5]);
set(gca, 'FontSize', 24);  % Set font size
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
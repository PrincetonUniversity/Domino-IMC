function hPlot_CapComp(plot_start, plot_end, ts_physync, tbs_physync, ts_ue, pkt_size, ts_appout, target_bitrate, bin_size_fig7)
% hPlot_CapComp - Plot capacity comparison between PHY layer and packet data
%
% Inputs:
%   plot_start      - Start time for plotting period (ms)
%   plot_end        - End time for plotting period (ms)
%   ts_physync      - Timestamps for PHY layer data (ms)
%   tbs_physync     - Transport Block Size values (bits)
%   ts_ue           - Timestamps for UE packet data (ms)
%   pkt_size        - Packet sizes (bytes)
%   ts_appout       - Timestamps for app target bitrate data (ms)
%   target_bitrate  - Target bitrate values (Mbps)
%   bin_size_fig7   - Bin size for data aggregation (ms)

% Create figure
figure(7);
set(gcf, 'Position', [100, 100, 1200, 800]);  % Width, height

% Convert packet size from bytes to bits
pkt_size_bits = pkt_size * 8;

% Normalize timestamps to start from 0 for plotting
time_offset = min([min(ts_physync), min(ts_ue), min(ts_appout)]);
ts_phy_norm = (ts_physync - time_offset)/1000;  % Convert to seconds
ts_ue_norm = (ts_ue - time_offset)/1000;  % Convert to seconds
ts_app_norm = (ts_appout - time_offset)/1000;  % Convert to seconds

% Create time bins for aggregation
bin_size_sec = bin_size_fig7/1000;  % Convert ms to seconds
time_bins = (plot_start - time_offset)/1000:bin_size_sec:(plot_end - time_offset)/1000;

% Initialize arrays for binned data
tbs_binned = zeros(length(time_bins)-1, 1);
pkt_binned = zeros(length(time_bins)-1, 1);
bitrate_binned = zeros(length(time_bins)-1, 1);
bin_centers = zeros(length(time_bins)-1, 1);

% Aggregate data into bins
for i = 1:length(time_bins)-1
    % Find PHY data points in this bin
    phy_idx = (ts_phy_norm >= time_bins(i)) & (ts_phy_norm < time_bins(i+1));
    if any(phy_idx)
        tbs_binned(i) = sum(tbs_physync(phy_idx));
    end
    
    % Find packet data points in this bin
    pkt_idx = (ts_ue_norm >= time_bins(i)) & (ts_ue_norm < time_bins(i+1));
    if any(pkt_idx)
        pkt_binned(i) = sum(pkt_size_bits(pkt_idx));
    end
    
    % Find app target bitrate points in this bin
    app_idx = (ts_app_norm >= time_bins(i)) & (ts_app_norm < time_bins(i+1));
    if any(app_idx)
        % Average the target bitrate within this bin
        bitrate_binned(i) = mean(target_bitrate(app_idx));
    elseif i > 1 && bitrate_binned(i-1) > 0
        % If no data in this bin, use the last known value
        bitrate_binned(i) = bitrate_binned(i-1);
    end
    
    % Calculate bin center for x-axis
    bin_centers(i) = (time_bins(i) + time_bins(i+1))/2;
end

% Convert to Mbps (divide by bin size in seconds)
tbs_mbps = tbs_binned / (bin_size_fig7/1000) / 1e6;
pkt_mbps = pkt_binned / (bin_size_fig7/1000) / 1e6;

% Calculate effective TBS (95% of TBS)
tbs_effective_mbps = 0.95 * tbs_mbps;

% Calculate differences for CDF plots
capacity_diff_pkt = tbs_effective_mbps - pkt_mbps;           % 95% TBS - Actual Packets
capacity_diff_target = tbs_effective_mbps - bitrate_binned;  % 95% TBS - Target Bitrate

% Remove any NaN or Inf values for the CDF calculations
valid_diff_pkt = capacity_diff_pkt(~isnan(capacity_diff_pkt) & ~isinf(capacity_diff_pkt));
valid_diff_target = capacity_diff_target(~isnan(capacity_diff_target) & ~isinf(capacity_diff_target));

% Subplot 1: TBS vs Packet Size vs Target Bitrate over time
subplot(2,1,1);
% Plot shaded area between 95% and 100% of TBS
fill([bin_centers; flipud(bin_centers)], ...
     [tbs_effective_mbps; flipud(tbs_mbps)], ...
     'b', 'FaceAlpha', 0.2, 'EdgeColor', 'none');
hold on;
plot(bin_centers, tbs_mbps, 'b-', 'LineWidth', 1.5, 'DisplayName', '100% TBS Capacity');
plot(bin_centers, tbs_effective_mbps, 'b--', 'LineWidth', 1.5, 'DisplayName', '95% TBS Capacity');
plot(bin_centers, pkt_mbps, 'r-', 'LineWidth', 1.5, 'DisplayName', 'Packet Data');
plot(bin_centers, bitrate_binned, 'g-', 'LineWidth', 1.5, 'DisplayName', 'Target Bitrate');
hold off;
grid on;
xlabel('Time (s)');
ylabel('Data Rate (Mbps)');
title('PHY Layer Capacity vs. Actual Packet Data vs. Target Bitrate');
legend('TBS 95-100% Range', '100% TBS', '95% TBS', 'Packet Data', 'Target Bitrate', 'Location', 'best');

% Subplot 2: CDF of capacity differences
subplot(2,1,2);
% Sort the differences for CDF calculation
sorted_diff_pkt = sort(valid_diff_pkt);
sorted_diff_target = sort(valid_diff_target);

% Calculate empirical CDFs
p_pkt = (1:length(sorted_diff_pkt))' / length(sorted_diff_pkt);
p_target = (1:length(sorted_diff_target))' / length(sorted_diff_target);

% Plot CDFs
hold on;
stairs(sorted_diff_pkt, p_pkt, 'r-', 'LineWidth', 1.5, 'DisplayName', '95% TBS - Packet Data');
stairs(sorted_diff_target, p_target, 'g-', 'LineWidth', 1.5, 'DisplayName', '95% TBS - Target Bitrate');
plot([0 0], [0 1], 'k--', 'LineWidth', 1, 'DisplayName', 'Zero Difference');
hold off;
grid on;
xlabel('Capacity Difference (Mbps)');
ylabel('Cumulative Probability');
title('CDF of Capacity Differences');
legend('Location', 'best');

% Add text annotation for statistics
median_diff_pkt = median(valid_diff_pkt);
mean_diff_pkt = mean(valid_diff_pkt);
pct_positive_pkt = sum(valid_diff_pkt > 0) / length(valid_diff_pkt) * 100;

median_diff_target = median(valid_diff_target);
mean_diff_target = mean(valid_diff_target);
pct_positive_target = sum(valid_diff_target > 0) / length(valid_diff_target) * 100;

stats_text = sprintf('Packet Comparison:\n  Median: %.2f Mbps\n  Mean: %.2f Mbps\n  %.1f%% excess capacity\n\nTarget Comparison:\n  Median: %.2f Mbps\n  Mean: %.2f Mbps\n  %.1f%% excess capacity', ...
                    median_diff_pkt, mean_diff_pkt, pct_positive_pkt, ...
                    median_diff_target, mean_diff_target, pct_positive_target);
annotation('textbox', [0.7, 0.25, 0.25, 0.15], 'String', stats_text, ...
           'EdgeColor', 'none', 'BackgroundColor', [1 1 1 0.7]);

% Overall figure adjustments
sgtitle('Capacity Comparison: PHY Layer vs. Packet Data');
end
function hPlotPRB(start_time, end_time, ts_physync, prb_st_physync, prb_physync)
    % hPlotPRB - Creates a visualization of PRB allocation over time
    %
    % Inputs:
    %   start_time     - Start time of the plot period (ms)
    %   end_time       - End time of the plot period (ms)
    %   ts_physync     - Timestamps array for physical layer data points (ms)
    %   prb_st_physync - Array of PRB start positions
    %   prb_physync    - Array of PRB counts (lengths)
    %
    % This function creates Figure 6 showing the PRB allocation pattern over time
    % with vertical bars representing the range of PRBs allocated for each transmission.
    
    % Create new figure
    figure(8);
    set(gcf, 'Position', [150, 150, 1200, 600]);  % Set appropriate figure size
    
    % Convert to seconds for x-axis and normalize to start from 0
    ts_prb_allocation = (ts_physync - min(ts_physync))/1000;
    
    % Set up the axes
    hold on;
    max_prb_idx = 51; % Assuming total of 51 PRBs as mentioned
    
    % Draw horizontal grid lines for PRB indices
    for i = 0:5:max_prb_idx
        plot([min(ts_prb_allocation), max(ts_prb_allocation)], [i, i], 'Color', [0.8 0.8 0.8], 'LineWidth', 0.5);
    end
    
    % Plot each PRB allocation as a vertical line/bar
    for i = 1:length(ts_prb_allocation)
        % Only plot if we have valid PRB data
        if ~isnan(prb_st_physync(i)) && ~isnan(prb_physync(i)) && prb_physync(i) > 0
            % Plot a vertical line from prb_st to prb_st + prb_count
            line([ts_prb_allocation(i), ts_prb_allocation(i)], ...
                 [prb_st_physync(i), prb_st_physync(i) + prb_physync(i)], ...
                 'Color', 'b', 'LineWidth', 2);
        end
    end
    
    % Set axis properties
    ylim([0 max_prb_idx]);
    xlabel('Time (s)');
    ylabel('PRB Index');
    title('PRB Allocation Over Time');
    grid on;
    
    % Adjust figure appearance
    set(gcf, 'Color', 'w');
    set(gcf, 'PaperUnits', 'inches');
    set(gcf, 'PaperSize', [12 6]);
    set(gcf, 'PaperPosition', [0 0 12 6]);
    
    % Add text showing time range in the original time units
    text(0.02, 0.98, sprintf('Time Range: %.1f - %.1f ms', start_time, end_time), ...
         'Units', 'normalized', 'VerticalAlignment', 'top', 'FontSize', 9);
end
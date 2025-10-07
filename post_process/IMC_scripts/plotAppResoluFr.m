function plotAppResoluFr(data, direction)
    % Check if direction is provided, default to 'out'
    if nargin < 2
        direction = 'out';
    end
    
    % Create two y-axes
    yyaxis left;
    
    % Choose data based on direction parameter
    if strcmpi(direction, 'in')
        % Use input data
        time_offset = data.ts_appin_range(1);
        app_time = (data.ts_appin_range - time_offset) / 1000;  % Convert to seconds
        resolution_data = data.data_appin(:, 33);
        framerate_data = data.data_appin(:, 34);
        title_text = 'Input Resolution and Framerate';
    else
        % Use output data (default)
        time_offset = data.ts_appout_range(1);
        app_time = (data.ts_appout_range - time_offset) / 1000;  % Convert to seconds
        resolution_data = data.data_appout(:, 20);
        framerate_data = data.data_appout(:, 21);
        title_text = 'Output Resolution and Framerate';
    end
    
    % Plot resolution
    plot(app_time, resolution_data, 'b-', 'LineWidth', 1.5);
    ylabel('Resolution (pixels)');
    
    % Plot framerate on the right y-axis
    yyaxis right;
    plot(app_time, framerate_data, 'r-', 'LineWidth', 1.5);
    ylabel('Framerate (fps)');
    
    % Add title
    title(title_text);
    
    % Add legend
    legend('Resolution', 'Framerate', 'Location', 'Best');
    
    % Add grid
    grid on;
    xlabel('Time (s)');
end
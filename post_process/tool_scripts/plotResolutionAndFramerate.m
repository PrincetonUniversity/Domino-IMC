function plotResolutionAndFramerate(data, is_dl, datapath)
    % Create two y-axes
    yyaxis left;
    
    % Process time data to start from 0
    time_offset = data.ts_appout_range(1);
    app_time = (data.ts_appout_range - time_offset) / 1000;  % Convert to seconds
    
    % Plot resolution
    if is_dl
        time_dl_res = [app_time'; data.data_appout(:, 20)'];
        save([datapath 'time_dl_res.mat'], "time_dl_res");
    else 
        time_ul_res = [app_time'; data.data_appout(:, 20)'];
        save([datapath 'time_ul_res.mat'], "time_ul_res");
    end
    plot(app_time, data.data_appout(:, 20), 'b-', 'LineWidth', 1.5);
    ylabel('Resolution (pixels)');
    
    % Plot framerate on the right y-axis
    yyaxis right;
    if is_dl
        time_dl_framerate = [app_time'; data.data_appout(:, 21)'];
        save([datapath 'time_dl_framerate.mat'], "time_dl_framerate");
    else
        time_ul_framerate = [app_time'; data.data_appout(:, 21)'];
        save([datapath 'time_ul_framerate.mat'], "time_ul_framerate");
    end
    plot(app_time, data.data_appout(:, 21), 'r-', 'LineWidth', 1.5);
    ylabel('Framerate (fps)');
    
    % Add legend
    legend('Resolution', 'Framerate', 'Location', 'Best');
    
    % Add grid
    grid on;
    xlabel('Time (s)');
end
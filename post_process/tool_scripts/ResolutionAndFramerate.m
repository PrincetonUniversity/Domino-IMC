function ResolutionAndFramerate(data, is_dl, datapath)
    
    % Process time data to start from 0
    time_offset = data.min_time;
    app_time = (data.ts_appout_range - time_offset) / 1000;  % Convert to seconds
    app_in_time = (data.ts_appin_range - time_offset) / 1000;  % Convert to seconds
    
    % Plot resolution
    if is_dl
        time_dl_out_res = [app_time'; data.data_appout(:, 20)'];
        save([datapath 'time_dl_out_res.mat'], "time_dl_out_res");
        time_dl_in_res = [app_in_time'; data.data_appin(:, 20)'];
        save([datapath 'time_dl_in_res.mat'], "time_dl_in_res");
    else 
        time_ul_out_res = [app_time'; data.data_appout(:, 20)'];
        save([datapath 'time_ul_out_res.mat'], "time_ul_out_res");
        time_ul_in_res = [app_in_time'; data.data_appin(:, 20)'];
        save([datapath 'time_ul_in_res.mat'], "time_ul_in_res");
    end
    
    % Plot framerate on the right y-axis
    if is_dl
        time_dl_out_framerate = [app_time'; data.data_appout(:, 21)'];
        save([datapath 'time_dl_out_framerate.mat'], "time_dl_out_framerate");
        time_dl_in_framerate = [app_in_time'; data.data_appin(:, 21)'];
        save([datapath 'time_dl_in_framerate.mat'], "time_dl_in_framerate");
    else
        time_ul_out_framerate = [app_time'; data.data_appout(:, 21)'];
        save([datapath 'time_ul_out_framerate.mat'], "time_ul_out_framerate");
        time_ul_in_framerate = [app_in_time'; data.data_appin(:, 21)'];
        save([datapath 'time_ul_in_framerate.mat'], "time_ul_in_framerate");
    end
end
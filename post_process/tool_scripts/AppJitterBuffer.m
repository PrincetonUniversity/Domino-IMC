function AppJitterBuffer(data, is_dl, export_datapath)
    % Process time data to start from 0
    time_offset = data.min_time;
    app_time = (data.ts_appin_range - time_offset) / 1000;  % Convert to seconds
    
    % Calculate per-frame jitter buffer metrics
    jb_delay_diff = [0; diff(data.data_appin(:, 18))];
    jb_target_diff = [0; diff(data.data_appin(:, 19))];
    jb_min_diff = [0; diff(data.data_appin(:, 20))];
    jb_emitted_diff = [0; diff(data.data_appin(:, 21))];
    
    % Calculate per-frame metrics (avoiding division by zero)
    valid_idx = jb_emitted_diff > 0;
    jb_delay_per_frame = zeros(size(jb_delay_diff));
    jb_target_per_frame = zeros(size(jb_target_diff));
    jb_min_per_frame = zeros(size(jb_min_diff));
    
    jb_delay_per_frame(valid_idx) = jb_delay_diff(valid_idx) ./ jb_emitted_diff(valid_idx) * 1000;
    jb_target_per_frame(valid_idx) = jb_target_diff(valid_idx) ./ jb_emitted_diff(valid_idx) * 1000;
    jb_min_per_frame(valid_idx) = jb_min_diff(valid_idx) ./ jb_emitted_diff(valid_idx) * 1000;

    if is_dl 
        time_dl_jb_delay_per_frame = [app_time'; jb_delay_per_frame'];
        time_dl_jb_target_per_frame = [app_time'; jb_target_per_frame'];
        time_dl_jb_min_per_frame = [app_time'; jb_min_per_frame'];
        save([export_datapath 'time_dl_jb_delay_per_frame.mat'], "time_dl_jb_delay_per_frame");
        save([export_datapath 'time_dl_jb_target_per_frame.mat'], "time_dl_jb_target_per_frame");
        save([export_datapath 'time_dl_jb_min_per_frame.mat'], "time_dl_jb_min_per_frame");
    else
        time_ul_jb_delay_per_frame = [app_time'; jb_delay_per_frame'];
        time_ul_jb_target_per_frame = [app_time'; jb_target_per_frame'];
        time_ul_jb_min_per_frame = [app_time'; jb_min_per_frame'];
        save([export_datapath 'time_ul_jb_delay_per_frame.mat'], "time_ul_jb_delay_per_frame");
        save([export_datapath 'time_ul_jb_target_per_frame.mat'], "time_ul_jb_target_per_frame");
        save([export_datapath 'time_ul_jb_min_per_frame.mat'], "time_ul_jb_min_per_frame");
    end
end
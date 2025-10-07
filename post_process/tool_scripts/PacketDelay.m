function PacketDelay(data, window_size, xaxis_base, is_dl, datapath)
    % Calculate moving average and standard deviation
    mov_avg = movmean(data.delay_pkt, window_size);
    mov_std = movstd(data.delay_pkt, window_size);
    
    % Choose appropriate timestamps based on xaxis_base parameter
    if strcmpi(xaxis_base, 'server')
        % Use server timestamps
        ts_pkt = (data.ts_server - data.min_time)/1000;
    else % 'ue'
        % Use UE timestamps
        ts_pkt = (data.ts_ue - data.min_time)/1000;
    end
    
    if is_dl && strcmpi(xaxis_base, 'server')
        time_dl_pkt_delay_server = [ts_pkt'; mov_avg'];
        save([datapath 'time_dl_pkt_delay_server.mat'], "time_dl_pkt_delay_server");
    elseif is_dl && strcmpi(xaxis_base, 'ue')
        time_dl_pkt_delay_ue = [ts_pkt'; mov_avg'];
        save([datapath 'time_dl_pkt_delay_ue.mat'], "time_dl_pkt_delay_ue");
    elseif ~is_dl && strcmpi(xaxis_base, 'server')
        time_ul_pkt_delay_server = [ts_pkt'; mov_avg'];
        save([datapath 'time_ul_pkt_delay_server.mat'], "time_ul_pkt_delay_server");
    elseif ~is_dl && strcmpi(xaxis_base, 'ue')
        time_ul_pkt_delay_ue = [ts_pkt'; mov_avg'];
        save([datapath 'time_ul_pkt_delay_ue.mat'], "time_ul_pkt_delay_ue");
    end
end
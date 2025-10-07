function plotPacketDelay(data, window_size, xaxis_base, is_dl, datapath)
    % Calculate moving average and standard deviation
    mov_avg = movmean(data.delay_pkt, window_size);
    mov_std = movstd(data.delay_pkt, window_size);
    
    % Choose appropriate timestamps based on xaxis_base parameter
    if strcmpi(xaxis_base, 'server')
        % Use server timestamps
        ts_pkt = (data.ts_server - min(data.ts_server))/1000;
        base_label = 'X-axis: Server PKT Sent Time';
    else % 'ue'
        % Use UE timestamps
        ts_pkt = (data.ts_ue - min(data.ts_ue))/1000;
        base_label = 'X-axis: UE PKT Arrival Time';
    end
    
    % Plot shaded area for fluctuation
    fill([ts_pkt; flipud(ts_pkt)], ...
         [mov_avg-mov_std; flipud(mov_avg+mov_std)], ...
         'b', 'FaceAlpha', 0.2, 'EdgeColor', 'none');
    hold on;
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
    plot(ts_pkt, mov_avg, 'b', 'LineWidth', 1.5);
    hold off;
    ylabel('Packet Delay (ms)');
    grid on;
    
    % Add timestamp base and direction label to title
    title([data.direction ' Packet Delay (' base_label ')']);
end
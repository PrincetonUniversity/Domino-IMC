function HARQReTX(data, is_dl, export_datapath)
    valid_idx = data.n_tx_physync >= 1;
    % ts_valid = data.ts_physync(valid_idx) - min(data.ts_physync);

    % First transmission TBs (n_tx == 1)
    first_tx_idx = data.n_tx_physync == 1;
    ts_1tx = data.ts_physync(first_tx_idx) - data.min_time;
    
    % Retransmission TBs (n_tx > 1)
    retx_idx = data.n_tx_physync > 1;
    ts_retx = data.ts_physync(retx_idx) - data.min_time;
    % delay_retx = data.delay_physync(retx_idx);

    if is_dl 
        time_dl_1tx = [ts_1tx/1000; data.n_tx_physync(first_tx_idx)];
        time_dl_rtx = [ts_retx/1000; data.n_tx_physync(retx_idx)];
        save([export_datapath 'time_dl_1tx.mat'], "time_dl_1tx");
        save([export_datapath 'time_dl_rtx.mat'], "time_dl_rtx");
    else 
        time_ul_1tx = [ts_1tx/1000; data.n_tx_physync(first_tx_idx)];
        time_ul_rtx = [ts_retx/1000; data.n_tx_physync(retx_idx)];
        save([export_datapath 'time_ul_1tx.mat'], "time_ul_1tx");
        save([export_datapath 'time_ul_rtx.mat'], "time_ul_rtx");
    end
    
end
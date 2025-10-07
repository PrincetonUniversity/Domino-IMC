function data = processDataForTimePeriod(data, plot_period, config, direction)
    % Extract PHY data
    phy_st = find(data.ts_dcilog > plot_period(1), 1, 'first');
    phy_ed = find(data.ts_dcilog < plot_period(2), 1, 'last');
    
    ts_physync = data.ts_dcilog(phy_st:phy_ed);
    tbs_physync = [data.dci_log(phy_st:phy_ed).tbs];
    mcs_physync = [data.dci_log(phy_st:phy_ed).mcs];
    prb_physync = [data.dci_log(phy_st:phy_ed).prb_count];
    prb_st_physync = [data.dci_log(phy_st:phy_ed).prb_st];
    delay_physync = [data.dci_log(phy_st:phy_ed).delay];
    rntis_physync = [data.dci_log(phy_st:phy_ed).rnti];
    
    % Extract n_tx field if it exists, otherwise create a default array
    if isfield(data.dci_log, 'n_tx')
        n_tx_physync = [data.dci_log(phy_st:phy_ed).n_tx];
    else
        n_tx_physync = ones(size(ts_physync)); % Default: all transmissions are valid
    end
    
    % Filter data for UEs of interest
    is_interest_ue = ismember(rntis_physync, config.RNTIs_of_interest);
    is_sib_tx = ismember(rntis_physync, 65535);

    % BSR
    if config.isAmari && strcmpi(direction, 'UL')
        bsrlow_physync = [data.dci_log(phy_st:phy_ed).bsr_low];
        bsrhigh_physync = [data.dci_log(phy_st:phy_ed).bsr_high];  
        data.bsrlow_physync = bsrlow_physync;
        data.bsrhigh_physync = bsrhigh_physync;        
    end    
    
    % UEs of interest data
    ts_physync_interest = ts_physync(is_interest_ue);
    tbs_physync_interest = tbs_physync(is_interest_ue);
    mcs_physync_interest = mcs_physync(is_interest_ue);
    prb_physync_interest = prb_physync(is_interest_ue);
    delay_physync_interest = delay_physync(is_interest_ue);
    n_tx_physync_interest = n_tx_physync(is_interest_ue);
    
    % Other UEs data
    ts_physync_others = ts_physync(~is_interest_ue & ~is_sib_tx);
    tbs_physync_others = tbs_physync(~is_interest_ue & ~is_sib_tx);
    mcs_physync_others = mcs_physync(~is_interest_ue & ~is_sib_tx);
    prb_physync_others = prb_physync(~is_interest_ue & ~is_sib_tx);
    delay_physync_others = delay_physync(~is_interest_ue & ~is_sib_tx);
    n_tx_physync_others = n_tx_physync(~is_interest_ue & ~is_sib_tx);
    
    % Extract packet data
    % Choose appropriate timestamp column based on direction
    if strcmpi(direction, 'DL')
        % For downlink, use ts_server (column 15)
        pkt_st = find(data.data_packets(:, 15) > plot_period(1), 1, 'first');
        pkt_ed = find(data.data_packets(:, 15) < plot_period(2), 1, 'last');
    else
        % For uplink, use ts_ue (column 14)
        pkt_st = find(data.data_packets(:, 14) > plot_period(1), 1, 'first');
        pkt_ed = find(data.data_packets(:, 14) < plot_period(2), 1, 'last');
    end
    
    pkt_size = data.data_packets(pkt_st:pkt_ed, 8);
    ts_ue = data.data_packets(pkt_st:pkt_ed, 14);
    ts_server = data.data_packets(pkt_st:pkt_ed, 15);
    delay_pkt = data.data_packets(pkt_st:pkt_ed, 16);
    
    % Extract app-out data
    appout_st = find(data.ts_appout > plot_period(1), 1, 'first');
    appout_ed = find(data.ts_appout < plot_period(2), 1, 'last');
    ts_appout_range = data.ts_appout(appout_st:appout_ed);
    data_appout = data.file_appout(appout_st:appout_ed, :);
    
    if ~isempty(data.quality_cell)
        quality_data = data.quality_cell(appout_st:appout_ed);
    else
        quality_data = [];
    end

    % Extract app-in data
    appin_st = find(data.ts_appin > plot_period(1), 1, 'first');
    appin_ed = find(data.ts_appin < plot_period(2), 1, 'last');
    ts_appin_range = data.ts_appin(appin_st:appin_ed);
    data_appin = data.file_appin(appin_st:appin_ed, :);    

    % Extract app-pc data
    apppc_st = find(data.ts_apppc > plot_period(1), 1, 'first');
    apppc_ed = find(data.ts_apppc < plot_period(2), 1, 'last');
    ts_apppc_range = data.ts_apppc(apppc_st:apppc_ed);
    data_apppc = data.file_apppc(apppc_st:apppc_ed, :);      
    
    % Filter GCC data by time period
    if ~isempty(data.gcc_data)
        
        % Filter GCC data by the plot period
        valid_indices = data.gcc_data.timestamp_ms >= plot_period(1) & ...
                        data.gcc_data.timestamp_ms <= plot_period(2);
        gcc_data_filtered = data.gcc_data(valid_indices, :);
    else
        gcc_data_filtered = [];
    end
    
    % Add processed data to the struct
    data.ts_physync = ts_physync;
    data.tbs_physync = tbs_physync;
    data.mcs_physync = mcs_physync;
    data.prb_physync = prb_physync;
    data.prb_st_physync = prb_st_physync;
    data.delay_physync = delay_physync;
    data.rntis_physync = rntis_physync;
    data.n_tx_physync = n_tx_physync;  % Add n_tx_physync field
    data.is_interest_ue = is_interest_ue;
    data.is_sib = is_sib_tx;
    
    data.ts_physync_interest = ts_physync_interest;
    data.tbs_physync_interest = tbs_physync_interest;
    data.mcs_physync_interest = mcs_physync_interest;
    data.prb_physync_interest = prb_physync_interest;
    data.delay_physync_interest = delay_physync_interest;
    data.n_tx_physync_interest = n_tx_physync_interest;  % Add n_tx_physync_interest field
    
    data.ts_physync_others = ts_physync_others;
    data.tbs_physync_others = tbs_physync_others;
    data.mcs_physync_others = mcs_physync_others;
    data.prb_physync_others = prb_physync_others;
    data.delay_physync_others = delay_physync_others;
    data.n_tx_physync_others = n_tx_physync_others;  % Add n_tx_physync_others field
    
    data.pkt_size = pkt_size;
    data.ts_ue = ts_ue;
    data.ts_server = ts_server;
    data.delay_pkt = delay_pkt;
    
    % app metrics
    data.ts_appout_range = ts_appout_range;
    data.data_appout = data_appout;
    data.quality_data = quality_data;

    data.ts_appin_range = ts_appin_range;
    data.data_appin = data_appin;    

    data.ts_apppc_range = ts_apppc_range;
    data.data_apppc = data_apppc;        
    
    % gcc metrics
    data.gcc_data_filtered = gcc_data_filtered;
    
    % Store the direction for use in plotting functions
    data.direction = direction;
    
    % Calculate time offsets (for x-axis normalization)
    data.min_time = min([min(ts_physync), min(ts_ue), min(ts_appout_range)]);
end
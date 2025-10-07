function [ulData, dlData, config] = loadWebRTCData(expCode, appCode, enb2sfu_delay, datapath)

% ----- Load Configuration Parameters -----
% Basic parameters
config.expCode = expCode;
config.appCode = appCode;
config.experiment_name = ['webrtc-' expCode];
config.time_drifting = 1; % ms
config.header_len = 34; % 34 bytes
config.enb2sfu_delay = enb2sfu_delay;
config.gcc_offset = -0; % ms

% Determine slot duration based on experiment code
amarisoft = {'0420', '0421'};
need_conversion = {'0422'};
scs30k = {'0404', '0407', '0412', '0413', '0419', '0420', '0421', '0423', '0426'};
scs15k = {'0406', '0405', '0414', '0416', '0417', '0418', '0422'};

% Determine duplex mode based on experiment code
fdd_codes = {'0405', '0406', '0414', '0416', '0417', '0418', '0422'};
tdd_codes = {'0404', '0407', '0412', '0413', '0419', '0420', '0421', '0423', '0426'};


% Check if expCode is a member of either array
if ismember(expCode, scs30k)
    config.slot_duration = 0.5; % SCS: 30KHz
elseif ismember(expCode, scs15k)
    config.slot_duration = 1; % SCS: 15KHz
else
    % Default value or error handling if needed
    warning('Unknown expCode: %s. Using default slot_duration.', expCode);
    config.slot_duration = NaN; % or some default value
end


% Check expCode
if ismember(expCode, fdd_codes)
    config.duplex_mode = 'FDD';
elseif ismember(expCode, tdd_codes)
    config.duplex_mode = 'TDD';
else
    warning('Unknown expCode: %s. Using default duplex mode.', expCode);
    config.duplex_mode = 'unknown';
end

if ismember(expCode, amarisoft)
    config.isAmari = true;
else
    config.isAmari = false;
end

% Read RNTIs from file
rnti_file_path = [datapath 'data_exp' expCode '/rnti.txt'];
config.RNTIs_of_interest = readmatrix(rnti_file_path);

% ----- Load Experiment Data -----
% Create structs to store data
ulData = struct();
dlData = struct();

% Load data for both links
linktypes = {'U', 'D'};
data_structs = {ulData, dlData};

for i = 1:length(linktypes)
    linktype = linktypes{i};
    
    % Set direction-specific parameters
    if strcmp(linktype, 'U')
        dir_prefix = 'UL';
        pkts_file_suffix = '-join-pkts-up.csv';
        appout_rtp = '-out-rtp-2.csv';
        appin_rtp = '-in-rtp-1.csv';
        apppc_file = '-pc-2.csv';
        gcc_file = '-gcc-2.csv';
        direction_title = 'Uplink';
    else % 'D'
        dir_prefix = 'DL';
        pkts_file_suffix = '-join-pkts-down.csv';
        appout_rtp = '-out-rtp-1.csv';
        appin_rtp = '-in-rtp-2.csv';
        apppc_file = '-pc-1.csv';
        gcc_file = '-gcc-1.csv';
        direction_title = 'Downlink';
    end
    
    % Read packets data
    pktname = [datapath 'data_exp' expCode '/' config.experiment_name pkts_file_suffix];
    headers = readcell(pktname, 'Range', '1:1');
    data_packets = readmatrix(pktname, 'Range', 2);
    ts_pktOffset = data_packets(1, 1)*1000;
    
    % Read PHY data
    phyname = [datapath 'data_exp' expCode '/' dir_prefix '_tbs_delay_' expCode '.mat'];
    phy_data = load(phyname);

    % Conversion for 0422
    if ismember(expCode, need_conversion)
        % Convert from new_dci_log (struct of arrays) to dci_log (array of structs)
        if isfield(phy_data, 'new_dci_log')
            % Get field names from the new_dci_log structure
            fields = fieldnames(phy_data.new_dci_log);
            
            % Determine the length of the arrays
            array_length = length(phy_data.new_dci_log.(fields{1}));
            
            % Initialize an empty struct array with the correct size
            dci_log(array_length).dummy = []; % Pre-allocate with a dummy field
            dci_log = rmfield(dci_log, 'dummy'); % Remove the dummy field
            
            % Use deal to efficiently populate the struct array
            for k = 1:numel(fields)
                field_name = fields{k};
                field_values = num2cell(phy_data.new_dci_log.(field_name));
                [dci_log.(field_name)] = deal(field_values{:});
            end
            
            % Replace the original data with the converted data
            phy_data.dci_log = dci_log;
        else
            warning('Expected new_dci_log field not found in PHY data for expCode %s', expCode);
        end
    end 

    if strcmp(linktype, 'U')
        ts_dcilog = [phy_data.dci_log.ts] - ts_pktOffset + [phy_data.dci_log.k]*config.slot_duration - config.time_drifting; % in unit of ms
    else
        ts_dcilog = [phy_data.dci_log.ts] - ts_pktOffset + [phy_data.dci_log.k]*config.slot_duration - config.time_drifting + config.enb2sfu_delay;
    end
    % Read app logs
    appout = [datapath 'data_exp' expCode '/' appCode appout_rtp];
    appin = [datapath 'data_exp' expCode '/' appCode appin_rtp];
    apppc = [datapath 'data_exp' expCode '/' appCode apppc_file];
    
    % Read app-out
    outheaders = readcell(appout, 'Range', '1:1');
    opts = detectImportOptions(appout);
    opts.VariableNamesLine = 1;
    temp_table = readtable(appout, opts);
    video_idx = strcmp(temp_table.kind, 'video');
    file_appout = readmatrix(appout);
    file_appout = file_appout(video_idx, :);
    ts_appout = file_appout(:, 1) - file_appout(1, 1) + data_packets(1, 14);
    data_table_appout = temp_table(video_idx, :);
    quality_cell = data_table_appout.quality_limitation_reason;
    
    % Read app-in
    inheaders = readcell(appin, 'Range', '1:1');
    opts = detectImportOptions(appin);
    opts.VariableNamesLine = 1;
    temp_table = readtable(appin, opts);
    video_idx = strcmp(temp_table.kind, 'video');
    file_appin = readmatrix(appin, 'Range', 2);
    file_appin = file_appin(video_idx, :);
    ts_appin = file_appin(:, 1) - file_appin(1, 1) + data_packets(1, 14);
    
    % Read PC data
    pcheaders = readcell(apppc, 'Range', '1:1');
    file_apppc = readmatrix(apppc, 'Range', 2);
    ts_apppc = file_apppc(:, 1) - file_apppc(1, 1) + data_packets(1, 14);
    
    % Read GCC data
    gcc_filename = [datapath 'data_exp' expCode '/' appCode gcc_file];
    if exist(gcc_filename, 'file')
        % Read the CSV file
        opts = detectImportOptions(gcc_filename);
        opts.VariableNamesLine = 1;
        opts.DataLines = 2;
        opts.Delimiter = ',';
        
        % Convert all numeric cell columns to double arrays
        numericCols = {'timestamp_ms', 'modified_trend', 'threshold', 'target_bitrate_bps', ...
                      'loss_based_target_rate_bps', 'pushback_target_rate_bps', ...
                      'stable_target_rate_bps', 'fraction_loss', 'peer_id', ...
                      'outstanding_bytes', 'time_window_ms', 'data_window_bytes'};
        
        % Set all specified numeric columns to type 'double'
        for j = 1:length(numericCols)
            colName = numericCols{j};
            if any(strcmp(opts.VariableNames, colName))
                opts = setvartype(opts, colName, 'double');
            end
        end
        
        gcc_data = readtable(gcc_filename, opts);
        
        % Convert any remaining cell columns to numeric if needed
        for j = 1:length(numericCols)
            colName = numericCols{j};
            if ismember(colName, gcc_data.Properties.VariableNames) && iscell(gcc_data.(colName))
                gcc_data.(colName) = cellfun(@str2double, gcc_data.(colName));
            end
        end
        
        % Normalize timestamps
        first_timestamp = gcc_data.timestamp_ms(1);
        gcc_data.timestamp_ms = gcc_data.timestamp_ms - first_timestamp + data_packets(1, 14) - config.gcc_offset;
    else
        gcc_data = [];
        warning('GCC data file %s does not exist.', gcc_filename);
    end
    
    % Create data structure
    data_struct = struct();
    data_struct.data_packets = data_packets;
    data_struct.ts_dcilog = ts_dcilog;
    data_struct.dci_log = phy_data.dci_log;
    data_struct.ts_appout = ts_appout;
    data_struct.file_appout = file_appout;
    data_struct.quality_cell = quality_cell;
    data_struct.ts_appin = ts_appin;
    data_struct.file_appin = file_appin;
    data_struct.ts_apppc = ts_apppc;
    data_struct.file_apppc = file_apppc;
    data_struct.ts_pktOffset = ts_pktOffset;
    data_struct.direction = direction_title;
    data_struct.gcc_data = gcc_data;
    
    % Save data to the appropriate struct
    if strcmp(linktype, 'U')
        ulData = data_struct;
    else
        dlData = data_struct;
    end
end

end
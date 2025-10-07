%% Data preparation
clear;close all

% Define parameters
expCode = '0420';
linktype = 'U';  % 'U' for uplink, 'D' for downlink

% Determine file paths based on linktype
if strcmpi(linktype, 'U')
    filePath = ['../data_webrtc/data_exp' expCode '/gnb_ul_webrtc_parsed.csv'];
    savePath = ['../data_webrtc/data_exp' expCode '/UL_tbs_delay_' expCode '.mat'];
else
    filePath = ['../data_webrtc/data_exp' expCode '/gnb_dl_webrtc_parsed.csv'];
    savePath = ['../data_webrtc/data_exp' expCode '/DL_tbs_delay_' expCode '.mat'];
end

% Read the entire file into memory: data
opts = detectImportOptions(filePath, 'FileType', 'text');
opts = setvartype(opts, 'RNTI', 'string');  % Force RNTI as string explicitly
data = readtable(filePath, opts);

% Initialize structure array to store data with conditional BSR fields
if strcmpi(linktype, 'U')
    dci_log = struct('line_idx', [], 'ts', [], 'frame_i', [], 'slot_i', [], 'rnti', [], ...
        'k', [], 'prb_st', [], 'prb_count', [], 'mcs', [], 'tbs', [], 'harq_id', [], ...
        'n_tx', [], 'delay', [], 'ori_line_idx', [], 'bsr_low', [], 'bsr_high', [], ...
        'pad_len', []);
else
    dci_log = struct('line_idx', [], 'ts', [], 'frame_i', [], 'slot_i', [], 'rnti', [], ...
        'k', [], 'prb_st', [], 'prb_count', [], 'mcs', [], 'tbs', [], 'harq_id', [], ...
        'n_tx', [], 'delay', [], 'ori_line_idx', [], 'pad_len', []);
end

% Create MCS mapping table (q=2 for your scenario)
mcs_table = createMCSTable();
% Counter for unmapped MCS entries
unmapped_mcs_count = 0;

%% Processing loop
% Create a map to track original transmissions for each HARQ ID and RNTI
harq_map = containers.Map('KeyType', 'char', 'ValueType', 'any');
log_idx = 1;
tbs_mismatch_count = 0;
total_retx_count = 0;

% Create arrays to store analysis data
mismatch_data = struct('ori_idx', {}, 'retx_idx', {}, 'ori_tbs', {}, 'retx_tbs', {}, ...
    'harq_id', {}, 'rnti', {}, 'ori_ts', {}, 'retx_ts', {});
mismatch_count = 0;

% Loop through each row in the CSV
for i = 1:height(data)
    % Extract HARQ ID properly (handling cell array and 'si' case)
    harq_id = getHARQValue(data.HARQ(i));
    
    % Skip if essential fields are missing
    if isempty(harq_id) || isnan(data.TB_Len(i))
        continue;
    end
    
    % Create key for harq map using RNTI and HARQ ID
    rnti_value = getRNTIValue(data.RNTI(i));
    if isnumeric(harq_id)
        harq_key = sprintf('%d_%d', rnti_value, harq_id);
    else
        % For 'si' case or other string cases
        harq_key = sprintf('%d_%s', rnti_value, harq_id);
    end
    
    % Determine if this is a retransmission
    is_retx = data.Retx(i) > 0;
    
    % Set basic fields
    dci_log(log_idx).line_idx = i;
    dci_log(log_idx).ts = data.Timestamp_us(i)/1000;
    if log_idx>1 && dci_log(log_idx).ts==dci_log(log_idx-1).ts
        dci_log(log_idx).ts = dci_log(log_idx).ts+0.5;
    end

    dci_log(log_idx).frame_i = data.Frame_Idx(i);
    dci_log(log_idx).slot_i = data.Slot_Idx(i);
    dci_log(log_idx).rnti = rnti_value;
    dci_log(log_idx).k = 0;
    [prb_st, prb_count] = parsePRB(data.PRB(i));
    dci_log(log_idx).prb_st = prb_st;
    dci_log(log_idx).prb_count = prb_count;    
    dci_log(log_idx).tbs = data.TB_Len(i)*8; % in Bits
    % dci_log(log_idx).pad_len = data.PAD_Len(i)*8;
    dci_log(log_idx).harq_id = harq_id;
    dci_log(log_idx).rv = data.RV_Idx(i);
    
    % Find MCS index based on Mod and CR
    if ~isnan(data.Mod(i)) && ~isnan(data.CR(i))
        mod_order = data.Mod(i);
        cr_scaled = data.CR(i); % Scale and round CR as required
        mcs_idx = findMCSIndex(mod_order, cr_scaled, mcs_table);
        if mcs_idx == -1
            unmapped_mcs_count = unmapped_mcs_count + 1;
        end
        dci_log(log_idx).mcs = mcs_idx;
    else
        dci_log(log_idx).mcs = -1;
        unmapped_mcs_count = unmapped_mcs_count + 1;
    end    

    % Get BSR range only for uplink
    if strcmpi(linktype, 'U')
        bsr_index = 0;  % Default value
        is_long_bsr = false;

        if ~isnan(data.BSR_BS(i))  % Short BSR case
            bsr_index = data.BSR_BS(i);
            is_long_bsr = false;
        elseif ~isempty(data.BSR_7_(i)) && ~strcmp(data.BSR_7_(i), '')  % Long BSR case with LCG 7
            bsr_value = str2double(data.BSR_7_(i));
            if ~isnan(bsr_value)
                bsr_index = bsr_value;
                is_long_bsr = true;
            end
        end

        [dci_log(log_idx).bsr_low, dci_log(log_idx).bsr_high] = hGetBSRRange(bsr_index, is_long_bsr); % bits
    end
    
    % Handle original transmissions and retransmissions
    if ~is_retx
        % This is an initial transmission
        dci_log(log_idx).n_tx = 1;
        dci_log(log_idx).delay = 0;
        dci_log(log_idx).ori_line_idx = i;
        
        % Store this transmission info in the map
        harq_map(harq_key) = struct('line_idx', i, 'ts', data.Timestamp_us(i)/1000, ...
            'tbs', data.TB_Len(i)*8);
    else
        % This is a retransmission
        total_retx_count = total_retx_count + 1;
        
        if harq_map.isKey(harq_key)
            % Get original transmission info
            ori_tx = harq_map(harq_key);
            
            dci_log(log_idx).n_tx = data.Retx(i) + 1;
            dci_log(log_idx).delay = data.Timestamp_us(i)/1000 - ori_tx.ts;
            dci_log(log_idx).ori_line_idx = ori_tx.line_idx;
            
            % Check for TBS mismatch
            if ori_tx.tbs ~= data.TB_Len(i)*8
                tbs_mismatch_count = tbs_mismatch_count + 1;
                mismatch_count = mismatch_count + 1;
                
                % Store mismatch information
                mismatch_data(mismatch_count).ori_idx = ori_tx.line_idx;
                mismatch_data(mismatch_count).retx_idx = i;
                mismatch_data(mismatch_count).ori_tbs = ori_tx.tbs;
                mismatch_data(mismatch_count).retx_tbs = data.TB_Len(i)*8;
                mismatch_data(mismatch_count).harq_id = harq_id;
                mismatch_data(mismatch_count).rnti = rnti_value;
                mismatch_data(mismatch_count).ori_ts = ori_tx.ts;
                mismatch_data(mismatch_count).retx_ts = data.Timestamp_us(i)/1000;
            end
        else
            % Cannot find original transmission
            if isnumeric(harq_id)
                warning('Cannot find original transmission for HARQ ID %d at line %d', harq_id, i);
            else
                warning('Cannot find original transmission for HARQ ID %s at line %d', harq_id, i);
            end
            dci_log(log_idx).n_tx = 1;
            dci_log(log_idx).delay = 0;
            dci_log(log_idx).ori_line_idx = i;
            
            % Store this transmission info in the map
            harq_map(harq_key) = struct('line_idx', i, 'ts', data.Timestamp_us(i)/1000, ...
                'tbs', data.TB_Len(i)*8);
        end
    end
    
    log_idx = log_idx + 1;
end

% Print analysis results with link direction
if strcmpi(linktype, 'U')
    fprintf('\nUplink Analysis Results:\n');
else
    fprintf('\nDownlink Analysis Results:\n');
end
fprintf('Total retransmissions: %d\n', total_retx_count);
fprintf('TBS mismatches: %d (%.2f%%)\n', tbs_mismatch_count, ...
    (tbs_mismatch_count/max(total_retx_count,1))*100);
fprintf('Unmapped MCS entries: %d (%.2f%%)\n', unmapped_mcs_count, ...
    (unmapped_mcs_count/max((log_idx-1),1))*100);

% Create detailed mismatch analysis
if mismatch_count > 0
    mismatch_table = struct2table(mismatch_data);
    
    % Calculate statistics
    tbs_change = [mismatch_data.retx_tbs] - [mismatch_data.ori_tbs];
    delay_ms = ([mismatch_data.retx_ts] - [mismatch_data.ori_ts])/1000;
    
    fprintf('\nTBS Change Statistics:\n');
    fprintf('Mean change: %.2f bytes\n', mean(tbs_change));
    fprintf('Median change: %.2f bytes\n', median(tbs_change));
    fprintf('Min change: %d bytes\n', min(tbs_change));
    fprintf('Max change: %d bytes\n', max(tbs_change));
    
    % Save mismatch data for further analysis
    save([savePath(1:end-4) '_tbs_mismatch.mat'], 'mismatch_data');
    
    % Optional: Create a scatter plot of original vs retransmission TBS
    figure;
    scatter([mismatch_data.ori_tbs], [mismatch_data.retx_tbs], 'filled', 'alpha', 0.5);
    hold on;
    plot([0 max([mismatch_data.ori_tbs])], [0 max([mismatch_data.ori_tbs])], 'r--');
    xlabel('Original TBS (bytes)');
    ylabel('Retransmission TBS (bytes)');
    if strcmpi(linktype, 'U')
        title('Uplink: Original vs Retransmission TBS Comparison');
    else
        title('Downlink: Original vs Retransmission TBS Comparison');
    end
    grid on;
    
    % Create a histogram of TBS changes
    figure;
    histogram(tbs_change, 'Normalization', 'probability');
    xlabel('TBS Change (bytes)');
    ylabel('Probability');
    if strcmpi(linktype, 'U')
        title('Uplink: Distribution of TBS Changes in Retransmissions');
    else
        title('Downlink: Distribution of TBS Changes in Retransmissions');
    end
    grid on;
end

% Save to file
save(savePath,"dci_log");

%% Define MCS mapping function

function mcs_table = createMCSTable()
    % Create the MCS table based on the provided mapping
    % Note: q = 2 in this scenario
    mcs_table = struct('mcs_idx', {}, 'mod_order', {}, 'target_code_rate', {});
    
    % Define the entries
    mod_orders = [2,2,2,2,2,4,4,4,4,4,4,6,6,6,6,6,6,6,6,6,8,8,8,8,8,8,8,8];
    code_rates = [120,193,308,449,602,378,434,490,553,616,658,466,517,567,616,666,719,772,822,873,682.5,711,754,797,841,885,916.5,948];
    
    % Populate the table
    for i = 1:length(mod_orders)
        mcs_table(i).mcs_idx = i-1;  % 0-based index
        mcs_table(i).mod_order = mod_orders(i);
        mcs_table(i).target_code_rate = code_rates(i);
    end
end

function mcs_idx = findMCSIndex(mod_order, cr_scaled, mcs_table)    
    min_diff = Inf;
    best_idx = -1;
    
    for i = 1:length(mcs_table)
        rounded_code_rate = round(mcs_table(i).target_code_rate/1024 * 100) / 100;
        
        % If modulation order matches
        if mcs_table(i).mod_order == mod_order
            % Calculate difference to track closest match
            diff = abs(rounded_code_rate - cr_scaled);
            
            % If this is closer than previous matches
            if diff < min_diff
                min_diff = diff;
                best_idx = i;
            end
        end
    end
    
    % Return the MCS index of the closest match, or -1 if no matching modulation order
    if best_idx ~= -1
        mcs_idx = mcs_table(best_idx).mcs_idx;
    else
        mcs_idx = -1; % No match found
    end
end

function harq_id = getHARQValue(harq_data)
    % Extract HARQ ID from cell array or numeric value, handling 'si' case
    if iscell(harq_data)
        harq_str = harq_data{1};
        % Check if it's 'si' or a similar special string value
        if ischar(harq_str) && ~isempty(harq_str) && ~isnumeric(str2double(harq_str))
            if strcmp(harq_str, 'si')
                harq_id = 'si';  % Keep as string for special cases
            else
                harq_id = harq_str;  % Keep as string for other special cases
            end
        else
            % Convert to numeric if it's a numeric string
            harq_id = str2double(harq_str);
            if isnan(harq_id)
                harq_id = [];  % Empty for invalid values
            end
        end
    else
        % If already numeric
        harq_id = harq_data;
    end
end

%% Function to parse PRB string

function [prb_st, prb_count] = parsePRB(prb_cell)
    if isempty(prb_cell) || isempty(prb_cell{1})
        prb_st = 0;  % Initialize with default values
        prb_count = 0;
        return;
    end
    
    prb_str = prb_cell{1};  % Extract string from cell
    if contains(prb_str, ':')
        % Case like '42:7'
        parts = split(prb_str, ':');
        prb_st = str2double(parts{1});
        prb_count = str2double(parts{2});
    else
        % Case like '42'
        prb_st = str2double(prb_str);
        prb_count = 1;
    end
end

function rnti_value = getRNTIValue(rnti_data)
    if iscell(rnti_data)
        % If it's a cell, convert the string to a value
        rnti_str = rnti_data{1};
        % Try to convert from hex if it looks like hex

        % Convert hex string to number
        rnti_value = hex2dec(strrep(rnti_str, 'b', ''));
    else
        rnti_value = hex2dec(strrep(rnti_data, 'b', ''));
    end
end
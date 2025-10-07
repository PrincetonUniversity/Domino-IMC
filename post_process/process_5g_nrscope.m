%% Data preparation
clear;

% Define parameters
expCode = '0423';
linktype = 'U';  % 'U' for uplink, 'D' for downlink
scs30k = {'0404', '0407', '0412', '0413', '0419', '0423', '0426'};
scs15k = {'0406', '0405', '0414', '0416', '0417', '0418', '0422'};

% Determine link directionality based on linktype
if strcmp(linktype, 'U')
    direction_str = "0_1";  % Uplink
    file_prefix = 'UL';
elseif strcmp(linktype, 'D')
    direction_str = "1_1";  % Downlink
    file_prefix = 'DL';
else
    error('Invalid linktype. Must be ''U'' or ''D''.');
end

% Check if expCode is a member of either array
if ismember(expCode, scs30k)
    slot_duration = 0.5; % SCS: 30KHz
elseif ismember(expCode, scs15k)
    slot_duration = 1; % SCS: 15KHz
else
    % Default value or error handling if needed
    warning('Unknown expCode: %s. Using default slot_duration.', expCode);
    slot_duration = NaN; % or some default value
end

% Read the entire file into memory: data
filePath = ['../data_webrtc/data_exp' expCode '/dcilog.csv']; 
data = readtable(filePath, 'FileType', 'text');

% Load RNTIs of interest - adapt file name based on linktype
fileName = ['../data_webrtc/data_exp' expCode '/UE_rnti5G_' expCode '.mat'];
RNTIs = load(fileName);
RNTIs_of_interest = RNTIs.rntisAboveThreshold; 

% Extract the specified columns
numericalDataColumns = [1, 2, 3, 4, 7, 11, 12, 19, 20, 22, 23, 28];
stringDataColumn = 6;
numericalData = table2array(data(:, numericalDataColumns));
stringData = table2array(data(:, stringDataColumn));

% Initialize structure array to store data
dci_log = struct('line_idx', [], 'ts', [], 'frame_i', [], 'slot_i', [], 'rnti', [], 'k', [], ...
    'prb_st', [], 'prb_count', [], 'mcs', [], 'tbs', [], 'rv', [], 'ndi', [], 'harq_id', [], ...
    'n_tx', [], 'delay', [], 'ori_line_idx', []);


%% Preprocessing loop: Keep rows with RNTIs_of_interest, and matching direction

% Keep only valid rows
validRows = false(size(numericalData, 1), 1);
for i = 1:size(data, 1)
    if ismember(numericalData(i, 4), [RNTIs_of_interest, 0]) && strcmp(stringData{i}, direction_str)
        validRows(i) = true;
    end
end
numericalData = numericalData(validRows, :);
stringData = stringData(validRows);

% Calculate slots per frame based on slot duration
slots_per_frame = 10 / slot_duration;

% Add three columns: Initialize additional columns in numericalData
n_transmission = ones(size(numericalData, 1), 1);
delay = zeros(size(numericalData, 1), 1);
original_line_idx = (1:size(numericalData, 1))';
numericalData = [numericalData, n_transmission, delay, original_line_idx];

% Timestamp correction loop
% Create a temporary matrix to store corrected values
correctedData = numericalData;

% Store the original timestamps for reference
original_timestamps = numericalData(:, 1);

% Loop through rows starting from the second row
for i = 2:size(numericalData, 1)
    % Calculate frame_slot_difference accounting for wrapping
    current_frame = numericalData(i, 2);
    current_slot = numericalData(i, 3);
    prev_frame = numericalData(i-1, 2);
    prev_slot = numericalData(i-1, 3);
    
    % Calculate total slots for current and previous entry
    total_current_slots = current_frame * slots_per_frame + current_slot;
    total_prev_slots = prev_frame * slots_per_frame + prev_slot;
    
    % Handle frame wrapping (max frame = 1023)
    max_frame = 1024; % 10 bits (0-1023)
    max_slots = max_frame * slots_per_frame;
    
    % Calculate difference in slots with potential wrapping
    frame_slot_difference = total_current_slots - total_prev_slots;
    
    % If difference is very negative, it likely means we wrapped around
    if frame_slot_difference < 0 && abs(frame_slot_difference) > (max_slots / 2)
        frame_slot_difference = frame_slot_difference + max_slots;
    % If difference is very positive, it likely means we wrapped backward
    elseif frame_slot_difference > 0 && frame_slot_difference > (max_slots / 2)
        frame_slot_difference = frame_slot_difference - max_slots;
    end
    
    % Correct timestamp (numericalData(1) is in seconds, slot_duration is in ms)
    correctedData(i, 1) = correctedData(i-1, 1) + (frame_slot_difference * slot_duration / 1000);
end

% Find and sort disordered events
[~, sortedIndices] = sort(correctedData(:, 1));
numericalData = correctedData(sortedIndices, :);
stringData = stringData(sortedIndices);

% Initialize harq_ndi list
harq_ndi = -1 * ones(16, 2); % First column for ndi, second for line_idx

%% Second loop: Handling retransmissions
for i = 1:size(numericalData, 1)
    rowNumerical = numericalData(i, :);
    rowString = stringData{i};

    harq_id = rowNumerical(12) + 1;
    ndi = rowNumerical(11);

    if harq_ndi(harq_id, 1) == -1
        % First encounter of this HARQ ID, initialize
        harq_ndi(harq_id, :) = [ndi, i];
    else
        previous_ndi = harq_ndi(harq_id, 1);
        previous_idx = harq_ndi(harq_id, 2);

        if ndi ~= previous_ndi
            % NDI toggles, new transmission
            harq_ndi(harq_id, :) = [ndi, i];
        else
            % Cross validate RxTX, NDI and rv>0. 
            if numericalData(i,10)>0            
                numericalData(i, 13) = numericalData(previous_idx, 13) + 1; % Increment n_transmission
                numericalData(previous_idx, 13) = 0; % Reset failed TB n_transmission
                numericalData(i, 14) = numericalData(previous_idx, 14) + calculate_delta_t(i, previous_idx, numericalData, slot_duration); % delay
                numericalData(i, 15) = numericalData(previous_idx, 15); % Forward original line_idx
                % assign mcs, tbs to original tx
                numericalData(i,[8,9]) = numericalData(previous_idx,[8,9]);
            end

            % Update harq_ndi list
            harq_ndi(harq_id, 2) = i;
        end
    end
end

%% Third loop: Data logging
tic

valid_idx = 0;
for i = 1:size(numericalData, 1)
    rowNumerical = numericalData(i, :);
    rowString = stringData{i};

    % Process the row if RNTI matches, and if it matches the direction
    if ismember(rowNumerical(4), [RNTIs_of_interest, 0]) && strcmp(rowString, direction_str)
        valid_idx = valid_idx + 1;
        dci_log(valid_idx).line_idx = i;
        dci_log(valid_idx).ts = rowNumerical(1) * 1000; % in unit of ms        
        dci_log(valid_idx).frame_i = rowNumerical(2);
        dci_log(valid_idx).slot_i = rowNumerical(3);
        dci_log(valid_idx).rnti = rowNumerical(4);
        dci_log(valid_idx).k = rowNumerical(5);
        dci_log(valid_idx).prb_st = rowNumerical(6);
        dci_log(valid_idx).prb_count = rowNumerical(7);
        dci_log(valid_idx).mcs = rowNumerical(8);
        dci_log(valid_idx).tbs = rowNumerical(9);        
        dci_log(valid_idx).rv = rowNumerical(10);
        dci_log(valid_idx).ndi = rowNumerical(11);
        dci_log(valid_idx).harq_id = rowNumerical(12);
        dci_log(valid_idx).n_tx = rowNumerical(13); % Add n_tx
        dci_log(valid_idx).delay = rowNumerical(14);
        dci_log(valid_idx).ori_line_idx = rowNumerical(15); % Add original_line_idx      
    end
end


% Save to file - Use file_prefix for appropriate naming
% fields = fieldnames(dci_log);
% new_dci_log = struct();
% for k = 1:numel(fields)
%     new_dci_log.(fields{k}) = [dci_log.(fields{k})];
% end
% clear dci_log;

savePath = ['../data_webrtc/data_exp' expCode '/' file_prefix '_tbs_delay_' expCode '.mat'];
save(savePath, "dci_log"); % Add the '-v7.3' flag



% Add linktype to figure title for clarity
link_title = '';
if strcmp(linktype, 'U')
    link_title = 'Uplink ';
else
    link_title = 'Downlink ';
end

line_list = [dci_log.line_idx];
% Plotting
figure;
subplot(2,2,1);
plot(line_list, [dci_log.mcs]);
title([link_title 'MCS list']);
xlabel('Time (s)', 'FontSize', 20);
ylabel('MCS', 'FontSize', 20);
set(gca, 'FontSize', 20);

subplot(2,2,3);
plot(line_list, [dci_log.tbs]);
title([link_title 'TBS list']);
xlabel('Time (s)', 'FontSize', 20);
ylabel('TBS', 'FontSize', 20);
set(gca, 'FontSize', 20);

subplot(2,2,2);
plot(line_list, [dci_log.delay]);
title([link_title 'Delay list']);
xlabel('Time (s)', 'FontSize', 20);
ylabel('Delay (ms)', 'FontSize', 20);
set(gca, 'FontSize', 20);

subplot(2,2,4);
plot(line_list, [dci_log.prb_count]);
title([link_title 'Allocated PRB']);
xlabel('Time (s)', 'FontSize', 20);
ylabel('Allocated PRB', 'FontSize', 20);
set(gca, 'FontSize', 20);
toc

%% Helper functions
function delta_t = calculate_delta_t(current_idx, previous_idx, numericalData, slot_duration)
    % Calculate time difference based on frame and slot indices, accounting for k and frame wrapping
    % Parameters:
    %   current_idx - Index of current row in numericalData
    %   previous_idx - Index of previous row in numericalData
    %   numericalData - The array containing frame, slot, and k data
    %   slot_duration - Duration of a slot in ms
    % Returns:
    %   delta_t - Time difference in milliseconds
    
    % Extract frame, slot indices, and k for both rows
    current_frame = numericalData(current_idx, 2);
    current_slot = numericalData(current_idx, 3);
    current_k = numericalData(current_idx, 5);
    
    previous_frame = numericalData(previous_idx, 2);
    previous_slot = numericalData(previous_idx, 3);
    previous_k = numericalData(previous_idx, 5);
    
    % Calculate slots per frame based on slot duration
    slots_per_frame = 10 / slot_duration;
    
    % Calculate total slots for each timestamp
    total_current_slots = current_frame * slots_per_frame + current_slot + current_k;
    total_previous_slots = previous_frame * slots_per_frame + previous_slot + previous_k;
    
    % Handle frame wrapping (1023 -> 0)
    % Maximum frame number is 1023 (10 bits)
    max_frame = 1024;
    max_slots = max_frame * slots_per_frame;
    
    % Calculate difference in slots with potential wrapping
    delta_slots = total_current_slots - total_previous_slots;
    
    % If delta is negative and large, it likely means we wrapped around
    if delta_slots < 0 && abs(delta_slots) > (max_slots / 2)
        delta_slots = delta_slots + max_slots;
    % If delta is positive and large, it likely means we wrapped backward
    elseif delta_slots > 0 && delta_slots > (max_slots / 2)
        delta_slots = delta_slots - max_slots;
    end
    
    % Convert to time in milliseconds
    delta_t = delta_slots * slot_duration;
end
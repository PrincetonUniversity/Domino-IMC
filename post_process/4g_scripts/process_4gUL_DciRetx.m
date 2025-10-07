%% Data preparation
clear;close all

% Define parameters
expCode = '0422';

% Load RNTIs of interest
fileName = ['../../data/data_exp' expCode '/UL_rnti_' expCode '.mat'];
RNTIs = load(fileName);
RNTIs_of_interest = RNTIs.rntisAboveThreshold; 

% Read the entire file into memory
linktype = 'U';
filePath = ['../../data/data_exp' expCode '/dci_raw_log_ul_freq_3610000000.dciLog']; % dci_raw_log_ul_freq_2602000000
data = readmatrix(filePath, 'FileType', 'text');
timestamp_range = [data(1,12), data(end,12)];

% Initialize structure array to store data
dci_log = struct('line_idx', [], 'tti', [], 'rnti', [], 'ts', [], 'prb', [], 'mcs', [], 'rv', [], 'tbs', [], 'delay', [], 'n_tx', [], 'RLC_fail', []);

%% Data processing
tic
% % First pass to make sure there is only one DCI per TTI
% i = 1;
% while i < size(data, 1)
%     if data(i, 1) == data(i + 1, 1)
%         if ismember(data(i, 2), RNTIs_of_interest)
%             data(i + 1, :) = [];  % Delete the (i+1)-th row
%             % No increment of i, as the next row has shifted up
%         else
%             data(i, :) = [];  % Delete the current row
%             % No need to increment i as the current row is deleted
%         end
%     else
%         i = i + 1;  % Increment to next row only if no deletion
%     end
% end

% First pass to handle retransmissions
delay_retx = 10; % TTI difference
error_entry = 0;
valid_entry = 0;
for i = 1:size(data, 1)
    % row i
    row = data(i, :);   
    % if retransmission happens
    if ismember(row(2),RNTIs_of_interest) && row(6)>0 && i>delay_retx
        % find row j that represents the previous transmission
        prev_tti = mod(row(1) - delay_retx + 10240, 10240);
        tti_found = 0;
        for j = i-9:-1:i-100
            if data(j,1)==prev_tti && ismember(data(j, 2), RNTIs_of_interest) 
                % if data(j, 11)==4
                %     data(i, 2:10) = zeros(1, 9);
                % else
                data(i, 3:5) = data(j, 3:5);
                data(i, 11) = data(j, 11)+1;
                data(j, 2:11) = zeros(1, 10);
                % end
                tti_found = 1;
                break
            end
        end
        if tti_found == 1
            valid_entry = valid_entry+1; 
        else
            data(i, 2:10) = zeros(1, 9);
            error_entry = error_entry+1;
        end
    end

end

% Second pass to store data into dcl_log
dci_failed = [];
valid_idx = 0;
for i = 1:size(data, 1)
    row = data(i, :);

    % Check if the timestamp is within range
    if row(12) < timestamp_range(1) || row(12) > timestamp_range(2)
        continue; % Skip this row
    end

    % Process the row if RNTI matches
    if ismember(row(2), [RNTIs_of_interest,0])
        valid_idx = valid_idx + 1;
        dci_log(valid_idx).line_idx = i;
        dci_log(valid_idx).tti = row(1);
        dci_log(valid_idx).rnti = row(2);
        dci_log(valid_idx).ts = row(12)/1000; % in unit of ms
        dci_log(valid_idx).prb = row(4);
        dci_log(valid_idx).mcs = row(5);
        dci_log(valid_idx).rv = row(6);
        dci_log(valid_idx).tbs = calc_4g_tbs(row(5), row(4), linktype);
        
        % Assign delay based on number of retransmissions
        if row(11)>=4 
            dci_log(valid_idx).n_tx = row(11)+1; % Max N_HARQ transmission is 4, MAC HARQ failure
            dci_log(valid_idx).delay = row(11)*10;
            dci_log(valid_idx).RLC_fail = 1;
        else
            dci_log(valid_idx).n_tx = row(11)+1; % each retransmission adds 10ms delay
            dci_log(valid_idx).delay = row(11)*10;
            dci_log(valid_idx).RLC_fail = 0;
        end

        % log failed transmissions
        dci_failed(valid_idx) = 0;
        if row(11)>0
            dci_failed(valid_idx-row(11)*10) = dci_log(valid_idx).tbs;
        end
    end
end

CountMACFailure = sum([dci_log.n_tx] <= -10);

% Save to file
savePath = ['../../data/data_exp' expCode '/UL_tbs_delay_' expCode '.mat'];
save(savePath,"dci_log", "dci_failed");

% Plotting
figure;
subplot(3,1,1);
plot(([dci_log.ts] - timestamp_range(1)/1e3)/1e3, [dci_log.mcs]);
title('MCS list');
xlabel('Time (s)', 'FontSize', 20);
ylabel('MCS', 'FontSize', 20);
set(gca, 'FontSize', 20);

subplot(3,1,2);
plot(([dci_log.ts] - timestamp_range(1)/1e3)/1e3, [dci_log.tbs]);
title('TBS list');
xlabel('Time (s)', 'FontSize', 20);
ylabel('TBS', 'FontSize', 20);
set(gca, 'FontSize', 20);

subplot(3,1,3);
plot(([dci_log.ts] - timestamp_range(1)/1e3)/1e3, [dci_log.n_tx].*10);
title('Delay list');
xlabel('Time (s)', 'FontSize', 20);
ylabel('Delay (ms)', 'FontSize', 20);
set(gca, 'FontSize', 20);
toc


%% Helper functions
function updatedArray = deleteRow(array, rowIndex)
    % This function deletes the row at rowIndex from the array

    % Check if the rowIndex is valid
    if rowIndex > size(array, 1) || rowIndex < 1
        error('Row index is out of bounds');
    end

    % Delete the specified row
    updatedArray = array([1:rowIndex-1, rowIndex+1:end], :);
end

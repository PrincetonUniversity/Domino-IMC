%% Used for tethering delay test

% Read and process ping data from CSV files
pc_file = '/home/paws/fanyi/proj_webrtc/data_ping/data_exp1124/ping_pc_1124.csv';
ue_file = '/home/paws/fanyi/proj_webrtc/data_ping/data_exp1124/ping_ue_1124.csv';
offset = -0.34382;

% Read CSV files
pc_data = readtable(pc_file);
ue_data = readtable(ue_file);

% Get unique sequence numbers
seq_nums = unique(pc_data.SequenceNumber);

% Initialize result array
result = zeros(length(seq_nums), 4);  % [seq_num, pc_ts, ue_ts1, ue_ts2]

% Process each sequence number
for i = 1:length(seq_nums)
    seq = seq_nums(i);
    result(i,1) = seq;
    
    % Get PC timestamp
    pc_idx = find(pc_data.SequenceNumber == seq);
    if ~isempty(pc_idx)
        result(i,2) = pc_data.Timestamp(pc_idx(1))+offset;
    end
    
    % Get UE timestamps for both IPs
    ue_idx1 = find(ue_data.SequenceNumber == seq & ...
                  strcmp(ue_data.SourceIP, '192.168.142.150'));
    ue_idx2 = find(ue_data.SequenceNumber == seq & ...
                  strcmp(ue_data.SourceIP, '192.168.3.2'));
    
    if ~isempty(ue_idx1)
        result(i,3) = ue_data.Timestamp(ue_idx1(1));
    end
    if ~isempty(ue_idx2)
        result(i,4) = ue_data.Timestamp(ue_idx2(1));
    end
end

% Remove rows with zeros (missing data)
result = result(all(result ~= 0, 2), :);

% Calculate time differences
diff1 = result(:,3) - result(:,2);  % UE1 - PC
diff2 = result(:,4) - result(:,3);  % UE2 - UE1

% Plot CDFs
figure;

% First CDF: PC to UE1
subplot(2,1,1);
[f1,x1] = ecdf(diff1);
plot(x1*1000, f1, 'LineWidth', 2);  % Convert to milliseconds
grid on;
title('CDF of Time Difference: PC -> phone(192.168.142.150)');
xlabel('Time Difference (ms)');
ylabel('Cumulative Probability');


% Second CDF: UE1 to UE2
subplot(2,1,2);
[f2,x2] = ecdf(diff2);
plot(x2*1000, f2, 'LineWidth', 2);  % Convert to milliseconds
grid on;
title('CDF of Time Difference: phone(192.168.142.150) -> phone(192.168.3.2)');
xlabel('Time Difference (ms)');
ylabel('Cumulative Probability');

% Print statistics
fprintf('Statistics for UE1 - PC (ms):\n');
fprintf('Mean: %.2f\n', mean(diff1)*1000);
fprintf('Median: %.2f\n', median(diff1)*1000);
fprintf('Std: %.2f\n\n', std(diff1)*1000);

fprintf('Statistics for UE2 - UE1 (ms):\n');
fprintf('Mean: %.2f\n', mean(diff2)*1000);
fprintf('Median: %.2f\n', median(diff2)*1000);
fprintf('Std: %.2f\n', std(diff2)*1000);


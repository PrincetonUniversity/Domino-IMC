%% Data preparation
clear;

% Define parameters
expCode = '0408';
threshold = 300;

% Read the entire file into memory
filePath = ['../data/data_exp' expCode '/dci_raw_log_ul_freq_2602000000.dciLog'];
data = readmatrix(filePath, 'FileType', 'text');

% Initialize a map to store RNTI counts
rntiCounts = containers.Map('KeyType', 'double', 'ValueType', 'int32');


%% Process the data
tic
for i = 1:size(data, 1)
    row = data(i, :);
    
    % Extract the RNTI (second column)
    rnti = row(2);
    
    % Update the count for this RNTI
    if rnti~=0 && rnti~=65535
        if isKey(rntiCounts, rnti)
            rntiCounts(rnti) = rntiCounts(rnti) + 1;
        else
            rntiCounts(rnti) = 1;
        end
    end
end

% Filter RNTIs with counts of threshold or more
rntisToKeep = keys(rntiCounts);
rntisAboveThreshold = []; % Initialize an array for RNTIs with sufficient counts

for i = 1:length(rntisToKeep)
    if rntiCounts(rntisToKeep{i}) >= threshold
        rntisAboveThreshold(end+1) = rntisToKeep{i};
    end
end

% Save to file
rntiPath = ['UL_rnti_' expCode '.mat'];
save(rntiPath, "rntisAboveThreshold", "rntiCounts");

% Display the RNTIs above the threshold and their counts
for i = 1:length(rntisAboveThreshold)
    disp(['RNTI: ' num2str(rntisAboveThreshold(i)) ', Count: ' num2str(rntiCounts(rntisAboveThreshold(i)))]);
end
toc
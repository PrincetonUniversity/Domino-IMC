%% Data preparation
clear;
% Define parameters
expCode = '0423';
threshold1 = 1000;  % Renamed from threshold
threshold2 = 1000;   % New threshold

% Read the entire file into memory
filePath = ['../data_webrtc/data_exp' expCode '/dcilog.csv'];
data = readmatrix(filePath, 'FileType', 'text', 'NumHeaderLines', 1);

% Initialize a map to store RNTI counts
rntiCounts = containers.Map('KeyType', 'double', 'ValueType', 'int32');

%% Process the data
tic
for i = 1:size(data, 1)
    row = data(i, :);
    % Extract the RNTI (second column)
    rnti = row(4);
    % Update the count for this RNTI
    if rnti~=0 && rnti~=65535
        if isKey(rntiCounts, rnti)
            rntiCounts(rnti) = rntiCounts(rnti) + 1;
        else
            rntiCounts(rnti) = 1;
        end
    end
end

% Filter RNTIs with counts of threshold1 or more
rntisToKeep = keys(rntiCounts);
rntisAboveThreshold = []; % Initialize an array for RNTIs with counts >= threshold1
rntisBelowThreshold = []; % Initialize an array for RNTIs with counts between threshold2 and threshold1

for i = 1:length(rntisToKeep)
    currentRnti = rntisToKeep{i};
    currentCount = rntiCounts(currentRnti);
    
    if currentCount >= threshold1
        rntisAboveThreshold(end+1) = currentRnti;
    elseif currentCount >= threshold2 && currentCount < threshold1
        rntisBelowThreshold(end+1) = currentRnti;
    end
end

% Save to file
rntiPath = ['../data_webrtc/data_exp' expCode '/UE_rnti5G_' expCode '.mat'];
save(rntiPath, "rntisAboveThreshold", "rntisBelowThreshold", "rntiCounts");

% Display the RNTIs above threshold1 and their counts
disp('RNTIs above threshold1:');
for i = 1:length(rntisAboveThreshold)
    disp(['RNTI: ' num2str(rntisAboveThreshold(i)) ', Count: ' num2str(rntiCounts(rntisAboveThreshold(i)))]);
end

% Display the RNTIs between threshold2 and threshold1 and their counts
disp('RNTIs between threshold2 and threshold1:');
for i = 1:length(rntisBelowThreshold)
    disp(['RNTI: ' num2str(rntisBelowThreshold(i)) ', Count: ' num2str(rntiCounts(rntisBelowThreshold(i)))]);
end

toc
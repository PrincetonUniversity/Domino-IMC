%% Parameters
clear;close all

% Define experiment and application codes
expCodes = {'0423', '0422', '0421', '0426'};
appCodes = {'1745699530', '1745696580', '1745693934', '1746214121'};
expLabels = {'T-Mobile 100 MHz TDD', 'T-Mobile 15 MHz FDD', 'Amarisoft Cell', 'Mosolabs Cell'};

% Constants
enb2sfu_delay = 0.0; % ms
resolutionValues = [360, 540, 720, 1080]; % Resolution values to analyze (removed 270)

% Create arrays to store percentage data
dl_percentages = zeros(length(resolutionValues), length(expCodes));
ul_percentages = zeros(length(resolutionValues), length(expCodes));

% Loop through experiments to calculate percentages
for i = 1:length(expCodes)
    % Load data for each experiment
    [ulData, dlData, ~] = loadWebRTCData_noPHY(expCodes{i}, appCodes{i}, enb2sfu_delay);
    
    % Get resolution data (starting from index 10 as in original code)
    ul_resolution = ulData.file_appout(10:end, 20);
    dl_resolution = dlData.file_appout(10:end, 20);
    
    % Calculate percentages for each resolution value
    for j = 1:length(resolutionValues)
        % Calculate percentage of samples with this resolution
        dl_percentages(j, i) = sum(dl_resolution == resolutionValues(j)) / length(dl_resolution);
        ul_percentages(j, i) = sum(ul_resolution == resolutionValues(j)) / length(ul_resolution);
    end
    
    % Normalize percentages to sum to 1 for each experiment
    dl_sum = sum(dl_percentages(:, i));
    ul_sum = sum(ul_percentages(:, i));
    
    % Avoid division by zero
    if dl_sum > 0
        dl_percentages(:, i) = dl_percentages(:, i) / dl_sum;
    end
    
    if ul_sum > 0
        ul_percentages(:, i) = ul_percentages(:, i) / ul_sum;
    end
end

% Create the stacked bar plot
figure('Position', [100, 100, 1200, 600]);

% Create x-position for bars
% Each experiment has two bars (UL and DL) with a small gap between experiment groups
x = zeros(1, 2*length(expCodes));
for i = 1:length(expCodes)
    x(2*i-1) = 3*i - 1.5; % UL bar
    x(2*i) = 3*i - 0.5;   % DL bar
end

% Bar width
barWidth = 0.8;

% Base colors for UL (blue) and DL (red)
baseColorUL = [0.4, 0.6, 0.9];  % base blue
baseColorDL = [0.9, 0.5, 0.5];  % base red

% Plot stacked bars
hold on;

% Define pattern styles for the different resolutions - using ONLY valid styles
hatchStyles = {'fill', 'single', 'cross', 'single'};  % Valid pattern styles

% Define hatch angles for variation
hatchAngles = [45, 0, 45, 45];  % Different angles for single hatches

% Plot UL bars (blue)
for i = 1:length(expCodes)
    curr_bar = 2*i-1;
    bottom = 0;
    
    for j = 1:length(resolutionValues)
        % Calculate vertices for patch (rectangle)
        xLeft = x(curr_bar) - barWidth/2;
        xRight = x(curr_bar) + barWidth/2;
        yBottom = bottom;
        yTop = bottom + ul_percentages(j, i);
        
        % Create vertices
        xVertices = [xLeft, xRight, xRight, xLeft];
        yVertices = [yBottom, yBottom, yTop, yTop];
        
        % Create the patch object
        p = patch(xVertices, yVertices, baseColorUL, 'EdgeColor', 'blue', 'LineWidth', 1);
        
        % Apply hatchfill2 with different patterns for each resolution
        hatchfill2(p, hatchStyles{j}, 'HatchColor', 'blue', 'HatchAngle', hatchAngles(j), 'HatchDensity', 20, 'HatchLineWidth', 1);

        
        % Update the bottom for next stack
        bottom = yTop;
    end
end

% Plot DL bars (red)
for i = 1:length(expCodes)
    curr_bar = 2*i;
    bottom = 0;
    
    for j = 1:length(resolutionValues)
        % Calculate vertices for patch (rectangle)
        xLeft = x(curr_bar) - barWidth/2;
        xRight = x(curr_bar) + barWidth/2;
        yBottom = bottom;
        yTop = bottom + dl_percentages(j, i);
        
        % Create vertices
        xVertices = [xLeft, xRight, xRight, xLeft];
        yVertices = [yBottom, yBottom, yTop, yTop];
        
        % Create the patch object
        p = patch(xVertices, yVertices, baseColorDL, 'EdgeColor', 'red', 'LineWidth', 1);
        
        % Apply hatchfill2 with different patterns for each resolution
        if dl_percentages(j, i) > 0.01  % Only apply pattern if segment is visible
            hatchfill2(p, hatchStyles{j}, 'HatchColor', 'red', 'HatchAngle', hatchAngles(j), 'HatchDensity', 40, 'HatchLineWidth', 1);
        end
        
        % Update the bottom for next stack
        bottom = yTop;
    end
end

% Add labels and customize plot
xlim([min(x)-barWidth, max(x)+barWidth]);
ylim([0, 1]);
ylabel('Percentage', 'FontSize', 32);
yticks(0:0.25:1);
grid on;

% Set x-axis ticks and labels to only show experiment names
xticks((x(1:2:end) + x(2:2:end))/2);  % Position labels between UL/DL pairs
xticklabels(expLabels);
xtickangle(30);  % Lean labels to fit better

% Create a custom legend for resolutions
legendLabels = cell(1, length(resolutionValues));
legendHandles = zeros(length(resolutionValues), 1);

% Create small invisible axes for legend patches
legendAx = axes('Position', [0.75, 0.7, 0.2, 0.2], 'Visible', 'off');

% Create patches for legend with patterns
for j = 1:length(resolutionValues)
    p = patch(legendAx, [0 1 1 0], [j j+0.8 j+0.8 j], baseColorUL, 'EdgeColor', 'none');
    hatchfill2(p, hatchStyles{j}, 'HatchColor', 'blue', 'HatchAngle', hatchAngles(j), 'HatchDensity', 40, 'HatchLineWidth', 1);
    legendHandles(j) = p;
    legendLabels{j} = [num2str(resolutionValues(j)), 'p'];
end

% Create the legend
legend(legendAx, legendHandles, legendLabels, 'Location', 'northwest', 'FontSize', 24);
axes(legendAx); % Make sure legend is created in the correct axes

% Restore focus to main axes
axes(gca);

% Add title
title('Resolution Distribution Across Experiments', 'FontSize', 32);

% Set all figures to white background
set(0, 'DefaultFigureColor', 'w');
hold off;
% Custom function to add hatch patterns to bars
function addHatchPattern(ax, xData, yData, barWidth)
    for i = 1:length(xData)
        xStart = xData(i) - barWidth/2;
        xEnd = xData(i) + barWidth/2;
        yEnd = yData(i);
        
        % Add diagonal lines as hatch pattern
        step = 2; % Step size for pattern density
        for j = 0:step:yEnd
            % Diagonal line from bottom left to top right
            x = [xStart, xStart + min(barWidth, yEnd - j)];
            y = [j, j + min(barWidth, yEnd - j)];
            plot(ax, x, y, 'k-', 'LineWidth', 1);
            
            % Diagonal line from bottom right to top left
            x = [xEnd, xEnd - min(barWidth, yEnd - j)];
            y = [j, j + min(barWidth, yEnd - j)];
            plot(ax, x, y, 'k-', 'LineWidth', 1);
        end
    end
end

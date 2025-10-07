function plotPhyBSR(data)
    % Process data
    valid_bsr = data.bsrhigh_physync > 0;
    ts_bsr = data.ts_physync(valid_bsr);
    bsr_low_array = data.bsrlow_physync(valid_bsr)/1e6;
    bsr_high_array = data.bsrhigh_physync(valid_bsr)/1e6;
    ts_bsr = (ts_bsr - min(data.ts_physync))/1000;

    % Create figure
    hold on;
    for i = 1:length(ts_bsr)
        plot([ts_bsr(i) ts_bsr(i)], ...
             [bsr_low_array(i) bsr_high_array(i)], ...
             'g-', 'LineWidth', 1)
    end
    xlabel('Time (s)');
    ylabel('BSR (MBits)');
    title('UL BSR');

    % Add grid
    grid on;    
end
function tbs = calc_5g_tbs(nPRB, MCS_i, nlayers, nSymbol, table)

    Nsubcarr_PerPRB = 12;
    NRE_DMRS = 3; % 3 DMRS symbols
    NRE_PerPRB = Nsubcarr_PerPRB * nSymbol - NRE_DMRS * 8;

    % Table 1 for PDSCH
    MCSmod_tab1 = {'QPSK', 'QPSK', 'QPSK', 'QPSK', 'QPSK', 'QPSK', 'QPSK', 'QPSK', 'QPSK', 'QPSK', ...
        '16QAM', '16QAM', '16QAM', '16QAM', '16QAM', '16QAM', '16QAM', '64QAM', '64QAM', '64QAM', ...
        '64QAM', '64QAM', '64QAM', '64QAM', '64QAM', '64QAM', '64QAM', '64QAM', '64QAM'};
    MCStcr_tab1 = [120, 157, 193, 251, 308, 379, 449, 526, 602, 679, 340, 378, 434, 490, 553, 616, ...
        658, 438, 466, 517, 567, 616, 666, 719, 772, 822, 873, 910, 948] / 1024;    

    % Table 2 for PDSCH
    MCSmod_tab2 = {'QPSK', 'QPSK', 'QPSK', 'QPSK', 'QPSK', '16QAM', '16QAM', '16QAM', '16QAM', '16QAM', ...
        '16QAM', '64QAM', '64QAM', '64QAM', '64QAM', '64QAM', '64QAM', '64QAM', '64QAM', '64QAM', '256QAM', ...
        '256QAM', '256QAM', '256QAM', '256QAM', '256QAM', '256QAM', '256QAM'};
    MCStcr_tab2 = [120, 193, 308, 449, 602, 378, 434, 490, 553, 616, 658, 466, 517, 567, 616, 666, ...
        719, 772, 822, 873, 682.5, 711, 754, 797, 841, 885, 916.5, 948] / 1024;       

    % Table 3 for PDSCH
    MCSmod_tab3 = {'QPSK', 'QPSK', 'QPSK', 'QPSK', 'QPSK', 'QPSK', 'QPSK', 'QPSK', 'QPSK', 'QPSK', ...
        'QPSK', 'QPSK', 'QPSK', 'QPSK', 'QPSK', '16QAM', '16QAM', '16QAM', '16QAM', '16QAM', '16QAM', ...
        '64QAM', '64QAM', '64QAM', '64QAM', '64QAM', '64QAM', '64QAM', '64QAM'};
    MCStcr_tab3 = [30, 40, 50, 64, 78, 99, 120, 157, 193, 251, 308, 379, 449, 526, 602, 340, ...
        378, 434, 490, 553, 616, 438, 466, 517, 567, 616, 666, 719, 772] / 1024;

    % Select the appropriate MCS table based on the 'table' argument
    if table == 1
        MCSmod = MCSmod_tab1;
        MCStcr = MCStcr_tab1;
    elseif table == 2
        MCSmod = MCSmod_tab2;
        MCStcr = MCStcr_tab2;
    elseif table == 3
        MCSmod = MCSmod_tab3;
        MCStcr = MCStcr_tab3;
    else
        error('Invalid table selection. The table argument must be 1, 2, or 3.');
    end

    % Check if MCS_i is within the range
    if MCS_i >= length(MCStcr)
        tbs = 0;
        MCS.tcr = 0;
    else
        MCS.mod = MCSmod{MCS_i + 1};
        MCS.tcr = MCStcr(MCS_i + 1);

        tbs = nrTBS(MCS.mod, nlayers, nPRB, NRE_PerPRB, MCS.tcr);
    end
end

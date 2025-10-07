function [tbs] = calc_4g_tbs(imcs,nprb,linktype)

    if nprb==0
        tbs = 0;
    else
        if imcs>28
            imcs = 0;
        end
        if linktype=='D'
            [itbs, mod, rv] = lteMCS(imcs,'PDSCH');
        elseif linktype=='U'
            [itbs, mod, rv] = lteMCS(imcs,'PUSCH');
        end
    
        tbs = double(lteTBS(nprb,itbs));
        % throughput = tbs * 0.001; % Mbps
    end

end
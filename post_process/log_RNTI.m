expCode = '0625_1';
rntisAboveThreshold = [17024];
rntiPath = ['../zoom_data/data_exp' expCode '/UL_rnti_' expCode '.mat'];
save(rntiPath, "rntisAboveThreshold");

% 0624_1: 17025
% 0625_1: 17024
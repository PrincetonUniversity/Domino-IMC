import numpy as np
import scipy.io as sio
import argparse

keys = ['time_dl_10mcs', 'time_dl_50mcs', 'time_dl_90mcs', 'time_dl_bitrate',
        'time_ul_10mcs', 'time_ul_50mcs', 'time_ul_90mcs',
        'time_dl_out_framerate', 'time_dl_in_framerate', 'time_dl_gcc_outstanding_bytes', 
        'time_dl_gcc_window_bytes', 'time_dl_jb_delay_per_frame', 
        'time_dl_jb_min_per_frame', 'time_dl_jb_target_per_frame', 
        'time_ul_jb_delay_per_frame', 
        'time_ul_jb_min_per_frame', 'time_ul_jb_target_per_frame',
        'time_dl_loss_based_rate', 'time_dl_modified_trend', 'time_dl_numeric_states', 
        'time_dl_overuse', 'time_dl_pkt', 'time_ul_overuse', 
        'time_dl_pkt_delay_server', 'time_dl_pkt_delay_ue', 'time_dl_prb_interest',
        'time_dl_prb_others', 'time_dl_pushback', 'time_dl_in_res', 'time_dl_out_res', 'time_dl_tbs',
        'time_dl_tbs_effective', 'time_dl_thresholds', 'time_ul_bitrate', 
        'time_ul_out_framerate', 'time_ul_in_framerate', 'time_ul_gcc_outstanding_bytes', 'time_ul_gcc_window_bytes',
        'time_ul_loss_based_rate', 'time_ul_modified_trend', 'time_ul_numeric_states', 
        'time_ul_pkt', 'time_ul_pkt_delay_server', 'time_ul_pkt_delay_ue', 
        'time_ul_prb_interest', 'time_ul_prb_others', 
        'time_ul_pushback', 'time_ul_out_res', 'time_ul_in_res', 'time_ul_rnti', 'time_ul_tbs', 
        'time_ul_tbs_effective', 'time_ul_thresholds', 'time_ul_1tx', 'time_ul_rtx',
        'time_dl_1tx', 'time_dl_rtx']

def load_all_data(keys, datapath):
  feature_dict = {}
  for i in range(len(keys)):
    feature_dict[keys[i]] = sio.loadmat(datapath + keys[i] + '.mat')[keys[i]]
  return feature_dict

if __name__ == "__main__":
  parser = argparse.ArgumentParser()
  parser.add_argument('-d', '--directory', help="directory of the data")
  args = parser.parse_args()

  features = load_all_data(keys, args.directory)
  print(features)
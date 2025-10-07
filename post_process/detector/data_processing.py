from utils import *
from data_loader import *
import numpy as np

# Causal chain 1: 
#   5G DL cross traffic -> 5G DL congestion -> 
#   pkt sent bytes exceeds 5G DL cap. -> DL delay builds up -> 
#   DL ACKs backlogged -> UL un-ACKed outstanding bytes increase -> 
#   Pushback rate drops -> frame rate drops

# Causal chain 2:
#   RNTI change -> Delay builds up -> 
#   1. Outstanding Bytes accumulates -> pushback rate drops 
#   2. GCC detects overuse -> target rate drops -> Framerate drops

''' Features: '''
''' Consequences: ''' 
## 0. bool: does UE inbound (DL) fps drops?
## 1. bool: does server inbound (UL) fps drops?
## 2. bool: does UE outbound (UL) framerate drops?
## 3. bool: does server outbound (DL) framerate drops?
## 4. bool: does UE outbound (UL) resolution drops?
## 5. bool: does server outbound (DL) resolution drops?
''' Intermediate States for GCC/WebRTC: '''
## 6. bool: does UE jitter buffer (DL) drain?
## 7. bool: does server jitter buffer (UL) drain?
## 8. bool: does UE target bit rate (UL) drop?
## 9. bool: does server target bit rate (DL) drop?
## 10. bool: does UE gcc detects overuse (UL)?
## 11. bool: does server gcc detects overuse (DL)?
## 12. bool: does UE pushback rate (UL) drop? 
## 13. bool: does server pushback rate (DL) drop?
## 14. bool: does UE congestion window (UL) full?
## 15. bool: does server congestion window (DL) full?
## 16. bool: does UE outstanding bytes (UL) increase?
## 17. bool: does server outstanding bytes (DL) increase?
## 34. bool: does UL pushback rate is not equal to target bit rate?
## 35. bool: does DL pushback rate is not equal to target bit rate?
''' Center: '''
## 18. bool: does DL delay increase?
## 19. bool: does UL delay increase?
''' 5G States: '''
## 20: bool: does UL/DL rnti change?
## 21. bool: does UL allocated TBS drop?
## 22. bool: does DL allocated TBS drop? 
## 23. bool: does UL app bitrate > UL rate?
## 24. bool: does DL app bitrate > DL rate?
## 25. bool: are there other DL UE traffic?
## 26. bool: are there other UL UE traffic?
## 27. bool: is the UL channel bad?
## 28. bool: is the DL channel bad? 
## 29. bool: is there UL scheduling delay?
## 30. bool: are there UL HARQ retransmissions?
## 31. bool: are there DL HARQ retransmissions?
## 32. bool: are there UL RLC retransmissions?
## 33. bool: are there DL RLC retransmissions?


def get_window(data, start_time, end_time):
  # find the start_time index
  # print(data.shape)
  # print(start_time, end_time)
  start_idx = binary_search(data[0, :], start_time, 0, data[0, :].shape[0]-1)
  end_idx = binary_search(data[0, :], end_time, 0, data[0, :].shape[0]-1)
  # print(data[0, start_idx], data[0, end_idx])
  # print(data[1, start_idx], data[1, end_idx])

  return data[1, start_idx:end_idx]

def extract_window(data_dict, start_time, end_time):
  # features = np.zeros()
  windows = {}
  for (i, key) in enumerate(keys):
    data_array = data_dict[key]
    # print(i, key)
    windows[key] = get_window(data_array, start_time, end_time)
  return windows

def extract_feature(window):
  feature = np.zeros(36)

  ''' Consequences: ''' 
  ## 0. bool: does UE inbound (DL) fps drops?
  try:
    max_framerate = np.max(window['time_dl_in_framerate'])
    min_framerate = np.min(window['time_dl_in_framerate'])
    if ( min_framerate < 25 and max_framerate > 27):
      feature[0] = 1
  except:
    print("no data for feature 0")

  ## 1. bool: does server inbound (UL) fps drops?
  try:
    max_framerate = np.max(window['time_ul_in_framerate'])
    min_framerate = np.min(window['time_ul_in_framerate'])
    if ( min_framerate < 25 and max_framerate > 27):
      feature[1] = 1
  except:
    print("no data for feature 1")

  ## 2. bool: does UE outbound (UL) framerate drops?
  try:
    max_framerate = np.max(window['time_ul_out_framerate'])
    min_framerate = np.min(window['time_ul_out_framerate'])
    if ( min_framerate < 25 and max_framerate > 27):
      feature[2] = 1
  except:
    print("no data for feature 2")

  ## 3. bool: does server outbound (DL) framerate drops?
  try:
    max_framerate = np.max(window['time_dl_out_framerate'])
    min_framerate = np.min(window['time_dl_out_framerate'])
    if ( min_framerate < 25 and max_framerate > 27):
      feature[3] = 1
  except:
    print("no data for feature 3")

  ## 4. bool: does UE outbound (UL) resolution drops?
  try:
    resolution_diff = window['time_ul_out_res'][1:] - window['time_ul_out_res'][:-1]
    for i in range(resolution_diff.shape[0]):
      if resolution_diff[i] < 0:
        feature[4] = 1
        break
  except:
    print("no data for feature 4")

  ## 5. bool: does server outbound (DL) resolution drops?
  try:
    resolution_diff = window['time_dl_out_res'][1:] - window['time_dl_out_res'][:-1]
    for i in range(resolution_diff.shape[0]):
      if resolution_diff[i] < 0:
        feature[5] = 1
        break
  except:
    print("no data for feature 5")

  ''' Intermediate States for GCC/WebRTC: '''
  ## 6. bool: does UE jitter buffer (DL) drain?
  try:
    dl_jb = window['time_dl_jb_delay_per_frame'] < 50
    if (dl_jb.shape[0] > 1):
      feature[6] = 1
  except:
    print('no data for feature 6')

  ## 7. bool: does server jitter buffer (UL) drain?
  try:
    ul_jb = window['time_ul_jb_delay_per_frame'] < 50
    if (ul_jb.shape[0] > 1):
      feature[7] = 1
  except:
    print('no data for feature 7')

  ## 8. bool: does UE target bit rate (UL) drop?
  try:
    ul_target_br_diff = window['time_ul_loss_based_rate'][1:] - \
      window['time_ul_loss_based_rate'][:-1]
    for i in range(ul_target_br_diff.shape[0]):
      if (ul_target_br_diff[i] < 0):
        feature[8] = 1
        break
  except:
    print('no data for feature 8')
  
  ## 9. bool: does server target bit rate (DL) drop?
  try:
    dl_target_br_diff = window['time_dl_loss_based_rate'][1:] - \
      window['time_dl_loss_based_rate'][:-1]
    for i in range(dl_target_br_diff.shape[0]):
      if (dl_target_br_diff[i] < 0):
        feature[9] = 1
        break
  except:
    print('no data for feature 9')

  ## 10. bool: does UE gcc detects overuse (UL)?
  try:
    overuse = window['time_ul_overuse']
    for i in range(overuse.shape[0]):
      if (overuse[i] > 0):
        feature[10] = 1
        break
  except:
    print('no data for feature 10')

  ## 11. bool: does server gcc detects overuse (DL)?
  try:
    overuse = window['time_dl_overuse']
    for i in range(overuse.shape[0]):
      if (overuse[i] > 0):
        feature[11] = 1
        break
  except:
    print('no data for feature 11')

  ## 12. bool: does UE pushback rate (UL) drop? 
  try:
    pushback_diff = window['time_ul_pushback'][1:] - window['time_ul_pushback'][:-1]
    for i in range(pushback_diff.shape[0]):
      if (pushback_diff[i] < 0):
        feature[12] = 1
        break
  except:
    print('no data for feature 12')

  ## 13. bool: does server pushback rate (DL) drop?
  try:
    pushback_diff = window['time_dl_pushback'][1:] - window['time_dl_pushback'][:-1]
    for i in range(pushback_diff.shape[0]):
      if (pushback_diff[i] < 0):
        feature[13] = 1
        break
  except:
    print('no data for feature 13')

  ## 14. bool: does UE congestion window (UL) full?
  try:
    fill_rate = window['time_ul_gcc_outstanding_bytes'] / \
      window['time_ul_gcc_window_bytes']
    for i in range(fill_rate.shape[0]):
      if (fill_rate[i] >= 1):
        feature[14] = 1
        break
  except:
    print('no data for feature 14')

  # 15. bool: does server congestion window (DL) full?
  try:
    fill_rate = window['time_dl_gcc_outstanding_bytes'] / \
      window['time_dl_gcc_window_bytes']
    for i in range(fill_rate.shape[0]):
      if (fill_rate[i] >= 1):
        feature[15] = 1
        break
  except:
    print('no data for feature 15')

  ## 16. bool: does UE outstanding bytes (UL) increase?
  try:
    outstanding_diff = window['time_ul_gcc_outstanding_bytes'][1:] - \
      window['time_ul_gcc_outstanding_bytes'][:-1]
    for i in range(outstanding_diff.shape[0]):
      if (outstanding_diff[i] > 0):
        feature[16] = 1
        break
  except:
    print('no data for feature 16')

  ## 17. bool: does server outstanding bytes (DL) increase?
  try:
    outstanding_diff = window['time_dl_gcc_outstanding_bytes'][1:] - \
      window['time_dl_gcc_outstanding_bytes'][:-1]
    for i in range(outstanding_diff.shape[0]):
      if (outstanding_diff[i] > 0):
        feature[17] = 1
        break
  except:
    print('no data for feature 17')

  ''' Center: '''
  ## 18. bool: does DL delay increase?
  try:
    delay_diff = window['time_dl_pkt_delay_ue'][1:] - window['time_dl_pkt_delay_ue'][:-1]
    for i in range(delay_diff.shape[0]):
      if (delay_diff[i] > 0 and np.max(window['time_dl_pkt_delay_ue']) > 0.08) :
        feature[18] = 1
        break
  except:
    print('no data for feature 18')

  ## 19. bool: does UL delay increase?
  try:
    delay_diff = window['time_ul_pkt_delay_ue'][1:] - window['time_ul_pkt_delay_ue'][:-1]
    for i in range(delay_diff.shape[0]):
      if (delay_diff[i] > 0 and np.max(window['time_ul_pkt_delay_ue']) > 0.08) :
        feature[19] = 1
        break
  except:
    print('no data for feature 19')

  ''' 5G States: '''
  ## 20: bool: does UL/DL rnti change?
  if (window['time_ul_rnti'].shape[0] > 0):
    rnti_0 = window['time_ul_rnti'][0]
    for i in range(len(window['time_ul_rnti'])):
      if (window['time_ul_rnti'][i] != 0 and window['time_ul_rnti'][i] != rnti_0):
        feature[20] = 1
        break;
  else:
    print('no data for feature 20')

  ## 21. bool: does UL allocated TBS drop?
  try:
    max_tbs = np.max(window['time_ul_tbs'])
    min_tbs = np.min(window['time_ul_tbs'])
    if (min_tbs / max_tbs < 0.8):
      feature[21] = 1
  except:
    feature[21] = 1
    print('np data fro feature 21')

  ## 22. bool: does DL allocated TBS drop? 
  try:
    max_tbs = np.max(window['time_dl_tbs'])
    min_tbs = np.min(window['time_dl_tbs'])
    if (min_tbs / max_tbs < 0.8):
      feature[22] = 1
  except:
    feature[22] = 1
    print('np data fro feature 21')


  ## 23. bool: does UL app bitrate > UL rate?
  diff = window['time_ul_pkt'] - window['time_ul_tbs']
  if (np.sum(diff[diff > 0]) > 0.9 * np.sum(abs(diff[diff<0]))):
    feature[23] = 1

  ## 24. bool: does DL app bitrate > DL rate?
  diff = window['time_dl_pkt'] - window['time_dl_tbs']
  if (np.sum(diff[diff > 0]) > 0.9 * np.sum(abs(diff[diff<0]))):
    feature[24] = 1

  ## 25. bool: are there other DL UE traffic?
  dl_prb_interest = window['time_dl_prb_interest']
  dl_prb_others = window['time_dl_prb_others']
  if (np.sum(dl_prb_others) / np.sum(dl_prb_interest) > 0.2):
    feature[25] = 1

  ## 26. bool: are there other UL UE traffic?
  dl_prb_interest = window['time_ul_prb_interest']
  dl_prb_others = window['time_ul_prb_others']
  if (np.sum(dl_prb_others) / np.sum(dl_prb_interest) > 0.2):
    feature[26] = 1

  ## 27. bool: is the UL channel bad?
  ul_mcs_50 = window['time_ul_50mcs']
  counter = 0
  for i in ul_mcs_50:
    if (i < 10):
      counter += 1
    if (counter > 5):
      feature[27] = 1
      break

  ## 28. bool: is the DL channel bad? 
  dl_mcs_50 = window['time_dl_50mcs']
  counter = 0
  for i in dl_mcs_50:
    if (i < 10):
      counter += 1
    if (counter > 5):
      feature[28] = 1
      break

  ## 29. bool: is there UL scheduling delay?
  feature[29] = 1

  ## 30. bool: are there UL HARQ retransmissions?
  ul_harq = window['time_ul_rtx']
  counter = 0
  for i in ul_harq:
    if (i > 3):
      counter += 1
    if (counter > 10):
      feature[30] = 1
      break

  ## 31. bool: are there DL HARQ retransmissions?
  dl_harq = window['time_dl_rtx']
  counter = 0
  for i in dl_harq:
    if (i > 3):
      counter += 1
    if (counter > 10):
      feature[31] = 1
      break

  ## 32. bool: are there UL RLC retransmissions?
  feature[32] = 0
  ## 33. bool: are there DL RLC retransmissions?
  feature[33] = 0
  ## 34. bool: does UL pushback rate is not equal to target bit rate?
  pb_target = window['time_ul_pushback'] - window['time_ul_loss_based_rate']
  # print(pb_target)
  if (sum(pb_target) != 0):
    feature[34] = 1
  
  ## 35. bool: does DL pushback rate is not equal to target bit rate?
  pb_target = window['time_dl_pushback'] - window['time_dl_loss_based_rate']
  # print(pb_target)
  if (sum(pb_target) != 0):
    feature[35] = 1

  return feature
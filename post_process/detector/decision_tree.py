from data_loader import *
from utils import *
from data_processing import *
import argparse
import matplotlib.pyplot as plt
from generated_chain_search import *
import pandas as pd

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

feature_to_str = {0: "UE inbound FPS drops", 
                  1: "Server inbound FPS drops",
                  12: "UE pushback rate drops",
                  13: "Server pushback rate drops",
                  8: "UE target bitrate drops",
                  9: "Server target bitrate drops",
                  20: "RNTI changes",
                  25: "DL cross traffic",
                  26: "UL cross traffic",
                  27: "UL channel is bad",
                  28: "DL channel is bad",
                  29: "UL scheduling delay",
                  30: "UL HARQ retx",
                  31: "DL HARQ retx",
                  32: "UL RLC retx",
                  33: "DL RLC retx",
                  18: "DL Delay Up",
                  19: "UL Delay Up"}

# in seconds
WINDOW_LEN = 5
STEP_LEN = 0.5

def back_trace(features):
  consequences = set()
  causes = set()
  source_to_sink = ''

  # UE inbound (DL) fps drops
  if (feature[0]):
    consequences.add(0)
    # jitter buffer drains?
    if (feature[6]):
      # DL delay up?
      if (feature[18]):          
        # RNTI changes?
        if (feature[20]):
          # cause RNTI change
          causes.add(20)
          source_to_sink += '6-1,'
        # UL/DL app rate > TBS rate
        if (feature[23] or feature[24]):
          # DL channel bad
          if (feature[28]):
            causes.add(28)
            source_to_sink += '1-1,'
          # DL UE cross traffic
          if (feature[25]):
            causes.add(25)
            source_to_sink += '2-1,'
        # DL HARQ retx
        if (feature[31]):
          causes.add(31)
          source_to_sink += '4-1,'

  # Server inbound (UL) fps drops
  if (feature[1]):
    consequences.add(1)
    # jitter buffer drains?
    if (feature[7]):
      # UL delay up?
      if (feature[19]):
        # RNTI changes?
        if (feature[20]):
          # cause RNTI change
          causes.add(20)
          source_to_sink += '6-1,'
        # UL/DL app rate > TBS rate
        if (feature[23] or feature[24]):
          # UL channel bad
          if (feature[27]):
            causes.add(27)
            source_to_sink += '1-1,'
          # UL UE cross traffic
          if (feature[26]):
            causes.add(26)
            source_to_sink += '2-1,'
        # UL scheduling delay
        causes.add(29)
        source_to_sink += '3-1,'
        # UL HARQ retx
        if (feature[30]):
          causes.add(30)
          source_to_sink += '4-1,'

  # UE UL pushback bit rate drop
  if (feature[12] and (feature[34] or feature[35])):
      consequences.add(12)
      # check DL direction
      if (feature[18]):
        # RNTI changes?
        if (feature[20]):
          # cause RNTI change
          causes.add(20)
          source_to_sink += '6-3,'
        # UL/DL app rate > TBS rate
        if (feature[23] or feature[24]):
          # DL channel bad
          if (feature[28]):
            causes.add(28)
            source_to_sink += '1-3,'
          # DL UE cross traffic
          if (feature[25]):
            causes.add(25)
            source_to_sink += '2-3,'
        # DL HARQ retx
        if (feature[31]):
          causes.add(31)
          source_to_sink += '4-3,'
      # Check UL direction
      if (feature[19]):
        # RNTI changes?
        if (feature[20]):
          # cause RNTI change
          causes.add(20)
          source_to_sink += '6-3,'
        # UL/DL app rate > TBS rate
        if (feature[23] or feature[24]):
          # UL channel bad
          if (feature[27]):
            causes.add(27)
            source_to_sink += '1-3,'
          # UL UE cross traffic
          if (feature[26]):
            causes.add(26)
            source_to_sink += '2-3,'
        # UL scheduling delay
        causes.add(29)
        source_to_sink += '3-3,'
        # UL HARQ retx
        if (feature[30]):
          causes.add(30)
          source_to_sink += '4-3,'

  # UE target bitrate drops
  if (feature[8] and not (feature[34] or feature[35])):
    consequences.add(8)
    # check UL direction
    if (feature[19]):
      # RNTI changes?
      if (feature[20]):
        # cause RNTI change
        causes.add(20)
        source_to_sink += '6-2,'
      # UL/DL app rate > TBS rate
      if (feature[23] or feature[24]):
        # UL channel bad
        if (feature[27]):
          causes.add(27)
          source_to_sink += '1-2,'
        # UL UE cross traffic
        if (feature[26]):
          causes.add(26)
          source_to_sink += '2-2,'
      # UL scheduling delay
      causes.add(29)
      source_to_sink += '3-2,'
      # UL HARQ retx
      if (feature[30]):
        causes.add(30)
        source_to_sink += '4-2,'

  # Server DL pushback rate drop
  if (feature[13] and (feature[34] or feature[35])):
    consequences.add(13)
    # print("bidirectional detected!!!")
    # check UL direction
    if (feature[19]):
      # RNTI changes?
      if (feature[20]):
        # cause RNTI change
        causes.add(20)
        source_to_sink += '6-3,'
      # UL/DL app rate > TBS rate
      if (feature[23] or feature[24]):
        # UL channel bad
        if (feature[27]):
          causes.add(27)
          source_to_sink += '1-3,'
        # UL UE cross traffic
        if (feature[26]):
          causes.add(26)
          source_to_sink += '2-3,'
      # UL scheduling delay
      causes.add(29)
      source_to_sink += '3-3,'
      # UL HARQ retx
      if (feature[30]):
        causes.add(30)
        source_to_sink += '4-3,'
    # check DL direction
    if (feature[18]):
      # RNTI changes?
      if (feature[20]):
        # cause RNTI change
        causes.add(20)
        source_to_sink += '6-3,'
      # UL/DL app rate > TBS rate
      if (feature[23] or feature[24]):
        # DL channel bad
        if (feature[28]):
          causes.add(28)
          source_to_sink += '1-3,'
        # DL UE cross traffic
        if (feature[25]):
          causes.add(25)
          source_to_sink += '2-3,'
      # DL HARQ retx
      if (feature[31]):
        causes.add(31)
        source_to_sink += '4-3,'
    # pushback rate is equal to the target bit rate, single direction chain
  if (feature[9] and not (feature[34] or feature[35])):
    consequences.add(9)
    # check DL direction
    if (feature[18]):
      # RNTI changes?
      if (feature[20]):
        # cause RNTI change
        causes.add(20)
        source_to_sink += '6-2,'
      # UL/DL app rate > TBS rate
      if (feature[23] or feature[24]):
        # DL channel bad
        if (feature[28]):
          causes.add(28)
          source_to_sink += '1-2,'
        # DL UE cross traffic
        if (feature[25]):
          causes.add(25)
          source_to_sink += '2-2,'
      # DL HARQ retx
      if (feature[31]):
        causes.add(31)
        source_to_sink += '4-2,'
  return [consequences, causes, source_to_sink]
  
def detect_fast_recovery(window, feature, is_dl):
  target_bitrate = []
  if (is_dl):
    target_bitrate = window['time_dl_loss_based_rate']
  else:
    target_bitrate = window['time_ul_loss_based_rate']
  rate_diff = target_bitrate[1:] - target_bitrate[:-1]
  rise = np.max(rate_diff)
  rise_idx = np.argmax(rate_diff)
  drop = np.min(rate_diff)
  drop_idx = np.argmin(rate_diff)
  if (rise >= abs(drop)*0.9 and rise_idx < drop_idx):
    return True
  else:
    return False    


if __name__ == '__main__':
  parser = argparse.ArgumentParser()
  parser.add_argument('-d', '--directory', help="directory of the data")
  args = parser.parse_args()

  data_dict = load_all_data(keys, args.directory)

  duration = []
  for key in keys:
    duration.append(data_dict[key][0, -1])
    # print('{} with length {}'.format(key, data_dict[key].shape))
  max_time = np.min(duration)
  # print(max_time)

  # plt.figure()
  # plt.plot(data_dict['time_ul_prb_others'][1, :])
  # plt.plot(data_dict['time_dl_prb_others'][1, :])
  # plt.show()

  # plt.figure()
  # plt.plot(data_dict['time_dl_tbs'][1, :])
  # plt.plot(data_dict['time_dl_pkt'][1, :])
  # plt.show()

  start_time = 0
  end_time = start_time + WINDOW_LEN

  # Initialize the results dict
  results = {"Start Time": [],
             "End Time": []}
  for key in feature_to_str.keys():
    results[feature_to_str[key]] = []
  results["Fast Recovery"] = []
  results["Chains"] = []
  
  while (True):
    if (end_time >= max_time):
      break
    window = extract_window(data_dict, start_time, end_time)
    feature = extract_feature(window)
    result = back_trace(feature)
    # print("start time: {}, end_time: {}".format(start_time, end_time))
    if (len(result[0]) != 0):
      for key in results.keys():
        if (key != 'Chains'):
          results[key].append(0)
      results["Start Time"][-1] = start_time
      results["End Time"][-1] = end_time
      consequence_list = []
      cause_list = []
      for i in result[0]:
        consequence_list.append(feature_to_str[i])
        results[feature_to_str[i]][-1] = 1;
      for i in result[1]:
        cause_list.append(feature_to_str[i])
        results[feature_to_str[i]][-1] = 1;
      is_fast_recovery = False
      if (1 in result[0] or 2 in result[0] or 4 in result[0]):
        # uplink target bit rate
        is_fast_recovery = detect_fast_recovery(window, feature, is_dl=False)
      if (0 in result[0] or 3 in result[0] or 5 in result[0]):
        # downlink target bit rate
        is_fast_recovery = detect_fast_recovery(window, feature, is_dl=True)
      if(is_fast_recovery):
        results["Fast Recovery"][-1] = 1
      results['Chains'].append(result[2])
      # print("    {} caused by {}, fast recovery {}".format(consequence_list, 
      #   cause_list, is_fast_recovery))
    
    start_time += STEP_LEN
    end_time += STEP_LEN

  # Save DataFrame to CSV
  df = pd.DataFrame(results)
  df.to_csv(args.directory + 'events_detection.csv', index=False)
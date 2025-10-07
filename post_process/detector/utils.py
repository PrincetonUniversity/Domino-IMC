import numpy as np

def binary_search(time_series, time, l, r):
  if (time_series[l] == time):
    return l
  if (time_series[r] == time):
    return r
  if (r - l == 1 and time_series[l] <= time and time_series[r] >= time):
    return l 
  if (r <= l):
    return l
  
  mid = int(r / 2 + l / 2)
  # print('l: {}, r: {}, mid: {}'.format(l, r, mid))
  if (time_series[mid] == time):
    return mid
  elif (time_series[mid] < time):
    return binary_search(time_series, time, mid+1, r)
  else:
    return binary_search(time_series, time, l, mid-1)
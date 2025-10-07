import numpy as np
import matplotlib.pyplot as plt
import pandas as pd

from matplotlib.colors import LogNorm
import matplotlib.font_manager as fm
from matplotlib import rc
import sys
import subprocess
from matplotlib.ticker import FormatStrFormatter
from matplotlib.lines import Line2D
from matplotlib.patches import Rectangle

''' Data Loading '''
commercial_id = ['0416', '0417', '0418', '0419', '0422', '0423'] #
private_id = ['0420', '0421', '0426'] #
data_path = "~/Documents/data/athena/"
results_chain_commercial = np.zeros((3,7))
results_chain_private = np.zeros((3,7))

results_chain_commercial[2, 6] = 3

#[r"Poor Channel", r"Cross Traffic", r"UL Scheduling", r"HARQ ReTX", r"RLC ReTX", r"RRC State"]
total_count_commercial = np.zeros([3])
total_count_private = np.zeros([3])


for c_cell in commercial_id:
  file_name = data_path + "data_exp" + c_cell + '/detection_data/events_detection.csv'
  data = pd.read_csv(file_name)

  previous_row = []
  for index, row in data.iterrows():
    # print(row)
    if (index == 0):
      total_count_commercial[0] += row['UE inbound FPS drops']
      total_count_commercial[0] += row['Server inbound FPS drops']
      total_count_commercial[1] += row['UE target bitrate drops']
      total_count_commercial[1] += row['Server target bitrate drops']
      total_count_commercial[2] += row['UE pushback rate drops']
      total_count_commercial[2] += row['Server pushback rate drops']
      strings = row["Chains"]
      if type(strings) == type('a'):
        chains = strings.split(',')
        for chain in chains:
          if (len(chain) > 2):
            results_chain_commercial[int(chain.split('-')[1])-1, int(chain.split('-')[0])-1] += 1
      previous_row = row 
    else:
      if (row[0] - previous_row[0] == 0.5 and (row[2:] == previous_row[2:]).all()):
        previous_row = row
        continue
      else:
        total_count_commercial[0] += row['UE inbound FPS drops']
        total_count_commercial[0] += row['Server inbound FPS drops']
        total_count_commercial[1] += row['UE target bitrate drops']
        total_count_commercial[1] += row['Server target bitrate drops']
        total_count_commercial[2] += row['UE pushback rate drops']
        total_count_commercial[2] += row['Server pushback rate drops']
        strings = row["Chains"]
        if type(strings) == type('a'):
          chains = strings.split(',')
          for chain in chains:
            if (len(chain) > 2):
              results_chain_commercial[int(chain.split('-')[1])-1, int(chain.split('-')[0])-1] += 1
        previous_row = row 

for p_cell in private_id:
  file_name = data_path + "data_exp" + p_cell + '/detection_data/events_detection.csv'
  data = pd.read_csv(file_name)

  previous_row = []
  for index, row in data.iterrows():
    # print(row)
    if (index == 0):
      total_count_private[0] += row['UE inbound FPS drops']
      total_count_private[0] += row['Server inbound FPS drops']
      total_count_private[1] += row['UE target bitrate drops']
      total_count_private[1] += row['Server target bitrate drops']
      total_count_private[2] += row['UE pushback rate drops']
      total_count_private[2] += row['Server pushback rate drops']
      strings = row["Chains"]
      if type(strings) == type('a'):
        chains = strings.split(',')
        for chain in chains:
          if (len(chain) > 2):
            results_chain_private[int(chain.split('-')[1])-1, int(chain.split('-')[0])-1] += 1
      previous_row = row 
    else:
      if (row[0] - previous_row[0] == 0.5 and (row[2:] == previous_row[2:]).all()):
        previous_row = row
        continue
      else:
        total_count_private[0] += row['UE inbound FPS drops']
        total_count_private[0] += row['Server inbound FPS drops']
        total_count_private[1] += row['UE target bitrate drops']
        total_count_private[1] += row['Server target bitrate drops']
        total_count_private[2] += row['UE pushback rate drops']
        total_count_private[2] += row['Server pushback rate drops']
        strings = row["Chains"]
        if type(strings) == type('a'):
          chains = strings.split(',')
          for chain in chains:
            if (len(chain) > 2):
              results_chain_private[int(chain.split('-')[1])-1, int(chain.split('-')[0])-1] += 1
        previous_row = row 

results_chain_private[0, 4] += 1
results_chain_private[1, 4] += 2
results_chain_private[2, 4] += 2

''' Plot '''
# fig,ax1 = plt.subplots()
FONT_SIZE = 35
# fm._rebuild()
plt.rcParams["text.usetex"] = True
plt.rcParams["font.weight"] = "light"
plt.rcParams["font.family"] = "Times"
plt.rcParams["font.size"] = FONT_SIZE


ggplot2_sets = [ [55, 126, 184], [228, 26, 28], [152, 78, 163], [0, 184, 229], \
    [247, 129, 191],  [77, 175, 74], [166, 86, 40], [255, 127, 0], [255, 217, 47],\
    [100, 100, 100], [0, 0, 0]] 

ggplot2_sets = list(map(lambda  x: [y / 255.0 for y in x], ggplot2_sets))

c1 = ggplot2_sets[0]
c2 = ggplot2_sets[1]
c3 = ggplot2_sets[2]
c4 = ggplot2_sets[3]
c5 = ggplot2_sets[4]

fig = plt.figure(figsize=(10, 6))
ax1 = fig.add_subplot(111)
ax1.grid(True, color='lightgrey', linestyle='--', linewidth=0.8, dash_capstyle='butt')
ax1.set_axisbelow(True)

# ax1.spines['top'].set_linestyle((0, (4, 4)))
# ax1.spines['right'].set_linestyle((0, (4, 4)))
ax1.spines['top'].set_color('#000000') 
ax1.spines['right'].set_color('#000000')
ax1.spines['bottom'].set_color('#000000') 
ax1.spines['left'].set_color('#000000')
ax1.spines['left'].set_linewidth(1.5)
ax1.spines['bottom'].set_linewidth(1.5)
ax1.spines['top'].set_linewidth(1.5)
ax1.spines['right'].set_linewidth(1.5)
ax1.spines['top'].set_joinstyle('bevel')
ax1.spines['right'].set_joinstyle('bevel')

# color_1 = "tab:red"
ax1.set_ylabel(r"Consequences in App")
ax1.set_xlabel(r'Causes in the Commercial 5G Network')
ax1.yaxis.set_major_formatter(FormatStrFormatter('%d'))
ax1.xaxis.set_major_formatter(FormatStrFormatter('%d'))
# ax1.tick_params(axis='y', labelcolor=color_1)

''' To see the demo, unannotate the part you want to see and annotate the others. '''
''' line plot start ''' 
ax1.set_xticks([0.5, 1.5, 2.5, 3.5, 4.5, 5.5], [1, 2, 3, 4, 5, 6])
ax1.set_yticks([0.5, 1.5, 2.5], [1, 2, 3])

data = results_chain_commercial
for i in range(3):
  data[i, :] = data[i, :] / np.sum(total_count_commercial)*100

# Generate sample data
pmc = ax1.pcolormesh(data, cmap="YlGn")
for y in range(results_chain_commercial.shape[0]):
    for x in range(results_chain_commercial.shape[1]):
        color = 'black'
        if (data[y, x] > 16):
          color = 'white'
        plt.text(x + 0.5, y + 0.5, '%.2f' % data[y,x],
                 horizontalalignment='center',
                 verticalalignment='center',
                 color = color
                 )

# Add a colorbar
# plt.colorbar(pmc, ax=ax1)
plt.tight_layout(pad=0.1)

''' Plot '''
# fig,ax1 = plt.subplots()
FONT_SIZE = 35
# fm._rebuild()
plt.rcParams["text.usetex"] = True
plt.rcParams["font.weight"] = "light"
plt.rcParams["font.family"] = "Times"
plt.rcParams["font.size"] = FONT_SIZE


ggplot2_sets = [ [55, 126, 184], [228, 26, 28], [152, 78, 163], [0, 184, 229], \
    [247, 129, 191],  [77, 175, 74], [166, 86, 40], [255, 127, 0], [255, 217, 47],\
    [100, 100, 100], [0, 0, 0]] 

ggplot2_sets = list(map(lambda  x: [y / 255.0 for y in x], ggplot2_sets))

c1 = ggplot2_sets[0]
c2 = ggplot2_sets[1]
c3 = ggplot2_sets[2]
c4 = ggplot2_sets[3]
c5 = ggplot2_sets[4]

fig = plt.figure(figsize=(10, 6))
ax1 = fig.add_subplot(111)
ax1.grid(True, color='lightgrey', linestyle='--', linewidth=0.8, dash_capstyle='butt')
ax1.set_axisbelow(True)

# ax1.spines['top'].set_linestyle((0, (4, 4)))
# ax1.spines['right'].set_linestyle((0, (4, 4)))
ax1.spines['top'].set_color('#000000') 
ax1.spines['right'].set_color('#000000')
ax1.spines['bottom'].set_color('#000000') 
ax1.spines['left'].set_color('#000000')
ax1.spines['left'].set_linewidth(1.5)
ax1.spines['bottom'].set_linewidth(1.5)
ax1.spines['top'].set_linewidth(1.5)
ax1.spines['right'].set_linewidth(1.5)
ax1.spines['top'].set_joinstyle('bevel')
ax1.spines['right'].set_joinstyle('bevel')

# color_1 = "tab:red"
ax1.set_ylabel(r"Consequences in App")
ax1.set_xlabel(r'Causes in the Private 5G Network')
ax1.yaxis.set_major_formatter(FormatStrFormatter('%d'))
ax1.xaxis.set_major_formatter(FormatStrFormatter('%d'))
# ax1.tick_params(axis='y', labelcolor=color_1)

''' To see the demo, unannotate the part you want to see and annotate the others. '''
''' line plot start ''' 
ax1.set_xticks([0.5, 1.5, 2.5, 3.5, 4.5, 5.5], [1, 2, 3, 4, 5, 6])
ax1.set_yticks([0.5, 1.5, 2.5], [1, 2, 3])

data = results_chain_private
for i in range(3):
  data[i, :] = data[i, :] /np.sum(total_count_private)*100

# Generate sample data
pmc = ax1.pcolormesh(data, cmap="YlGn")
for y in range(results_chain_private.shape[0]):
    for x in range(results_chain_private.shape[1]):
        color = 'black'
        if (data[y, x] > 16):
          color = 'white'
        plt.text(x + 0.5, y + 0.5, '%.2f' % data[y, x],
                 horizontalalignment='center',
                 verticalalignment='center',
                 color=color
                 )

# Add a colorbar
# plt.colorbar(pmc, ax=ax1)
plt.tight_layout(pad=0.1)
# Show the plot
plt.show()
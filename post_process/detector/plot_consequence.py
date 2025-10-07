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
# 0416 5min, 0417 5min, 0418 10min, 0419 10min, 0420 10min, 0421 30min, 0422 30min, 0423 30min, 0426 30min
commercial_id = ['0416', '0417', '0418', '0419', '0422', '0423'] # 5 + 5 + 10 + 10 + 30 + 30 = 90
private_id = ['0420', '0421', '0426'] # 10 + 30 + 30 = 70
data_path = "~/Documents/data/athena/"
results_causes = np.zeros((4, 2))
#[r"Client inbound FPS", r"Server inbound FPS", r"Client Outbound FPS/Res", r"Server Outbound FPS/Res"]

for c_cell in commercial_id:
  file_name = data_path + "data_exp" + c_cell + '/detection_data/events_detection.csv'
  data = pd.read_csv(file_name)

  previous_row = []
  for index, row in data.iterrows():
    if (index == 0):
      results_causes[0, 0] += row["UE inbound FPS drops"]
      results_causes[1, 0] += row["Server inbound FPS drops"]
    #   fps_or_res = row["UE outbound FPS drops"] + row["UE outbound resolution drops"]
      results_causes[2, 0] += (row["UE outbound FPS drops"] or row["UE outbound resolution drops"])
    #   fps_or_res = data["Server outbound FPS drops"] + data["Server outbound resolution drops"]
      results_causes[3, 0] += (row["Server outbound FPS drops"] or row["Server outbound resolution drops"])
      previous_row = row
    else:
      if (row[0] - previous_row[0] == 0.5 and (row[2:] == previous_row[2:]).all()):
        previous_row = row
        continue
      else:
        results_causes[0, 0] += row["UE inbound FPS drops"]
        results_causes[1, 0] += row["Server inbound FPS drops"]
        #   fps_or_res = row["UE outbound FPS drops"] + row["UE outbound resolution drops"]
        results_causes[2, 0] += (row["UE outbound FPS drops"] or row["UE outbound resolution drops"])
        #   fps_or_res = data["Server outbound FPS drops"] + data["Server outbound resolution drops"]
        results_causes[3, 0] += (row["Server outbound FPS drops"] or row["Server outbound resolution drops"])
        previous_row = row

for p_cell in private_id:
  file_name = data_path + "data_exp" + p_cell + '/detection_data/events_detection.csv'
  data = pd.read_csv(file_name)
  previous_row = []
  for index, row in data.iterrows():
    if (index == 0):
      results_causes[0, 1] += row["UE inbound FPS drops"]
      results_causes[1, 1] += row["Server inbound FPS drops"]
    #   fps_or_res = row["UE outbound FPS drops"] + row["UE outbound resolution drops"]
      results_causes[2, 1] += (row["UE outbound FPS drops"] or row["UE outbound resolution drops"])
    #   fps_or_res = data["Server outbound FPS drops"] + data["Server outbound resolution drops"]
      results_causes[3, 1] += (row["Server outbound FPS drops"] or row["Server outbound resolution drops"])
      previous_row = row
    else:
      if (row[0] - previous_row[0] == 0.5 and (row[2:] == previous_row[2:]).all()):
        previous_row = row
        continue
      else:
        results_causes[0, 1] += row["UE inbound FPS drops"]
        results_causes[1, 1] += row["Server inbound FPS drops"]
        #   fps_or_res = row["UE outbound FPS drops"] + row["UE outbound resolution drops"]
        results_causes[2, 1] += (row["UE outbound FPS drops"] or row["UE outbound resolution drops"])
        #   fps_or_res = data["Server outbound FPS drops"] + data["Server outbound resolution drops"]
        results_causes[3, 1] += (row["Server outbound FPS drops"] or row["Server outbound resolution drops"])
        previous_row = row


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
ax1.set_xlabel(r"Consequences in WebRTC")
ax1.set_ylabel(r'Freq. per Minute')
ax1.yaxis.set_major_formatter(FormatStrFormatter('%d'))
ax1.xaxis.set_major_formatter(FormatStrFormatter('%f'))
# ax1.tick_params(axis='y', labelcolor=color_1)

''' To see the demo, unannotate the part you want to see and annotate the others. '''
''' line plot start ''' 
ax1.set_xticks([0, 7, 14, 21], [r"Client FPS In", r"Server FPS In", r"Client FPS/Res Out", r"Server FPS/Res Out"], rotation=20)
ax1.set_yticks([0, 1, 2, 3, 4])
ax1.set_ylim([0, 4])
# ax1.set_yscale('log')
# ax1.set_xscale("log")

boxes_commercial = ax1.bar(np.arange(4)*7-1.25, results_causes[:, 0] / 90, width=2.5, color=ggplot2_sets[0], edgecolor='black', label=r"Commercial 5G")
boxes_private = ax1.bar(np.arange(4)*7+1.25, results_causes[:, 1] / 70, width=2.5, color=ggplot2_sets[1], edgecolor='black', hatch="/", label=r"Private 5G")

for rect in boxes_commercial + boxes_private:
    height = rect.get_height()
    plt.text(rect.get_x() + rect.get_width() / 2.0, height, f'{height:.2f}', ha='center', va='bottom', fontdict={'size': 30})

ax1.legend(loc='lower left', bbox_to_anchor=(-0.05, 0.90),
          fancybox=False, shadow=False, frameon=False, ncol=6,
          #  handlelength=0.75, labelspacing=0.1, handletextpad=0.3,
          #  columnspacing=0.3,
          prop={'size': 30})
plt.tight_layout(pad=0.1)
plt.show()
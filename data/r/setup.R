
library(dplyr)
library(forcats)
library(ggplot2)
library(knitr)
library(lubridate)
library(purrr)
library(readr)
library(RColorBrewer)
library(magrittr)
library(scales)
library(stringr)
library(tibble)
library(tidyr)
library(zoo)

knitr::opts_chunk$set(
  echo = TRUE,
  dev = c('png', 'pdf'),
  fig.width = 9, fig.height = 4.5,
  fig.align = 'center',
  fig.keep = 'high',
  fig.path = 'fig/') 

show_table = function(table) {
  if (isTRUE(getOption('knitr.in.progress'))) kable(table) else table
}

library(RColorBrewer)
color_palette <- function(pal) brewer.pal(brewer.pal.info[pal, "maxcolors"], pal)

to_ms <- function(ts_s, ts_us, off_s = 0) {
  return((ts_s - off_s) * 1000 + ts_us / 1000)
}

theme_om <- function() {
  theme(
    axis.line             = element_line(color='transparent'),
    axis.text             = element_text(family='sans', size='9', color='#333333'),
    axis.ticks            = element_line(color='#333333', linewidth=0.5),
    axis.title            = element_text(family='sans', size='11', color='#222222'),
    legend.background     = element_rect(color='#CCCCCC', linewidth=0.3, linetype='solid', fill='transparent'),
    legend.box.background = element_rect(color='white', fill='white', linewidth=0,),
    legend.justification  = 'right',
    legend.key            = element_rect(fill="transparent", color=NA),
    legend.margin         = margin(t=2, r=2, b=2, l=2),
    legend.position        = 'inside',
    #legend.title          = element_blank(),
    panel.background      = element_rect(fill='#ffffff'),
    panel.border          = element_rect(color='#222222', linewidth=0.75, linetype='solid', fill='transparent'),
    panel.grid.major      = element_line(color='#999999', linetype='dotted', linewidth=0.3),
    panel.grid.minor      = element_blank(),
    plot.margin           = margin(t=2, r=1, b=1, l=1),
    validate              = TRUE
  )
}
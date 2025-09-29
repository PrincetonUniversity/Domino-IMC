#!/usr/bin/env Rscript

args = commandArgs(trailingOnly=TRUE)

if (length(args) != 3) {
  print("usage: join.R <ue.csv> <core.csv> <out.csv>", call.=FALSE)
}

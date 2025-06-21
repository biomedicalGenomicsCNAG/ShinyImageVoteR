# Libraries ####
library(shiny)
library(tidyr)
library(stringr)
# library(googlesheets4)
# options(gargle_quiet = FALSE)
# options(gargle_verbosity = "debug")
library(jsonlite)
library(magrittr)

passwords <- c(
  "Test" = "1234",
  "Test2" = "1plusmg",
  "Training (answers won't be saved)" = "1plusmg"
)

user_ids <- names(passwords)

#  Variables ####
observations_dict <- c(
  "Issues with coverage" = "coverage",
  "Low allele frequency" = "low_vaf",
  "Alignment issues" = "alignment",
  "Complex event" = "complex",
  "Quality issues with the image" = "img_qual_issue",
  "Issue with the voting platform" = "platform_issue"
)

# first N training questions will be stored but used for training only
training_questions <- 10

# a buffer of questions
n_sample <- 20




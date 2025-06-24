library(shiny)
library(dplyr)
library(tibble)
library(digest)
library(DBI)
library(RSQLite)
library(data.table)
library(jsonlite)
library(shinyjs)

# load configuration (variables have a "cfg_" prefix)
source("config.R")

# Initialize the SQLite database
if (!file.exists(cfg_sqlite_file)) {
  source("init_db.R")
}

# Initial login status
Logged <- FALSE

# create folders for all institutes
lapply(cfg_institute_ids, function(institute) {
  # replace spaces with underscores in institute names
  institute <- gsub(" ", "_", institute)
  dir.create(file.path("user_data", institute), recursive = TRUE, showWarnings = FALSE)
})

color_seq <- function(seq) {

  print("Coloring sequence:")
  print(seq)

  colored_seq <- seq %>%
    strsplit(., split = "") %>%
    unlist() %>%
    sapply(., function(x) sprintf('<span style="color:%s">%s</span>', cfg_nt2color_map[x], x)) %>%
    paste(collapse = "")

  colored_seq
}


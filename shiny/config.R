# Libraries ####
library(shiny)
# library(rsconnect)
library(tidyverse)
library(googlesheets4)
options(gargle_quiet = FALSE)
options(gargle_verbosity = "debug")
library(jsonlite)

# Google authentication ####
gs4_auth(email = Sys.getenv("GOOGLE_SERVICE_ACC"), path = "gsheets_config.json")

cat("------------- >> confirm user name:")
gs4_user()

# Drive data ####
gdoc_base_url <- "https://docs.google.com/spreadsheets/d/"
drive_paths <- list(
  screenshots = paste0(gdoc_base_url, Sys.getenv("GDOCS_SCREENSHOTS_UID"), "/edit?usp=sharing"),
  annotations = paste0(gdoc_base_url, Sys.getenv("GDOCS_ANNOTATIONS_UID"), "/edit?usp=sharing")
)

screenshots <- read_sheet(drive_paths$screenshots)

vartype_dict <- unique(screenshots$variant)

# Institutes and passwords ####

passwords <- c(
  "Test" = "1plusmg",
  "CNAG" = "1plusmg",
  "DKFZ" = "1plusmg",
  "DNGC" = "1plusmg",
  "Hartwig" = "1plusmg",
  "KU Leuven" = "2plusmg",
  "University of Oslo" = "1plusmg",
  "University of Verona" = "1plusmg",
  "University of Helsinki" = "1plusmg",
  "SciLifeLab" = "1plusmg",
  "ISCIII" = "1plusmg",
  "Latvian BRSC" = "1plusmg",
  "MOMA" = "1plusmg",
  "Universidade de Aveiro" = "1plusmg",
  "FPGMX" = "1plusmg",
  "Training (answers won't be saved)" = "1plusmg"
)

institutes <- names(passwords)

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



# Functions ####

choose_picture <- function(drive_paths, institute, training_questions, voting_institute, vartype, screenshots, vartype_dict, n_sample = 10) {
  annot <- read_sheet(drive_paths$annotations) %>%
    # first N questions per centre are for training
    group_by(institute) %>%
    slice(-c(1:training_questions)) %>%
    ungroup() %>%
    # a row that will be removed but contains all agreement fields
    bind_rows(tibble("image" = "-", already_voted = T, agreement = c("yes", "no", "diff_var", "not_confident"))) %>%
    # summarise if institute already voted
    group_by(image) %>%
    mutate(already_voted = (institute == voting_institute)) %>%
    mutate(already_voted = any(already_voted)) %>%
    count(image, already_voted, agreement) %>%
    spread(agreement, n, fill = 0) %>%
    mutate(total_votes = yes + no + diff_var + not_confident)


  # select candidates for random selection
  candidates <- screenshots %>%
    # pick the variants selected by the user
    filter((variant == vartype | !(vartype %in% vartype_dict))) %>%
    # get all images ids
    select(image, coordinates, path, REF, ALT, variant) %>%
    # add agreement info
    left_join(annot) %>%
    mutate(
      yes = coalesce(yes, 0),
      no = coalesce(no, 0),
      not_confident = coalesce(not_confident, 0),
      diff_var = coalesce(diff_var, 0),
      total_votes = coalesce(total_votes, 0),
      already_voted = coalesce(already_voted, FALSE)
    ) %>%
    # remove images if institute already voted
    # mutate(already_voted = !(is.na(already_voted) | !already_voted)) %>%
    filter(!already_voted) %>%
    # arrange(desc(total_votes)) %>%

    # filtering rules
    filter(!(yes >= 3 & yes / total_votes > 0.7)) %>%
    filter(!(no >= 3 & no / total_votes > 0.7))


  # subset a sample of screenshots
  if (!is.null(n_sample)) {
    if (nrow(candidates) < n_sample) {
      n_sample <- nrow(candidates)
    }
    candidates <- candidates %>%
      sample_n(size = n_sample)
  }

  candidates
}

color_seq <- function(seq) {
  # RColorBrewer::brewer.pal(12, name = "Paired")
  # color_dict = c("T" = "red", "C" = "blue", "A" = "green", "G" = "orange", "-" = "black")
  color_dict <- c(
    "T" = "#E31A1C",
    "C" = "#1F78B4",
    "A" = "#33A02C",
    "G" = "#FF7F00",
    "-" = "black"
  )

  colored_seq <- seq %>%
    strsplit(., split = "") %>%
    unlist() %>%
    sapply(., function(x) sprintf('<span style="color:%s">%s</span>', color_dict[x], x)) %>%
    paste(collapse = "")

  colored_seq
}

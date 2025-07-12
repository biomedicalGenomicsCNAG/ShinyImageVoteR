# Configuration file for the variant voting app

# Check if external configuration is set
external_config_path <- Sys.getenv("B1MG_CONFIG_PATH", unset = NA)

if (!is.na(external_config_path) && file.exists(external_config_path)) {
  # Source external configuration if it exists
  cat("Loading external configuration from:", external_config_path, "\n")
  source(external_config_path, local = TRUE)
  return() # Exit early to prevent loading this config
} else {
  # Try to find config in parent directory structure
  possible_config_paths <- c(
    "../../config/config.R",  # From inst/shiny-app to root/config
    "../../../config/config.R", # Alternative path
    "./config/config.R"       # Local config
  )
  
  config_found <- FALSE
  for (config_path in possible_config_paths) {
    if (file.exists(config_path)) {
      cat("Loading configuration from:", config_path, "\n")
      source(config_path, local = TRUE)
      config_found <- TRUE
      break
    }
  }
  
  if (!config_found) {
    cat("Using package configuration\n")
  } else {
    return() # Exit early if external config was loaded
  }
}

# Check if external user_data directory is set
external_user_data_dir <- Sys.getenv("B1MG_USER_DATA_DIR", unset = NA)

if (!is.na(external_user_data_dir) && dir.exists(external_user_data_dir)) {
  # Use external user_data directory
  cfg_user_data_dir <- external_user_data_dir
  message("Using external user_data directory: ", cfg_user_data_dir)
} else {
  # Fallback to local user_data directory (for development)
  cfg_user_data_dir <- "./user_data"
  if (!dir.exists(cfg_user_data_dir)) {
    dir.create(cfg_user_data_dir, recursive = TRUE, showWarnings = FALSE)
  }
  message("Using local user_data directory: ", cfg_user_data_dir)
}

# Check if external database path is set
external_db_path <- Sys.getenv("B1MG_DATABASE_PATH", unset = NA)

if (!is.na(external_db_path) && file.exists(external_db_path)) {
  # Use external database
  cfg_sqlite_file <- external_db_path
  message("Using external database: ", cfg_sqlite_file)
} else {
  # Fallback to local database (for development)
  cfg_sqlite_file <- "./db.sqlite"
  if (!file.exists(cfg_sqlite_file)) {
    message("Warning: Database file not found at ", cfg_sqlite_file)
  }
  message("Using local database: ", cfg_sqlite_file)
}

# Check if external server_data directory is set
external_server_data_dir <- Sys.getenv("B1MG_SERVER_DATA_DIR", unset = NA)

if (!is.na(external_server_data_dir) && dir.exists(external_server_data_dir)) {
  # Use external server_data directory
  cfg_server_data_dir <- external_server_data_dir
  message("Using external server_data directory: ", cfg_server_data_dir)
} else {
  # Fallback to local server_data directory (for development)
  cfg_server_data_dir <- "./server_data"
  if (!dir.exists(cfg_server_data_dir)) {
    dir.create(cfg_server_data_dir, recursive = TRUE, showWarnings = FALSE)
  }
  message("Using local server_data directory: ", cfg_server_data_dir)
}

# the application listenes to the existence of this file to gracefully shutdown
cfg_shutdown_file <- file.path(cfg_server_data_dir, "STOP")

## Database configuration

### file paths
cfg_to_be_voted_images_file <- "./screenshots/uro003_paths_mock.txt"

### database columns
cfg_db_general_cols <- c("coordinates", "REF", "ALT", "variant", "path")

cfg_vote2dbcolumn_map <- list(
  yes = "vote_count_correct",
  no = "vote_count_no_variant",
  diff_var = "vote_count_different_variant",
  not_confident = "vote_count_not_sure"
)

cfg_vote_counts_cols <- c(
  unlist(cfg_vote2dbcolumn_map, use.names = FALSE), 
  "vote_count_total"
)

cfg_db_cols <- c(
  cfg_db_general_cols, 
  cfg_vote_counts_cols
)

## Login UI
institute_ids <- (c(
  "CNAG",
  "DKFZ",
  "DNGC",
  "FPGMX",
  "Hartwig",
  "ISCIII",
  "KU Leuven",
  "Latvian BRSC",
  "MOMA",
  "SciLifeLab",
  "Universidade de Aveiro",
  "University of Helsinki",
  "University of Oslo",
  "University of Verona"
))

cfg_test_institute <- "Training_answers_not_saved"
cfg_institute_ids <- c(cfg_test_institute, institute_ids)

cfg_selected_institute_id <- cfg_test_institute
cfg_selected_institute_id <- "CNAG"

passwords <- c(
  "test" = "1234",
  "test2" = "1234"
)

cfg_user_ids <- names(passwords)

# credentials data frame for shinyauthr
cfg_credentials_df <- data.frame(
  user = cfg_user_ids,
  password = unname(passwords[cfg_user_ids]),
  stringsAsFactors = FALSE
)

cfg_cookie_expiry <- 1 # Days until session expires

cfg_selected_user_id <- "Test"

## Voting UI

cfg_application_title <- "B1MG Somatic Mutation Voting"

cfg_radioBtns_label <- "Is the somatic mutation above correct? [num keys 1-4]"

radio_options2val_map <- c(
  "Yes, it is" = "yes",
  "There is no variant" = "no",
  "There is a different variant" = "diff_var",
  "I'm not sure" = "not_confident"
)

cfg_radio_options2val_map <- setNames(
  as.vector(radio_options2val_map),
  paste0(names(radio_options2val_map), " [", seq_along(radio_options2val_map), "]")
)

### Options when the radio button I'm not sure [4] is selected

cfg_checkboxes_label <- "Please select the reason for your uncertainty [keyboard keys a-h]"

observations_dict <- c(
  "Issues with coverage" = "coverage",
  "Low allele frequency" = "low_vaf",
  "Alignment issues" = "alignment",
  "Complex event" = "complex",
  "Quality issues with the image" = "img_qual_issue",
  "Issue with the voting platform" = "platform_issue"
)

observation_hotkeys = c("a", "s", "d", "f", "g", "h")

cfg_observations2val_map <- setNames(
  as.vector(observations_dict),
  paste0(names(observations_dict), " [", observation_hotkeys, "]")
)

### Colors for the nucleotides
cfg_nt2color_map <- c(
  "T" = "#E31A1C", # Red
  "C" = "#1F78B4", # Blue
  "A" = "#33A02C", # Green
  "G" = "#FF7F00", # Orange
  "-" = "black"    # Black for gaps
) 

### user annotations file column names
cfg_user_annotations_colnames <- c(
   "coordinates",
   "agreement",
   "alternative_vartype",
   "observation",
   "comment",
   "shinyauthr_session_id",
   "time_till_vote_casted_in_seconds"
)

# Configuration file for the variant voting app
# This is the external configuration file that overrides package defaults

## Directory paths (will be set by package functions)
cfg_base_dir <- getwd() # Base directory for the app
cfg_user_data_dir <- "user_data"
cfg_server_data_dir <- "server_data" 
cfg_images_dir <- "images"

## Database configuration
cfg_sqlite_file <- "db.sqlite"

## Application configuration
cfg_application_title <- "B1MG Somatic Mutation Voting"

## External shutdown configuration
cfg_shutdown_file <- "STOP"

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
#' Load voting app configuration
#'
#' Returns a list of configuration values, optionally overridden by environment
#' variables or external files.
#'
#' @return A named list of configuration values (e.g., `cfg_sqlite_file`, `cfg_radio_options2val_map`, etc.)
#' @export
load_config <- function() {
  cfg <- list()

  # Determine paths
  cfg$user_data_dir <- Sys.getenv("B1MG_USER_DATA_DIR", unset = "./user_data")
  if (!dir.exists(cfg$user_data_dir)) dir.create(cfg$user_data_dir, recursive = TRUE)

  cfg$server_data_dir <- Sys.getenv("B1MG_SERVER_DATA_DIR", unset = "./server_data")
  if (!dir.exists(cfg$server_data_dir)) dir.create(cfg$server_data_dir, recursive = TRUE)

  cfg$shutdown_file <- file.path(cfg$server_data_dir, "STOP")

  cfg$sqlite_file <- Sys.getenv("B1MG_DATABASE_PATH", unset = "./db.sqlite")
  if (!file.exists(cfg$sqlite_file)) {
    message("Warning: Database file not found at ", cfg$sqlite_file)
  }

  # Voting image file
  cfg$to_be_voted_images_file <- "./screenshots/uro003_paths_mock.txt"

  # Application-wide voting UI config
  cfg$application_title <- "B1MG Somatic Mutation Voting"
  cfg$radioBtns_label <- "Is the somatic mutation above correct? [num keys 1-4]"
  cfg$checkboxes_label <- "Please select the reason for your uncertainty [keyboard keys a-h]"

  # Voting options
  radio_options <- c(
    "Yes, it is" = "yes",
    "There is no variant" = "no",
    "There is a different variant" = "diff_var",
    "I'm not sure" = "not_confident"
  )
  cfg$radio_options2val_map <- setNames(as.vector(radio_options), paste0(names(radio_options), " [", seq_along(radio_options), "]"))

  observations_dict <- c(
    "Issues with coverage" = "coverage",
    "Low allele frequency" = "low_vaf",
    "Alignment issues" = "alignment",
    "Complex event" = "complex",
    "Quality issues with the image" = "img_qual_issue",
    "Issue with the voting platform" = "platform_issue"
  )
  observation_hotkeys <- c("a", "s", "d", "f", "g", "h")
  cfg$observations2val_map <- setNames(as.vector(observations_dict), paste0(names(observations_dict), " [", observation_hotkeys, "]"))

  # Color mapping
  cfg$nt2color_map <- c(
    "T" = "#E31A1C",
    "C" = "#1F78B4",
    "A" = "#33A02C",
    "G" = "#FF7F00",
    "-" = "black"
  )

  # Columns
  cfg$db_general_cols <- c("coordinates", "REF", "ALT", "variant", "path")
  cfg$vote2dbcolumn_map <- list(
    yes = "vote_count_correct",
    no = "vote_count_no_variant",
    diff_var = "vote_count_different_variant",
    not_confident = "vote_count_not_sure"
  )
  cfg$vote_counts_cols <- c(unlist(cfg$vote2dbcolumn_map, use.names = FALSE), "vote_count_total")
  cfg$db_cols <- c(cfg$db_general_cols, cfg$vote_counts_cols)

  # User annotations
  cfg$user_annotations_colnames <- c(
    "coordinates", "agreement", "alternative_vartype",
    "observation", "comment", "shinyauthr_session_id",
    "time_till_vote_casted_in_seconds"
  )

  # Login configuration
  institute_ids <- c(
    "CNAG", "DKFZ", "DNGC", "FPGMX", "Hartwig", "ISCIII",
    "KU Leuven", "Latvian BRSC", "MOMA", "SciLifeLab",
    "Universidade de Aveiro", "University of Helsinki",
    "University of Oslo", "University of Verona"
  )
  cfg$test_institute <- "Training_answers_not_saved"
  cfg$institute_ids <- c(cfg$test_institute, institute_ids)
  cfg$selected_institute_id <- "CNAG"

  passwords <- c("test" = "1234", "test2" = "1234")
  cfg$user_ids <- names(passwords)
  cfg$credentials_df <- data.frame(
    user = cfg$user_ids,
    password = unname(passwords[cfg$user_ids]),
    stringsAsFactors = FALSE
  )
  cfg$cookie_expiry <- 1
  cfg$selected_user_id <- "Test"

  return(cfg)
}

#' Load voting app configuration
#'
#' Returns a list of configuration values, optionally overridden by environment
#' variables or external files.
#'
#' @return A named list of configuration values (e.g., `cfg_sqlite_file`, `cfg_radio_options2val_map`, etc.)
#' @export
load_config <- function() {
  app_dir <- get_app_dir()
  package_cfg <- file.path(app_dir, "config.json")
  external_cfg <- file.path("config", "config.json")

  config_path <- if (file.exists(external_cfg)) external_cfg else package_cfg

  if (!file.exists(config_path)) {
    stop("No configuration JSON found")
  }

  cfg <- jsonlite::read_json(config_path, simplifyVector = TRUE)

  cfg$user_data_dir <- Sys.getenv("B1MG_USER_DATA_DIR", unset = cfg$user_data_dir)
  if (!dir.exists(cfg$user_data_dir)) dir.create(cfg$user_data_dir, recursive = TRUE)

  cfg$server_data_dir <- Sys.getenv("B1MG_SERVER_DATA_DIR", unset = cfg$server_data_dir)
  if (!dir.exists(cfg$server_data_dir)) dir.create(cfg$server_data_dir, recursive = TRUE)
  cfg$shutdown_file <- file.path(cfg$server_data_dir, "STOP")

  cfg$sqlite_file <- Sys.getenv("B1MG_DATABASE_PATH", unset = cfg$sqlite_file)
  if (!file.exists(cfg$sqlite_file)) {
    message("Warning: Database file not found at ", cfg$sqlite_file)
  }

  cfg$radio_options2val_map <- setNames(
    as.vector(cfg$radio_options2val_map),
    paste0(names(cfg$radio_options2val_map), " [", seq_along(cfg$radio_options2val_map), "]")
  )

  cfg$observations2val_map <- setNames(
    as.vector(cfg$observations_dict),
    paste0(names(cfg$observations_dict), " [", cfg$observation_hotkeys, "]")
  )

  cfg$vote_counts_cols <- c(unlist(cfg$vote2dbcolumn_map, use.names = FALSE), "vote_count_total")
  cfg$db_cols <- c(cfg$db_general_cols, cfg$vote_counts_cols)

  cfg$user_ids <- names(cfg$passwords)
  cfg$credentials_df <- data.frame(
    user = cfg$user_ids,
    password = unname(cfg$passwords[cfg$user_ids]),
    stringsAsFactors = FALSE
  )

  return(cfg)
}

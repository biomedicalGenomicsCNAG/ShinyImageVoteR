#' Load voting app configuration
#'
#' Returns a list of configuration values, optionally overridden by environment
#' variables or external files.
#'
#' @return A named list of configuration values (e.g., `cfg_sqlite_file`, `cfg_radio_options2val_map`, etc.)
#' @import yaml
#' @export
load_config <- function() {
  app_dir <- get_app_dir()
  print("app_dir:")
  print(app_dir)
  package_cfg <- file.path(app_dir, "default_config.yaml")
  external_cfg <- file.path(Sys.getenv("B1MG_CONFIG_DIR"), "config.yaml")

  print("external_cfg full path:")
  print(normalizePath(external_cfg, mustWork = FALSE))

  config_path <- if (file.exists(external_cfg)) external_cfg else package_cfg

  print("Loading configuration from:")
  print(config_path)

  if (!file.exists(config_path)) {
    stop("No configuration YAML found")
  }

  cfg <- yaml::read_yaml(config_path)

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

  cfg$credentials_df <- data.frame(
    user = names(cfg$user2passwords_map),
    password = vapply(cfg$user2passwords_map, identity, character(1)),
    stringsAsFactors = FALSE
  )

  return(cfg)
}

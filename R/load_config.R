#' Load voting app configuration
#'
#' Returns a list of configuration values, optionally overridden by environment
#' variables or external files.
#' @param config_file_path Character. Path to the configuration file. Default is the one in the app directory
#'
#' @return A named list of configuration values (e.g., `cfg_sqlite_file`, `cfg_radio_options2val_map`, etc.)
#' @import yaml
#' @export


# TODO
# figure out if two defaults are possible
# 1. default in package directory
# 2. default cfg <- Sys.getenv("IMGVOTER_CONFIG_FILE_PATH")

load_config <- function(
  config_file_path = file.path(
    get_app_dir(), "default_env", "config", "config.yaml"
  )
) {
  cfg <- yaml::read_yaml(config_file_path)

  # Override with environment variables if they exist
  cfg_sqlite_file <- Sys.getenv("IMGVOTER_DB_PATH", cfg$sqlite_file)
  cfg$sqlite_file <- normalizePath(cfg_sqlite_file, mustWork = TRUE)

  cfg$images_dir <- Sys.getenv("IMGVOTER_IMAGES_DIR", cfg$images_dir)
  cfg$images_dir <- normalizePath(cfg$images_dir, mustWork = TRUE)

  cfg$server_data_dir <- Sys.getenv(
    "IMGVOTER_SERVER_DATA_DIR", cfg$server_data_dir
  )

  print("cwd")
  print(getwd())
  print("server_data_dir")
  print(cfg$server_data_dir)
  cfg$server_data_dir <- normalizePath(cfg$server_data_dir, mustWork = TRUE)

  cfg$user_data_dir <- Sys.getenv("IMGVOTER_USER_DATA_DIR", cfg$user_data_dir)
  cfg$user_data_dir <- normalizePath(cfg$user_data_dir, mustWork = TRUE)

  cfg$radio_options2val_map <- setNames(
    as.vector(cfg$radio_options2val_map),
    paste0(names(cfg$radio_options2val_map), " [", seq_along(cfg$radio_options2val_map), "]")
  )

  cfg$observations2val_map <- setNames(
    as.vector(cfg$observations_dict),
    paste0(names(cfg$observations_dict), " [", cfg$observation_hotkeys, "]")
  )

  cfg$vote_counts_cols <- c(
    unlist(cfg$vote2dbcolumn_map, 
    use.names = FALSE), 
    "vote_count_total"
  )

  cfg$db_cols <- c(cfg$db_general_cols, cfg$vote_counts_cols)

  # TODO
  # missing annotations_cols

  cfg$theme <- bslib::bs_theme(version = 5)

  return(cfg)
}

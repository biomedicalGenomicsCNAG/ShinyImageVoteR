# TODO
# figure out if two defaults are possible
# 1. default in package directory
# 2. default cfg <- Sys.getenv("IMGVOTER_CONFIG_FILE_PATH")

overwrite_if_relative <- function(path) {
  print(paste0("Checking if path is relative: ", path))
  base_dir <- Sys.getenv("IMGVOTER_BASE_DIR")
  is_relative <- !grepl("^(/|[A-Za-z]:)", path) # Unix or Windows absolute path
  if (is_relative) {
    print(paste0("Path is relative: ", path))
    rel_path <- path
    path <- normalizePath(file.path(base_dir, rel_path), mustWork = FALSE)
    print(paste0("Overwriting with absolute path: ", path))
  }
  return(path)
}

overwrite_if_env_var <- function(env_var_name, cfg_value) {
  env_path <- Sys.getenv(env_var_name)
  if (!is.na(env_path) && nchar(env_path) > 0) {
    print(paste0(env_var_name, " detected; value: ", env_path))
    return(env_path)
  }
  return(cfg_value)
}

#' Load voting app configuration
#'
#' Returns a list of configuration values, optionally overridden by environment
#' variables or external files.
#' @param config_file_path Character. Path to the configuration file. Default is the one in the app directory
#'
#' @return A named list of configuration values (e.g., `cfg_sqlite_file`, `cfg_radio_options2val_map`, etc.)
#' @import yaml
#' @export
load_config <- function(config_file_path) {
  print(paste0("Loading configuration from: ", config_file_path))
  if (!file.exists(config_file_path)) {
    stop(paste0("Configuration file not found: ", config_file_path))
  }

  cfg <- yaml::read_yaml(config_file_path)

  env_vars_to_cfg <- c(
    "IMGVOTER_USER_DATA_DIR" = "user_data_dir",
    "IMGVOTER_SERVER_DATA_DIR" = "server_data_dir",
    "IMGVOTER_IMAGES_DIR" = "images_dir",
    "IMGVOTER_TO_BE_VOTED_IMAGES_FILE" = "to_be_voted_images_file",
    "IMGVOTER_DB_PATH" = "sqlite_file",
    "IMG_VOTER_GROUPED_CREDENTIALS" = "grouped_credentials_file"
  )

  print("name of env_vars_to_cfg:")
  print(names(env_vars_to_cfg))

  # loop through environment variables and overwrite cfg values
  for (env_var in names(env_vars_to_cfg)) {
    cfg_var_name <- env_vars_to_cfg[[env_var]]
    cfg[[cfg_var_name]] <- overwrite_if_env_var(env_var, cfg[[cfg_var_name]])
  }

  print("Configuration after environment variable overrides:")
  print(cfg)

  # loop through cfg values and overwrite with absolute paths if relative
  cfg$user_data_dir <- overwrite_if_relative(cfg$user_data_dir)
  print("user_data_dir:")
  print(cfg$user_data_dir)
  cfg$server_data_dir <- overwrite_if_relative(cfg$server_data_dir)
  cfg$images_dir <- overwrite_if_relative(cfg$images_dir)
  cfg$sqlite_file <- overwrite_if_relative(cfg$sqlite_file)
  cfg$grouped_credentials_file <- overwrite_if_relative(cfg$grouped_credentials_file)
  cfg$to_be_voted_images_file <- overwrite_if_relative(cfg$to_be_voted_images_file)

  # # Override with environment variables if they exist
  # cfg_sqlite_file <- Sys.getenv("IMGVOTER_DB_PATH", cfg$sqlite_file)
  # # chheck if the path is relative or absolute
  # # cfg_sqlite_file <- overwrite_if_relative(cfg_sqlite_file, base_dir)

  # cfg$images_dir <- Sys.getenv("IMGVOTER_IMAGES_DIR", cfg$images_dir)
  # cfg$images_dir <- normalizePath(cfg$images_dir, mustWork = TRUE)

  # cfg$server_data_dir <- Sys.getenv(
  #   "IMGVOTER_SERVER_DATA_DIR", cfg$server_data_dir
  # )

  # print("cwd")
  # print(getwd())
  # print("server_data_dir")
  # print(cfg$server_data_dir)

  # cfg$server_data_dir <- normalizePath(cfg$server_data_dir, mustWork = TRUE)

  # cfg$user_data_dir <- Sys.getenv("IMGVOTER_USER_DATA_DIR", cfg$user_data_dir)
  # cfg$user_data_dir <- normalizePath(cfg$user_data_dir, mustWork = TRUE)

  cfg$observations2val_map <- setNames(
    as.vector(cfg$observations_dict),
    paste0(names(cfg$observations_dict), " [", cfg$observation_hotkeys, "]")
  )

  cfg$vote_counts_cols <- c(
    unlist(cfg$vote2dbcolumn_map,
      use.names = FALSE
    ),
    "vote_count_total"
  )

  cfg$db_cols <- c(cfg$db_general_cols, cfg$vote_counts_cols)

  # TODO
  # missing annotations_cols
  cfg$theme <- bslib::bs_theme(version = 5)

  return(cfg)
}

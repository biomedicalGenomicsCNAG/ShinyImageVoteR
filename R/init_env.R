#' Initialize environment for the application
#'
#' Sets up the app environment directory and the database.
#'
#' @param config_file_path Character. Path to the configuration file.
#'    Default is app_env/config/config.yaml in the current working directory.
#' @return List with paths to user_data directory, database file, and config file
#' @export  
init_environment <- function(
  config_file_path
) {
  # check if "IMGVOTER_BASE_DIR" is set, then set it as base directory
  base_dir <- Sys.getenv("IMGVOTER_BASE_DIR", unset = getwd())

  default_file_path <- file.path(
    get_app_dir(), "default_env", "config", "config.yaml"
  )

  if (config_file_path == default_file_path) {
    config_dir <- file.path(base_dir, "app_env", "config")

    if(!dir.exists(config_dir)) {
      copy_dir_from_app(config_dir)
      config_file_path <- file.path(config_dir, "config.yaml")
    }
  }

  cfg <- load_config(config_file_path)
  print("Configuration loaded:")  
  print(cfg)
  
  Sys.setenv(
    IMGVOTER_BASE_DIR = normalizePath(base_dir, mustWork = TRUE),
    IMGVOTER_CONFIG_FILE_PATH = normalizePath(config_file_path, mustWork = TRUE)
  )
  # TODO use this for every load_config call

  # Set up expected directories
  expected_dirs <- c("images", "user_data", "server_data")
  # browser()
  purrr::walk(expected_dirs, function(name) {
    key      <- glue::glue("{name}_dir")
    cfg_path <- cfg[[key]]

    # Determine if path is relative or absolute
    is_relative <- !grepl("^(/|[A-Za-z]:)", cfg_path)  # Unix or Windows absolute path
    abs_path <- if (is_relative) {
      rel_path <- cfg_path
      normalizePath(file.path(base_dir, rel_path), mustWork = FALSE)
    } else {
      cfg_path
    }

    cat("Checking directory:", abs_path, "\n") 

    if (!dir.exists(abs_path)) {
      abs_path <<- copy_dir_from_app(abs_path)
    }

    if (name == "images") {
      # only set the IMGVOTER_IMAGES_DIR if it is not already set
      if (Sys.getenv("IMGVOTER_IMAGES_DIR") == "") {
        Sys.setenv(IMGVOTER_IMAGES_DIR = abs_path)
        message("Set IMGVOTER_IMAGES_DIR to: ", abs_path)
      }

    }
  })

  # get the directory in which the sqlite file is located
  sqlite_file_full_path <- normalizePath(cfg$sqlite_file)
  print("SQLite file path:")
  print(sqlite_file_full_path)

  grouped_credentials <- yaml::read_yaml(normalizePath(
    cfg$grouped_credentials_file, mustWork = TRUE
  ))

  if (!file.exists(sqlite_file_full_path)) {
    sqlite_file_full_path <- create_database(
      sqlite_file_full_path,
      normalizePath(cfg$to_be_voted_images_file, mustWork = TRUE),
      grouped_credentials
    )
  }

  sqlite_file_dir <- dirname(sqlite_file_full_path)

  ensure_gitignore(
    sqlite_file_dir, 
    patterns = c("*.sqlite", "*.db")
  )

  #----- Create user data directories for each group---------
  groups <- names(grouped_credentials)

  # Create group subdirectories
  for (group in groups) {
    # make sure the group name is valid for a directory
    safe_dir_create(file.path(
      cfg$user_data_dir, 
      group
    ))
  }
  
  Sys.setenv(
    IMGVOTER_USER_GROUPS_COMMA_SEPARATED = paste(groups, collapse = ","),
    IMGVOTER_USER_DATA_DIR = normalizePath(cfg$user_data_dir, mustWork = TRUE)
  )
}

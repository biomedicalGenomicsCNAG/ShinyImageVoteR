#' Data Directory Management Functions
#'
#' Functions to manage user data directories outside the package
#'
#' @name data_management
NULL

#' Get or create the user data directory
#'
#' This function returns the path to the user_data directory, creating it if necessary.
#' The directory is located outside the package installation.
#'
#' @param base_dir Character. Base directory where user_data should be located. 
#'   If NULL, uses the current working directory.
#' @return Character path to the user_data directory
#' @export
get_user_data_dir <- function(base_dir = NULL) {
  if (is.null(base_dir) || base_dir == "") {
    base_dir <- getwd()
  }
  
  user_data_dir <- file.path(base_dir, "user_data")
  
  # Create the directory if it doesn't exist
  if (!dir.exists(user_data_dir)) {
    dir.create(user_data_dir, recursive = TRUE, showWarnings = FALSE)
    message("Created user_data directory at: ", user_data_dir)
  }
  return(user_data_dir)
}

#' Initialize the database connection pool
#' @keywords internal
#' @param cfg_sqlite_file Path to an existing SQLite file
#' @return A DBI pool object
#' @export
init_db <- function(cfg_sqlite_file) {
  pool <- dbPool(
    RSQLite::SQLite(),
    dbname = cfg_sqlite_file
  )

  shiny::onStop(function() {
    poolClose(pool)
  })

  return(pool)
}

# #' Get configuration with external user_data path
# #'
# #' Returns a configuration object with the correct user_data path
# #'
# #' @param base_dir Character. Base directory for user_data
# #' @return List with configuration including user_data_path
# #' @export
# get_external_config <- function(base_dir = NULL) {
#   user_data_dir <- get_user_data_dir(base_dir)
  
#   config <- list(
#     user_data_path = user_data_dir,
#     app_dir = get_app_dir()
#   )
  
#   return(config)
# }

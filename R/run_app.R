#' Run B1MG Variant Voting Shiny Application
#'
#' This function launches the B1MG Variant Voting Shiny application.
#'
#' @param host Character. Host to run the application on. Default is "127.0.0.1"
#' @param port Integer. Port to run the application on. Default is NULL (random port)
#' @param launch.browser Logical. Should the browser be launched? Default is TRUE
#' @param user_data_dir Character. Path to the user_data directory. If NULL, uses get_user_data_dir()
#' @param ... Additional arguments passed to shiny::runApp()
#'
#' @return Runs the Shiny application
#' @export
#'
#' @examples
#' \dontrun{
#' run_voting_app()
#' run_voting_app(user_data_dir = "/path/to/my/user_data")
#' }
run_voting_app <- function(host = "127.0.0.1", port = NULL, launch.browser = TRUE, user_data_dir = NULL, ...) {
  app_dir <- system.file("shiny-app", package = "B1MGVariantVoting")
  
  if (app_dir == "") {
    stop("Could not find Shiny app directory. Please reinstall the package.")
  }
  
  # Set up external user_data directory
  if (is.null(user_data_dir)) {
    user_data_dir <- get_user_data_dir()
  }
  
  # Initialize the user_data structure
  init_user_data_structure(base_dir = dirname(user_data_dir))
  
  # Set environment variable for the app to use
  Sys.setenv(B1MG_USER_DATA_DIR = user_data_dir)
  
  # Change to app directory but remember current directory
  old_wd <- getwd()
  on.exit(setwd(old_wd))
  setwd(app_dir)
  
  message("Starting B1MG Variant Voting App...")
  message("App directory: ", app_dir)
  message("User data directory: ", user_data_dir)
  
  shiny::runApp(
    appDir = app_dir,
    host = host,
    port = port,
    launch.browser = launch.browser,
    ...
  )
}

#' Get the path to the Shiny app directory
#'
#' @return Character path to the Shiny app directory
#' @export
get_app_dir <- function() {
  system.file("shiny-app", package = "B1MGVariantVoting")
}

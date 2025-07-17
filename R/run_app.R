#' Get the path to the Shiny app directory
#'
#' @return Character path to the Shiny app directory
#' @export
get_app_dir <- function() {
  system.file("shiny-app", package = "ShinyImgVoteR")
}

#' Run B1MG Variant Voting Shiny Application
#'
#' This function launches the B1MG Variant Voting Shiny application.
#'
#' @param host Character. Host to run the application on. Default is "127.0.0.1"
#' @param port Integer. Port to run the application on. Default is NULL (random port)
#' @param launch.browser Logical. Should the browser be launched? Default is TRUE
#' @param config_file_path Character. Path to the configuration file. Default is the on in the app directory
#'
#' @return Runs the Shiny application
#' @export
#'
#' @examples
#' \dontrun{
#' run_voting_app()
#' run_voting_app(user_data_dir = "/path/to/my/user_data")
#' run_voting_app(database_path = "/path/to/my/database.sqlite")
#' }
run_voting_app <- function(
    host = "127.0.0.1", 
    port = 8000, 
    launch.browser = TRUE, 
    config_file_path = file.path(
      get_app_dir(), "default_env", "config", "config.yaml"
    ),
    ...
  ) {
  app_dir <- system.file("shiny-app", package = "ShinyImgVoteR")

  init_environment(config_file_path)
  
  # Set up external environment
  # if (is.null(cfg$user_data_dir)) {
  #   user_data_dir <- get_user_data_dir()
  # }
  
  # # Initialize the user_data structure
  # init_user_data_structure(base_dir = dirname(user_data_dir))
  
  # Initialize external database
  # if (is.null(database_path)) {
  #   database_path <- init_external_database(base_dir = dirname(user_data_dir))
  # }
  
  # # Set environment variables for the app to use
  # Sys.setenv(IMGVOTER_USER_DATA_DIR = user_data_dir)
  # Sys.setenv(IMGVOTER_DATABASE_PATH = database_path)
  
  # # Change to app directory but remember current directory
  # old_wd <- getwd()
  # on.exit(setwd(old_wd))
  # setwd(app_dir)

  # Sys.setenv("IMGVOTER_CURRENT_DIR" = old_wd)
  
  # message("Starting B1MG Variant Voting App...")
  # message("App directory: ", app_dir)
  # message("User data directory: ", user_data_dir)
  # message("Database path: ", database_path)
  
  shiny::runApp(
    appDir = app_dir,
    host = host,
    port = port,
    launch.browser = launch.browser,
    ...
  )
}
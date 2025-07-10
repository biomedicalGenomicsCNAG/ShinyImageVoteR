#' Run B1MG Variant Voting Shiny Application
#'
#' This function launches the B1MG Variant Voting Shiny application.
#'
#' @param host Character. Host to run the application on. Default is "127.0.0.1"
#' @param port Integer. Port to run the application on. Default is NULL (random port)
#' @param launch.browser Logical. Should the browser be launched? Default is TRUE
#' @param ... Additional arguments passed to shiny::runApp()
#'
#' @return Runs the Shiny application
#' @export
#'
#' @examples
#' \dontrun{
#' run_voting_app()
#' }
run_voting_app <- function(host = "127.0.0.1", port = NULL, launch.browser = TRUE, ...) {
  app_dir <- system.file("shiny-app", package = "B1MGVariantVoting")
  
  if (app_dir == "") {
    stop("Could not find Shiny app directory. Please reinstall the package.")
  }
  
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

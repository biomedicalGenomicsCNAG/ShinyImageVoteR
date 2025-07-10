#' Launch the B1MG Variant Voting Shiny application
#'
#' This helper makes it easy to run the packaged app via `B1MGVariantVoting::run_app()`.
#' @export
run_app <- function(port = 8000, launch.browser = TRUE) {
  shiny::runApp(shiny::getwd(), port = port, launch.browser = launch.browser)
}

#' About module UI
#'
#' Provides a static informational page describing the purpose and functionality
#' of the B1MG Variant Voting application. This module does not require server-side logic.
#'
#' @param id A string identifier for the module namespace.
#'
#' @return A Shiny UI element (`fluidPage`) for rendering the about page.
#' @export
aboutUI <- function(id, cfg) {
  ns <- shiny::NS(id)
  shiny::fluidPage(
    theme = cfg$theme,
    shiny::h3("About this app"),
    shiny::p("This app allows users to vote on somatic mutations in images."),
    shiny::p("Users can log in, view images, and provide their votes and comments."),
    shiny::p("The app tracks user sessions and stores annotations in a SQLite database."),
    shiny::p("Developed by Ivo Christopher Leist")
  )
}

#' About module server logic
#'
#' Placeholder server function for the about module. No reactivity or logic is required,
#' but the function must exist to satisfy Shiny module conventions.
#'
#' @param id A string identifier for the module namespace.
#'
#' @return None. Side effect only: registers a module server.
#' @export
aboutServer <- function(id, cfg) {
  moduleServer(id, function(input, output, session) {
    # No server-side logic needed for the about page
  })
}

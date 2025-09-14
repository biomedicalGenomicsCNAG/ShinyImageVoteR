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
#' @param cfg App configuration
#' @param tab_trigger Optional reactive that triggers when the about tab is selected
#'
#' @return None. Side effect only: registers a module server.
#' @export
aboutServer <- function(id, cfg, tab_trigger = NULL) {
  moduleServer(id, function(input, output, session) {
    # Create a reactive that triggers when the user stats tab is selected
    # This allows automatic refresh when navigating to the stats page
    tab_change_trigger <- reactive({
      if (!is.null(tab_trigger)) {
        tab_trigger()
      } else {
        NULL
      }
    })

    # Dummy listener so the URL query string gets
    # updated when navigating to the tab
    observe({
      tab_change_trigger()
    })
  })
}

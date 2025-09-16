#' FAQ module UI
#'
#' Provides a static informational page describing the purpose and functionality
#' of the B1MG Variant Voting application.
#'
#' @param id A string identifier for the module namespace.
#'
#' @return A Shiny UI element (`fluidPage`) for rendering the about page.
#' @export
faqUI <- function(id, cfg) {
  shiny::includeMarkdown(file.path(get_app_dir(), "docs", "faq.md"))
}

#' FAQ module server logic
#'
#' @param id A string identifier for the module namespace.
#' @param cfg App configuration
#' @param tab_trigger Optional reactive that triggers when the about tab is selected
#'
#' @return None. Side effect only: registers a module server.
#' @export
faqServer <- function(id, cfg, tab_trigger = NULL) {
  shiny::moduleServer(id, function(input, output, session) {
    # Create a reactive that triggers when the user stats tab is selected
    # This allows automatic refresh when navigating to the stats page
    tab_change_trigger <- shiny::reactive({
      if (!is.null(tab_trigger)) {
        tab_trigger()
      } else {
        NULL
      }
    })

    # Dummy listener so the URL query string gets
    # updated when navigating to the tab
    shiny::observe({
      tab_change_trigger()
    })
  })
}

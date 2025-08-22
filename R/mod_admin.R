#' Admin module UI
#'
#' Displays password retrieval tokens for users who have not retrieved their password yet.
#'
#' @param id Module namespace
#' @param cfg App configuration object
#'
#' @return A Shiny UI element
#' @export
adminUI <- function(id, cfg) {
  ns <- shiny::NS(id)
  shiny::fluidPage(
    theme = cfg$theme,
    shiny::tableOutput(ns("tokens_table")),
    shiny::actionButton(ns("refresh_tokens"), "Refresh tokens")
  )
}

#' Admin module server
#'
#' Shows password retrieval tokens for users who have not accessed their retrieval link.
#'
#' @param id Module namespace
#' @param cfg App configuration
#' @param login_trigger Reactive containing login data
#' @param db_pool Database connection pool
#' @param tab_trigger Optional reactive triggered when admin tab is selected
#' @export
adminServer <- function(id, cfg, login_trigger, db_pool, tab_trigger = NULL) {
  moduleServer(id, function(input, output, session) {
    tab_change_trigger <- reactive({
      if (!is.null(tab_trigger)) {
        tab_trigger()
      } else {
        NULL
      }
    })

    tokens <- eventReactive(c(login_trigger(), input$refresh_tokens, tab_change_trigger()), {
      req(login_trigger()$admin == 1)
      DBI::dbGetQuery(
        db_pool,
        paste(
          "SELECT userid, pwd_retrieval_token FROM passwords",
          "WHERE pwd_retrieval_token IS NOT NULL AND pwd_retrieved_timestamp IS NULL"
        )
      )
    })

    output$tokens_table <- renderTable({
      tokens()
    })

    return(tokens)
  })
}

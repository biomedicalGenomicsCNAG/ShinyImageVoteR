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
    DT::dataTableOutput(ns("pwd_retrieval_table")),
    shiny::actionButton(ns("refresh_tokens"), "Refresh")
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

    pwd_retrieval_tbl <- eventReactive(c(login_trigger(), input$refresh_tokens, tab_change_trigger()), {
      req(login_trigger()$admin == 1)
      DBI::dbGetQuery(
        db_pool,
        paste(
          "SELECT userid, pwd_retrieval_token FROM passwords",
          "WHERE pwd_retrieval_token IS NOT NULL AND pwd_retrieved_timestamp IS NULL"
        )
      )
    })

    output$pwd_retrieval_table <- DT::renderDT(
      {
        tbl <- pwd_retrieval_tbl()

        # Get current URL components
        protocol <- if (session$clientData$url_port == 443) "https://" else "http://"
        hostname <- session$clientData$url_hostname
        port <- if (session$clientData$url_port %in% c(80, 443)) "" else paste0(":", session$clientData$url_port)
        base_url <- paste0(protocol, hostname, port)

        tbl$link <- paste0(
          base_url,
          "?pwd_retrieval_token=",
          tbl$pwd_retrieval_token
        )

        # Add email template button
        tbl$email_btn <- sprintf(
          '<button class="btn btn-primary btn-sm" onclick="Shiny.setInputValue(\'%s\', \'%s\', {priority: \'event\'});">Email Template</button>',
          session$ns("email_template_btn"),
          tbl$userid
        )

        # Remove the password retrieval token column
        tbl$pwd_retrieval_token <- NULL
        colnames(tbl) <- c("User ID", "Password Retrieval Link", "Email Template")
        tbl
      },
      escape = FALSE,
      options = list(pageLength = 10)
    )

    # Handle email template button clicks
    observeEvent(input$email_template_btn, {
      user_id <- input$email_template_btn
      tbl <- pwd_retrieval_tbl()
      user_row <- tbl[tbl$userid == user_id, ]

      if (nrow(user_row) > 0) {
        # Get current URL components
        protocol <- if (session$clientData$url_port == 443) "https://" else "http://"
        hostname <- session$clientData$url_hostname
        port <- if (session$clientData$url_port %in% c(80, 443)) "" else paste0(":", session$clientData$url_port)
        base_url <- paste0(protocol, hostname, port)

        retrieval_link <- paste0(base_url, "?pwd_retrieval_token=", user_row$pwd_retrieval_token)

        email_template <- paste0(
          "Subject: Password for the B1MG Variant Voting beta\n\n",
          "Dear ", user_id, ",\n\n",
          "Your account has been created in order to retrieve the password please click on the following link:\n\n",
          retrieval_link, "\n\n",
          "Note, this link will work only once. So store the displayed password immediately!\n\n",
          "If you have any questions, please contact help.b1mg@cnag.eu\n\n",
          "Kind regards,\n",
          "The B1MG Variant Voting Admin Team at CNAG"
        )

        showModal(modalDialog(
          title = paste("Email Template for", user_id),
          tags$pre(style = "white-space: pre-wrap; font-family: monospace;", email_template),
          easyClose = TRUE,
          footer = modalButton("Close")
        ))
      }
    })
  })
}

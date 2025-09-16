#' Admin module UI
#'
#' Displays password retrieval tokens for users who have not retrieved their password yet and
#' allows admins to add new users.
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
    # shiny::br(),
    # shiny::fluidRow(
    #   shiny::column(
    #     4,
    #     shiny::textInput(ns("new_userid"), "User ID")
    #   ),
    #   shiny::column(
    #     4,
    #     shiny::textInput(ns("new_institute"), "Institute")
    #   ),
    #   shiny::column(
    #     2,
    #     shiny::actionButton(ns("add_user"), "Add user")
    #   ),
    #   shiny::column(
    #     2,
    #     shiny::actionButton(ns("refresh_tokens"), "Refresh")
    #   )
    # )
  )
}

#' Admin module server
#'
#' Shows password retrieval tokens for users who have not accessed their retrieval link and
#' allows admins to add new users.
#'
#' @param id Module namespace
#' @param cfg App configuration
#' @param login_trigger Reactive containing login data
#' @param db_pool Database connection pool
#' @param tab_trigger Optional reactive triggered when admin tab is selected
#' @export
adminServer <- function(id, cfg, login_trigger, db_pool, tab_trigger = NULL) {
  shiny::moduleServer(id, function(input, output, session) {
    # Reactive trigger for table refresh
    table_refresh_trigger <- shiny::reactiveVal(0)

    tab_change_trigger <- shiny::reactive({
      if (!is.null(tab_trigger)) {
        tab_trigger()
      } else {
        NULL
      }
    })

    pwd_retrieval_tbl <- shiny::eventReactive(
      c(
        login_trigger(),
        input$refresh_tokens,
        tab_change_trigger(),
        table_refresh_trigger()
      ),
      {
        shiny::req(login_trigger()$admin == 1)
        DBI::dbGetQuery(
          db_pool,
          paste(
            "SELECT userid, institute, pwd_retrieval_token FROM passwords",
            "WHERE pwd_retrieval_token IS NOT NULL AND pwd_retrieved_timestamp IS NULL"
          )
        )
      }
    )

    output$pwd_retrieval_table <- DT::renderDT({
      tbl <- pwd_retrieval_tbl()

      # TODO
      # it is no working on the production server
      # https://simplevm-proxy-prod.denbi.dkfz.de/automaticlobster_100/b1mg-variant-voter-beta/?
      # there the following gets rendered:
      # http://simplevm-proxy-prod.denbi.dkfz.de:?pwd_retrieval_token=<token>

      # TODO
      # Put below in a function to reduce code duplication
      # --- Build base URL
      protocol <- if (session$clientData$url_port == 443) {
        "https://"
      } else {
        "http://"
      }
      hostname <- session$clientData$url_hostname
      port <- if (session$clientData$url_port %in% c(80, 443)) {
        ""
      } else {
        paste0(":", session$clientData$url_port)
      }
      base_url <- paste0(protocol, hostname, port)

      # --- rows
      tbl$link <- paste0(
        base_url,
        "?pwd_retrieval_token=",
        tbl$pwd_retrieval_token
      )
      tbl$email_btn <- sprintf(
        '<button class="btn btn-primary btn-sm" onclick="Shiny.setInputValue(\'%s\', \'%s\', {priority: \'event\'});">Email Template</button>',
        session$ns("email_template_btn"),
        tbl$userid
      )
      # Remove the password retrieval token column
      tbl$pwd_retrieval_token <- NULL
      cols <- c("User ID", "Institute", "Password Retrieval Link", "Action")
      names(tbl) <- cols

      # Ensure character cols & base df
      tbl[] <- lapply(tbl, as.character)
      tbl <- as.data.frame(tbl, stringsAsFactors = FALSE, check.names = FALSE)

      # --- Dummy new row (names & order must match `cols`)
      ns <- session$ns

      add_new_user_btn_html <- sprintf(
        '<button class="btn btn-success btn-sm"
                  title="Add user"
                  onclick="(function(){
                    var u = document.getElementById(\'%s\').value.trim();
                    var i = document.getElementById(\'%s\').value.trim();
                    // nonce ensures the event fires even with same values
                    Shiny.setInputValue(\'%s\', {userid: u, institute: i, nonce: Math.random()}, {priority:\'event\'});
                  })()">
            &#x2795; new user
          </button>',
        ns("new_userid"),
        ns("new_institute"),
        ns("add_user_btn")
      )

      new_row <- data.frame(
        `User ID` = as.character(shiny::textInput(
          ns("new_userid"),
          NULL,
          width = "100%"
        )),
        Institute = as.character(shiny::textInput(
          ns("new_institute"),
          NULL,
          width = "100%"
        )),
        `Password Retrieval Link` = "",
        Action = add_new_user_btn_html,
        stringsAsFactors = FALSE,
        check.names = FALSE
      )
      new_row <- new_row[, cols, drop = FALSE] # enforce same order

      # Prefer bind_rows for robustness; could also do: rbind(new_row[cols], tbl)
      show_df <- dplyr::bind_rows(new_row, tbl)

      DT::datatable(
        show_df,
        escape = FALSE,
        selection = "none",
        rownames = FALSE,
        options = list(pageLength = 10)
      )
    })

    # Handle email template button clicks
    shiny::observeEvent(input$email_template_btn, {
      user_id <- input$email_template_btn
      tbl <- pwd_retrieval_tbl()
      user_row <- tbl[tbl$userid == user_id, ]

      if (nrow(user_row) > 0) {
        # Get current URL components
        protocol <- if (session$clientData$url_port == 443) {
          "https://"
        } else {
          "http://"
        }
        hostname <- session$clientData$url_hostname
        port <- if (session$clientData$url_port %in% c(80, 443)) {
          ""
        } else {
          paste0(":", session$clientData$url_port)
        }
        base_url <- paste0(protocol, hostname, port)

        retrieval_link <- paste0(
          base_url,
          "?pwd_retrieval_token=",
          user_row$pwd_retrieval_token
        )

        email_template <- paste0(
          "Subject: Password for the B1MG Variant Voting beta\n\n",
          "Dear ",
          user_id,
          ",\n\n",
          "Your account has been created in order to retrieve the password please click on the following link:\n\n",
          retrieval_link,
          "\n\n",
          "Note, this link will work only once. So store the displayed password immediately!\n\n",
          "If you have any questions, please contact help.b1mg@cnag.eu\n\n",
          "Kind regards,\n",
          "The B1MG Variant Voting Admin Team at CNAG"
        )

        shiny::showModal(shiny::modalDialog(
          title = paste("Email Template for", user_id),
          shiny::tags$pre(
            style = "white-space: pre-wrap; font-family: monospace;",
            email_template
          ),
          easyClose = TRUE,
          footer = shiny::modalButton("Close")
        ))
      }
    })

    shiny::observeEvent(input$add_user_btn, {
      print("Add user button clicked")

      shiny::req(login_trigger()$admin == 1)
      user_id <- trimws(input$add_user_btn$userid)
      institute <- trimws(input$add_user_btn$institute %||% "")

      if (user_id == "" || institute == "") {
        shiny::showModal(shiny::modalDialog(
          title = "Missing information",
          "Please provide both user ID and institute.",
          easyClose = TRUE,
          footer = shiny::modalButton("Close")
        ))
        return()
      }

      existing <- DBI::dbGetQuery(
        db_pool,
        "SELECT userid FROM passwords WHERE userid = ?",
        params = list(user_id)
      )

      if (nrow(existing) > 0) {
        shiny::showModal(shiny::modalDialog(
          title = "User exists",
          "A user with this ID already exists.",
          easyClose = TRUE,
          footer = shiny::modalButton("Close")
        ))
        return()
      }

      password <- generate_password()
      token <- digest::digest(paste0(user_id, Sys.time(), runif(1)))

      DBI::dbExecute(
        db_pool,
        "INSERT INTO passwords (userid, institute, password, admin, pwd_retrieval_token, pwd_retrieved_timestamp) VALUES (?, ?, ?, 0, ?, NULL)",
        params = list(user_id, institute, password, token)
      )

      protocol <- if (session$clientData$url_port == 443) {
        "https://"
      } else {
        "http://"
      }
      hostname <- session$clientData$url_hostname
      port <- if (session$clientData$url_port %in% c(80, 443)) {
        ""
      } else {
        paste0(":", session$clientData$url_port)
      }
      base_url <- paste0(protocol, hostname, port)
      retrieval_link <- paste0(base_url, "?pwd_retrieval_token=", token)

      shiny::showModal(shiny::modalDialog(
        title = paste("User", user_id, "added"),
        shiny::tags$pre(
          style = "white-space: pre-wrap; font-family: monospace;",
          "User successfully added and password generated."
        ),
        easyClose = TRUE,
        footer = shiny::modalButton("Close")
      ))

      # Clear fields and refresh table
      shinyjs::runjs(sprintf(
        "document.getElementById('%s').value=''; document.getElementById('%s').value='';",
        session$ns("new_userid"),
        session$ns("new_institute")
      ))

      # Trigger table refresh
      table_refresh_trigger(table_refresh_trigger() + 1)
    })
  })
}

# TODO
# Allow the upload of user data via CSV/TSV
# Columns: UserID/Institute/Password/Admin
# To enable bulk user creation

# TODO
# The addition of new users should update the
# institute2userids2password.yaml file accordingly.

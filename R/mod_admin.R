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
    DT::dataTableOutput(ns("users_table")),
    shiny::div(
      shiny::actionButton(ns("refresh_tokens"), "Refresh"),
      shiny::actionButton(
        ns("download_annotations_btn"),
        "Download annotations",
        class = "btn btn-secondary"
      ),
      shiny::downloadButton(
        ns("download_annotations"),
        "Download annotations",
        style = "display:none;"
      )
    )
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

    users_tbl <- shiny::eventReactive(
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

    users_table_display <- shiny::reactive({
      raw_tbl <- users_tbl()
      base_url <- build_base_url(session)
      display_tbl <- raw_tbl
      display_tbl$link <- paste0(
        base_url,
        "?pwd_retrieval_token=",
        raw_tbl$pwd_retrieval_token
      )
      display_tbl$email_btn <- sprintf(
        '<button
            class="btn btn-primary btn-sm"
            onclick="Shiny.setInputValue(
              \'%s\', \'%s\',
              {priority: \'event\'});"
        >
          Email Template
        </button>',
        session$ns("email_template_btn"),
        raw_tbl$userid
      )
      display_tbl$pwd_retrieval_token <- NULL
      cols <- c("User ID", "Institute", "Password Retrieval Link", "Action")
      names(display_tbl) <- cols

      display_tbl[] <- lapply(display_tbl, as.character)
      display_tbl <- as.data.frame(display_tbl, stringsAsFactors = FALSE, check.names = FALSE)

      ns <- session$ns

      add_new_user_btn_html <- sprintf(
        '<button
            class="btn btn-success btn-sm"
            title="Add user"
            onclick="(function(){
              var u = document.getElementById(\'%s\').value.trim();
              var i = document.getElementById(\'%s\').value.trim();
              // nonce ensures the event fires even with same values
              Shiny.setInputValue(
                \'%s\',
                {userid: u, institute: i, nonce: Math.random()},
                {priority:\'event\'}
              );
            })()"
        >
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
      new_row <- new_row[, cols, drop = FALSE]

      show_df <- dplyr::bind_rows(new_row, display_tbl)

      list(
        display = show_df,
        raw = raw_tbl,
        row_lookup = c(NA_integer_, seq_len(nrow(raw_tbl)))
      )
    })

    output$users_table <- DT::renderDT({
      data <- users_table_display()
      DT::datatable(
        data$display,
        escape = FALSE,
        selection = list(mode = "single", target = "row"),
        rownames = FALSE,
        extensions = "Select",
        options = list(
          dom = "frtip",
          pageLength = 10,
          select = list(style = "single")
        )
      )
    })

    # Handle email template button clicks
    shiny::observeEvent(input$email_template_btn, {
      user_id <- input$email_template_btn
      tbl <- users_tbl()
      user_row <- tbl[tbl$userid == user_id, ]

      if (nrow(user_row) > 0) {
        # Get base URL using helper function
        base_url <- build_base_url(session)

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

      base_url <- build_base_url(session)
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

    download_context <- shiny::reactiveVal(NULL)

    shiny::observeEvent(input$download_annotations_btn, {
      table_data <- users_table_display()
      selected <- input$users_table_rows_selected

      if (length(selected) == 0) {
        shiny::showModal(shiny::modalDialog(
          title = "Select a user",
          "Please select a user before downloading annotations.",
          easyClose = TRUE,
          footer = shiny::modalButton("Close")
        ))
        return()
      }

      selected_idx <- as.integer(selected[1])
      row_lookup <- table_data$row_lookup %||% integer(0)

      if (selected_idx < 1 || selected_idx > length(row_lookup)) {
        shiny::showModal(shiny::modalDialog(
          title = "Select a user",
          "Please choose a valid user row before downloading annotations.",
          easyClose = TRUE,
          footer = shiny::modalButton("Close")
        ))
        return()
      }

      raw_idx <- row_lookup[selected_idx]
      raw_tbl <- table_data$raw

      if (is.na(raw_idx) || raw_idx < 1 || raw_idx > nrow(raw_tbl)) {
        shiny::showModal(shiny::modalDialog(
          title = "Select a user",
          "Please select a user row (not the input row) before downloading annotations.",
          easyClose = TRUE,
          footer = shiny::modalButton("Close")
        ))
        return()
      }

      user_id <- raw_tbl$userid[raw_idx]
      institute <- raw_tbl$institute[raw_idx]

      user_id <- trimws(ifelse(is.na(user_id), "", as.character(user_id)))
      institute <- trimws(ifelse(is.na(institute), "", as.character(institute)))

      if (user_id == "" || institute == "") {
        shiny::showModal(shiny::modalDialog(
          title = "Select a user",
          "Please select a user row (not the input row) before downloading annotations.",
          easyClose = TRUE,
          footer = shiny::modalButton("Close")
        ))
        return()
      }

      base_dir <- Sys.getenv("IMGVOTER_USER_DATA_DIR", unset = cfg$user_data_dir %||% "")

      if (base_dir == "") {
        shiny::showModal(shiny::modalDialog(
          title = "Configuration error",
          "The user data directory is not configured.",
          easyClose = TRUE,
          footer = shiny::modalButton("Close")
        ))
        return()
      }

      annotations_path <- file.path(
        base_dir,
        institute,
        user_id,
        paste0(user_id, "_annotations.tsv")
      )

      if (!file.exists(annotations_path)) {
        shiny::showModal(shiny::modalDialog(
          title = "File not found",
          paste0(
            "No annotation file was found for user ",
            user_id,
            " at institute ",
            institute,
            "."
          ),
          easyClose = TRUE,
          footer = shiny::modalButton("Close")
        ))
        return()
      }

      download_context(list(
        userid = user_id,
        institute = institute,
        path = annotations_path
      ))

      shinyjs::runjs(sprintf(
        "document.getElementById('%s').click();",
        session$ns("download_annotations")
      ))
    })

    output$download_annotations <- shiny::downloadHandler(
      filename = function() {
        ctx <- download_context()
        shiny::req(ctx)
        basename(ctx$path)
      },
      content = function(file) {
        ctx <- download_context()
        shiny::req(ctx)
        if (!file.exists(ctx$path)) {
          stop("Annotation file no longer exists.")
        }
        file.copy(ctx$path, file, overwrite = TRUE)
      }
    )
  })
}

# TODO
# Allow the upload of user data via CSV/TSV
# Columns: UserID/Institute/Password/Admin
# To enable bulk user creation

# TODO
# The addition of new users should update the
# institute2userids2password.yaml file accordingly.

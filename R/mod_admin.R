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
    shinyjs::useShinyjs(),
    shiny::div(
      class = "d-flex gap-2 mb-3",
      shiny::actionButton(ns("refresh_tokens"), "Refresh"),
      shiny::actionButton(ns("download_annotations_btn"), "Download annotations"),
      shiny::downloadButton(
        ns("download_annotations"),
        label = "",
        style = "display: none;"
      )
    ),
    DT::dataTableOutput(ns("users_table"))
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

    # Helper function to count votes for a user
    count_user_votes <- function(userid, institute) {
      user_dir <- file.path(cfg$user_data_dir, institute, userid)
      user_annotations_file <- file.path(user_dir, paste0(userid, "_annotations.tsv"))
      
      if (!file.exists(user_annotations_file)) {
        return(0)
      }
      
      tryCatch({
        user_annotations_df <- read.table(
          user_annotations_file,
          header = TRUE,
          sep = "\t",
          stringsAsFactors = FALSE
        )
        sum(!is.na(user_annotations_df$shinyauthr_session_id))
      }, error = function(e) {
        return(0)
      })
    }

    users_tbl <- shiny::eventReactive(
      c(
        login_trigger(),
        input$refresh_tokens,
        tab_change_trigger(),
        table_refresh_trigger()
      ),
      {
        shiny::req(login_trigger()$admin == 1)
        # Get all users from the database
        all_users <- DBI::dbGetQuery(
          db_pool,
          "SELECT userid, institute, pwd_retrieval_token, pwd_retrieved_timestamp FROM passwords"
        )
        
        # Add vote counts for each user
        all_users$votes_count <- mapply(
          count_user_votes,
          all_users$userid,
          all_users$institute,
          SIMPLIFY = TRUE
        )
        
        all_users
      }
    )

    output$users_table <- DT::renderDT({
      tbl <- users_tbl()
      base_url <- build_base_url(session)
      
      # --- rows
      # Create password retrieval link only for users with pending tokens
      tbl$link <- ifelse(
        !is.na(tbl$pwd_retrieval_token) & is.na(tbl$pwd_retrieved_timestamp),
        paste0(base_url, "?pwd_retrieval_token=", tbl$pwd_retrieval_token),
        ""
      )
      
      # Create email button only for users with pending tokens
      tbl$email_btn <- ifelse(
        !is.na(tbl$pwd_retrieval_token) & is.na(tbl$pwd_retrieved_timestamp),
        sprintf(
          '<button
              class="btn btn-primary btn-sm"
              onclick="Shiny.setInputValue(
                \'%s\', \'%s\',
                {priority: \'event\'});"
          >
            Email Template
          </button>',
          session$ns("email_template_btn"),
          tbl$userid
        ),
        ""
      )
      
      # Remove the password retrieval token column
      tbl$pwd_retrieval_token <- NULL
      tbl$pwd_retrieved_timestamp <- NULL
      
      cols <- c("User ID", "Institute", "Votes Count", "Password Retrieval Link", "Action")
      names(tbl) <- cols

      # Ensure character cols & base df
      tbl[] <- lapply(tbl, as.character)
      tbl <- as.data.frame(tbl, stringsAsFactors = FALSE, check.names = FALSE)

      # --- Dummy new row (names & order must match `cols`)
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
        `Votes Count` = "",
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
        rownames = FALSE,
        extensions = c("Buttons"),
        selection = list(mode = "single", target = "row"),
        options = list(
          pageLength = 10,
          dom = "Blfrtip", # enables buttons
          buttons = list(
            "selectAll",
            "selectNone"
          )
        )
      )
    })

    # Track selected user
    selected_user <- shiny::reactive({
      sel <- input$users_table_rows_selected
      tbl <- users_tbl()

      if (length(sel) == 0 || is.null(tbl) || nrow(tbl) == 0) {
        return(NULL)
      }

      idx <- sel[1] - 1

      if (idx < 1 || idx > nrow(tbl)) {
        return(NULL)
      }

      list(
        userid = tbl$userid[idx],
        institute = tbl$institute[idx]
      )
    })

    shiny::observe({
      shinyjs::toggleState("download_annotations_btn", condition = !is.null(selected_user()))
    })

    selected_annotation_path <- shiny::reactiveVal(NULL)

    find_annotation_file <- function(user_info) {
      if (is.null(user_info)) {
        return(NULL)
      }

      user_dir <- file.path(cfg$user_data_dir, user_info$institute, user_info$userid)

      if (!dir.exists(user_dir)) {
        return(NULL)
      }

      preferred <- file.path(user_dir, paste0(user_info$userid, "_annotations.tsv"))

      if (file.exists(preferred)) {
        print(paste("Found preferred annotation file:", preferred))
        return(preferred)
      }

      files <- list.files(user_dir, pattern = "_annotations\\.tsv$", full.names = TRUE)

      if (length(files) == 0) {
        return(NULL)
      }

      print("Annotations files found:")
      print(files)

      files[[1]]
    }

    output$download_annotations <- shiny::downloadHandler(
      filename = function() {
        path <- selected_annotation_path()

        shiny::req(path)
        shiny::req(file.exists(path))

        basename(path)
      },
      content = function(file) {
        path <- selected_annotation_path()

        shiny::req(path)
        shiny::req(file.exists(path))

        # normalize for weird relative paths / symlinks
        src <- normalizePath(path, mustWork = TRUE)
        dst <- normalizePath(file, mustWork = FALSE)

        tryCatch(
          {
            ok <- file.copy(src, dst, overwrite = TRUE)
            if (!ok) stop("file.copy returned FALSE (likely permissions or path problem)")
          },
          error = function(e) {
            shiny::showNotification(
              paste("Download failed:", conditionMessage(e)),
              type = "error", duration = 7
            )
            stop(e) # rethrow so the browser gets a proper download error
          }
        )
      },
      contentType = "text/tab-separated-values; charset=utf-8"
    )

    shiny::outputOptions(
      output,
      "download_annotations",
      suspendWhenHidden = FALSE
    )

    shiny::observeEvent(selected_user(),
      {
        info <- selected_user()

        if (is.null(info)) {
          selected_annotation_path(NULL)
        }
      },
      ignoreNULL = FALSE
    )

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

    shiny::observeEvent(input$download_annotations_btn, {
      print("Download annotations button clicked")
      info <- selected_user()
      print("Selected user info:")
      print(info)

      annotation_path <- find_annotation_file(info)
      print("Found annotation path:")
      print(annotation_path)

      if (is.null(annotation_path)) {
        print("No annotation file found, showing modal.")
        shiny::showModal(shiny::modalDialog(
          title = "Annotations not found",
          paste0(
            "No annotations file was found for ",
            info$userid,
            " at institute ",
            info$institute,
            "."
          ),
          easyClose = TRUE,
          footer = shiny::modalButton("Close")
        ))
        return()
      }

      print("Setting selected annotation path")
      selected_annotation_path(annotation_path)

      print("Triggering download...")
      print("session$ns('download_annotations'):")
      print(session$ns("download_annotations"))
      shinyjs::runjs(sprintf(
        "document.getElementById('%s').click();",
        session$ns("download_annotations")
      ))
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
  })
}

# TODO
# Allow the upload of user data via CSV/TSV
# Columns: UserID/Institute/Password/Admin
# To enable bulk user creation

# TODO
# The addition of new users should update the
# institute2userids2password.yaml file accordingly.

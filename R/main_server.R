#' Factory function to create the Shiny server for the voting application
#' @param db_pool A database connection pool
#' @return A Shiny server function
#' @export
makeVotingAppServer <- function(db_pool, cfg) {
  function(input, output, session) {
    # Tracks the trigger source of the get_mutation function
    # could be "login", "next", "back", "manual url params change"
    get_mutation_trigger_source <- shiny::reactiveVal(NULL)

    # browser()

    total_images <- DBI::dbGetQuery(
      db_pool,
      "SELECT COUNT(*) as n FROM annotations"
    )$n
    cat(sprintf("Total annotations in DB: %s\n", total_images))

    # Helper function to create a tab trigger reactive
    # Track when a specific tab is selected
    # to trigger automatic refresh of the content in that tab
    make_tab_trigger <- function(tab_name) {
      shiny::reactive({
        shiny::req(input$main_navbar)
        if (input$main_navbar == tab_name) {
          # Return a timestamp to ensure the reactive fires each time the tab is selected
          Sys.time()

          # update tabname by removing spaces and converting to lowercase
          tab_name_clean <- gsub(" ", "_", tolower(tab_name))

          # Update the URL to include the tab name as a query parameter
          new_query_string <- paste0("?tab=", tab_name_clean)
          current_query <- shiny::parseQueryString(
            session$clientData$url_search
          )

          if (tab_name_clean == "vote" && length(current_query) > 0) {
            new_query_string <- paste0(
              new_query_string,
              "&coordinate=",
              current_query[["coordinate"]]
            )
          }

          shiny::updateQueryString(
            new_query_string,
            mode = "replace",
            session = session
          )
        } else {
          NULL
        }
      })
    }

    shiny::observe({
      query <- shiny::parseQueryString(session$clientData$url_search)
      token <- query[["pwd_retrieval_token"]]
      if (!is.null(token)) {
        pwd <- retrieve_password_from_link(token, db_pool)
        print("Retrieved password:")
        print(pwd)
        shiny::showModal(shiny::modalDialog(
          title = "Your password:",
          pwd,
          easyClose = TRUE,
          footer = "Save it this link will expire after you close this dialog"
        ))
      }
    })

    # Initialize the login module
    login_return <- loginServer(
      "login",
      cfg,
      db_conn = db_pool,
      log_out = reactive(logout_init())
    )

    # Initialize the logout module
    logout_init <- shinyauthr::logoutServer(
      id = "logout",
      active = reactive(login_return$credentials()$user_auth)
    )

    output$logged_in <- reactive({
      login_return$credentials()$user_auth
    })
    outputOptions(output, "logged_in", suspendWhenHidden = FALSE)

    login_data <- login_return$login_data

    # Dynamically show/hide admin tab based on user admin status
    admin_tab_added <- shiny::reactiveVal(FALSE)

    shiny::observeEvent(login_data()$admin, {
      is_admin <- isTRUE(login_data()$admin == 1)

      if (is_admin && !admin_tab_added()) {
        shiny::insertTab(
          inputId = "main_navbar",
          tab = shiny::tabPanel("Admin", adminUI("admin", cfg)),
          target = "FAQ",
          position = "after",
          select = FALSE
        )
        admin_tab_added(TRUE)
      } else if (!is_admin && admin_tab_added()) {
        shiny::removeTab(
          inputId = "main_navbar",
          target = "Admin"
        )
        admin_tab_added(FALSE)
      }
    })

    observeEvent(login_data(), {
      req(login_data())
      user_id <- login_data()$user_id
      voting_institute <- login_data()$institute

      session$userData$shinyauthr_session_id <- login_data()$session_id
      cancel_pending_logout(session$userData$shinyauthr_session_id)

      session$userData$userId <- user_id
      session$userData$votingInstitute <- voting_institute

      user_dir <- file.path(
        Sys.getenv("IMGVOTER_USER_DATA_DIR"),
        voting_institute,
        user_id
      )

      print(paste("User directory:", user_dir))
      print(paste("User ID:", user_id))

      session$userData$userInfoFile <- file.path(
        user_dir,
        paste0(user_id, "_info.json")
      )
      session$userData$userAnnotationsFile <- file.path(
        user_dir,
        paste0(user_id, "_annotations.tsv")
      )

      print(paste(
        "User Annotations File:",
        session$userData$userAnnotationsFile
      ))

      safe_dir_create(user_dir)

      # if (!dir.exists(user_dir)) {
      #   cat(sprintf("Creating directory for user: %s at %s\n", user_id, user_dir))
      #   dir.create(user_dir, recursive = TRUE)
      # }

      if (file.exists(session$userData$userInfoFile)) {
        get_mutation_trigger_source("login")
        return()
      }

      # Concatenate time and user_id
      combined <- paste0(user_id, as.numeric(Sys.time()))

      # Create a numeric seed (e.g., using crc32 hash and convert to integer)
      seed <- strtoi(
        substr(digest::digest(combined, algo = "crc32"), 1, 7),
        base = 16
      )
      print("Seed for randomization:")
      print(seed)
      "********"

      # store user info in json file
      set.seed(seed) # Use user_id to create a unique seed

      user_info <- list(
        user_id = user_id,
        voting_institute = voting_institute,
        images_randomisation_seed = seed
      )

      session$userData$sessionInfo <- list(
        start_time = Sys.time(),
        end_time = NA # to be updated when the session ends
      )

      print("User info:")
      print(user_info)

      # create user info file
      jsonlite::write_json(
        user_info,
        session$userData$userInfoFile,
        auto_unbox = TRUE,
        pretty = TRUE
      )

      # create user annotations file
      # query the database for all coordinates
      query <- "SELECT coordinates FROM annotations"
      coords <- DBI::dbGetQuery(db_pool, query)

      coords_vec <- as.character(coords[[1]])
      randomised_coords <- sample(
        coords_vec,
        length(coords_vec),
        replace = FALSE
      )

      # Initialize with empty strings except for coordinates
      annotations_df <- setNames(
        as.data.frame(
          lapply(cfg$user_annotations_colnames, function(col) {
            if (col == "coordinates") {
              randomised_coords
            } else {
              rep("", length(randomised_coords))
            }
          }),
          stringsAsFactors = FALSE
        ),
        cfg$user_annotations_colnames
      )

      # write annotations_df to a text file
      write.table(
        annotations_df,
        file = session$userData$userAnnotationsFile,
        sep = "\t",
        row.names = FALSE,
        col.names = TRUE,
        quote = FALSE
      )
      get_mutation_trigger_source("login")
    })

    observeEvent(logout_init(), {
      if (!is.null(session$userData$shinyauthr_session_id)) {
        print("Logging out user:")
        print("Updating logout time in database")
        print(paste("Session ID:", session$userData$shinyauthr_session_id))
        print("login_return:")
        print(login_return)
        print("login_return$update_logout_time:")
        print(login_return$update_logout_time)
        cancel_pending_logout(session$userData$shinyauthr_session_id)
        login_return$update_logout_time(session$userData$shinyauthr_session_id)
      }
    })

    session$onSessionEnded(function() {
      print("Session ended")
      print(paste("Session ID:", session$userData$shinyauthr_session_id))

      if (!is.null(session$userData$shinyauthr_session_id)) {
        schedule_logout_update(
          session$userData$shinyauthr_session_id,
          function() {
            conn <- pool::poolCheckout(db_pool)
            on.exit(pool::poolReturn(conn))
            login_return$update_logout_time(
              session$userData$shinyauthr_session_id,
              conn = conn
            )
          }
        )
      }
    })

    voting_tab_trigger <- make_tab_trigger("Vote")
    user_stats_tab_trigger <- make_tab_trigger("User stats")
    leaderboard_tab_trigger <- make_tab_trigger("Leaderboard")
    admin_tab_trigger <- make_tab_trigger("Admin")
    faq_tab_trigger <- make_tab_trigger("FAQ")
    about_tab_trigger <- make_tab_trigger("About")

    # initialize modules
    votingServer(
      "voting",
      cfg,
      login_data,
      db_pool,
      get_mutation_trigger_source,
      voting_tab_trigger
    )
    leaderboardServer("leaderboard", cfg, login_data, leaderboard_tab_trigger)
    userStatsServer(
      "userstats",
      cfg,
      login_data,
      db_pool,
      user_stats_tab_trigger
    )
    adminServer("admin", cfg, login_data, db_pool, admin_tab_trigger)
    faqServer("faq", cfg, faq_tab_trigger)
    aboutServer("about", cfg, about_tab_trigger)

    # TODO
    # below is not working

    # every 2 seconds, check for external shutdown file
    observe({
      invalidateLater(2000, session)
      if (file.exists(cfg$shutdown_trigger_file)) {
        print("External shutdown request received.")
        file.remove(cfg$shutdown_trigger_file)
        showNotification(
          "External shutdown request received…",
          type = "warning"
        )
        stopApp()
      }
    })
  }
}

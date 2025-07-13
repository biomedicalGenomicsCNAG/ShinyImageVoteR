#' Factory function to create the Shiny server for the voting application
#' @param db_pool A database connection pool
#' @return A Shiny server function
#' @export
makeVotingAppServer <- function(db_pool) {
  function (input, output, session) {

    cfg <- B1MGVariantVoting::load_config()

    # Tracks the trigger source of the get_mutation function
    # could be "login", "next", "back", "manual url params change"
    get_mutation_trigger_source <- reactiveVal(NULL)
    
    total_images <- DBI::dbGetQuery(db_pool, "SELECT COUNT(*) as n FROM annotations")$n
    cat(sprintf("Total annotations in DB: %s\n", total_images))

    # Initialize the login module
    login_return <- loginServer(
      "login",
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

    observeEvent(login_data(), {
      req(login_data())
      user_id <- login_data()$user_id
      voting_institute <- login_data()$voting_institute
      session$userData$shinyauthr_session_id <- login_data()$session_id
      cancel_pending_logout(session$userData$shinyauthr_session_id)

      session$userData$userId <- user_id
      session$userData$votingInstitute <- voting_institute

      user_dir <- file.path(cfg$user_data_dir, voting_institute, user_id)

      print(paste("User directory:", user_dir))
      print(paste("User ID:", user_id)) 

      session$userData$userInfoFile <- file.path(user_dir, paste0(user_id, "_info.json"))
      session$userData$userAnnotationsFile <- file.path(user_dir, paste0(user_id, "_annotations.tsv"))

      print(paste("User Annotations File:", session$userData$userAnnotationsFile))

      if (!dir.exists(user_dir)) {
        cat(sprintf("Creating directory for user: %s at %s\n", user_id, user_dir))
        dir.create(user_dir, recursive = TRUE)
      }

      if (file.exists(session$userData$userInfoFile)) {
        get_mutation_trigger_source("login")
        return()
      }

      # Concatenate time and user_id
      combined <- paste0(user_id, as.numeric(Sys.time()))

      # Create a numeric seed (e.g., using crc32 hash and convert to integer)
      seed <- strtoi(substr(digest::digest(combined, algo = "crc32"), 1, 7), base = 16)
      print("Seed for randomization:")
      print(seed)
      "********"

      # store user info in json file
      set.seed(seed)  # Use user_id to create a unique seed

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
      randomised_coords <- sample(coords_vec, length(coords_vec), replace = FALSE)

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
    
    # Track when the User stats tab is selected to trigger automatic refresh
    user_stats_tab_trigger <- reactive({
      req(input$main_navbar)
      if (input$main_navbar == "User stats") {
        # Return a timestamp to ensure the reactive fires each time the tab is selected
        Sys.time()
      } else {
        NULL
      }
    })
    
    # Track when the Leaderboard tab is selected to trigger automatic refresh
    leaderboard_tab_trigger <- reactive({
      req(input$main_navbar)
      if (input$main_navbar == "Leaderboard") {
        # Return a timestamp to ensure the reactive fires each time the tab is selected
        Sys.time()
      } else {
        NULL
      }
    })
    
    votingServer("voting", login_data, db_pool, get_mutation_trigger_source)
    leaderboardServer("leaderboard", login_data, leaderboard_tab_trigger)
    userStatsServer("userstats", login_data, db_pool, user_stats_tab_trigger)
    aboutServer("about")

    # TODO
    # below is not working

    # every 2 seconds, check for external shutdown file
    observe({
      invalidateLater(2000, session)
      # print("Checking for external shutdown request…")
      # print(cfg_shutdown_file)
      if (file.exists(cfg$shutdown_file)) {
        print("External shutdown request received.")
        file.remove(cfg$shutdown_file)
        showNotification("External shutdown request received…", type="warning")
        stopApp()
      }
    })
  }
}

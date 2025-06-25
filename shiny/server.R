
library(DBI)
library(data.table)
library(digest)
library(dplyr)
library(jsonlite)
library(RSQLite)
library(shiny)
library(shinyjs)
library(tibble)

source("config.R")
source("ui.R")
source("modules/login_module.R")
source("modules/leaderboard_module.R")
source("modules/user_stats_module.R")
source("modules/about_module.R")

# Initialize the SQLite database
if (!file.exists(cfg_sqlite_file)) {
  source("init_db.R")
}

# create folders for all institutes
lapply(cfg_institute_ids, function(institute) {
  # replace spaces with underscores in institute names
  institute <- gsub(" ", "_", institute)
  dir.create(file.path("user_data", institute), recursive = TRUE, showWarnings = FALSE)
})

server <- function(input, output, session) {

  # Tracks the url parameters be they manually set in the URL or
  # set by the app when the user clicks on the "Back" button
  # or presses "Go back one page" in the browser
  url_params <- reactive({
    # example "?coords=chrY:10935390"
    parseQueryString(session$clientData$url_search)
  })

  # Tracks the trigger source of the get_mutation function
  # could be "login", "next", "back", "manual url params change"
  get_mutation_trigger_source <- reactiveVal(NULL)
  
  # Holds the data of the currently displayed mutation
  current_mutation <- reactiveVal(NULL)

  # Track when the current voting image was rendered
  vote_start_time <- reactiveVal(Sys.time())

  # Connect to the annotations database
  con <- dbConnect(SQLite(), cfg_sqlite_file)
  onStop(function() {
    dbDisconnect(con)
  })
  total_images <- dbGetQuery(con, "SELECT COUNT(*) as n FROM annotations")$n
  cat(sprintf("Total annotations in DB: %s\n", total_images))

  output$page <- renderUI({
    loginUI("login")
  }) 

  login_data <- loginServer("login")

  observeEvent(login_data(), {
    req(login_data())
    user_id <- login_data()$user_id
    voting_institute <- login_data()$voting_institute

    output$page <- renderUI({
      render_voting_page()
    })
    session$userData$userId <- user_id
    session$userData$votingInstitute <- voting_institute

    user_dir <- file.path("user_data", voting_institute, user_id)
    session$userData$userInfoFile <- file.path(user_dir, paste0(user_id, "_info.json"))
    session$userData$userAnnotationsFile <- file.path(user_dir, paste0(user_id, "_annotations.tsv"))

    if (!dir.exists(user_dir)) {
      cat(sprintf("Creating directory for user: %s at %s\n", user_id, user_dir))
      dir.create(user_dir, recursive = TRUE)
    }

    if (file.exists(session$userData$userInfoFile)) {
      # Load existing user info
      user_info_file <- session$userData$userInfoFile
      user_info <- read_json(user_info_file)

      session$userData$sessionInfo <- list(
        start_time = Sys.time(),
        end_time = NA  # to be updated when the session ends
      )

      user_info$sessions[[session$token]] <- session$userData$sessionInfo
      write_json(user_info, user_info_file, auto_unbox = TRUE, pretty = TRUE)
      get_mutation_trigger_source("login")
      return()
    }

    # Concatenate time and user_id
    combined <- paste0(user_id, as.numeric(Sys.time()))

    # Create a numeric seed (e.g., using crc32 hash and convert to integer)
    seed <- strtoi(substr(digest(combined, algo = "crc32"), 1, 7), base = 16)
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
    user_info$sessions[[session$token]] <- session$userData$sessionInfo

    print("User info:")
    print(user_info)

    # create user info file
    write_json(
      user_info,
      session$userData$userInfoFile,
      auto_unbox = TRUE,
      pretty = TRUE
    )

    # create user annotations file
    # query the database for all coordinates
    query <- "SELECT coordinates FROM annotations"
    coords <- dbGetQuery(con, query)

    coords_vec <- as.character(coords[[1]])
    randomised_coords <- sample(coords_vec, length(coords_vec), replace = FALSE)

    # Initialize with empty strings except for coordinates
    annotations_df <- setNames(
      as.data.frame(
        lapply(cfg_user_annotations_colnames, function(col) {
          if (col == "coordinates") {
            randomised_coords
          } else {
            rep("", length(randomised_coords))
          }
        }),
        stringsAsFactors = FALSE
      ),
      cfg_user_annotations_colnames
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

  # Update end_time on session end
  session$onSessionEnded(function() {
    cat(sprintf("Session ended"))
    user_info_file <- session$userData$userInfoFile
    print(paste("User info file:", user_info_file))
    if (is.null(user_info_file)) {
      print("No user info file found.")
      return()
    }
    user_info <- read_json(user_info_file)
    user_info$sessions[[session$token]]$end_time <- Sys.time()
    write_json(user_info, user_info_file, auto_unbox = TRUE, pretty = TRUE)
  })

  observeEvent(input$nextBtn, {
    get_mutation_trigger_source("next")
    showElement("backBtn")
    enable("backBtn")
    
    mut_df <- current_mutation()
    user_annotations_file <- session$userData$userAnnotationsFile

    annotations_df <- read.table(
      user_annotations_file,
      header = TRUE,
      sep = "\t",
      stringsAsFactors = FALSE
    )

    print("Annotations DataFrame before update:")
    print(annotations_df)

    # Update the annotations_df with the new agreement
    coords <- mut_df$coordinates

    print(paste("Updating annotations for coordinates:", coords))
    print(paste("Agreement:", input$agreement))
    print(paste("Alternative vartype:", input$alternative_vartype))
    print(paste("Observation:", input$observation))
    print(paste("Comment:", input$comment))

    # use the row index to update the annotations_df
    rowIdx <- which(annotations_df$coordinates == coords)

    # store the previous agreement for later use
    previous_agreement <- annotations_df[rowIdx, "agreement"]
    already_voted <- !is.na(previous_agreement) && previous_agreement != ""
    new_agreement <- input$agreement

    # always update the agreement and the shiny_session_id
    annotations_df[rowIdx, "agreement"] <- input$agreement 
    annotations_df[rowIdx, "shiny_session_id"] <- session$token

    # only update if provided
    if (!is.null(input$alternative_vartype)) {
      annotations_df[rowIdx, "alternative_vartype"] <- input$alternative_vartype
    }

    if (!is.null(input$observation)) {
      annotations_df[rowIdx, "observation"] <- input$observation
    }

    # handle comment (default NA)
    comment <- NA
    if (input$comment != "") {
      comment <- input$comment
      annotations_df[rowIdx, "comment"] <- comment
    }

    # calculate time spent on the current variant
    time_spent <- as.numeric(difftime(Sys.time(), vote_start_time(), units = "secs"))
    annotations_df[rowIdx, "time_till_vote_casted_in_seconds"] <- time_spent

    print(paste0("already_voted:", already_voted))
    
    if (!already_voted && session$userData$votingInstitute != cfg_test_institute) {
      # Increment the total images voted for the user
      user_info_file <- session$userData$userInfoFile
      user_info <- read_json(user_info_file)
       
      # depending on the agreement, update the vote counts in the database
      vote_col <- cfg_vote2dbcolumn_map[[input$agreement]]

      dbExecute(
        con,
        paste0(
          "UPDATE annotations SET ", 
          vote_col, 
          " = ", vote_col, " + 1 WHERE coordinates = ?"
        ),
        params = list(coords)
      )
    }

    print("Annotations DataFrame after update:")
    print(annotations_df)

    # Write the updated annotations_df back to the file
    write.table(
      annotations_df,
      file = user_annotations_file,
      sep = "\t",
      row.names = FALSE,
      col.names = TRUE,
      quote = FALSE
    )

    if (
      already_voted && 
      previous_agreement != input$agreement 
      && session$userData$votingInstitute != cfg_test_institute
      ) {
      files <- list.files(
        path = "user_data", 
        pattern = "\\.txt$", 
        full.names = TRUE,
        recursive = TRUE
      )
      print("already_voted -> Files to read for annotations:")
      print(files)

      # Exclude files from the cfg_test_institute folder
      files <- files[!grepl(paste0(cfg_test_institute,"/"), files)]

      # get all rows with the same coordinates from all user annotation files
      same_coords_df <- rbindlist(lapply(files, function(f) {
        dt <- fread(f)
        dt_sub <- dt[grepl(coords, coordinates)]
        if (nrow(dt_sub)) dt_sub[, file := basename(f)]
        dt_sub
      }), use.names = TRUE, fill = TRUE) 

      print("Resulting DataFrame after reading all user annotations:")
      print(same_coords_df)

      # Count the different agreements (yes, no, diff_var, not_confident)
      agreement_counts_df <- same_coords_df %>%
        group_by(agreement) %>%
        summarise(count = n(), .groups = 'drop')
      print("Counts of agreements:")
      print(counts)

      # loop over the agreement_counts_df and update the vote counts in the database
      for (i in 1:nrow(agreement_counts_df)) {
        agreement <- agreement_counts_df$agreement[i]
        count <- agreement_counts_df$count[i] 
        vote_col <- vote2dbcolumn_map[[agreement]]
        if (!is.null(vote_col)) {
          dbExecute(
            con,
            paste0(
              "UPDATE annotations SET ", 
              vote_col, 
              " = ", vote_col, " + ", count, 
              " WHERE coordinates = ?"
            ),
            params = list(coords)
          )
        }
      }
      print("Vote counts updated in the database based on all user annotations.")
    }
    print("Annotations saved successfully.")
  })

  observeEvent(url_params(), {
    get_mutation_trigger_source("url-params-change")
  })

  # Triggered when the user logs in, clicks the next button, 
  # or goes back (with the actionButton "Back" or browser back button)
  get_mutation <- eventReactive(c(input[["login-loginBtn"]], input$nextBtn, url_params()), {
    user_annotations_file <- session$userData$userAnnotationsFile

    annotations_df <- read.table(
      user_annotations_file,
      header = TRUE,
      sep = "\t",
      stringsAsFactors = FALSE
    )

    # actionButton "Back" or Go back one page in browser pressed
    print("Checking if the user pressed the Back button or went back in the browser...")
    if (get_mutation_trigger_source() == "url-params-change") {
      print("URL change detected, showing the image from the URL.")
      # Get the coordinates from the URL
      coords <- parseQueryString(session$clientData$url_search)$coords
      if (is.null(coords)) {
        print("No coordinates found in the URL or all variants have been voted on.")
        return(NULL)
      }

      if (coords == "done") {
        print("All variants have been voted on.")
        res <- tibble(
          rowid = NA,
          coordinates = "You have already voted on all variants in this category!",
          REF = "-",
          ALT = "-",
          variant = NA,
          path = "https://imgpile.com/images/Ud9lAi.jpg"
        )

        hideElement("voting_questions_div")
        hideElement("nextBtn")
        disable("nextBtn")

        current_mutation(res)
        vote_start_time(Sys.time())
        return(res)
      } else {
        showElement("voting_questions_div")
        showElement("nextBtn")
        enable("nextBtn")
      }

      # Query the database for the variant with these coordinates
      query <- paste0("SELECT rowid, coordinates, REF, ALT, variant, path FROM annotations WHERE coordinates = '", coords, "'")
      df <- dbGetQuery(con, query)
      # assert that the query returns only one row
      if (nrow(df) > 1) {
        stop("Query returned more than one row. Check the DB.")
      }
      if (nrow(df) > 0) {
        current_mutation(df[1, ])
        vote_start_time(Sys.time())
        # check if the back button needs to be shown or hidden
        print("annotations_df before filtering:")
        print(annotations_df)

        # filter the annotations_df to only show the rows with the same session ID
        session_annotations_df <- annotations_df %>%
          filter(shiny_session_id == session$token)

        # session_id <- session$token
        # annotations_df <- annotations_df[annotations_df$shiny_session_id == session_id, ]
        print("Filtered Annotations DataFrame for the current session:")
        print(session_annotations_df)

        if (nrow(session_annotations_df) > 0) {
          rowIdx <- which(session_annotations_df$coordinates == coords)
          print(paste("Row index for coordinates:", coords, "is", rowIdx))
          # if rowIdx is null, it means that the coordinates were not found in the annotations_df
          if (length(rowIdx) == 0) {
            show("backBtn")
            enable("backBtn")
          } else {
            if (rowIdx == 1) {
              print("HIDE back button")
              hideElement("backBtn")
              disable("backBtn")
            }

            if (rowIdx > 1) {
              print("SHOW back button")
              showElement("backBtn")
              enable("backBtn")
            }
          }
        }
        return(df[1, ])
      } else {
        print("No mutation found for the given coordinates.")
        return(NULL)
      }
    }

    if (all(!is.na(annotations_df$agreement))) {
      res <- tibble(
        rowid = NA,
        coordinates = "You have already voted on all variants in this category!",
        REF = "-",
        ALT = "-",
        variant = NA,
        path = "https://imgpile.com/images/Ud9lAi.jpg"
      )
      updateQueryString(
        "?coords=done",
        mode = "push",
        session = session
      )
      current_mutation(res)
      vote_start_time(Sys.time())
      return(res)
    }

    # loop through the annotations_df to find the next variant that has not been voted on
    print("Looking for the next variant that has not been voted on...")
    not_voted_image_found <- FALSE
    for (i in 1:nrow(annotations_df)) {
      if (is.na(annotations_df$agreement[i])) {
        # Get the coordinates of the variant
        coordinates <- annotations_df$coordinates[i]
        # Query the database for the variant with these coordinates

        query <- paste0(
          "SELECT ", 
          paste(cfg_db_cols, collapse = ", "), 
          " FROM annotations WHERE coordinates = '", coordinates, "'"
        )
        # Execute the query to get the variant that has not been voted on
        df <- dbGetQuery(con, query)
        print("Query result:")
        print(df)

        # assert that the query returns only one row
        if (nrow(df) > 1) {
          stop("Query returned more than one row. Check the DB.")
        }

        if (nrow(df) > 0) {
          # TODO
          # Filter logic for the actual voting
          # Reasoning why this is commented out in the README
 
          # inspritation for the filtering logic from legacy code:
          # filter(!(yes >= 3 & yes / total_votes > 0.7)) %>%
          # filter(!(no >= 3 & no / total_votes > 0.7))

          # If a variant is found, return it
          coords <- df[1, ]$coordinates

          current_mutation(df[1, ])
          vote_start_time(Sys.time())
          updateQueryString(
            paste0("?coords=",coords),
            mode = "push",
            session = session
          )
          return(df[1, ])
        }
      }
    }
  })

  output$voting_image_div <- renderUI({
    mut_df <- get_mutation()
    if (is.null(mut_df)) {
      return(NULL)
    }
    render_voting_image_div(mut_df, cfg_nt2color_map)
  })

  output$voting_questions_div <- renderUI(
    render_voting_questions_div()
  )

  leaderboardServer("leaderboard", login_data)
  userStatsServer("userstats", login_data)
  aboutServer("about")
}

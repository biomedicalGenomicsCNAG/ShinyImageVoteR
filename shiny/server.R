
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

  # Load the voting module within this environment so it can
  # access reactive values defined above
  source("modules/voting_module.R", local = TRUE)

  # Connect to the annotations database
  con <- dbConnect(SQLite(), cfg_sqlite_file)
  onStop(function() {
    dbDisconnect(con)
  })
  total_images <- dbGetQuery(con, "SELECT COUNT(*) as n FROM annotations")$n
  cat(sprintf("Total annotations in DB: %s\n", total_images))

  logged_in <- reactiveVal(FALSE)

  output$logged_in <- reactive({
    logged_in()
  })
  outputOptions(output, "logged_in", suspendWhenHidden = FALSE)

  login_data <- loginServer("login")

  observeEvent(login_data(), {
    req(login_data())
    user_id <- login_data()$user_id
    voting_institute <- login_data()$voting_institute

    logged_in(TRUE)

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


  votingServer("voting", login_data)
  leaderboardServer("leaderboard", login_data)
  userStatsServer("userstats", login_data)
  aboutServer("about")

  # every 2 seconds, check for external shutdown file
  observe({
    invalidateLater(2000, session)
    if (file.exists(cfg_shutdown_file)) {
      print("External shutdown request received.")
      file.remove(cfg_shutdown_file)
      showNotification("External shutdown request received…", type="warning")
      stopApp()
    }
  })
}

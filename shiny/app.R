library(shiny)
library(dplyr)
library(tibble)
library(digest)
library(DBI)
library(RSQLite)
library(data.table)
library(jsonlite)
library(shinyjs)

# load configuration (variables have a "cfg_" prefix)
source("config.R")

# Initialize the SQLite database
if (!file.exists(cfg_sqlite_file)) {
  source("init_db.R")
}

# Initial login status
Logged <- FALSE

# create folders for all institutes
lapply(cfg_institute_ids, function(institute) {
  # replace spaces with underscores in institute names
  institute <- gsub(" ", "_", institute)
  dir.create(file.path("user_data", institute), recursive = TRUE, showWarnings = FALSE)
})

ui1 <- function() {
  tagList(
    div(
      id = "login",
      wellPanel(
        selectInput(
          inputId = "institutes_id",
          label = "Institute ID",
          choices = cfg_institute_ids,
          selected = cfg_selected_institute_id
        ),
        textInput(
          inputId = "user_id",
          label = "User ID",
          value = cfg_selected_user_id
        ),
        passwordInput("passwd", "Password", value = ""),
        br(),
        actionButton("loginBtn", "Log in"),
        br(),
      )
    ),
    tags$style(
      type = "text/css",
      "#login {font-size:10px; text-align: left; position:absolute; top: 40%; left: 50%; margin-top: -100px; margin-left: -150px;}"
    )
  )
}

# Main UI (after login)
ui2 <- function() {
   tagList(
    # useShinyjs(),
    navbarPage(
      "Variant voter",
      tabPanel(
        # useShinyjs(),  # Initialize shinyjs
        "Vote",
        uiOutput("ui2_questions"),
        hidden(
          disabled(
            actionButton(
              "backBtn",  
              "Back (press Backspace)",
              onclick="history.back(); return false;")
            )
        ),
        actionButton("nextBtn",  "Next (press Enter)")
      ),
      tabPanel(
        "Monitor",
        fluidPage(
          tableOutput("table_counts"),
          actionButton("refresh_counts", "Refresh counts")
        )
      )
    )
  )
  # navbarPage(
  #   "Variant voter",
  #   header = useShinyjs(),  # ← inject shinyjs via header
  #   tabPanel(
  #     "Vote",
  #     uiOutput("ui2_questions"),
  #     actionButton(inputId = "testDiv", "✅ shinyjs is running!"), 
  #     actionButton(
  #       inputId = "backBtn", 
  #       label = "Back (press Backspace)",
  #       onclick = "history.back(); return false;"
  #     ),
  #     actionButton(
  #       inputId = "nextBtn", 
  #       label = "Next (press Enter)"
  #     ),
  #   ),
  #   tabPanel(
  #     # TODO
  #     # merge the user files of all intitutes into one dataframe
  #     # and then count the number of non NA rows
  #     # to get the number of total votes per institute
  #     "Monitor",
  #     fluidPage(
  #       # h5(sprintf("Total images: %s", nrow(images))),
  #       tableOutput("table_counts"),
  #       actionButton(inputId = "refresh_counts", label = "Refresh counts")
  #     )
  #   )
  # )
}

# Main UI ####
ui <- fluidPage(
  useShinyjs(),  # Initialize shinyjs
  tags$head(
    tags$script("
      $(document).on('keydown', function(e) {
        if (e.key === 'Enter') {
          $('#loginBtn').click();
        }
      });
    "),
  ),
  htmlOutput("page"),
)

# Functions ####
color_seq <- function(seq) {

  print("Coloring sequence:")
  print(seq)

  colored_seq <- seq %>%
    strsplit(., split = "") %>%
    unlist() %>%
    sapply(., function(x) sprintf('<span style="color:%s">%s</span>', cfg_nt2color_map[x], x)) %>%
    paste(collapse = "")

  colored_seq
}

server <- function(input, output, session) {

  # Reactive value to track user authentication
  USER <- reactiveValues(Logged = Logged)

  # Connect to the annotations database
  con <- dbConnect(SQLite(), cfg_sqlite_file)
  onStop(function() {
    dbDisconnect(con)
  })
  total_images <- dbGetQuery(con, "SELECT COUNT(*) as n FROM annotations")$n
  cat(sprintf("Total annotations in DB: %s\n", total_images))

  observeEvent(input$loginBtn, {
    user_id <<- isolate(input$user_id)
    voting_institute <<- isolate(input$institutes_id)
    submitted_password <- isolate(input$passwd)

    if (passwords[user_id] == submitted_password) {
      USER$Logged <- TRUE
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
        images_randomisation_seed = seed,
        total_images_voted = 0
        # TODO figure out how you could track below with Shiny
        # average_time_per_image = 0,
        # average_images_per_session = 0,
        # max_images_per_session = 0,
        # max_time_per_image = 0,
        # average_session_length_in_minutes = 0,
        # max_session_length_in_minutes = 0,
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
    }
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

  # Render the appropriate UI based on login status.
  observe({
    if (USER$Logged == FALSE) {
      output$page <- renderUI({
        div(class = "outer", do.call(bootstrapPage, c("", ui1())))
      })
    }
    if (USER$Logged == TRUE) {
      output$page <- renderUI({
        div(class = "outer", do.call(bootstrapPage, c("", ui2())))
      })
    }
  })

  current_pic <- reactiveVal(NULL)

  observeEvent(input$nextBtn, {
    pic <- current_pic()

    user_dir <- file.path("user_data", voting_institute, user_id)
    user_annotations_file <- file.path(user_dir, paste0(user_id, "_annotations.tsv"))

    annotations_df <- read.table(
      user_annotations_file,
      header = TRUE,
      sep = "\t",
      stringsAsFactors = FALSE
    )

    print("Annotations DataFrame before update:")
    print(annotations_df)

    # Update the annotations_df with the new agreement
    coords <- pic$coordinates

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

    print("HERE")
    print(paste0("already_voted:", already_voted))
    # TODO
    # Hide + disable the "Next" button if all ?coords=done

    # TODO
    # Hide + disable the back button if this is the first image in that session
    # Idea in _info.json count the number of images voted in that session
    # and if it is 0, then hide the back button
    
    if (!already_voted && user_dir != "Training_answers_not_saved") {
      # Increment the total images voted for the user
      user_info_file <- session$userData$userInfoFile
      user_info <- read_json(user_info_file)
      
      # update total images voted
      user_info$total_images_voted <- user_info$total_images_voted + 1
      
      write_json(
        user_info, 
        user_info_file,
        auto_unbox = TRUE, 
        pretty = TRUE
      )

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
      && user_dir != "Training_answers_not_saved"
      ) {
      files <- list.files(
        path = "user_data", 
        pattern = "\\.txt$", 
        full.names = TRUE,
        recursive = TRUE
      )
      print("already_voted -> Files to read for annotations:")
      print(files)

      # Exclude files from the "Training_answers_not_saved" folder
      files <- files[!grepl("Training_answers_not_saved/", files)]

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

  # Reactive value to track the trigger source
  choosePic_trigger_source <- reactiveVal(NULL)

  # Observers to update the choosePic trigger source
  observeEvent(input$loginBtn, {
    print("Login button pressed, setting trigger source to 'login'.")
    shinyjs::runjs("console.log('✅ shinyjs loaded at ' + new Date());")
    choosePic_trigger_source("login")
  })

  observeEvent(input$nextBtn, {
    showElement("backBtn")
    enable("backBtn")
    choosePic_trigger_source("go")
  })

  # actionButton "Back" or Go back one page in browser pressed
  query <- reactive({
    # example string "?coords=chrY:10935390" string
    parseQueryString(session$clientData$url_search)
  })
  
  observeEvent(query(), {
    cat("Query string changed! New params:\n")
    print(query())

    # # load the annotation_df from that user
    # user_annotations_file <- session$userData$userAnnotationsFile

    # if (is.null(user_annotations_file)) {
    #   cat("User annotations file is not set in session data.\n")
    #   return(NULL)
    # }

    # if (!file.exists(user_annotations_file)) {
    #   cat(sprintf("User annotations file does not exist: %s\n", user_annotations_file))
    #   return(NULL)
    # }

    # coords <- parseQueryString(session$clientData$url_search)$coords
    # if (is.null(coords) || coords == "done") {
    #   print("No coordinates found in the URL or all variants have been voted on.")
    #   return(NULL)
    # }

    # print(paste0("user_annotations_file:", user_annotations_file))
    # annotations_df <- read.table(
    #   user_annotations_file,
    #   header = TRUE,
    #   sep = "\t",
    #   stringsAsFactors = FALSE
    # )

    # # filter tha annotations_df for the current sessionId
    # session_id <- session$token
    # annotations_df <- annotations_df[annotations_df$shiny_session_id == session_id, ]

    # if (nrow(annotations_df) == 0) {
    #   print("No annotations found for the current session.")
    #   return(NULL)
    # }

    # print("Annotations DataFrame for the current session:")
    # print(annotations_df)

    # # get the row index for the coordinates
    # rowIdx <- which(annotations_df$coordinates == coords)
    # print(paste("Row index for coordinates:", coords, "is", rowIdx))
    # if (length(rowIdx) == 0) {
    #   print("HIDE back button")
    #   hideElement("backBtn")
    #   disable("backBtn")
    # } else {
    #   print("SHOW back button")
    #   showElement("backBtn")
    #   enable("backBtn")
    # }
    choosePic_trigger_source("query-string-change")
  })


  # Triggered when the user logs in, clicks the next button, 
  # or goes back (with the actionButton "Back" or browser back button)
  choosePic <- eventReactive(c(input$loginBtn, input$nextBtn, query()), {
    user_dir <- file.path("user_data", voting_institute, user_id)
    user_annotations_file <- file.path(user_dir, paste0(user_id, "_annotations.tsv"))

    annotations_df <- read.table(
      user_annotations_file,
      header = TRUE,
      sep = "\t",
      stringsAsFactors = FALSE
    )

    # print("Annotations DataFrame:")
    # print(annotations_df)

    # print("annotations_df$agreement:")
    # print(annotations_df$agreement)

    # Check if the user has already voted on all variants
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
      current_pic(res)
      return(res)
    }

    # actionButton "Back" or Go back one page in browser pressed
    print("Checking if the user pressed the Back button or went back in the browser...")
    if (choosePic_trigger_source() == "query-string-change") {
      print("URL change detected, showing the image from the URL.")
      # Get the coordinates from the URL
      coords <- parseQueryString(session$clientData$url_search)$coords
      if (is.null(coords) || coords == "done") {
        print("No coordinates found in the URL or all variants have been voted on.")
        return(NULL)
      }
      # Query the database for the variant with these coordinates
      query <- paste0("SELECT rowid, coordinates, REF, ALT, variant, path FROM annotations WHERE coordinates = '", coords, "'")
      df <- dbGetQuery(con, query)
      # assert that the query returns only one row
      if (nrow(df) > 1) {
        stop("Query returned more than one row. Check the DB.")
      }
      if (nrow(df) > 0) {
        current_pic(df[1, ])
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
        print("No picture found for the given coordinates.")
        return(NULL)
      }
    }

    # loop through the annotations_df to find the next variant that has not been voted on
    print("Looking for the next variant that has not been voted on...")
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

          current_pic(df[1, ])
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

  voterUI <- function() {
    renderUI({
      pic <- choosePic()
      fluidPage(
        # to make sure that the script is loaded only once
        shiny::singleton(
          includeScript("www/scripts/hotkeys.js")
        ),
        p(paste("Logged in as", user_id)),
        h5(pic$coordinates),
        img(
          id = "variantImage",
          src = paste0(pic$path),
          style = "max-width:100%; height:auto;"
        ),
        br(),
        br(),
        tags$h5(
          id = "variantInfo",
          HTML(paste0(
            "Somatic mutation: ", 
            color_seq(choosePic()$REF),
            " > ", 
            color_seq(choosePic()$ALT)
          ))
        ),
        br(),
        div(
          radioButtons(
            inputId = "agreement",
            label = cfg_radioBtns_label,
            choices = cfg_radio_options2val_map
          ),
        ),
        conditionalPanel(
          condition = "input.agreement == 'not_confident'",
          checkboxGroupInput(
            inputId = "observation",
            label = cfg_checkboxes_label,
            choices = cfg_observations2val_map
          )
        ),
        conditionalPanel(
          condition = "input.agreement == 'diff_var' || input.agreement == 'not_confident'",
          textInput(
            inputId = "comment",
            label = "Comments",
            value = ""
          )
        )
      )
    })
  }

  output$ui2_questions <- voterUI()

  # table_counts <- eventReactive(c(input$Login, input$refresh_counts), {
  #   read_sheet(drive_paths$annotations) %>%
  #     filter(institute %in% institutes) %>%
  #     count(Institute = institute, sort = TRUE, name = "Votes") %>%
  #     mutate(Votes = as.integer(Votes - training_questions))
  # })

  # output$table_counts <- renderTable({
  #   table_counts()
  # })
}

# Run the Shiny app
shinyApp(ui = ui, server = server)
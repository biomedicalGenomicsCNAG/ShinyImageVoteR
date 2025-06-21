# setwd("/Users/lestelles/test22/")
source("config.R")
library(shiny)
# library(googleAuthR)
library(dplyr)
library(tibble)
# library(readr)
# library(googlesheets4)
library(digest)
library(DBI)
library(RSQLite)

source("init_db.R")
db_path <- "./screenshots/annotations.sqlite"

# Set the Google OAuth client id (use your own if needed)
cat(Sys.getenv("GOOGLE_AUTH_CLIENT_ID"))

# options(googleAuthR.webapp.client_id = Sys.getenv("GOOGLE_AUTH_CLIENT_ID"))

# Initial login status
Logged <- FALSE

# Login UI with manual inputs and a Google sign-in button


institute_ids <- (c(
  "CNAG", "DKFZ", "DNGC", "Hartwig", "KU Leuven",
  "University of Oslo", "University of Verona", "University of Helsinki",
  "SciLifeLab", "ISCIII", "Latvian BRSC", "MOMA",
  "Universidade de Aveiro", "FPGMX", "Training_answers_not_saved"
))

# create folders for all institutes
lapply(institute_ids, function(institute) {
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
          choices = institute_ids,
          selected = "Training_answers_not_saved"
        ),
        selectInput(
          inputId = "user_id",
          label = "User ID",
          choices = user_ids,
          selected = "Test"
        ),

        # googleSignInUI("demo")
        # selectInput(
        #         inputId = "selected_vartype",
        #         label = "Evaluate variants",
        #         choices = c("All variants", vartype_dict)
        # ),
        passwordInput("passwd", "Password", value = ""),
        br(),
        actionButton("loginButton", "Log in"),
        br(),
        # Minimal Google Sign-In button as per your sample
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
  navbarPage(
    "Variant voter",
    tabPanel(
      "Vote",
      uiOutput("ui2_questions"),
      actionButton(inputId = "back", label = "Back"),
      actionButton(inputId = "go", label = "Next (press Enter)"),
      br(),
      textOutput("save_txt"),
      br(),
      br()
    ),
    tabPanel(
      "Monitor",
      fluidPage(
        # h5(sprintf("Total screenshots: %s", nrow(screenshots))),
        tableOutput("table_counts"),
        h6(sprintf("*%s training questions are subtracted from the number of votes.", training_questions)),
        actionButton(inputId = "refresh_counts", label = "Refresh counts")
      )
    )
  )
}

# Main UI now includes an updated CSP meta tag that allows inline scripts without a nonce.
ui <- fluidPage(
  tags$head(
    # tags$script(HTML("
    #   history.pushState(null, null, location.href);  // Add a fake history state

    #   window.onpopstate = function(event) {
    #     // Prevent actual browser navigation
    #     console.log('Back button pressed, preventing navigation');
    #     history.pushState(null, null, location.href);

    #     // Send signal to Shiny that back was pressed
    #     Shiny.setInputValue('back_button_pressed', new Date().getTime());
    #   };
    # });
    # ")),
    # tags$script(src = "scripts/handleBrowserBackButton.js"),
    tags$script(src = "scripts/hotkeys.js"),
  ),
  htmlOutput("page"),
)

# Functions ####
choose_picture <- function(drive_paths, institute, training_questions, voting_institute, vartype, screenshots, vartype_dict, n_sample = 10) {
  annot <- read_sheet(drive_paths$annotations) %>%
    # first N questions per centre are for training
    group_by(institute) %>%
    slice(-c(1:training_questions)) %>%
    ungroup() %>%
    # a row that will be removed but contains all agreement fields
    bind_rows(tibble("image" = "-", already_voted = T, agreement = c("yes", "no", "diff_var", "not_confident"))) %>%
    # summarise if institute already voted
    group_by(image) %>%
    mutate(already_voted = (institute == voting_institute)) %>%
    mutate(already_voted = any(already_voted)) %>%
    count(image, already_voted, agreement) %>%
    spread(agreement, n, fill = 0) %>%
    mutate(total_votes = yes + no + diff_var + not_confident)


  # select candidates for random selection
  candidates <- screenshots %>%
    # pick the variants selected by the user
    # filter((variant == vartype | !(vartype %in% vartype_dict))) %>%
    # get all images ids
    select(image, coordinates, path, REF, ALT, variant) %>%
    # add agreement info
    left_join(annot) %>%
    mutate(
      yes = coalesce(yes, 0),
      no = coalesce(no, 0),
      not_confident = coalesce(not_confident, 0),
      diff_var = coalesce(diff_var, 0),
      total_votes = coalesce(total_votes, 0),
      already_voted = coalesce(already_voted, FALSE)
    ) %>%
    # remove images if institute already voted
    # mutate(already_voted = !(is.na(already_voted) | !already_voted)) %>%
    filter(!already_voted) %>%
    # arrange(desc(total_votes)) %>%

    # filtering rules
    filter(!(yes >= 3 & yes / total_votes > 0.7)) %>%
    filter(!(no >= 3 & no / total_votes > 0.7))


  # subset a sample of screenshots
  if (!is.null(n_sample)) {
    if (nrow(candidates) < n_sample) {
      n_sample <- nrow(candidates)
    }
    candidates <- candidates %>%
      sample_n(size = n_sample)
  }

  # replace the path to the image with lh(3-6).googleusercontent.com
  candidates <- candidates %>%
    mutate(path = str_replace(
      path,
      "drive.google.com/uc\\?export=view&id=",
      "lh3.googleusercontent.com/d/"
    ))
  candidates
}

color_seq <- function(seq) {

  print("Coloring sequence:")
  print(seq)

  # RColorBrewer::brewer.pal(12, name = "Paired")
  # color_dict = c("T" = "red", "C" = "blue", "A" = "green", "G" = "orange", "-" = "black")
  color_dict <- c(
    "T" = "#E31A1C",
    "C" = "#1F78B4",
    "A" = "#33A02C",
    "G" = "#FF7F00",
    "-" = "black"
  )

  colored_seq <- seq %>%
    strsplit(., split = "") %>%
    unlist() %>%
    sapply(., function(x) sprintf('<span style="color:%s">%s</span>', color_dict[x], x)) %>%
    paste(collapse = "")

  colored_seq
}

server <- function(input, output, session) {
  source("init_db.R")

  # Reactive value to track user authentication
  USER <- reactiveValues(Logged = Logged, screenshots_randomized = FALSE, randomized_screenshots = NULL)

  # Connect to the annotations database
  con <- dbConnect(SQLite(), db_path)
  onStop(function() {
    dbDisconnect(con)
  })
  total_screenshots <- dbGetQuery(con, "SELECT COUNT(*) as n FROM annotations")$n
  cat(sprintf("Total annotations in DB: %s\n", total_screenshots))

  observeEvent(input$loginButton, {
    user_id <<- isolate(input$user_id)
    voting_institute <<- isolate(input$institutes_id)
    submitted_password <- isolate(input$passwd)

    if (passwords[user_id] == submitted_password) {
      USER$Logged <- TRUE
    }
  })


  # Render the appropriate UI based on login status.
  # Also, randomize screenshots once per session.
  observe({
    if (USER$Logged == FALSE) {
      output$page <- renderUI({
        div(class = "outer", do.call(bootstrapPage, c("", ui1())))
      })
    }
    if (USER$Logged == TRUE) {
      cat("Observer User logged in !!\n")

      # Create user-specific file if it doesn't exist
      if (!is.null(user_id) && nzchar(user_id)) {
        user_dir <- file.path("user_data", voting_institute, user_id)
        print("User directory:")
        print(user_dir)
        print("++++++++")
        if (!dir.exists(user_dir)) {
          cat(sprintf("Creating directory for user: %s at %s\n", user_id, user_dir))
          dir.create(user_dir, recursive = TRUE)

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
            seed = seed,
            first_login = Sys.time(),
            last_login = Sys.time(),
            total_screenshots_voted = 0
            # TODO figure out how you could track below with Shiny
            # average_time_per_screenshot = 0,
            # average_screenshots_per_session = 0,
            # max_screenshots_per_session = 0,
            # max_time_per_screenshot = 0,
            # average_session_length_in_minutes = 0,
            # max_session_length_in_minutes = 0,
          )
          user_info_file <- file.path(user_dir, paste0(user_id, "_info.json"))
          if (!file.exists(user_info_file)) {
            cat(sprintf("Creating user info file for: %s at %s\n", user_id, user_info_file))
            write_json(user_info, user_info_file)
          }

          # unser annotations file
          user_annotations_file <- file.path(user_dir, paste0(user_id, "_annotations.txt"))
          if (!file.exists(user_annotations_file)) {
            cat(sprintf("Creating user annotations file for: %s at %s\n", user_id, user_annotations_file))

            annotations_header <- c(
              "coordinates", "agreement", "alternative_vartype","observation","comment"
            )

            # query the database for all coordinates
            query <- "SELECT coordinates FROM annotations"
            coords <- dbGetQuery(con, query)
            print("Coordinates from DB:")
            print(coords)

            # coords <- screenshots_df$coordinates
            # randomize coordinates
            coords <- sample(coords, length(coords), replace = FALSE)
            
            # create a dataframe with the coordinates and empty columns for annotations
            annotations_df <- data.frame(
              coordinates = coords,
              agreement = rep("", length(coords)),
              alternative_vartype = rep("", length(coords)),
              observation = rep("", length(coords)),
              comment = rep("", length(coords)),
              stringsAsFactors = FALSE
            )
            
            # write annotations_df to a text file
            write.table(
              annotations_df,
              file = user_annotations_file,
              sep = "\t",
              row.names = FALSE,
              col.names = TRUE,
              quote = FALSE
            )            
          }
        }
      }
      output$page <- renderUI({
        div(class = "outer", do.call(bootstrapPage, c("", ui2())))
      })
    }
  })

  current_pic <- reactiveVal(NULL)

  save_txt <- observeEvent(input$go, {
    pic <- current_pic()
    if (!is.null(pic) && !is.na(pic$rowid)) {
      dbExecute(
        con,
        "UPDATE annotations SET vote_count = vote_count + 1 WHERE rowid = ?",
        params = list(pic$rowid)
      )
    }
    print("Saving annotations...")
    user_dir <- file.path("user_data", voting_institute, user_id)
    user_annotations_file <- file.path(user_dir, paste0(user_id, "_annotations.txt"))

    annotations_df <- read.table(
      user_annotations_file,
      header = TRUE,
      sep = "\t",
      stringsAsFactors = FALSE
    )

    print("Annotations DataFrame before update:")
    print(annotations_df)

    # Update the annotations_df with the new agreement
    if (!is.null(pic) && !is.na(pic$rowid)) {
      coordinates <- pic$coordinates

      print(paste("Updating annotations for coordinates:", coordinates))
      print(paste("Agreement:", input$agreement))
      print(paste("Alternative vartype:", input$alternative_vartype))
      print(paste("Observation:", input$observation))
      print(paste("Comment:", input$comment))



      annotations_df[annotations_df$coordinates == coordinates, "agreement"] <- input$agreement

      if (!is.null(input$alternative_vartype)) {
        annotations_df[annotations_df$coordinates == coordinates, "alternative_vartype"] <- input$alternative_vartype
      }

      if (!is.null(input$observation)) {
        annotations_df[annotations_df$coordinates == coordinates, "observation"] <- input$observation
      }
      
      comment <- NA
      if (input$comment != "") {
        comment <- input$comment
        annotations_df[annotations_df$coordinates == coordinates, "comment"] <- comment
      }
    } else {
      print("No picture selected or picture is NA.")
    }

    print("Annotations DataFrame after update:")
    # print(annotations_df)

    # Write the updated annotations_df back to the file
    write.table(
      annotations_df,
      file = user_annotations_file,
      sep = "\t",
      row.names = FALSE,
      col.names = TRUE,
      quote = FALSE
    )
    print("Annotations saved successfully.")
  })

  # Reactive value to track the trigger source
  choosePic_trigger_source <- reactiveVal(NULL)

  # Observer to update the choosePic trigger source
  observeEvent(input$loginButton, {
    choosePic_trigger_source("login")
  })

  observeEvent(input$go, {
    choosePic_trigger_source("go")
  })

  observeEvent(input$back, {
    choosePic_trigger_source("back")
  })

  # browser back button pressed
  observeEvent(input$back_button_pressed, {
    choosePic_trigger_source("back")
  })

  choosePic <- eventReactive(c(input$loginButton, input$go, input$back, input$back_button_pressed), {
    user_dir <- file.path("user_data", voting_institute, user_id)
    user_annotations_file <- file.path(user_dir, paste0(user_id, "_annotations.txt"))

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
      current_pic(res)
      return(res)
    }

    # if back button was pressed, we need to find the previous variant
    if (choosePic_trigger_source() == "back") {
      print("Back button pressed, showing previous image.")
      # Get the last voted variant
      last_voted_variant <- tail(annotations_df$coordinates[!is.na(annotations_df$agreement)], 1)
      if (length(last_voted_variant) == 0) {
        print("No previous variant found.")
        return(NULL)
      }
      # Query the database for the variant with these coordinates
      query <- paste0("SELECT rowid, coordinates, REF, ALT, variant, path FROM annotations WHERE coordinates = '", last_voted_variant, "'")
      df <- dbGetQuery(con, query)
      # assert that the query returns only one row
      if (nrow(df) > 1) {
        stop("Query returned more than one row. Check the DB.")
      }
      # replace in the path /vol/b1mg/ with images/
      df$path <- gsub("/vol/b1mg/", "images/", df$path)
      if (nrow(df) > 0) {
        current_pic(df[1, ])
        return(df[1, ])
      } else {
        print("No previous picture found.")
        return(NULL)
      }
    }

    # loop through the annotations_df to find the next variant that has not been voted on
    for (i in 1:nrow(annotations_df)) {
      if (is.na(annotations_df$agreement[i])) {
        # Get the coordinates of the variant
        coordinates <- annotations_df$coordinates[i]
        # Query the database for the variant with these coordinates
        query <- paste0("SELECT rowid, coordinates, REF, ALT, variant, path FROM annotations WHERE coordinates = '", coordinates, "'")

        # Execute the query to get the variant that has not been voted on
        df <- dbGetQuery(con, query)  

        # assert that the query returns only one row
        if (nrow(df) > 1) {
          stop("Query returned more than one row. Check the DB.")
        }

        # replace in the path /vol/b1mg/ with images/
        df$path <- gsub("/vol/b1mg/", "images/", df$path)

        if (nrow(df) > 0) {
          # If a variant is found, return it
          current_pic(df[1, ])
          return(df[1, ])
        }
      }
    }

    # Limit the query to 1 result
    # query <- paste0(query, " LIMIT 1")
    # Execute the query to get a random variant that has not been voted on
    # and has less than 3 votes
    # df <- dbGetQuery(con, query)

    # if (nrow(df) == 0) {
    #   res <- tibble(
    #     rowid = NA,
    #     coordinates = "There are no more variants to vote in this category!",
    #     REF = "-",
    #     ALT = "-",
    #     variant = NA,
    #     path = "https://imgpile.com/images/Ud9lAi.jpg"
    #   )
    # } else {
    #   res <- df[1, ]
    # }

    # current_pic(res)
    # res
  })

  observeEvent(input$back_button_pressed, {
    # Your logic to show previous image
    print("Back button pressed, showing previous image.")

    user_dir <- file.path("user_data", voting_institute, user_id)
    user_annotations_file <- file.path(user_dir, paste0(user_id, "_annotations.txt"))

    annotations_df <- read.table(
      user_annotations_file,
      header = TRUE,
      sep = "\t",
      stringsAsFactors = FALSE
    )

    pic <- current_pic()
    print("Current picture:")
    print(pic)

    coordinates <- pic$coordinates

    # find in annotations_df the row with the same coordinates
    row_index <- which(annotations_df$coordinates == coordinates)
    print(paste("Row index in annotations_df for coordinates", coordinates, ":", row_index))

    # get the previous row index
    prev_row_index <- row_index - 1
    print(paste("Previous row index in annotations_df for coordinates", coordinates, ":", prev_row_index))

    if (prev_row_index < 1) {
      print("No previous row found, staying on the current picture.")
      return()
    }
    prev_coordinates <- annotations_df$coordinates[prev_row_index]
    print(paste("Previous coordinates:", prev_coordinates))
    # Query the database for the variant with these coordinates
    query <- paste0("SELECT rowid, coordinates, REF, ALT, variant, path FROM annotations WHERE coordinates = '", prev_coordinates, "'")
    # Execute the query to get the variant that has not been voted on
    df <- dbGetQuery(con, query)
    # assert that the query returns only one row
    if (nrow(df) > 1) {
      stop("Query returned more than one row. Check the DB.")
    }
    # replace in the path /vol/b1mg/ with images/
    df$path <- gsub("/vol/b1mg/", "images/", df$path)
    if (nrow(df) > 0) {
      # If a variant is found, return it
      current_pic(df[1, ])
      print("Previous picture set successfully.")
    } else {
      print("No previous picture found.")
    }
  })

  voterUI <- function() {
    renderUI({
      pic <- choosePic()
      fluidPage(
        p(paste("Logged in as", user_id)),
        h5(pic$coordinates),
        img(
          src = paste0(pic$path),
          style = "max-width:100%; height:auto;"
        ),
        br(),
        br(),
        tags$h5(
          HTML(paste0(
            "Variant: ", color_seq(choosePic()$REF), " > ", color_seq(choosePic()$ALT),
            "&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;"
          ))
        ),
        br(),
        div(
          radioButtons(
            inputId = "agreement",
            label = "Is the variant above correct? [hotkey 1-4]",
            choices = c(
              "Yes, it is [1]" = "yes",
              "There is no variant [2]" = "no",
              "There is a different variant [3]" = "diff_var",
              "I'm not sure [4]" = "not_confident"
            )
          ),
        ),
        conditionalPanel(
          condition = "input.agreement == 'not_confident'",
          checkboxGroupInput(
            inputId = "observation",
            label = "Observations",
            choices = observations_dict
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
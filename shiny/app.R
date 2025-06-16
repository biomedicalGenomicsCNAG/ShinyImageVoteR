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
db_path <- "./screenshots/screenshots.sqlite"

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
  "Universidade de Aveiro", "FPGMX", "Training (answers won't be saved)"
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
          choices = c(institute_ids, "CNAG")
        ),
        selectInput(
          inputId = "user_id",
          label = "User ID",
          choices = c(user_ids, "Training (answers won't be saved)")
        ),

        # googleSignInUI("demo")
        # selectInput(
        #         inputId = "selected_vartype",
        #         label = "Evaluate variants",
        #         choices = c("All variants", vartype_dict)
        # ),
        passwordInput("passwd", "Password", value = ""),
        br(),
        actionButton("Login", "Log in"),
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
      actionButton(inputId = "go", label = "Next"),
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
    tags$meta(
      `http-equiv` = "Content-Security-Policy",
      content = "script-src 'self' 'unsafe-inline' 'unsafe-eval' blob: data: https://www.gstatic.com https://apis.google.com;"
    ),
    tags$meta(
      `http-equiv` = "Cross-Origin-Opener-Policy",
      content = "same-origin-allow-popups"
    )
  ),
  htmlOutput("page")
)

server <- function(input, output, session) {
  # Set up Google sign in using the minimal sample approach.
  # sign_ins <- callModule(googleSignIn, "demo")

  # Reactive value to track user authentication
  USER <- reactiveValues(Logged = Logged, screenshots_randomized = FALSE, randomized_screenshots = NULL)

  # Connect to the screenshots database
  con <- dbConnect(SQLite(), db_path)
  onStop(function() {
    dbDisconnect(con)
  })
  total_screenshots <- dbGetQuery(con, "SELECT COUNT(*) as n FROM screenshots")$n
  cat(sprintf("Total screenshots in DB: %s\n", total_screenshots))

  # If a user signs in with Google, mark them as logged in.
  # observe({
  #   if (!is.null(sign_ins()) && !is.null(sign_ins()$email)) {
  #     # Optionally, assign the signed in email as the institute
  #     cat("User signed in with Google")
  #     cat("Email: ", sign_ins()$email, "\n")
  #     voting_institute <<- sign_ins()$email
  #     USER$Logged <- TRUE
  #   }
  # })

  # Manual login logic remains unchanged.
  # observeEvent(input$Login, {
  #   voting_institute <<- isolate(input$voting_institute)
  #   # vartype <<- isolate(input$selected_vartype)
  #   submitted_password <- isolate(input$passwd)

  #   if (passwords[voting_institute] == submitted_password) {
  #     USER$Logged <- TRUE
  #   }
  # })

  observeEvent(input$Login, {
    user_id <<- isolate(input$user_id)
    voting_institute <<- isolate(input$institutes_id)
    # vartype <<- isolate(input$selected_vartype)
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
            coords <- screenshots_df$coordinates
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
        "UPDATE screenshots SET vote_count = vote_count + 1 WHERE rowid = ?",
        params = list(pic$rowid)
      )
    }
  })

  choosePic <- eventReactive(c(input$Login, input$go), {
    df <- dbGetQuery(
      con,
      "SELECT rowid, coordinates, REF, ALT, variant, path FROM screenshots WHERE vote_count < 3 ORDER BY RANDOM() LIMIT 1"
    )

    if (nrow(df) == 0) {
      res <- tibble(
        rowid = NA,
        coordinates = "There are no more variants to vote in this category!",
        REF = "-",
        ALT = "-",
        variant = NA,
        path = "https://imgpile.com/images/Ud9lAi.jpg"
      )
    } else {
      res <- df[1, ]
    }

    current_pic(res)
    res
  })

  voterUI <- function() {
    renderUI({
      pic <- choosePic()
      fluidPage(
        p(paste("Logged in as", user_id)),
        h5(pic$coordinates),
        img(src = paste0(pic$path, "=h2000-w2000")),
        br(),
        br(),
        tags$h5(
          HTML(paste0(
            "Variant: ", color_seq(choosePic()$REF), " > ", color_seq(choosePic()$ALT),
            "&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;"
          ))
        ),
        br(),
        radioButtons(
          inputId = "agreement",
          label = "Is the variant above correct?",
          choices = c(
            "Yes, it is." = "yes",
            "There is no variant." = "no",
            "There is a different variant." = "diff_var",
            "I'm not sure." = "not_confident"
          )
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

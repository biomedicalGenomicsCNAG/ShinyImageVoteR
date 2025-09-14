#' Voting module UI
#'
#' Provides the user interface for displaying a voting task, including:
#' - An image of a candidate somatic mutation
#' - A radio button to express agreement with the annotation
#' - Conditional inputs for alternate variant type and comments
#' - Navigation controls (Back / Next)
#'
#' This module uses `shinyjs` for interactivity and includes a custom `hotkeys.js`
#' script to enable keyboard shortcuts (e.g., Enter for "Next", Backspace for "Back").
#'
#' The displayed options and labels are configured using:
#' - `cfg$radioBtns_label`
#' - `cfg$radio_options2val_map`
#' - `cfg$checkboxes_label`
#' - `cfg$observations2val_map`
#'
#' These should be defined in a sourced configuration file (config.yaml).
#'
#' @param id A string identifier for the module namespace.
#'
#' @return A Shiny UI element (`fluidPage`) representing the voting interface.
#' @export
votingUI <- function(id, cfg) {
  ns <- shiny::NS(id)

  shiny::fluidPage(
    theme = cfg$theme,
    shinyjs::useShinyjs(),
    shiny::singleton(
      shiny::includeScript(
        file.path(
          get_app_dir(), "www", "hotkeys.js"
        )
      )
    ),

    # Responsive layout: image on left, controls on right for larger screens
    shiny::fluidRow(
      class = "voting-row",
      shiny::column(
        width = 10,
        class = "img-col",
        # TODO
        # look into making the tool tip editable
        # https://github.com/dreamRs/shinyWidgets/issues/719
        shiny::tags$details(
          shiny::tags$summary("⚙️ Show image width slider"),
          shinyWidgets::noUiSliderInput(
            ns("image_width"),
            label = "Image width (%)",
            min = 10,
            max = 100,
            value = 100,
            step = 1,
            tooltips = TRUE, # show the value
            behaviour = c("tap", "drag"),
            width = "98%",
            height = "20px"
          ),
        ),
        shiny::uiOutput(ns("voting_image_div"))
      ),

      # Voting controls column - stacks below on small screens, right side on larger screens
      shiny::column(
        width = 2,
        class = "ctrl-col",
        shiny::div(
          id = "voting_controls_div",
          shiny::uiOutput(
            ns("somatic_mutation"),
          ),
          shiny::div(
            id = ns("voting_questions_div"),
            shiny::tags$head(
              shiny::tags$link(
                rel = "stylesheet",
                type = "text/css",
                href = "voting-styles.css"
              )
            ),
            shiny::div(
              class = "voting-questions",
              shiny::div(
                class = "radio-section",
                shiny::radioButtons(
                  inputId = ns("agreement"),
                  label = cfg$radioBtns_label,
                  choiceNames = lapply(
                    seq_along(cfg$radio_options2val_map), function(i) {
                      shiny::tags$span(
                        class = "numbered-radio",
                        shiny::tags$span(class = "circle", i),
                        names(cfg$radio_options2val_map)[i]
                      )
                    }
                  ),
                  choiceValues = c("yes", "no", "diff_var", "not_confident"),
                )
              ),
              shiny::div(
                class = "conditional-section",
                shiny::conditionalPanel(
                  condition = sprintf(
                    "input['%s'] == 'not_confident'",
                    ns("agreement")
                  ),
                  shinyWidgets::checkboxGroupButtons(
                    inputId = ns("observation"),
                    label = cfg$checkboxes_label,
                    direction = "vertical",
                    choices = cfg$observations2val_map,
                    individual = TRUE,
                    size = "xs"
                  ),
                ),
                shiny::conditionalPanel(
                  condition = sprintf(
                    "input['%1$s'] == 'diff_var' ||
                    input['%1$s'] == 'not_confident'",
                    ns("agreement")
                  ),
                  shiny::textInput(
                    inputId = ns("comment"),
                    label   = "Comments",
                    value   = ""
                  )
                )
              ),
              shiny::div(
                class = "voting-btns",
                shiny::actionButton(
                  ns("nextBtn"),
                  label = tagList(
                    "Next (press",
                    icon("level-down-alt", class = "fa-rotate-90"),
                    ")"
                  ),
                  class = "arrow-right"
                ),
                # shinyjs::hidden(
                shinyjs::disabled(
                  shiny::actionButton(
                    ns("backBtn"),
                    label = tagList(
                      "Back (press",
                      icon("backspace"),
                      ")"
                    ),
                    onclick = "history.back(); return false;",
                    class = "arrow-left"
                  )
                )
                # ),
              )
            )
          )
        )
      )
    )
  )
}

#' Voting module server logic
#'
#' Handles the server-side logic for the variant voting workflow.
#' This includes:
#' - Reactively loading mutation images and metadata
#' - Capturing user input (agreement, observation, comment)
#' - Writing votes to a tsv file and session data to a database
#' - Advancing to the next voting item based on user interaction or trigger source
#'
#' The module is triggered when the `login_trigger` reactive becomes active
#' and optionally by `get_mutation_trigger_source()` to load new voting tasks.
#'
#' Annotations are saved to the database connection provided in `db_pool`.
#'
#' @param id A string identifier for the module namespace.
#' @param login_trigger A reactive expression that indicates when a user has logged in.
#' @param db_pool A database pool object (e.g. SQLite or PostgreSQL) for writing annotations.
#' @param get_mutation_trigger_source A reactive expression that signals a new mutation should be loaded.
#' @param cfg App configuration
#' @param tab_trigger Optional reactive that triggers when the voting tab is selected.
#'
#' @return None. Side effect only: registers reactive observers and UI updates.
#' @export
votingServer <- function(id, cfg, login_trigger, db_pool, get_mutation_trigger_source, tab_trigger = NULL) {
  moduleServer(id, function(input, output, session) {
    # Helper function to create the "done" tibble
    create_done_tibble <- function() {
      tibble::tibble(
        rowid = NA,
        coordinates = "done",
        REF = "-",
        ALT = "-",
        variant = NA,
        path = "done.png"
      )
    }

    # Tracks the url parameters be they manually set in the URL or
    # set by the app when the user clicks on the "Back" button
    # or presses "Go back one page" in the browser
    url_params <- reactive({
      # example "?coords=chrY:10935390"
      parseQueryString(session$clientData$url_search)
    })

    # Tracks the trigger source of the get_mutation function
    # could be "login", "next", "back", "manual url params change"
    # get_mutation_trigger_source <- reactiveVal(NULL)

    # Holds the data of the currently displayed mutation
    current_mutation <- shiny::reactiveVal(NULL)

    # Track when the current voting image was rendered
    vote_start_time <- shiny::reactiveVal(Sys.time())

    # Trigger to load the next mutation only after annotations are saved
    next_trigger <- shiny::reactiveVal(0)

    # Create a reactive that triggers when the voting tab is selected
    tab_change_trigger <- reactive({
      if (!is.null(tab_trigger)) {
        tab_trigger()
      } else {
        NULL
      }
    })
    # Dummy listener so the URL query string
    # gets updated when navigating to the tab
    observe({
      tab_change_trigger()
    })

    observeEvent(input$nextBtn, {
      req(login_trigger())
      get_mutation_trigger_source("next")

      session$onFlushed(
        function() {
          shinyjs::enable(session$ns("backBtn"))
        }
      )

      mut_df <- current_mutation()
      if (is.null(mut_df)) {
        next_trigger(next_trigger() + 1)
        return()
      }
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
      print(paste("Row index for coordinates:", coords, "is", rowIdx))

      if (length(rowIdx) == 0) {
        warning("No annotation row for coordinates; skipping update")
        return(NULL)
      }

      # store the previous agreement for later use
      previous_agreement <- annotations_df[rowIdx, "agreement"]
      already_voted <- !is.na(previous_agreement) && previous_agreement != ""
      new_agreement <- input$agreement

      print(paste("Previous agreement:", previous_agreement))
      print(paste("New agreement:", new_agreement))

      # always update the agreement and the shinyauthr_session_id
      annotations_df[rowIdx, "agreement"] <- input$agreement
      annotations_df[rowIdx, "shinyauthr_session_id"] <- session$userData$shinyauthr_session_id

      print("Annotations DataFrame after updating agreement:")
      print(annotations_df)

      # only update if provided
      if (!is.null(input$alternative_vartype)) {
        annotations_df[rowIdx, "alternative_vartype"] <- input$alternative_vartype
      }

      if (!is.null(input$observation)) {
        annotations_df[rowIdx, "observation"] <- paste(input$observation, collapse = ";")
      }

      comment <- NA
      if (!is.null(input$comment) && input$comment != "") {
        comment <- input$comment
      }
      print("Before updating the time_till_vote_casted_in_seconds:")

      # calculate time spent on the current variant
      time_spent <- as.numeric(difftime(Sys.time(), vote_start_time(), units = "secs"))
      annotations_df[rowIdx, "time_till_vote_casted_in_seconds"] <- time_spent

      print(paste0("already_voted:", already_voted))

      if (!already_voted) {
        # depending on the agreement, update the vote counts in the database
        vote_col <- cfg$vote2dbcolumn_map[[input$agreement]]

        DBI::dbExecute(
          db_pool,
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
      ) {
        files <- list.files(
          path = "user_data",
          pattern = "\\.txt$",
          full.names = TRUE,
          recursive = TRUE
        )
        print("already_voted -> Files to read for annotations:")
        print(files)

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
          dplyr::group_by(agreement) %>%
          dplyr::summarise(count = n(), .groups = "drop")
        print("Counts of agreements:")
        print(counts)

        # loop over the agreement_counts_df and update the vote counts in the database
        for (i in 1:nrow(agreement_counts_df)) {
          agreement <- agreement_counts_df$agreement[i]
          count <- agreement_counts_df$count[i]
          vote_col <- vote2dbcolumn_map[[agreement]]
          if (!is.null(vote_col)) {
            DBI::dbExecute(
              db_pool,
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
      next_trigger(next_trigger() + 1)
    })

    # observeEvent(url_params(), {
    #   req(login_trigger())
    #   get_mutation_trigger_source("url-params-change")
    # })

    observeEvent(
      url_params(),
      {
        req(login_trigger())
        get_mutation_trigger_source("url-params-change")
      },
      # higher priority so get_mutation gets triggered by url_params()
      priority = 1
    )

    # Triggered when the user logs in, clicks the next button,
    # or goes back (with the actionButton "Back" or browser back button)
    get_mutation <- eventReactive(c(login_trigger(), next_trigger(), url_params()), {
      req(login_trigger())
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
          res <- create_done_tibble()
          # TODO
          # Freepic attribution for done.png
          # url: "https://www.flaticon.com/free-icon/done_14018771"

          session$onFlushed(function() {
            shinyjs::hideElement(session$ns("voting_questions_div"))
            shinyjs::hideElement(session$ns("nextBtn"))
            shinyjs::disable(session$ns("nextBtn"))
          })

          current_mutation(res)
          vote_start_time(Sys.time())
          return(res)
        } else {
          print("HERE2")
          print("session$ns('voting_questions_div')")
          print(session$ns("voting_questions_div"))

          session$onFlushed(function() {
            shinyjs::showElement(session$ns("voting_questions_div"))
            shinyjs::showElement(session$ns("nextBtn"))
            shinyjs::enable(session$ns("nextBtn"))
          })
        }

        # Query the database for the variant with these coordinates
        query <- paste0("SELECT rowid, coordinates, REF, ALT, variant, path FROM annotations WHERE coordinates = '", coords, "'")
        df <- DBI::dbGetQuery(db_pool, query)
        if (nrow(df) > 0) {
          current_mutation(df[1, ])
          vote_start_time(Sys.time())

          # check if the back button needs to be disabled or enabled
          print("annotations_df before filtering:")
          print(annotations_df)

          # filter the annotations_df to only show the rows with the same session ID
          session_annotations_df <- annotations_df %>%
            dplyr::filter(shinyauthr_session_id == session$userData$shinyauthr_session_id)

          print("Filtered Annotations DataFrame for the current session:")
          print(session_annotations_df)

          if (nrow(session_annotations_df) > 0) {
            rowIdx <- which(session_annotations_df$coordinates == coords)
            print(paste("Row index for coordinates:", coords, "is", rowIdx))
            if (length(rowIdx) > 0) {
              session$onFlushed(function() {
                if (rowIdx == 1) {
                  # disable backBtn
                  # when navigated back to the first mutation voted on in that session
                  shinyjs::disable(session$ns("backBtn"))
                } else {
                  shinyjs::enable(session$ns("backBtn"))
                }
              })
            }
          }
          print("HERE")
          return(df[1, ])
        } else {
          print("No mutation found for the given coordinates.")
          print(paste("Coordinates:", coords))
          # return the whole coordinates column from the database
          query <- "SELECT coordinates FROM annotations"
          coords_df <- DBI::dbGetQuery(db_pool, query)
          print("Available coordinates in the database:")
          print(coords_df)
          return(NULL)
        }
      }

      if (all(!is.na(annotations_df$agreement))) {
        res <- create_done_tibble()
        shiny::updateQueryString(
          "?coords=done",
          mode = "push",
          session = session
        )

        session$onFlushed(function() {
          shinyjs::hideElement(session$ns("voting_questions_div"))
          shinyjs::hideElement(session$ns("nextBtn"))
          shinyjs::disable(session$ns("nextBtn"))
        })
        current_mutation(res)
        vote_start_time(Sys.time())
        return(res)
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
            paste(cfg$db_cols, collapse = ", "),
            " FROM annotations WHERE coordinates = '", coordinates, "'"
          )
          # Execute the query to get the variant that has not been voted on
          df <- DBI::dbGetQuery(db_pool, query)
          print("Query result:")
          print(df)

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
            shiny::updateQueryString(
              paste0("?coords=", coords),
              mode = "push",
              session = session
            )
            return(df[1, ])
          }
        }
      }
    })
    output$voting_image_div <- shiny::renderUI({
      mut_df <- get_mutation()
      if (is.null(mut_df)) {
        return(NULL)
      }
      shiny::div(
        shiny::img(
          src = glue::glue("images/{mut_df$path}"),
          style = paste0("width: ", input$image_width, "%;")
        )
      )
    })

    output$somatic_mutation <- shiny::renderText({
      mut_df <- get_mutation()
      if (is.null(mut_df)) {
        return("No mutation available.")
      }
      paste0(
        "Somatic mutation: ",
        color_seq(mut_df$REF, cfg$nt2color_map),
        " > ",
        color_seq(mut_df$ALT, cfg$nt2color_map)
      )
    })
  })
}

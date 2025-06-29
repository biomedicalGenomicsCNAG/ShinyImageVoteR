votingUI <- function(id) {
  ns <- NS(id)
    fluidPage(
      useShinyjs(),
      shiny::singleton(
        includeScript("www/scripts/hotkeys.js")
      ),
      uiOutput(ns("voting_image_div")),
      div(
        id = ns("voting_questions_div"),
        radioButtons(
          inputId = ns("agreement"),
          label   = cfg_radioBtns_label,
          choices = cfg_radio_options2val_map
        ),

        conditionalPanel(
          condition = sprintf("input['%s'] == 'not_confident'", ns("agreement")),
          checkboxGroupInput(
            inputId = ns("observation"),
            label   = cfg_checkboxes_label,
            choices = cfg_observations2val_map
          )
        ),

        conditionalPanel(
          condition = sprintf(
            "input['%1$s'] == 'diff_var' || input['%1$s'] == 'not_confident'",
            ns("agreement")
          ),
          textInput(
            inputId = ns("comment"),
            label   = "Comments",
            value   = ""
          )
        )
      ),
      hidden(
        disabled(
          actionButton(
            ns("backBtn"),
            "Back (press Backspace)",
            onclick = "history.back(); return false;"
          )
        )
      ),
      actionButton(ns("nextBtn"), "Next (press Enter)")
    )
}

votingServer <- function(id, login_trigger) {
  
  color_seq <- function(seq, nt2color_map) {
    print("Coloring sequence:")
    print(seq)

    colored_seq <- seq %>%
      strsplit(., split = "") %>%
      unlist() %>%
      sapply(., function(x) sprintf('<span style="color:%s">%s</span>', nt2color_map[x], x)) %>%
      paste(collapse = "")
    colored_seq
  }

  moduleServer(id, function(input, output, session) {

    observeEvent(input$nextBtn, {
      req(login_trigger())
      get_mutation_trigger_source("next")

      session$onFlushed(
        function() {
          showElement(session$ns("backBtn"))
          enable(session$ns("backBtn"))
        }
      )
      
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
      req(login_trigger())
      get_mutation_trigger_source("url-params-change")
    })

    # Triggered when the user logs in, clicks the next button, 
    # or goes back (with the actionButton "Back" or browser back button)
    get_mutation <- eventReactive(c(login_trigger(), input$nextBtn, url_params()), {
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
          res <- tibble(
            rowid = NA,
            coordinates = "You have already voted on all variants in this category!",
            REF = "-",
            ALT = "-",
            variant = NA,
            path = "https://imgpile.com/images/Ud9lAi.jpg"
          )

          session$onFlushed(function() {
            hideElement(session$ns("voting_questions_div"))
            hideElement(session$ns("nextBtn"))
            disable(session$ns("nextBtn"))
          })

          current_mutation(res)
          vote_start_time(Sys.time())
          return(res)
        } else {
          print("HERE2")
          print("session$ns('voting_questions_div')")
          print(session$ns("voting_questions_div"))

          session$onFlushed(function() {
            showElement(session$ns("voting_questions_div"))
            showElement(session$ns("nextBtn"))
            enable(session$ns("nextBtn"))
          })
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
            if (length(rowIdx) > 0) {
              session$onFlushed(function() {
                if (rowIdx == 1) {
                  # hide & disable backBtn 
                  # when navigated back to the first mutation voted on in that session
                  hideElement(session$ns("backBtn"))
                  disable(session$ns("backBtn"))
                } else {
                  # show & enable backBtn otherwise
                  showElement(session$ns("backBtn"))
                  enable(session$ns("backBtn"))
                }
              })
            }
          } 
          print("HERE")
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
      div(
        img(
          id = "mutationImage",
          src = paste0(mut_df$path),
        ),
        div(
          HTML(paste0(
            "Somatic mutation: ", 
            color_seq(mut_df$REF, cfg_nt2color_map),
            " > ", 
            color_seq(mut_df$ALT, cfg_nt2color_map)
          ))
        ),
        br()
      )
    })
  })
}
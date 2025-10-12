#' Voting module UI
#'
#' Provides the user interface for displaying a voting task, including:
#' - An image of a candidate somatic mutation
#' - A radio button to express agreement with the annotation
#' - Conditional inputs for alternate mutation type and comments
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
          get_app_dir(),
          "www",
          "hotkeys.js"
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
                    seq_along(cfg$radio_options2val_map),
                    function(i) {
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
                    label = "Comments",
                    value = ""
                  )
                )
              ),
              shiny::div(
                class = "voting-btns",
                shinyjs::disabled(
                  shiny::actionButton(
                    ns("nextBtn"),
                    label = shiny::tagList(
                      "Next (press",
                      shiny::icon("level-down-alt", class = "fa-rotate-90"),
                      ")"
                    ),
                    class = "arrow-right"
                  )
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
#' Handles the server-side logic for the mutation voting workflow.
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
votingServer <- function(
    id,
    cfg,
    login_trigger,
    db_pool,
    get_mutation_trigger_source,
    tab_trigger = NULL) {
  shiny::moduleServer(id, function(input, output, session) {
    # validate cfg cols using "validate_cols" function from db.R
    validate_cols(db_pool, "annotations", cfg$db_cols)

    # Helper function to create the "done" tibble
    create_done_tibble <- function() {
      tibble::tibble(
        rowid = NA,
        coordinates = "done",
        REF = "-",
        ALT = "-",
        path = "done.png"
      )
    }

    # Tracks the url parameters be they manually set in the URL or
    # set by the app when the user clicks on the "Back" button
    # or presses "Go back one page" in the browser
    url_params <- shiny::reactive({
      # example "?coordinate=chrY:10935390"
      shiny::parseQueryString(session$clientData$url_search)
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

    shiny::observe({
      mut_df <- current_mutation()
      agreement <- input$agreement

      if (is.null(mut_df)) {
        shinyjs::disable(session$ns("nextBtn"))
        return()
      }

      if (!is.null(mut_df$coordinates) && identical(as.character(mut_df$coordinates), "done")) {
        shinyjs::disable(session$ns("nextBtn"))
        return()
      }

      if (!is.null(agreement) && length(agreement) > 0 && !identical(agreement, "")) {
        shinyjs::enable(session$ns("nextBtn"))
      } else {
        shinyjs::disable(session$ns("nextBtn"))
      }
    })

    # Create a reactive that triggers when the voting tab is selected
    tab_change_trigger <- shiny::reactive({
      if (!is.null(tab_trigger)) {
        tab_trigger()
      } else {
        NULL
      }
    })
    # Dummy listener so the URL query string
    # gets updated when navigating to the tab
    shiny::observe({
      tab_change_trigger()
    })

    shiny::observeEvent(input$nextBtn, {
      shiny::req(login_trigger())
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
      coord <- mut_df$coordinates

      # TOOD
      # check if alternative_vartype is still in use

      print(paste("Updating annotations for coordinates:", coord))
      print(paste("Agreement:", input$agreement))
      print(paste("Alternative vartype:", input$alternative_vartype))
      print(paste("Observation:", input$observation))
      print(paste("Comment:", input$comment))

      # use the row index to update the annotations_df
      rowIdx <- which(annotations_df$coordinates == coord)
      print(paste("Row index for coordinates:", coord, "is", rowIdx))

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
      annotations_df[
        rowIdx,
        "shinyauthr_session_id"
      ] <- session$userData$shinyauthr_session_id

      print("Annotations DataFrame after updating agreement:")
      print(annotations_df)

      # only update if provided
      if (!is.null(input$alternative_vartype)) {
        annotations_df[
          rowIdx,
          "alternative_vartype"
        ] <- input$alternative_vartype
      }

      if (!is.null(input$observation)) {
        annotations_df[rowIdx, "observation"] <- paste(
          input$observation,
          collapse = ";"
        )
      }

      comment <- NA
      if (!is.null(input$comment) && input$comment != "") {
        comment <- input$comment
      }
      annotations_df[rowIdx, "comment"] <- comment

      print("Before updating the time_till_vote_casted_in_seconds:")

      # calculate time spent on the current mutation
      time_spent <- as.numeric(difftime(
        Sys.time(),
        vote_start_time(),
        units = "secs"
      ))
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
            " = ",
            vote_col,
            " + 1 WHERE coordinates = ?"
          ),
          params = list(coord)
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
        print("User changed their vote, adjusting the database vote counts...")

        prev_vote_col <- cfg$vote2dbcolumn_map[[previous_agreement]]
        new_vote_col <- cfg$vote2dbcolumn_map[[input$agreement]]

        if (!is.null(prev_vote_col) && !is.null(new_vote_col)) {
          if (prev_vote_col == new_vote_col) {
            warning(
              "Previous and new agreements map to the same database column; skipping update."
            )
          } else {
            DBI::dbExecute(
              db_pool,
              paste0(
                "UPDATE annotations SET ",
                prev_vote_col,
                " = ",
                prev_vote_col,
                " - 1, ",
                new_vote_col,
                " = ",
                new_vote_col,
                " + 1 WHERE coordinates = ?"
              ),
              params = list(coord)
            )
          }
        } else {
          warning(
            "Could not find vote columns for previous or new agreement; skipping database adjustment."
          )
        }
      }
      print("Annotations saved successfully.")
      next_trigger(next_trigger() + 1)
    })

    shiny::observeEvent(
      url_params(),
      {
        shiny::req(login_trigger())
        get_mutation_trigger_source("url-params-change")
      },
      # higher priority to ensure get_mutation gets triggered by url_params()
      priority = 1
    )

    # Triggered when the user logs in, clicks the next button,
    # or goes back (with the actionButton "Back" or browser back button)
    get_mutation <- shiny::eventReactive(
      c(login_trigger(), next_trigger(), url_params()),
      {
        shiny::req(login_trigger())
        user_annotations_file <- session$userData$userAnnotationsFile

        annotations_df <- read.table(
          user_annotations_file,
          header = TRUE,
          sep = "\t",
          stringsAsFactors = FALSE
        )

        # actionButton "Back" or Go back one page in browser pressed
        print(
          "Checking if the user pressed the Back button or went back in the browser..."
        )
        if (get_mutation_trigger_source() == "url-params-change") {
          print("URL change detected, showing the image from the URL.")
          # Get the coordinate from the URL

          coord <- parseQueryString(session$clientData$url_search)$coordinate
          if (is.null(coord)) {
            print(
              "No coordinates found in the URL or all mutations have been voted on."
            )
            return(NULL)
          }

          if (coord == "done") {
            print("All mutations have been voted on.")
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

          # Query the database for the mutation with these coordinates
          df <- query_annotations_db_by_coord(db_pool, coord, cfg$db_cols)

          if (nrow(df) == 1) {
            current_mutation(df[1, ])
            vote_start_time(Sys.time())

            # check if the back button needs to be disabled or enabled
            print("annotations_df before filtering:")
            print(annotations_df)

            # filter the annotations_df to only show the rows with the same session ID
            session_annotations_df <- annotations_df %>%
              dplyr::filter(
                shinyauthr_session_id == session$userData$shinyauthr_session_id
              )

            print("Filtered Annotations DataFrame for the current session:")
            print(session_annotations_df)

            if (nrow(session_annotations_df) > 0) {
              rowIdx <- which(session_annotations_df$coordinates == coord)
              print(paste("Row index for coordinate:", coord, "is", rowIdx))
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
            print("No mutation found for the given coordinate")
            print(paste("Coordinate:", coord))
            return(NULL)
          }
        }

        if (all(!is.na(annotations_df$agreement))) {
          res <- create_done_tibble()
          shiny::updateQueryString(
            "?coordinate=done",
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

        # loop through the annotations_df to find the next mutation that has not been voted on
        print("Looking for the next mutation that has not been voted on...")
        for (i in seq_len(nrow(annotations_df))) {
          if (is.na(annotations_df$agreement[i])) {
            # Get the coordinates of the mutation
            coord <- annotations_df$coordinates[i]
            # Query the database for the mutation with these coordinates

            print("cfg$db_cols:")
            print(cfg$db_cols)

            df <- query_annotations_db_by_coord(db_pool, coord, cfg$db_cols)

            # query <- paste0(
            #   "SELECT ",
            #   paste(cfg$db_cols, collapse = ", "),
            #   " FROM annotations WHERE coordinates = '", coordinate, "'"
            # )
            # # Execute the query to get the mutation that has not been voted on
            # df <- DBI::dbGetQuery(db_pool, query)
            # print("Query result:")
            # print(df)

            if (nrow(df) == 1) {
              # TODO
              # Filter logic for the actual voting
              # Reasoning why this is commented out in the README

              # inspiration for the filtering logic from legacy code:
              # filter(!(yes >= 3 & yes / total_votes > 0.7)) %>%
              # filter(!(no >= 3 & no / total_votes > 0.7))

              # If a mutation is found, return it
              coord <- df[1, ]$coordinates

              current_mutation(df[1, ])
              vote_start_time(Sys.time())
              shiny::updateQueryString(
                paste0("?coordinate=", coord),
                mode = "push",
                session = session
              )
              return(df[1, ])
            }
          }
        }
      }
    )
    output$voting_image_div <- shiny::renderUI({
      mut_df <- get_mutation()
      if (is.null(mut_df)) {
        return(NULL)
      }
      shiny::div(
        leaflet::leafletOutput(
          session$ns("voting_image"),
          width = "100%",
          height = "840px"
        )
      )
    })

    output$voting_image <- leaflet::renderLeaflet({
      mut_df <- get_mutation()
      if (is.null(mut_df)) {
        return(NULL)
      }

      image_url <- glue::glue("images/{mut_df$path}")

      leaflet::leaflet(
        options = leaflet::leafletOptions(
          crs = leaflet::leafletCRS(crsClass = "L.CRS.Simple"),
          minZoom = -1, # coarse limits; we'll refine dynamically
          maxZoom = 4,
          zoomSnap = 0,
          zoomDelta = 0.25,
          zoomControl = FALSE, # we'll add our own toolbar
          preferCanvas = TRUE
        )
      ) %>%
        leaflet::addControl(
          html = htmltools::HTML(
            '<div id="imgTools" style="background:#fff;border-radius:8px;box-shadow:0 1px 4px rgba(0,0,0,.2);padding:6px;display:flex;gap:6px;align-items:center">
              <button id="zoomIn"  title="Zoom in"  style="padding:2px 8px">+</button>
              <button id="zoomOut" title="Zoom out" style="padding:2px 10px">-</button>
              <button id="fitBtn"  title="Fit to view" style="padding:2px 8px">Fit</button>
            </div>'
          ),
          position = "topleft"
        ) %>%
        htmlwidgets::onRender(
          # language=JavaScript
          "function(el, x, data) {
            var map = this;
            var imageUrl = data.imageUrl;

            // remove previous overlay if present
            if (map.imageOverlayLayer) {
              map.removeLayer(map.imageOverlayLayer);
              map.imageOverlayLayer = null;
            }

            var img = new Image();
            img.onload = function() {
              var w = this.naturalWidth, h = this.naturalHeight;

              // Leaflet CRS.Simple uses [y,x] ordering for bounds
              var bounds = L.latLngBounds([[0, 0], [h, w]]);
              map.imageOverlayLayer = L.imageOverlay(imageUrl, bounds, {interactive:true}).addTo(map);

              // Fit and set padded max bounds
              map.fitBounds(bounds, {animate:false});
              var padX = w * 0.10, padY = h * 0.10;
              map.setMaxBounds(L.latLngBounds([[-padY, -padX], [h + padY, w + padX]]));

              // --- Zoom helpers ---
              function fitView() {
                map.fitBounds(bounds);
              }

              // Wire buttons once (idempotent)
              function once(id, handler) {
                var btn = el.querySelector('#' + id);
                if (!btn) return;
                if (!btn._bound) {
                  btn.addEventListener('click', handler);
                  btn._bound = true;
                }
              }

              once('zoomIn',  function(){ map.zoomIn(map.options.zoomDelta || 1); });
              once('zoomOut', function(){ map.zoomOut(map.options.zoomDelta || 1); });
              once('fitBtn',  function(){ fitView(); });

              // When the container is resized (e.g., input$image_width changes),
              // recompute 'fit' and keep center stable
              var ro = new ResizeObserver(function(){
                // maintain center; re-fit bounds to container size
                var c = map.getCenter();
                var z = map.getZoom();
                map.invalidateSize();
                // Option: keep current zoom; or re-fit. Here we keep zoom & center.
                map.setView(c, z, {animate:false});
              });
              ro.observe(el); // observe the widget container

              // Optional: expose helpers for external calls (e.g., Shiny handlers)
              map._imgTools = { fitView: fitView, bounds: bounds, w:w, h:h };
            };
            img.src = imageUrl;
          }",
          data = list(imageUrl = image_url)
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

    # Observer to restore saved votes when navigating between images
    shiny::observe({
      mut_df <- get_mutation()
      if (is.null(mut_df) || mut_df$coordinates == "done") {
        return()
      }

      # Read the user's annotations file to get saved values
      user_annotations_file <- session$userData$userAnnotationsFile
      shiny::req(user_annotations_file)

      annotations_df <- read.table(
        user_annotations_file,
        header = TRUE,
        sep = "\t",
        stringsAsFactors = FALSE
      )

      # Find the row for the current coordinate
      coord <- mut_df$coordinates
      rowIdx <- which(annotations_df$coordinates == coord)

      if (length(rowIdx) > 0) {
        saved_agreement <- annotations_df[rowIdx, "agreement"]
        saved_observation <- annotations_df[rowIdx, "observation"]
        saved_comment <- annotations_df[rowIdx, "comment"]
        saved_alternative_vartype <- annotations_df[rowIdx, "alternative_vartype"]

        # Update radio buttons for agreement
        if (!is.na(saved_agreement) && saved_agreement != "") {
          shiny::updateRadioButtons(
            session,
            "agreement",
            selected = saved_agreement
          )
        } else {
          # Reset to no selection if no saved value
          shiny::updateRadioButtons(
            session,
            "agreement",
            selected = character(0)
          )
        }

        # Update checkboxes for observation
        if (!is.na(saved_observation) && saved_observation != "") {
          observation_values <- strsplit(saved_observation, ";")[[1]]
          shinyWidgets::updateCheckboxGroupButtons(
            session,
            "observation",
            selected = observation_values
          )
        } else {
          # Clear all checkboxes if no saved value
          shinyWidgets::updateCheckboxGroupButtons(
            session,
            "observation",
            selected = character(0)
          )
        }

        # Update comment text input
        if (!is.na(saved_comment) && saved_comment != "") {
          shiny::updateTextInput(
            session,
            "comment",
            value = saved_comment
          )
        } else {
          # Clear comment if no saved value
          shiny::updateTextInput(
            session,
            "comment",
            value = ""
          )
        }

        # Update alternative vartype if it exists
        if (!is.null(saved_alternative_vartype) && !is.na(saved_alternative_vartype) && saved_alternative_vartype != "") {
          shiny::updateTextInput(
            session,
            "alternative_vartype",
            value = saved_alternative_vartype
          )
        } else if ("alternative_vartype" %in% names(input)) {
          shiny::updateTextInput(
            session,
            "alternative_vartype",
            value = ""
          )
        }
      }
    })
  })
}

library(magrittr)

#' Leaderboard module UI
#'
#' Provides a user interface for displaying the number of votes submitted
#' by each participating institute in the B1MG Variant Voting app.
#'
#' The UI includes a table of vote counts and a button to refresh the data.
#'
#' @param id A string identifier for the module namespace.
#'
#' @return A Shiny UI element (`fluidPage`) for displaying the leaderboard.
#' @export
leaderboardUI <- function(id, cfg) {
  ns <- shiny::NS(id)
  shiny::fluidPage(
    theme = cfg$theme,
    shiny::tableOutput(ns("institutes_voting_counts")),
    shiny::actionButton(ns("refresh_counts"), "Refresh counts")
  )
}

#' Leaderboard Server Module
#'
#' This module provides leaderboard functionality with automatic refresh
#' when navigating to the leaderboard tab.
#'
#' @param id Module namespace ID
#' @param login_trigger Reactive that triggers when user logs in
#' @param tab_trigger Optional reactive that triggers when the leaderboard tab is selected
#'                   This enables automatic refresh of counts when navigating to the page
#' @return Reactive containing leaderboard data frame
#' @export
leaderboardServer <- function(id, cfg, login_trigger, tab_trigger = NULL) {
  moduleServer(id, function(input, output, session) {
    # Create a reactive that triggers when the leaderboard tab is selected
    # This allows automatic refresh when navigating to the leaderboard page
    tab_change_trigger <- reactive({
      if (!is.null(tab_trigger)) {
        tab_trigger()
      } else {
        NULL
      }
    })

    counts <- eventReactive(
      c(login_trigger(), input$refresh_counts, tab_change_trigger()),
      {
        req(login_trigger())
        institute_ids <- unlist(strsplit(
          Sys.getenv("IMGVOTER_USER_GROUPS_COMMA_SEPARATED"),
          ","
        ))

        # browser()
        counts_list <- lapply(institute_ids, function(institute) {
          institutes_dir <- file.path(
            Sys.getenv("IMGVOTER_USER_DATA_DIR"),
            institute
          )
          user_dirs <- list.dirs(
            institutes_dir,
            full.names = TRUE,
            recursive = FALSE
          )
          if (length(user_dirs) == 0) {
            return(data.frame(
              institute = institute,
              users = 0,
              total_images_voted = 0
            ))
          }
          total_users <- length(user_dirs)
          total_images <- 0
          for (user_dir in user_dirs) {
            user_annotations_file <- file.path(
              user_dir,
              paste0(basename(user_dir), "_annotations.tsv")
            )
            if (!file.exists(user_annotations_file)) {
              next
            }
            user_annotations_df <- read.table(
              user_annotations_file,
              header = TRUE,
              sep = "\t",
              stringsAsFactors = FALSE
            )
            user_voted_images <- sum(
              !is.na(user_annotations_df$shinyauthr_session_id)
            )
            total_images <- total_images + user_voted_images
          }
          data.frame(
            institute = institute,
            users = total_users,
            total_images_voted = total_images
          )
        })
        counts_df <- do.call(rbind, counts_list)

        counts_df <- counts_df %>%
          dplyr::mutate(
            institute = factor(institute, levels = institute_ids)
          ) %>%
          dplyr::arrange(desc(total_images_voted))
        counts_df
      }
    )

    output$institutes_voting_counts <- renderTable({
      counts()
    })

    return(counts)
  })
}

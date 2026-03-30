#' User statistics module UI
#'
#' Provides the user interface for displaying statistics related to the current user's
#' voting activity within the B1MG Variant Voting app. This typically includes a table
#' of vote counts or annotations per session, along with a refresh button.
#'
#' @param id A string identifier for the module namespace.
#'
#' @return A Shiny UI element (`fluidPage`) for rendering user statistics.
#' @export
userstatsUI <- function(id, cfg) {
  ns <- shiny::NS(id)
  shiny::fluidPage(
    theme = cfg$theme,
    shiny::tableOutput(ns("user_stats_table")),
    shiny::actionButton(ns("refresh_user_stats"), "Refresh user stats")
  )
}


#' User Stats Server Module
#'
#' This module provides user statistics functionality with automatic refresh
#' when navigating to the user stats tab.
#'
#' @param id Module namespace ID
#' @param login_trigger Reactive that triggers when user logs in
#' @param db_pool Database connection pool
#' @param tab_trigger Optional reactive that triggers when the user stats tab is selected
#'                   This enables automatic refresh of stats when navigating to the page
#' @return Reactive containing user statistics data frame
#' @export
userStatsServer <- function(
  id,
  cfg,
  login_trigger,
  db_pool,
  tab_trigger = NULL
) {
  shiny::moduleServer(id, function(input, output, session) {
    # Create a reactive that triggers when the user stats tab is selected
    # This allows automatic refresh when navigating to the stats page
    tab_change_trigger <- shiny::reactive({
      if (!is.null(tab_trigger)) {
        tab_trigger()
      } else {
        NULL
      }
    })

    stats <- shiny::eventReactive(
      c(login_trigger(), input$refresh_user_stats, tab_change_trigger()),
      {
        shiny::req(login_trigger())
        user_annotations_file <- session$userData$userAnnotationsFile

        if (!file.exists(user_annotations_file)) {
          return(data.frame())
        }

        annotations_df <- read.table(
          user_annotations_file,
          header = TRUE,
          sep = "\t",
          stringsAsFactors = FALSE,
          quote = ""
        )
        annotations_df <- annotations_df[
          !is.na(annotations_df$shinyauthr_session_id),
        ]

        session_counts_df <- annotations_df %>%
          dplyr::group_by(shinyauthr_session_id) %>%
          dplyr::summarise(images_voted = dplyr::n(), .groups = "drop")

        # TODO dbReadTable does not seem to work with pool
        session_df <- DBI::dbReadTable(db_pool, "sessionids") %>%
          dplyr::filter(userid == session$userData$userId) %>%
          dplyr::mutate(
            login_time = lubridate::ymd_hms(login_time),
            logout_time = lubridate::ymd_hms(logout_time)
          ) %>%
          dplyr::filter(!is.na(logout_time)) %>%
          dplyr::mutate(
            session_length = as.numeric(difftime(
              logout_time,
              login_time,
              units = "mins"
            ))
          )
        session_times <- session_df$session_length

        average_session_length <- NA
        max_session_length <- NA
        if (length(session_times) > 0) {
          average_session_length <- mean(session_times)
          max_session_length <- max(session_times)
        }

        time_vals <- as.numeric(annotations_df$time_till_vote_casted_in_seconds)
        time_vals <- time_vals[!is.na(time_vals)]

        average_time_per_vote <- NA
        max_time_per_vote <- NA
        if (length(time_vals) > 0) {
          average_time_per_vote <- mean(time_vals)
          max_time_per_vote <- max(time_vals)
        }

        voting_stats_df <- data.frame(
          user_id = session$userData$userId,
          voting_institute = session$userData$votingInstitute,
          total_votes = sum(session_counts_df$images_voted),
          total_sessions_with_at_least_1_vote = nrow(session_counts_df),
          average_votes_per_session = mean(session_counts_df$images_voted),
          max_votes_per_session = max(session_counts_df$images_voted),
          average_session_length_in_minutes = average_session_length,
          max_session_length_in_minutes = max_session_length,
          average_time_per_vote_in_seconds = average_time_per_vote,
          max_time_per_vote_in_seconds = max_time_per_vote
        )

        transposed_df <- as.data.frame(t(voting_stats_df))
        colnames(transposed_df) <- "value"
        transposed_df$metric <- rownames(transposed_df)
        rownames(transposed_df) <- NULL
        transposed_df <- transposed_df[, c("metric", "value")]
        transposed_df
      }
    )

    output$user_stats_table <- shiny::renderTable({
      stats()
    })

    return(stats)
  })
}

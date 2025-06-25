userStatsUI <- function(id) {
  ns <- NS(id)
  tagList(
    tableOutput(ns("user_stats_table")),
    actionButton(ns("refresh_user_stats"), "Refresh user stats")
  )
}

userStatsServer <- function(id, login_trigger) {
  moduleServer(id, function(input, output, session) {
    stats <- eventReactive(c(login_trigger(), input$refresh_user_stats), {
      req(login_trigger())
      user_info_file <- session$userData$userInfoFile
      user_annotations_file <- session$userData$userAnnotationsFile

      if (!file.exists(user_info_file)) {
        return(data.frame())
      }

      annotations_df <- read.table(
        user_annotations_file,
        header = TRUE,
        sep = "\t",
        stringsAsFactors = FALSE
      )
      annotations_df <- annotations_df[!is.na(annotations_df$shiny_session_id), ]

      session_counts_df <- annotations_df %>%
        group_by(shiny_session_id) %>%
        summarise(images_voted = n(), .groups = 'drop')

      user_info <- read_json(user_info_file)
      sessions <- user_info$sessions
      session_times <- sapply(sessions, function(s) {
        if (!is.null(s$start_time) && !is.null(s$end_time)) {
          as.numeric(difftime(s$end_time, s$start_time, units = "mins"))
        } else {
          NA
        }
      })
      session_times <- session_times[!is.na(session_times)]

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
        total_sessions = nrow(session_counts_df),
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
    })

    output$user_stats_table <- renderTable({
      stats()
    })

    return(stats)
  })
}

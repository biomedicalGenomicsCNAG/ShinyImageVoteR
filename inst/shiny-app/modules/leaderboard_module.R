leaderboardUI <- function(id) {
  ns <- NS(id)
  fluidPage(
    tableOutput(ns("institutes_voting_counts")),
    actionButton(ns("refresh_counts"), "Refresh counts")
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
leaderboardServer <- function(id, login_trigger, tab_trigger = NULL) {
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
    
    counts <- eventReactive(c(login_trigger(), input$refresh_counts, tab_change_trigger()), {
      req(login_trigger())
      counts_list <- lapply(cfg_institute_ids, function(institute) {
        institutes_dir <- file.path(cfg_user_data_dir, institute)
        if (!dir.exists(institutes_dir)) {
          return(data.frame(institute = institute, users = 0, total_images_voted = 0))
        }
        user_dirs <- list.dirs(institutes_dir, full.names = TRUE, recursive = FALSE)
        total_users <- length(user_dirs)
        total_images <- 0
        for (user_dir in user_dirs) {
          user_annotations_file <- file.path(user_dir, paste0(basename(user_dir), "_annotations.tsv"))
          if (!file.exists(user_annotations_file)) {
            next
          }
          user_annotations_df <- read.table(
            user_annotations_file,
            header = TRUE,
            sep = "\t",
            stringsAsFactors = FALSE
          )
          user_voted_images <- sum(!is.na(user_annotations_df$shinyauthr_session_id))
          total_images <- total_images + user_voted_images
        }
        data.frame(institute = institute, users = total_users, total_images_voted = total_images)
      })
      counts_df <- do.call(rbind, counts_list)
      counts_df <- counts_df %>%
        mutate(institute = factor(institute, levels = cfg_institute_ids)) %>%
        arrange(desc(total_images_voted))
      counts_df
    })

    output$institutes_voting_counts <- renderTable({
      counts()
    })

    return(counts)
  })
}

leaderboardUI <- function(id) {
  ns <- NS(id)
  tagList(
    tableOutput(ns("institutes_voting_counts")),
    actionButton(ns("refresh_counts"), "Refresh counts")
  )
}

leaderboardServer <- function(id, login_trigger) {
  moduleServer(id, function(input, output, session) {
    counts <- eventReactive(c(login_trigger(), input$refresh_counts), {
      req(login_trigger())
      counts_list <- lapply(cfg_institute_ids, function(institute) {
        institutes_dir <- file.path("user_data", institute)
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
          user_voted_images <- sum(!is.na(user_annotations_df$shiny_session_id))
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

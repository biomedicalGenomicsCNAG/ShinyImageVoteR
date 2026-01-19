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
    shiny::uiOutput(ns("institutes_voting_counts")),
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
#' @param db_conn A database pool or connection used to fetch institutes
#' @param tab_trigger Optional reactive that triggers when the leaderboard tab is selected
#'                   This enables automatic refresh of counts when navigating to the page
#' @return Reactive containing leaderboard data frame
#' @export
leaderboardServer <- function(
  id,
  cfg,
  login_trigger,
  db_conn,
  tab_trigger = NULL
) {
  shiny::moduleServer(id, function(input, output, session) {
    # Create a reactive that triggers when the leaderboard tab is selected
    # This allows automatic refresh when navigating to the leaderboard page
    tab_change_trigger <- shiny::reactive({
      if (!is.null(tab_trigger)) {
        tab_trigger()
      } else {
        NULL
      }
    })

    counts <- shiny::eventReactive(
      c(login_trigger(), input$refresh_counts, tab_change_trigger()),
      {
        shiny::req(login_trigger())
        institutes_df <- DBI::dbGetQuery(
          db_conn,
          "SELECT DISTINCT institute FROM passwords WHERE institute IS NOT NULL AND institute != ''"
        )
        institute_ids <- as.character(institutes_df$institute)
        if (length(institute_ids) == 0) {
          institute_ids <- unlist(strsplit(
            Sys.getenv("IMGVOTER_USER_GROUPS_COMMA_SEPARATED"),
            ","
          ))
        }

        counts_list <- lapply(institute_ids, function(institute) {
          users_df <- DBI::dbGetQuery(
            db_conn,
            "SELECT userid FROM passwords WHERE institute = ?",
            params = list(institute)
          )
          institute_users <- as.character(users_df$userid)

          institutes_dir <- file.path(
            Sys.getenv("IMGVOTER_USER_DATA_DIR"),
            institute
          )
          user_dirs <- list.dirs(
            institutes_dir,
            full.names = TRUE,
            recursive = FALSE
          )
          total_users <- length(unique(institute_users))
          total_images <- 0
          total_skipped <- 0
          unique_keys <- character(0)
          per_user_rows <- list()
          for (user_id in institute_users) {
            user_annotations_file <- file.path(
              Sys.getenv("IMGVOTER_USER_DATA_DIR"),
              institute,
              user_id,
              paste0(user_id, "_annotations.tsv")
            )

            user_voted_images <- 0
            user_skipped_images <- 0

            if (file.exists(user_annotations_file)) {
              user_annotations_df <- read.table(
                user_annotations_file,
                header = TRUE,
                sep = "\t",
                stringsAsFactors = FALSE
              )
              has_session <- !is.na(user_annotations_df$shinyauthr_session_id)
              has_skip <- !is.na(user_annotations_df$agreement) &
                grepl("^skipped -", user_annotations_df$agreement)

              user_voted_images <- sum(has_session & !has_skip)
              user_skipped_images <- sum(has_skip)

              user_voted_df <- user_annotations_df[has_session & !has_skip, ]
              if (nrow(user_voted_df) > 0) {
                user_keys <- paste(
                  user_voted_df$coordinates,
                  user_voted_df$REF,
                  user_voted_df$ALT,
                  sep = "|"
                )
                unique_keys <- unique(c(unique_keys, user_keys))
              }
            }

            total_images <- total_images + user_voted_images
            total_skipped <- total_skipped + user_skipped_images

            per_user_rows[[length(per_user_rows) + 1]] <- data.frame(
              user_id = user_id,
              images_voted = user_voted_images,
              skipped_images = user_skipped_images,
              stringsAsFactors = FALSE
            )
          }
          per_user_df <- if (length(per_user_rows) > 0) {
            do.call(rbind, per_user_rows)
          } else {
            data.frame(
              user_id = character(0),
              images_voted = integer(0),
              skipped_images = integer(0),
              stringsAsFactors = FALSE
            )
          }

          list(
            summary = data.frame(
              institute = institute,
              users = total_users,
              total_images_voted = total_images,
              skipped_images = total_skipped,
              unique_images_voted = length(unique_keys)
            ),
            per_user = per_user_df
          )
        })
        counts_df <- do.call(
          rbind,
          lapply(counts_list, function(x) x$summary)
        )

        counts_df <- counts_df %>%
          dplyr::mutate(
            institute = factor(institute, levels = institute_ids)
          ) %>%
          dplyr::arrange(dplyr::desc(total_images_voted))

        per_user_list <- lapply(counts_list, function(x) x$per_user)
        names(per_user_list) <- institute_ids

        list(
          summary = counts_df,
          per_user = per_user_list
        )
      }
    )

    output$institutes_voting_counts <- shiny::renderUI({
      counts_data <- counts()
      is_admin <- isTRUE(login_trigger()$admin == 1)
      ns <- session$ns

      if (!is_admin) {
        shiny::tableOutput(ns("institutes_voting_counts_table"))
      } else {
        summary_df <- counts_data$summary
        per_user_list <- counts_data$per_user

        build_user_table <- function(user_df) {
          shiny::tags$table(
            class = "table table-striped table-sm",
            shiny::tags$thead(
              shiny::tags$tr(
                shiny::tags$th("User"),
                shiny::tags$th("Images voted"),
                shiny::tags$th("Skipped images")
              )
            ),
            shiny::tags$tbody(
              lapply(seq_len(nrow(user_df)), function(i) {
                shiny::tags$tr(
                  shiny::tags$td(user_df$user_id[i]),
                  shiny::tags$td(user_df$images_voted[i]),
                  shiny::tags$td(user_df$skipped_images[i])
                )
              })
            )
          )
        }

        shiny::tagList(
          lapply(seq_len(nrow(summary_df)), function(i) {
            institute <- as.character(summary_df$institute[i])
            user_df <- per_user_list[[institute]]
            if (is.null(user_df)) {
              user_df <- data.frame(
                user_id = character(0),
                images_voted = integer(0),
                skipped_images = integer(0),
                stringsAsFactors = FALSE
              )
            }

            shiny::tags$details(
              shiny::tags$summary(
                sprintf(
                  "%s | Users: %s | Total: %s | Skipped: %s | Unique: %s",
                  institute,
                  summary_df$users[i],
                  summary_df$total_images_voted[i],
                  summary_df$skipped_images[i],
                  summary_df$unique_images_voted[i]
                )
              ),
              build_user_table(user_df)
            )
          })
        )
      }
    })

    output$institutes_voting_counts_table <- shiny::renderTable({
      counts()$summary
    })

    return(counts)
  })
}

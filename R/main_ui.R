#' Voting app UI
#'
#' @return A Shiny UI object (tagList)
#' @export
votingAppUI <- function(cfg) {
  # cfg <- ShinyImgVoteR::load_config(
  #   config_file_path = Sys.getenv("IMGVOTER_CONFIG_FILE_PATH")
  # )

  fluidPage(
    theme = cfg$theme,
    shiny::conditionalPanel(
      condition = "!output.logged_in",
      loginUI("login", cfg)
    ),

    shiny::conditionalPanel(
      condition = "output.logged_in",
      tagList(
        navbarPage(
          theme = cfg$theme,
          cfg$application_title,
          id = "main_navbar",
          tabPanel("Vote", votingUI("voting", cfg)),
          tabPanel("Leaderboard", leaderboardUI("leaderboard",  cfg)),
          tabPanel("User stats", userStatsUI("userstats",  cfg)),
          tabPanel("About", aboutUI("about", cfg)),
          tabPanel("FAQ", includeMarkdown(
            file.path(
              get_app_dir(),
              "docs",
              "faq.md"
            )
          )),
          header = div(
            style = "position:absolute; right:1em; top:0.5em; z-index:1000;",
            shinyauthr::logoutUI("logout")
          )
        )
      )
    )
  )
}

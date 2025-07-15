#' Voting app UI
#'
#' @return A Shiny UI object (tagList)
#' @export
votingAppUI <- function() {
  cfg <- ShinyImgVoteR::load_config()
  fluidPage(
    shiny::conditionalPanel(
      condition = "!output.logged_in",
      loginUI("login")
    ),

    shiny::conditionalPanel(
      condition = "output.logged_in",
      tagList(
        navbarPage(
          cfg$application_title,
          id = "main_navbar",
          tabPanel("Vote", votingUI("voting")),
          tabPanel("Leaderboard", leaderboardUI("leaderboard")),
          tabPanel("User stats", userStatsUI("userstats")),
          tabPanel("About", aboutUI("about")),
          tabPanel("FAQ", includeMarkdown("docs/faq.md")),
          header = div(
            style = "position:absolute; right:1em; top:0.5em; z-index:1000;",
            shinyauthr::logoutUI("logout")
          )
        )
      )
    )
  )
}

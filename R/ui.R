# Main UI
ui <- fluidPage(
  conditionalPanel(
    condition = "!output.logged_in",
    loginUI("login")
  ),

  conditionalPanel(
    condition = "output.logged_in",
    tagList(
      navbarPage(
        cfg_application_title,
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

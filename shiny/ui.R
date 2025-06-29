source("modules/login_module.R")
source("modules/voting_module.R")
source("modules/leaderboard_module.R")
source("modules/user_stats_module.R")
source("modules/about_module.R")

# Main UI
ui <- fluidPage(
  includeCSS("www/css/styles.css"), 

  conditionalPanel(
    condition = "!output.logged_in",
    loginUI("login")
  ),

  conditionalPanel(
    condition = "output.logged_in",
    navbarPage(
      cfg_application_title,
      tabPanel("Vote",          votingUI("voting")),
      tabPanel("Leaderboard",   leaderboardUI("leaderboard")),
      tabPanel("User stats",    userStatsUI("userstats")),
      tabPanel("About",         aboutUI("about"))
    )
  )
)
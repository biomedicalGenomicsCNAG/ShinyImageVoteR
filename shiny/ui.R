source("modules/voting_module.R")
source("modules/leaderboard_module.R")
source("modules/user_stats_module.R")
source("modules/about_module.R")

# main_page is only visible after login
main_page <- function() {
  tagList(
    div(class = "pull-right", shinyauthr::logoutUI("logout")),
    navbarPage(
      cfg_application_title,
      tabPanel(
        "Vote",
        votingUI("voting")
      ),
      tabPanel(
        "Leaderboard",
        leaderboardUI("leaderboard")
      ),
      tabPanel(
        "User stats",
        userStatsUI("userstats")
      ),
      tabPanel(
        "About",
        aboutUI("about")
      )
    )
  )
}

# Main UI
ui <- fluidPage(
  includeCSS("www/css/styles.css"), 
  htmlOutput("page"),
)
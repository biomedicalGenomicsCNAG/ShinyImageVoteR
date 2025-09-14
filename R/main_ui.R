#' Voting app UI
#'
#' @return A Shiny UI object (tagList)
#' @export
votingAppUI <- function(cfg) {
  shiny::fluidPage(
    theme = cfg$theme,
    shiny::conditionalPanel(
      condition = "!output.logged_in",
      loginUI("login", cfg)
    ),
    shiny::conditionalPanel(
      condition = "output.logged_in",
      shiny::tagList(
        # 1. inject your CSS
        shiny::tags$head(
          tags$style(HTML("
              @media (max-width: 990px) {
                #logout-btn {
                  right: 8em !important;
                }
              }
            "))
        ),
        shiny::navbarPage(
          theme = cfg$theme,
          collapsible = TRUE,
          cfg$application_title,
          id = "main_navbar",
          shiny::tabPanel("Vote", votingUI("voting", cfg)),
          shiny::tabPanel("Leaderboard", leaderboardUI("leaderboard", cfg)),
          shiny::tabPanel("User stats", userstatsUI("userstats", cfg)),
          shiny::tabPanel("About", aboutUI("about", cfg)),
          shiny::tabPanel("FAQ", shiny::includeMarkdown(
            file.path(
              get_app_dir(),
              "docs",
              "faq.md"
            )
          )),
          header = shiny::div(
            id    = "logout-btn",
            style = "position:absolute; right:1em; top:0.5em; z-index:1000;",
            shinyauthr::logoutUI("logout")
          )
        )
      )
    )
  )
}

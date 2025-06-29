library(shinyjs)
source("modules/login_module.R")
source("modules/leaderboard_module.R")
source("modules/user_stats_module.R")
source("modules/about_module.R")

source("modules/voting_module.R")

color_seq <- function(seq, nt2color_map) {
  print("Coloring sequence:")
  print(seq)

  colored_seq <- seq %>%
    strsplit(., split = "") %>%
    unlist() %>%
    sapply(., function(x) sprintf('<span style="color:%s">%s</span>', nt2color_map[x], x)) %>%
    paste(collapse = "")
  colored_seq
}

render_voting_image_div <- function(mut_df, nt2color_map) {
  div(
    img(
      id = "mutationImage",
      src = paste0(mut_df$path),
    ),
    div(
      HTML(paste0(
        "Somatic mutation: ", 
        color_seq(mut_df$REF, nt2color_map),
        " > ", 
        color_seq(mut_df$ALT, nt2color_map)
      ))
    ),
    br()
  )
}

main_page <- function() {
   tagList(
    navbarPage(
      cfg_application_title,
      tabPanel(
        "Vote",
        fluidPage(votingUI("voting"))
      ),
      tabPanel(
        "Leaderboard",
        fluidPage(leaderboardUI("leaderboard"))
      ),
      tabPanel(
        "User stats",
        fluidPage(userStatsUI("userstats"))
      ),
      tabPanel(
        "About",
        fluidPage(aboutUI("about"))
      )
    )
  )
}

# Main UI
ui <- fluidPage(
  useShinyjs(),  # Initialize shinyjs
  includeCSS("www/css/styles.css"),  # Include custom CSS
  tags$head(
    tags$script("
      $(document).on('keydown', function(e) {
        if (e.key === 'Enter') {
          $('#login-loginBtn').click();
        }
      });
    "),
  ),
  htmlOutput("page"),
)
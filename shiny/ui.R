ui1 <- function() {
  tagList(
    div(
      id = "login",
      wellPanel(
        selectInput(
          inputId = "institutes_id",
          label = "Institute ID",
          choices = cfg_institute_ids,
          selected = cfg_selected_institute_id
        ),
        textInput(
          inputId = "user_id",
          label = "User ID",
          value = cfg_selected_user_id
        ),
        passwordInput("passwd", "Password", value = ""),
        br(),
        actionButton("loginBtn", "Log in"),
        br(),
      )
    ),
    tags$style(
      type = "text/css",
      "#login {font-size:10px; text-align: left; position:absolute; top: 40%; left: 50%; margin-top: -100px; margin-left: -150px;}"
    )
  )
}

# Main UI (after login)
ui2 <- function() {
   tagList(
    navbarPage(
      "Variant voter",
      tabPanel(
        shiny::singleton(
          includeScript("www/scripts/hotkeys.js")
        ),
        title = "Vote",
        fluidPage(
          uiOutput("ui2_image"),
          uiOutput("ui2_questions")
        ),
        hidden(
          disabled(
            actionButton(
              "backBtn",  
              "Back (press Backspace)",
              onclick="history.back(); return false;")
            )
        ),
        actionButton("nextBtn",  "Next (press Enter)")
      ),
      tabPanel(
        "Leaderboard",
        fluidPage(
          tableOutput("institutes_voting_counts"),
          actionButton("refresh_counts", "Refresh counts")
        )
      ),
      tabPanel(
        "User stats",
        fluidPage(
         tableOutput("user_stats_table"),
         actionButton("refresh_user_stats", "Refresh user stats"), 
        )
      ),
      tabPanel(
        "About",
        fluidPage(
          h3("About this app"),
          p("This app allows users to vote on somatic mutations in images."),
          p("Users can log in, view images, and provide their votes and comments."),
          p("The app tracks user sessions and stores annotations in a SQLite database."),
          p("Developed by Ivo Christopher Leist")
        )
      )
    )
  )
}

# Main UI ####
ui <- fluidPage(
  useShinyjs(),  # Initialize shinyjs
  tags$head(
    tags$script("
      $(document).on('keydown', function(e) {
        if (e.key === 'Enter') {
          $('#loginBtn').click();
        }
      });
    "),
  ),
  htmlOutput("page"),
)


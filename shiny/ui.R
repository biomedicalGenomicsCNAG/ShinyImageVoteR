library(shinyjs)
library(shinyauthr)

login_page <- function() {
  tagList(
    div(
      id = "login",
      wellPanel(
        selectInput(
          inputId = "institutes_id",
          label = "Institute",
          choices = cfg_institute_ids,
          selected = cfg_selected_institute_id
        ),
        shinyauthr::loginUI("auth")
      )
    )
  )
}

render_login_page <- function() {
  div(class = "outer", do.call(
    bootstrapPage, 
    c("", loginUI(
      "Login",
      id="login"
    ))
  ))
}

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

render_voting_questions_div <- function() {
  div(
    radioButtons(
      inputId = "agreement",
      label = cfg_radioBtns_label,
      choices = cfg_radio_options2val_map
    ),
    conditionalPanel(
      condition = "input.agreement == 'not_confident'",
      checkboxGroupInput(
        inputId = "observation",
        label = cfg_checkboxes_label,
        choices = cfg_observations2val_map
      )
    ),
    conditionalPanel(
      condition = "input.agreement == 'diff_var' || input.agreement == 'not_confident'",
      textInput(
        inputId = "comment",
        label = "Comments",
        value = ""
      )
    )
  )
}

voting_page <- function() {
   tagList(
  navbarPage(
    "Variant voter",
    header = div(
      shinyauthr::logoutUI("logout")
    ),
      tabPanel(
        shiny::singleton(
          includeScript("www/scripts/hotkeys.js")
        ),
        title = "Vote",
        fluidPage(
          uiOutput("voting_image_div"),
          uiOutput("voting_questions_div"),
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

render_voting_page <- function() {
  div(class = "outer", do.call(bootstrapPage, c("", voting_page())))
}

# Main UI
ui <- fluidPage(
  useShinyjs(),  # Initialize shinyjs
  includeCSS("www/css/styles.css"),  # Include custom CSS
  tags$head(
    tags$script("
      $(document).on('keydown', function(e) {
        if (e.key === 'Enter') {
          $('#auth-login_button').click();
        }
      });
    ")
  ),
  htmlOutput('page')
)

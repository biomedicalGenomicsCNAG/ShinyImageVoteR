library(shinyjs)

login_page <- function() {
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
        div(
          id = "login_error",
          style = "color:red;"
        ),
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

render_login_page <- function() {
  div(class = "outer", do.call(bootstrapPage, c("", login_page())))
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
      id = "variantImage",
      src = paste0(mut_df$path),
      style = "max-width:100%; height:auto;"
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
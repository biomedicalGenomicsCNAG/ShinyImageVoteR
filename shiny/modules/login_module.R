source("config.R")

loginUI <- function(id) {
  ns <- NS(id)
  tagList(
    tags$script("
      $(document).on('keydown', function(e) {
        if (e.key === 'Enter') {
          $('#login-loginBtn').click();
        }
      });
    "),
    div(
      id = ns("loginPanel"),
      wellPanel(
        selectInput(
          inputId = ns("institutes_id"),
          label = "Institute",
          choices = cfg_institute_ids,
          selected = cfg_selected_institute_id
        ),
        textInput(
          inputId = ns("user_id"),
          label = "Username",
          value = cfg_selected_user_id
        ),
        passwordInput(ns("passwd"), "Password", value = ""),
        textOutput(ns("login_error")),
        br(),
        actionButton(ns("loginBtn"), "Log in"),
        br()
      )
    )
  )
}

loginServer <- function(id) {
  moduleServer(id, function(input, output, session) {

    login_data <- eventReactive(input$loginBtn, {
      user_id <- input$user_id

      if (input$passwd != passwords[user_id]) {
        output$login_error <- renderText({
          "Invalid username or password"
        })
        return(NULL)
      }

      output$login_error <- renderText({ "" })
      list(
        user_id = user_id,
        voting_institute = input$institutes_id
      )
    })
    return(login_data)
  })
}

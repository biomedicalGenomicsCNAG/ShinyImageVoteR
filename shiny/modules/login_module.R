source("config.R")
library(shinyauthr)

loginUI <- function(id) {
  ns <- NS(id)
  wellPanel(
    id = ns("loginPanel"),
    h3(paste0("Welcome to ", cfg_application_title)),
    br(),
    h4("First select your institute"),
    selectInput(
      inputId = ns("institutes_id"),
      label = "Institute",
      choices = cfg_institute_ids,
      selected = cfg_selected_institute_id
    ),
    h4("Then enter your user name and password"),
    shinyauthr::loginUI(
      ns("auth"),
      ""
    ),
    style = "
      position: absolute;
      top: 50%; left: 50%;
      transform: translate(-50%, -50%);
      max-width: 400px;
      width: 90%;
    "
  )
}

loginServer <- function(id) {
  moduleServer(id, function(input, output, session) {

    print("cfg_credentials_df:")
    print(cfg_credentials_df)

    credentials <- shinyauthr::loginServer(
      id = "auth",
      data = cfg_credentials_df,
      user_col = user,
      pwd_col = password,
      sodium_hashed = FALSE
      # log_out = reactive(FALSE) for what is this?
    )

    login_data <- reactive({
      req(credentials()$user_auth)
      list(
        user_id = credentials()$info$user,
        voting_institute = input$institutes_id
      )
    })

    return(login_data)
  })
}


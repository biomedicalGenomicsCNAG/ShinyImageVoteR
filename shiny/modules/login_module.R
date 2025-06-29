loginUI <- function(id) {
  ns <- NS(id)
  div(
    id = ns("loginPanel"),
    wellPanel(
      selectInput(
        inputId = ns("institutes_id"),
        label = "Institute",
        choices = cfg_institute_ids,
        selected = cfg_selected_institute_id
      ),
      shinyauthr::loginUI(ns("auth"))
    )
  )
}

loginServer <- function(id) {
  moduleServer(id, function(input, output, session) {
    user_base <- data.frame(
      user = cfg_user_ids,
      password = unname(passwords),
      stringsAsFactors = FALSE
    )

    credentials <- shinyauthr::loginServer(
      id = "auth",
      data = user_base,
      user_col = user,
      pwd_col = password,
      sodium_hashed = FALSE,
      log_out = reactive(logout_init())
    )

    logout_init <- shinyauthr::logoutServer(
      id = "logout",
      active = reactive(credentials()$user_auth)
    )

    login_data <- reactive({
      req(credentials()$user_auth)
      list(
        user_id = credentials()$info$user,
        voting_institute = input$institutes_id
      )
    })

    login_data
  })
}

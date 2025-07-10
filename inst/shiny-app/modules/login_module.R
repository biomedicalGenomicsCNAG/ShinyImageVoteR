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

loginServer <- function(id, db_conn = NULL, log_out = reactive(NULL)) {
  moduleServer(id, function(input, output, session) {

    add_sessionid_to_db <- function(user, sessionid, conn = db_conn) {
      tibble(
        user = user,
        sessionid = sessionid,
        login_time = as.character(lubridate::now()),
        logout_time = NA_character_
      ) %>%
      dbWriteTable(conn, "sessionids", ., append = TRUE)
    }

    update_logout_time_in_db <- function(sessionid, conn = db_conn) {
      dbExecute(
        conn,
        "UPDATE sessionids SET logout_time = ? WHERE sessionid = ? AND logout_time IS NULL",
        params = list(as.character(lubridate::now()), sessionid)
      )
    }

    get_sessionids_from_db <- function(conn = db_conn, expiry = cfg_cookie_expiry) {
      dbReadTable(conn, "sessionids") %>%
        mutate(login_time = lubridate::ymd_hms(login_time)) %>%
        as_tibble() %>%
        filter(
          is.na(logout_time),
          login_time > lubridate::now() - lubridate::days(expiry)
        )
    }

    print("cfg_credentials_df:")
    print(cfg_credentials_df)

    credentials <- shinyauthr::loginServer(
      id = "auth",
      data = cfg_credentials_df,
      user_col = user,
      pwd_col = password,
      sodium_hashed = FALSE,
      cookie_logins = TRUE,
      sessionid_col = sessionid,
      cookie_getter = get_sessionids_from_db,
      cookie_setter = add_sessionid_to_db,
      log_out = log_out,
    )

    login_data <- reactive({
      req(credentials()$user_auth)
      list(
        user_id = credentials()$info$user,
        voting_institute = input$institutes_id,
        session_id = credentials()$info$sessionid
      )
    })

    # return(login_data)
    return(list(
      login_data = login_data,
      credentials = credentials,
      update_logout_time = update_logout_time_in_db
    ))
  })
}


library(shinyauthr)
library(shiny)


#' Login module UI
#'
#' Provides the user interface for logging in to the B1MG Variant Voting application.
#' This module is based on `shinyauthr` and includes reactive user authentication.
#'
#' @param id A string identifier for the module namespace.
#' @return A Shiny UI element (typically a login panel) rendered within a namespace.
#' @export
loginUI <- function(id, cfg) {
  ns <- shiny::NS(id)
  shiny::wellPanel(
    id = ns("loginPanel"),
    theme = cfg$theme,
    shiny::h3(paste0("Welcome to ", cfg$application_title)),
    shiny::br(),
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

#' Login module server logic
#'
#' Handles user authentication and session tracking using the `shinyauthr` package.
#' This module supports login via a database-backed user table and emits reactive
#' values for downstream modules to consume.
#'
#' It also supports optional logout triggering and updates the session tracking database.
#'
#' @param id A string identifier for the module namespace.
#' @param db_conn A database pool connection (e.g. SQLite or PostgreSQL) used to track sessions.
#' @param log_out A reactive trigger (default: `reactive(NULL)`) to perform logout actions.
#'
#' @return A list containing:
#' \describe{
#'   \item{login_data}{A `reactiveVal` holding login metadata (e.g. user ID, voting institute, session ID)}
#'   \item{credentials}{A `reactive` object with user authentication status}
#'   \item{update_logout_time}{A function to record logout time for a session ID}
#' }
#' @importFrom magrittr %>%
#' @export
loginServer <- function(id, cfg, db_conn = NULL, log_out = reactive(NULL)) {
  moduleServer(id, function(input, output, session) {
    add_sessionid_to_db <- function(userid, sessionid, conn = db_conn) {
      tibble::tibble(
        userid = userid,
        sessionid = sessionid,
        login_time = as.character(lubridate::now()),
        logout_time = NA_character_
      ) %>%
        DBI::dbWriteTable(conn, "sessionids", ., append = TRUE)
    }

    update_logout_time_in_db <- function(sessionid, conn = db_conn) {
      DBI::dbExecute(
        conn,
        "UPDATE sessionids SET logout_time = ? WHERE sessionid = ? AND logout_time IS NULL",
        params = list(as.character(lubridate::now()), sessionid)
      )
    }

    # get_sessionids_from_db <- function(conn = db_conn, expiry = cfg$cookie_expiry) {
    #   DBI::dbReadTable(conn, "sessionids") %>%
    #     dplyr::mutate(login_time = lubridate::ymd_hms(login_time)) %>%
    #     tibble::as_tibble() %>%
    #     dplyr::filter(
    #       is.na(logout_time),
    #       login_time > lubridate::now() - lubridate::days(expiry)
    #     )
    # }

    get_sessionids_from_db <- function(
      conn = db_conn,
      expiry = cfg$cookie_expiry
    ) {
      DBI::dbGetQuery(
        conn,
        "SELECT userid, sessionid, login_time, logout_time
         FROM sessionids"
      ) %>%
        tibble::as_tibble() %>%
        dplyr::mutate(
          login_time = lubridate::ymd_hms(login_time)
        ) %>%
        dplyr::filter(
          is.na(logout_time),
          login_time > lubridate::now() - lubridate::days(expiry)
        )
    }

    # --- Load credentials once at session start -------------------------------
    user_base <- DBI::dbGetQuery(
      db_conn,
      "SELECT userid, password, institute, admin
       FROM passwords"
    ) %>%
      tibble::as_tibble()

    print("Loaded user base:")
    print(user_base)

    credentials <- shinyauthr::loginServer(
      id = "auth",
      data = user_base,
      user_col = userid,
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
        user_id = credentials()$info$userid,
        institute = credentials()$info$institute,
        session_id = credentials()$info$sessionid,
        admin = credentials()$info$admin
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

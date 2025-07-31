stub_loginServer <- function(id, cfg, db_conn = NULL, log_out = reactive(NULL)) {
  .test_login_rv <<- shiny::reactiveVal()
  list(
    cfg,
    login_data = reactive(.test_login_rv()),
    credentials = reactive(list(user_auth = TRUE)),
    update_logout_time = function(sessionid, conn = NULL) {
      .update_called <<- sessionid
    }
  )
}
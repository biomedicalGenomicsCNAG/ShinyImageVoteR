# Utility functions for scheduling logout updates
pending_logout_tasks <- new.env(parent = emptyenv())

schedule_logout_update <- function(sessionid, callback, delay = 5) {
  cancel_pending_logout(sessionid)
  handle <- later::later(function() {
    callback()
    rm(list = sessionid, envir = pending_logout_tasks)
  }, delay)
  assign(sessionid, handle, envir = pending_logout_tasks)
}

cancel_pending_logout <- function(sessionid) {
  if (exists(sessionid, envir = pending_logout_tasks)) {
    handle <- get(sessionid, envir = pending_logout_tasks)
    later::cancel(handle)
    rm(list = sessionid, envir = pending_logout_tasks)
  }
}
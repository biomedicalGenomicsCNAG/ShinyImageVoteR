# #' Server Utility Functions for B1MG Variant Voting
# #'
# #' This file contains utility functions for managing logout scheduling
# #' and other server-side operations.
# #'
# #' @name server_utils
# NULL

# # Global environment for tracking pending logout tasks
# pending_logout_tasks <- new.env(parent = emptyenv())

# #' Schedule a logout update with delay
# #'
# #' @param sessionid Character. The session ID to schedule logout for
# #' @param callback Function. The callback function to execute after delay
# #' @param delay Numeric. Delay in seconds before executing callback
# #' @export
# schedule_logout_update <- function(sessionid, callback, delay = 5) {
#   cancel_pending_logout(sessionid)
#   handle <- later::later(function() {
#     callback()
#     rm(list = sessionid, envir = pending_logout_tasks)
#   }, delay)
#   assign(sessionid, handle, envir = pending_logout_tasks)
# }

# #' Cancel a pending logout update
# #'
# #' @param sessionid Character. The session ID to cancel logout for
# #' @export
# cancel_pending_logout <- function(sessionid) {
#   if (exists(sessionid, envir = pending_logout_tasks)) {
#     handle <- get(sessionid, envir = pending_logout_tasks)
#     handle()                      
#     rm(list = sessionid, envir = pending_logout_tasks)
#   }
# }

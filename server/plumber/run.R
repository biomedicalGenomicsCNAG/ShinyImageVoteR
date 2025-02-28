library(plumber)
api <- plumb("api.R")
api$run(port = 3000, debug = TRUE)

library(shiny)
library(shinyjs)

# load configuration (variables have a "cfg_" prefix)
source("config.R")
source("global.R")
source("ui.R")
source("server.R")

shinyApp(ui, server)
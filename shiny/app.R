library(shiny)
library(shinyjs)

# load configuration (variables have a "cfg_" prefix)
source("config.R")

source("ui.R")
source("server.R")

shinyApp(ui = ui, server = server)
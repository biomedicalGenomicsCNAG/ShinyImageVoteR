aboutUI <- function(id) {
  ns <- shiny::NS(id)
  fluidPage(
    h3("About this app"),
    p("This app allows users to vote on somatic mutations in images."),
    p("Users can log in, view images, and provide their votes and comments."),
    p("The app tracks user sessions and stores annotations in a SQLite database."),
    p("Developed by Ivo Christopher Leist")
  )
}

aboutServer <- function(id) {
  moduleServer(id, function(input, output, session) {
    # No server-side logic needed for the about page
  })
}

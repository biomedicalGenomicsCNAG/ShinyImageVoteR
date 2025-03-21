# setwd("/Users/lestelles/test22/")
source("config.R")
library(shiny)
library(googleAuthR)
library(dplyr)
library(tibble)
library(googlesheets4)

cat(Sys.getenv("GOOGLE_AUTH_CLIENT_ID"))

options(googleAuthR.webapp.client_id = Sys.getenv("GOOGLE_AUTH_CLIENT_ID"))

# Initial login status
Logged <- FALSE

# Login UI with manual inputs and a Google sign-in button
ui1 <- function() {
        tagList(
                div(
                        id = "login",
                        wellPanel(
                                selectInput(
                                        inputId = "voting_institute",
                                        label = "Institute",
                                        choices = c(institutes, "Training (answers won't be saved)")
                                ),
                                # selectInput(
                                #         inputId = "selected_vartype",
                                #         label = "Evaluate variants",
                                #         choices = c("All variants", vartype_dict)
                                # ),
                                passwordInput("passwd", "Password", value = ""),
                                br(),
                                actionButton("Login", "Log in"),
                                br(),
                                # Minimal Google Sign-In button as per your sample
                                googleSignInUI("demo")
                        )
                ),
                tags$style(
                        type = "text/css",
                        "#login {font-size:10px; text-align: left; position:absolute; top: 40%; left: 50%; margin-top: -100px; margin-left: -150px;}"
                )
        )
}

# Main UI (after login)
ui2 <- function() {
        navbarPage(
                "Variant voter",
                tabPanel(
                        "Vote",
                        uiOutput("ui2_questions"),
                        actionButton(inputId = "go", label = "Next"),
                        br(),
                        textOutput("save_txt"),
                        br(),
                        br()
                ),
                tabPanel(
                        "Monitor",
                        fluidPage(
                                h5(sprintf("Total screenshots: %s", nrow(screenshots))),
                                tableOutput("table_counts"),
                                h6(sprintf("*%s training questions are subtracted from the number of votes.", training_questions)),
                                actionButton(inputId = "refresh_counts", label = "Refresh counts")
                        )
                )
        )
}

# Main UI now includes an updated CSP meta tag that allows inline scripts without a nonce.
ui <- fluidPage(
        tags$head(
                tags$meta(
                        `http-equiv` = "Content-Security-Policy",
                        content = "script-src 'self' 'unsafe-inline' 'unsafe-eval' blob: data: https://www.gstatic.com https://apis.google.com;"
                ),
                tags$meta(
                        `http-equiv` = "Cross-Origin-Opener-Policy",
                        content = "same-origin-allow-popups"
                )
        ),
        htmlOutput("page")
)

server <- function(input, output, session) {
        # Set up Google sign in using the minimal sample approach.
        sign_ins <- callModule(googleSignIn, "demo")

        # Reactive value to track user authentication
        USER <- reactiveValues(Logged = Logged)

        # If a user signs in with Google, mark them as logged in.
        observe({
                if (!is.null(sign_ins()) && !is.null(sign_ins()$email)) {
                        # Optionally, assign the signed in email as the institute
                        cat("User signed in with Google")
                        cat("Email: ", sign_ins()$email, "\n")
                        voting_institute <<- sign_ins()$email
                        USER$Logged <- TRUE
                }
        })

        # Manual login logic remains unchanged.
        observeEvent(input$Login, {
                voting_institute <<- isolate(input$voting_institute)
                # vartype <<- isolate(input$selected_vartype)
                submitted_password <- isolate(input$passwd)

                if (passwords[voting_institute] == submitted_password) {
                        USER$Logged <- TRUE
                }
        })

        # Render the appropriate UI based on login status.
        observe({
                if (USER$Logged == FALSE) {
                        output$page <- renderUI({
                                div(class = "outer", do.call(bootstrapPage, c("", ui1())))
                        })
                }
                if (USER$Logged == TRUE) {
                        cat("Observer User logged in !!")
                        output$page <- renderUI({
                                div(class = "outer", do.call(bootstrapPage, c("", ui2())))
                        })
                }
        })

        # ------------------ Rest of Your Server Code ------------------

        picture <<- NULL
        save_txt <- observeEvent(input$go, {
                if (input$go == 0) {
                        picture <<- c(choosePic()$image)
                }
                picture <<- c(picture, choosePic()$image) %>% tail(2)

                if (input$go > 0 && choosePic()$image != "done") {
                        if (!grepl("^Training", voting_institute)) {
                                sheet_append(
                                        ss = drive_paths$annotations,
                                        data = tibble(
                                                "timestamp" = Sys.time(),
                                                "institute" = voting_institute,
                                                "image" = picture[1],
                                                "agreement" = input$agreement,
                                                "observation" = input$observation,
                                                "comment" = input$comment
                                        )
                                )
                        }
                }
        })

        pic <<- tibble()
        choosePic <- eventReactive(c(input$Login, input$go), {
                if (nrow(pic) == 0) {
                        pic <<- choose_picture(
                                drive_paths,
                                institute,
                                training_questions,
                                voting_institute,
                                vartype,
                                screenshots,
                                vartype_dict,
                                n_sample = n_sample
                        )

                        if (nrow(pic) == 0) {
                                pic <<- tibble(
                                        image = "done",
                                        REF = "-", ALT = "-",
                                        coordinates = "There are no more variants to vote in this category!",
                                        path = "https://imgpile.com/images/Ud9lAi.jpg"
                                )
                        }
                }
                first_pic <- head(pic, 1)
                pic <<- slice(pic, -1)
                first_pic
        })

        voterUI <- function() {
                renderUI({
                        fluidPage(
                                p(paste("Logged in as", voting_institute)),
                                h5(choosePic()$coordinates),
                                img(src = paste0(choosePic()$path, "=h2000-w2000")),
                                br(),
                                br(),
                                tags$h5(
                                        HTML(paste0(
                                                "Variant: ", color_seq(choosePic()$REF), " > ", color_seq(choosePic()$ALT),
                                                "&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;"
                                        ))
                                ),
                                br(),
                                radioButtons(
                                        inputId = "agreement",
                                        label = "Is the variant above correct?",
                                        choices = c(
                                                "Yes, it is." = "yes",
                                                "There is no variant." = "no",
                                                "There is a different variant." = "diff_var",
                                                "I'm not sure." = "not_confident"
                                        )
                                ),
                                conditionalPanel(
                                        condition = "input.agreement == 'not_confident'",
                                        checkboxGroupInput(
                                                inputId = "observation",
                                                label = "Observations",
                                                choices = observations_dict
                                        )
                                ),
                                conditionalPanel(
                                        condition = "input.agreement == 'diff_var' || input.agreement == 'not_confident'",
                                        textInput(
                                                inputId = "comment",
                                                label = "Comments",
                                                value = ""
                                        )
                                )
                        )
                })
        }

        output$ui2_questions <- voterUI()

        table_counts <- eventReactive(c(input$Login, input$refresh_counts), {
                read_sheet(drive_paths$annotations) %>%
                        filter(institute %in% institutes) %>%
                        count(Institute = institute, sort = TRUE, name = "Votes") %>%
                        mutate(Votes = as.integer(Votes - training_questions))
        })

        output$table_counts <- renderTable({
                table_counts()
        })
}

# Run the Shiny app
shinyApp(ui = ui, server = server)

# setwd("/Users/lestelles/test22/")
source("config.R")

# Log in UI ####
Logged <- FALSE


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
                selectInput(
                    inputId = "selected_vartype",
                    label = "Evaluate variants",
                    choices = c("All variants", vartype_dict)
                ),
                passwordInput("passwd", "Password", value = ""), # passwords["Test"]),
                br(),
                actionButton("Login", "Log in")
            )
        ),
        tags$style(type = "text/css", "#login {font-size:10px;   text-align: left;position:absolute;top: 40%;left: 50%;margin-top: -100px;margin-left: -150px;}")
    )
}

# Voter placeholder and button UI  ####
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

ui <- htmlOutput("page")

# Define the server code
server <- function(input, output) {
    # Get institute and variant type ####
    observeEvent(input$Login, {
        voting_institute <<- isolate(input$voting_institute)
        vartype <<- isolate(input$selected_vartype)
    })


    # Log in logic ####
    USER <- reactiveValues(Logged = Logged)

    observe({
        if (USER$Logged == FALSE) {
            if (!is.null(input$Login)) {
                if (input$Login > 0) {
                    submitted_password <- isolate(input$passwd)

                    if (passwords[voting_institute] == submitted_password) {
                        USER$Logged <- TRUE
                    }
                }
            }
        }
    })



    observe({
        if (USER$Logged == FALSE) {
            output$page <- renderUI({
                div(class = "outer", do.call(bootstrapPage, c("", ui1())))
            })
        }
        if (USER$Logged == TRUE) {
            output$page <- renderUI({
                div(class = "outer", do.call(bootstrapPage, c("", ui2())))
            })
            print(ui)
        }
    })

    # Save user input ####
    picture <<- NULL
    save_txt <- observeEvent(c(input$go), {
        if (input$go == 0) {
            picture <<- c(choosePic()$image)
        }
        picture <<- c(picture, choosePic()$image) %>% tail(2)

        if (input$go > 0 & choosePic()$image != "done") {
            if (!grepl("^Training", voting_institute)) {
                sheet_append(
                    ss = drive_paths$annotations,
                    data = tibble(
                        "timestamp" = Sys.time(),
                        "institute" = voting_institute,
                        "image" = picture[1],
                        "agreement" = input$agreement,
                        # "alternative_vartype" = input$alt_vartype,
                        "observation" = input$observation,
                        "comment" = input$comment,
                    )
                )
            }
        }
    })

    # Choose a picture ####
    pic <<- tibble()
    choosePic <- eventReactive(c(input$Login, input$go), {
        print("in choosePic")

        print(pic)
        if (nrow(pic) == 0) {
            # print("institute")
            # print(institute)
            print("training_questions")
            print(training_questions)
            print("vartype")
            print(vartype)
            print("voting_institute")
            print(voting_institute)
            print("vartype_dict")
            print(vartype_dict)
            pic <<- choose_picture(drive_paths,
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

            # print(paste("-----------------------------------------------> getting new pics"))
            # print(pic)
        }


        first_pic <- head(pic, 1)
        pic <<- slice(pic, -1)



        first_pic
    })



    # Form UI ####
    voterUI <- function() {
        renderUI({
            fluidPage(
                p(paste("Logged in as", voting_institute)),
                # br(),
                h5(choosePic()$coordinates),
                img(src = choosePic()$path, height = 500, width = 500 * 16 / 9),
                br(),
                br(),
                tags$h5(
                    HTML(paste0(
                        "Variant: ", color_seq(choosePic()$REF), " > ", color_seq(choosePic()$ALT),
                        "&nbsp&nbsp&nbsp&nbsp&nbsp&nbsp&nbsp&nbsp"
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
                    ),
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


    # Monitor ####
    table_counts <- eventReactive(c(input$Login, input$refresh_counts), {
        read_sheet(drive_paths$annotations) %>%
            filter(institute %in% institutes) %>%
            count(Institute = institute, sort = TRUE, name = "Votes") %>%
            mutate(Votes = as.integer(Votes - training_questions))
    })

    table_counts2 <- function() {
        renderTable({
            table_counts()
        })
    }

    output$table_counts <- table_counts2()
}

# Return a Shiny app object
shinyApp(ui = ui, server = server)

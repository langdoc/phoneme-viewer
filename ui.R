
# This is the user-interface definition of a Shiny web application.
# You can find out more about building applications with Shiny here:
#
# http://shiny.rstudio.com
#

library(shiny)
library(shinydashboard)
library(tidyverse)
library(ggplot2)
library(glue)
library(tuneR)
library(seewave)
library(forcats)

shinyUI(dashboardPage(
  dashboardHeader(title = "Phoneme-viewer"),
  dashboardSidebar(sidebarMenu(
    menuItem("Vowels", tabName = "vowels", icon = icon("line-chart")),
    menuItem("Sibilants", tabName = "sibilants", icon = icon("hourglass-o")),
    menuItem("Extra", tabName = "cats", icon = icon("coffee"))
  )),
  dashboardBody(
    tabItems(
      tabItem(tabName = "vowels",
              fluidRow(
                column(width = 4,
                       plotOutput("vowel_plot", height = 420, width = 650,
                                  # Equivalent to: click = clickOpts(id = "plot_click")
                                  click = "vowel_click",
                                  brush = brushOpts(
                                    id = "vowel_brush"
                                  )
                       ),
                       actionButton("action", label = "Open Praat"),
                       actionButton("play", label = "Play")
                ),
                sliderInput("range", "Filter by length:",
                            min = 0.01, max = 0.3, value = c(0.01,0.3)),
                dataTableOutput("vowel_click_info")
              )),
      tabItem(tabName = "sibilants",
              fluidRow(
                column(width = 4,
                       plotOutput("plot1", height = 500, width = 800,
                                  # Equivalent to: click = clickOpts(id = "plot_click")
                                  click = "sibilant_click",
                                  brush = brushOpts(
                                    id = "plot1_brush"
                                  )
                       )
                )
              ),
              fluidRow(
                       actionButton("open_sibilant", label = "Open Praat"),
                       actionButton("play", label = "Play"),
                       #           sliderInput("range", "Filter by length:",
                       #                       min = 0.01, max = 0.3, value = c(0.01,0.3)),
                       dataTableOutput("click_info"),
                       textOutput("brush_info")
                
              )
      ), tabItem(tabName = "cats",
                 fluidRow(
                   actionButton("update" ,"Update View", icon("refresh"),
                                class = "btn btn-primary"),
                   helpText("Please click the button",
                            "to get a new cat picture"),
                   plotOutput("cat_image", width = "auto"))
      )
    )
  )))

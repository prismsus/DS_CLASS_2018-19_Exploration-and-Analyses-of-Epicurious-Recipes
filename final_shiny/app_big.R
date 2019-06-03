#
# This is a Shiny web application. You can run the application by clicking
# the 'Run App' button above.
#
# Find out more about building applications with Shiny here:
#
#    http://shiny.rstudio.com/
#

library(shiny)
library(tidyverse)
library(DT)
library(scales)
library(rattle)
library(rpart)
library(caret)
library(pROC)


cluster.t.hclust <- readRDS(file = "~/DS_CLASS_2018-19_Christina/Semester2/final_project/cluster_t_hclust.RDS")
result_dist_new <- readRDS(file = "~/DS_CLASS_2018-19_Christina/Semester2/final_project/result_dist_new.rds")
result_dist_new <- result_dist_new %>%
  as.matrix()

titles <- select(epi_na_scaled, title) %>% unlist()

epi_r <- read_csv("~/DS_CLASS_2018-19_Christina/Semester2/final_project/epicurious-recipes-with-rating-and-nutrition/epi_r.csv")
epi_na <- epi_r %>%
  distinct() %>%
  na.omit() %>%
  .[, -c(64, 65)] # removes columns bon appetit

epi_na_scaled <- epi_na %>%
  mutate(rating = rescale(rating, to = c(0, 1)),
         calories = rescale(calories, to = c(0, 1)),
         protein = rescale(protein, to = c(0, 1)),
         fat = rescale(fat, to = c(0, 1)),
         sodium = rescale(sodium, to = c(0, 1))
  )

nzv_col <- epi_na_scaled %>%
  select(-title) %>%
  colSums() %>%
  as.data.frame() %>%
  add_rownames("feature") %>%
  mutate(index = c(2:678)) %>%
  filter(`.` <= 1) %>%
  .$index %>%
  unlist()

epi_na_scaled_nzv <- epi_na_scaled[, -nzv_col]


rpart.calories <- readRDS("rpart_calories.rds")


rpart.test<-readRDS("rpart.test.rds")
test_summer<-readRDS("test_summer.rds")

epi_ingredient <- epi_na[, -c(1, 2, 3, 4, 5, 6)] %>%
  t() %>%
  as.data.frame() %>%
  rownames_to_column("features")

dist_t <- readRDS("dist_t.rds")
set.seed(1)
hc.complete <- hclust(dist_t, method = "complete")
hc.wd <- hclust(dist_t, method = "ward.D2")
hc.average <- hclust(dist_t, method = "average")

# Define UI for application that draws a histogram
ui <- navbarPage("Epicurious Food Analysis",
                 tabPanel("Recipe Explorer",
                          sidebarLayout(
                            sidebarPanel(
                              textInput("dish", label = h3("Enter recipe"), value = "Lentil, Apple, and Turkey Wrap"),
                              p("(Leave empty to display all recipes)"),
                              h3("Filters"),
                              textInput("filter1", label = "Include: ", value = ""),
                              textInput("filter2", label = "Include: ", value = ""),
                              textInput("filter3", label = "Include", value = ""),
                              
                              sliderInput("rating_filter", label = "Minimum rating", min = 0, 
                                          max = 4, value = 0),
                              
                              checkboxInput("rating_na", label = ("Include dishes with no ratings yet"), value = TRUE),
                              
                              sliderInput("calories", label = "Calories range", min = 0, 
                                          max = 5000, value = c(0, 5000))
                              
                              
                            ),
                            mainPanel(
                              dataTableOutput("recommend"),
                              p("       "),
                              h3("Want to find recipes similar to your favorite dishes?"),
                              h3("In the mood to try a new recipe?"),
                              p("Look no further than our recipe recommender! Input your recipe of interest on the left, ",
                                "and the table will show recipes most similar to it based on ingredients/tags [the recipes are ranked by their score, or distance, from the input recipe]."
                                ),
                              
                              p("Customize to your needs through our filters: add what ingredients you want the recipes to include, the minimum rating the recipe must have, and the calorie range")
                              
                            )
                          )  
                          
                 ),
                 
                 tabPanel("Clustering",
                          sidebarLayout(
                            sidebarPanel(
                              radioButtons("cluster_method", label = "Cluster method", 
                                           choices = list("Complete" = 1, "Average" = 2, "Ward's" = 3),
                                           selected = 3),
                              numericInput("ncluster", label = "Number of clusters", value = 50),
                              numericInput("cluster_index", label = "Index of cluster to display", value = 1),
                              p("(Enter as 0 to select cluster by ingredient)"),
                              textInput("ingredient", label = "Or select ingredient: ", value = "tomato")
                              
                              
                              
                            ),
                            
                            mainPanel(
                              h2("Clustering Ingredients by Recipes"),
                              p(em("Ever wonder which ingredients would go great together?")),
                              p(em("Want to find new, interesting combinations?")),
                              p("Our clustering model could help! It clusters almost 700 ingredients/tags together by looking at thousands of recipes and seeing how ingredients occur together."),
                              p("Choose a cluster to see what is in it, or choose an ingredient to see the cluster it is in"),
                              p("Play with the parameters on the left to adjust the model. ",
                                "The dendrogram will help visualize what the clustering looks like. Have fun exploring!"),
                              
                              dataTableOutput("cluster"),
                              plotOutput("dendrogram")
                            )
                          )        
                          
                 ),
                 
                 tabPanel("Rating",
                          fluidPage(h2("Predicting Rating of recipy with differnet Ingredients"),
                                    includeMarkdown("linear.md")
                                    
                          )
                          
                 ),
                 
                 tabPanel("Calories",
                          fluidPage(h2("Predicting Calorie Content with Ingredients"),
                                    fluidRow(
                                      column(5,
                                             p(em("Frustrated by recipes with no calorie content?")),
                                             p(em("Wonder if computers can learn what things are high/low calorie?")),
                                             p("Here, we built a ", strong("decision tree model"), "to predict ", strong("calorie content [high/mid/low]"), "based on ", strong("ingredients used and other simple tags. ")),
                                             
                                             p("Our final model can be seen on the right: you can trace how the computer uses different variables to help decide calorie content."),
                                             p("Below, the", strong("variable importance matrix"), "shows the most important variables that the computer was able to learn. Pretty cool that the computer, with no understanding of words whatsoever, can learn that cake/meats/dinner are generally higher calorie!"
                                             ),
                                             p("Our model ", strong("accuracy = 0.52"), "and it is more accurate (~0.7) for predicting dishes with high & low calories",
                                               "Kappa = 0.28. So clearly, our model isn't the most accurate, but it is better than guessing at random, and we could see that computers can indeed learn to pick out features and correlate them to calorie content")
                                             
                                      ),
                                      column(7, 
                                             plotOutput("rpart_plot", width = "100%", height = "500px")
                                      )
                                    ),
                                    
                                    
                                    fluidRow(
                                      column(12,
                                             p("      "),
                                             p("      "),
                                             p("      "))
                                    ),
                                    
                                    fluidRow(
                                      column(5,
                                             dataTableOutput("importance"),
                                             p("Check out which variables the computer thought was the most important")
                                      ),
                                      
                                      column(7, 
                                             verbatimTextOutput("confusion"))
                                      
                                    )
                          )
                 ),
                 
                 tabPanel("Summer",
                          fluidPage(h2("Adding 'summer' food tag based on ingredients"),
                                    fluidRow(
                                      p("Summer is coming!"),
                                      p("Want some summer-themed recipes? Here's a model that automatically tags them for you!"),
                                      p("We have built a decision tree model to predict whether if a recipe is summer-related based on ingredients used.")
                                    ),
                                    fluidRow(
                                      column(5,
                                             dataTableOutput("imp")
                                      ),
                                      
                                      column(7, 
                                             plotOutput("rpart_summer_plot", width = "100%", height = "500px")
                                      )),
                                    
                                    fluidRow(
                                      column(6,
                                             plotOutput("ROC", width = "100%", height = "500px") 
                                             
                                      ),
                                      
                                      column(6,
                                             verbatimTextOutput("Result_Summary")
                                             
                                      )
                                    ),
                                    
                                    fluidRow(
                                      p("The variable importance matrix shows the most important variables that the computer was able to learn. The most important features include Backyard BBQ, fourth of July, grill BBQ, peach which make sense. Usually people would associate outdoor BBQ with summer and surprisingly the computer was able to learn that without any idea of what they actually are!"),
                                      p("Our model accuracy =  0.82 (balanced accuracy 0.64) and the p-value is lower than 2e-16, showing that our model, although far from perfect, performs better than random guessing [see the ROC curve & confusion matrix statistics for more details]")
                                      
                                    )
                                    
                                    
                                    
                                    
                          )
                          
                 ),
                 tabPanel("About",
                          fluidPage(
                            includeMarkdown("about.md"),
                            p("Here is the entire table (use it to search for full names of recipes needed for Recipe Explorer"),
                            dataTableOutput("total"),
                            p("Here is the list of available ingredients/tags you can reference for Recipe Explorer or Clustering"),
                            verbatimTextOutput("variables")
                          )
                          
                 )
                 
)
# Define server logic required to draw a histogram
server <- function(input, output) {
  
  output$imp<-renderDataTable({
    varImp(rpart.test) %>%
      add_rownames() %>%
      arrange(desc(Overall))%>%
      head(13)%>%
      select(feature=rowname, importance = Overall) %>%
      mutate(importance = round(importance))
  })
  
  output$rpart_summer_plot<-renderPlot({
    fancyRpartPlot(rpart.test, sub = "")
  })
  
  output$ROC<-renderPlot({
    roc(predictor=predict(rpart.test, test_summer, type = "prob")[,2],response = test_summer$summer)%>%plot()
  })
  
  output$Result_Summary<-renderPrint({
    confusionMatrix(predict(rpart.test, test_summer, type = "class"), test_summer$summer)
  })
  
  output$datasummary<-renderTable({
    epi_na_scaled_nzv_nonzero<-read_csv("epi_na_scaled_nzv_nonzero.csv")[,1:10]%>%
      head()
  })
  
  output$recommend <- renderDataTable({
    
    # Filtering data ------------------
    get_filter <- function(f){
      
      variables <- colnames(epi_na_scaled)
      x <- which(variables == f) %>% .[1]
      if(!is.na(x)){
        temp <- epi_na_scaled[, x] %>% unlist()
        temp > 0
      }
      else{
        rep(TRUE, nrow(epi_na_scaled))
      }
    }
    
    r <- epi_na[, 2] >= input$rating_filter
    if(input$rating_na){
      r <- r | epi_na[, 2] == 0
    }
    
    c <- epi_na[, 3] >= input$calories[1] & epi_na[, 3] <= input$calories[2]
    
    # Recommendations -------------------
    name_index <- select(epi_na_scaled, title) %>%
      mutate(index = c(1:nrow(epi_na_scaled)))
    
    input_row <- which(titles == input$dish) %>% .[1]
    
    if(is.na(input_row)){
      epi_na %>%
        mutate(index = c(1:nrow(epi_na_scaled))) %>%
        .[get_filter(input$filter1) & get_filter(input$filter2) & get_filter(input$filter3) & r & c, ] %>%
        select(index, dish = title, rating)
    }
    else{
      temp <- result_dist_new %>%
        .[input_row, ] %>%
        as.data.frame() %>%
        rownames_to_column("index") %>%
        mutate(index = as.numeric(index)) %>%
        inner_join(name_index, by = c("index" = "index")) %>%
        .[get_filter(input$filter1) & get_filter(input$filter2) & get_filter(input$filter3) & r & c, ]
      
      
      names(temp)[2] <- "score"
      
      temp %>%
        arrange(score) %>%
        distinct(title, .keep_all = TRUE) %>%
        select(index, dish = title, score) %>%
        .[-1, ] %>%
        datatable() %>%
        formatCurrency(3, currency = "")
      
    }
  })
  
  output$rpart_plot <- renderPlot({
    fancyRpartPlot(rpart.calories, sub = "")
  })
  
  output$importance <- renderDataTable({
    varImp(rpart.calories) %>%
      rownames_to_column("feature") %>%
      arrange(desc(Overall)) %>%
      filter(Overall > 0) %>%
      select(feature, importance = Overall) %>%
      mutate(importance = round(importance))
  })
  
  output$confusion <- renderPrint({
    readRDS("confusion_calories.rds")
  })
  
  output$dendrogram <- renderPlot({
    if(input$cluster_method == 1){
      hc <- hc.complete
    }
    
    if(input$cluster_method == 2){
      hc <- hc.average
    }
    
    if(input$cluster_method == 3){
      hc <- hc.wd
    }
    
    plot(hc, labels = FALSE)
  })
  
  output$cluster <- renderDataTable({
    if(input$cluster_method == 1){
      hc <- hc.complete
    }
    
    if(input$cluster_method == 2){
      hc <- hc.average
    }
    
    if(input$cluster_method == 3){
      hc <- hc.wd
    }
    
    if(input$cluster_index > 0){
      tr <- cutree(hc, input$ncluster) %>% as.data.frame() %>% rownames_to_column("features")
      names(tr)[2] = "cluster"
      tr %>% dplyr::filter(cluster == input$cluster_index)
    }
    
    else{
      index <- which(epi_ingredient[, 1] %>% unlist() == input$ingredient)
      tr <- cutree(hc, input$ncluster) %>% as.data.frame() %>% rownames_to_column("features")
      names(tr)[2] = "cluster"
      group <- tr %>% .[index, 2]
      
      tr %>%
        dplyr::filter(cluster == group)
    }
  })
  
  output$total <- renderDataTable({
    epi_na[, -nzv_col]
  })
  
  output$variables <- renderPrint({
    epi_na_scaled_nzv %>% names()
  })
  
}

# Run the application 
shinyApp(ui = ui, server = server)



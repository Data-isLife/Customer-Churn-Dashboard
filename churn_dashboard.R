# Load required packages
library(shiny)
library(shinydashboard)
library(plotly)
library(dplyr)
library(caret)
library(data.table)
library(ggplot2)

# Load and prepare the dataset (assumes telco_customer_churn.csv is in working directory)
telco <- fread("telco_customer_churn.csv") %>%
  mutate_if(is.character, as.factor) %>%
  mutate(TotalCharges = as.numeric(TotalCharges)) %>%
  filter(!is.na(TotalCharges)) %>%
  mutate(TenureGroup = cut(tenure, breaks = c(0, 12, 24, 48, 72, Inf), 
                           labels = c("0-1yr", "1-2yr", "2-4yr", "4-6yr", "6+yr")))

# Train a simple random forest model (for demonstration)
set.seed(123)
train_index <- createDataPartition(telco$Churn, p = 0.7, list = FALSE)
train_data <- telco[train_index, ]
test_data <- telco[-train_index, ]
rf_model <- train(Churn ~ tenure + Contract + MonthlyCharges + TotalCharges + InternetService + PaymentMethod, 
                  data = train_data, 
                  method = "rf", 
                  trControl = trainControl(method = "cv", number = 3),
                  tuneLength = 3)

# UI for Split-Screen Dashboard
ui <- dashboardPage(
  skin = "blue",
  dashboardHeader(title = "Customer Churn Prediction Dashboard"),
  dashboardSidebar(disable = TRUE), # No sidebar needed
  dashboardBody(
    fluidRow(
      # Left Column: Exploration (50% width)
      column(width = 6,
             box(title = "Filters", width = 12, status = "primary", solidHeader = TRUE,
                 selectInput("contract", "Contract Type", choices = c("All", levels(telco$Contract))),
                 sliderInput("tenure", "Tenure (Months)", min = 0, max = 72, value = c(0, 72))),
             box(title = "Overview", width = 12, collapsible = TRUE,
                 tableOutput("summary_table"),
                 plotlyOutput("churn_plot", height = "300px")),
             box(title = "Exploratory Analysis", width = 12, collapsible = TRUE,
                 plotlyOutput("tenure_plot", height = "300px")),
             box(title = "Model Results", width = 12, collapsible = TRUE,
                 plotlyOutput("importance_plot", height = "300px"))
      ),
      # Right Column: Prediction (50% width)
      column(width = 6,
             box(title = "Predict Churn", width = 12, status = "warning", solidHeader = TRUE,
                 numericInput("tenure_input", "Tenure (Months)", value = 12, min = 0, max = 72),
                 selectInput("contract_input", "Contract Type", choices = levels(telco$Contract)),
                 numericInput("charges_input", "Monthly Charges", value = 50, min = 0),
                 selectInput("internet_input", "Internet Service", choices = levels(telco$InternetService)),
                 selectInput("payment_input", "Payment Method", choices = levels(telco$PaymentMethod)),
                 actionButton("predict_btn", "Predict Churn"),
                 textOutput("churn_prob")),
             box(title = "Prediction History", width = 12, collapsible = TRUE,
                 tableOutput("pred_history"))
      )
    )
  )
)

# Server logic
server <- function(input, output, session) {
  # Reactive filtered dataset based on user inputs
  filtered_data <- reactive({
    data <- telco
    if (input$contract != "All") {
      data <- data %>% filter(Contract == input$contract)
    }
    data <- data %>% filter(tenure >= input$tenure[1], tenure <= input$tenure[2])
    data
  })
  
  # Summary table
  output$summary_table <- renderTable({
    filtered_data() %>%
      summarise(
        Total_Customers = n(),
        Churn_Rate = mean(Churn == "Yes") * 100,
        Avg_Tenure = mean(tenure),
        Avg_Monthly_Charges = mean(MonthlyCharges)
      ) %>%
      mutate(Churn_Rate = round(Churn_Rate, 2),
             Avg_Tenure = round(Avg_Tenure, 1),
             Avg_Monthly_Charges = round(Avg_Monthly_Charges, 2))
  })
  
  # Churn rate by contract type
  output$churn_plot <- renderPlotly({
    p <- ggplot(filtered_data(), aes(x = Contract, fill = Churn)) +
      geom_bar(position = "fill") +
      labs(title = "Churn Rate by Contract Type", y = "Proportion") +
      theme_minimal()
    ggplotly(p)
  })
  
  # Tenure distribution
  output$tenure_plot <- renderPlotly({
    p <- ggplot(filtered_data(), aes(x = TenureGroup)) +
      geom_bar(fill = "steelblue") +
      labs(title = "Tenure Group Distribution", x = "Tenure Group", y = "Count") +
      theme_minimal()
    ggplotly(p)
  })
  
  # Feature importance
  output$importance_plot <- renderPlotly({
    imp <- varImp(rf_model)$importance
    imp_df <- data.frame(Feature = rownames(imp), Importance = imp$Overall)
    p <- ggplot(imp_df, aes(x = reorder(Feature, Importance), y = Importance)) +
      geom_bar(stat = "identity", fill = "darkgreen") +
      coord_flip() +
      labs(title = "Feature Importance", x = "", y = "Importance") +
      theme_minimal()
    ggplotly(p)
  })
  
  # Reactive prediction history
  pred_history <- reactiveVal(data.frame(Tenure = numeric(), Contract = character(), 
                                         MonthlyCharges = numeric(), InternetService = character(),
                                         PaymentMethod = character(), Churn_Prob = numeric()))
  
  # Churn probability prediction
  output$churn_prob <- renderText({
    input$predict_btn
    isolate({
      new_data <- data.frame(
        tenure = input$tenure_input,
        Contract = factor(input$contract_input, levels = levels(telco$Contract)),
        MonthlyCharges = input$charges_input,
        TotalCharges = input$charges_input * input$tenure_input,
        InternetService = factor(input$internet_input, levels = levels(telco$InternetService)),
        PaymentMethod = factor(input$payment_input, levels = levels(telco$PaymentMethod))
      )
      prob <- predict(rf_model, new_data, type = "prob")[, "Yes"]
      # Update prediction history
      new_entry <- data.frame(Tenure = input$tenure_input, 
                              Contract = input$contract_input,
                              MonthlyCharges = input$charges_input,
                              InternetService = input$internet_input,
                              PaymentMethod = input$payment_input,
                              Churn_Prob = round(prob, 2))
      pred_history(rbind(pred_history(), new_entry))
      paste("Churn Probability:", round(prob * 100, 2), "%")
    })
  })
  
  # Prediction history table
  output$pred_history <- renderTable({
    pred_history()
  })
}

# Run the Shiny app
shinyApp(ui, server)
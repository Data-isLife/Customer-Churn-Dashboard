# Customer Churn Dashboard
# Run this file from the repository folder with shiny::runApp().

required_packages <- c(
  "shiny", "shinydashboard", "plotly", "dplyr", "caret",
  "data.table", "ggplot2", "randomForest", "pROC", "scales"
)
missing_packages <- required_packages[
  !vapply(required_packages, requireNamespace, logical(1), quietly = TRUE)
]
if (length(missing_packages)) {
  stop("Install required packages first: ", paste(missing_packages, collapse = ", "))
}

suppressPackageStartupMessages({
  library(shiny)
  library(shinydashboard)
  library(plotly)
  library(dplyr)
  library(caret)
  library(data.table)
  library(ggplot2)
})

data_file <- "telco_customer_churn.csv"
if (!file.exists(data_file)) {
  stop("Could not find '", data_file, "'. Run the app from its project folder.")
}

# Parse TotalCharges while it is still text. Blank source values are removed;
# converting a factor to numeric first would silently replace amounts with codes.
telco <- fread(data_file, na.strings = c("", " "), data.table = FALSE) %>%
  mutate(TotalCharges = suppressWarnings(as.numeric(trimws(TotalCharges)))) %>%
  filter(!is.na(TotalCharges), !is.na(Churn)) %>%
  mutate(
    across(where(is.character), as.factor),
    Churn = factor(Churn, levels = c("Yes", "No")),
    TenureGroup = cut(
      tenure,
      breaks = c(-1, 12, 24, 48, 60, Inf),
      labels = c("0–12 months", "13–24 months", "25–48 months", "49–60 months", "61+ months")
    )
  )

model_features <- c("tenure", "Contract", "MonthlyCharges", "TotalCharges", "InternetService", "PaymentMethod")
set.seed(2025)
train_rows <- caret::createDataPartition(telco$Churn, p = 0.8, list = FALSE)
train_data <- telco[train_rows, c("Churn", model_features)]
test_data <- telco[-train_rows, c("Churn", model_features)]

# Tune only within training data. The held-out test set is used once below.
set.seed(2025)
rf_model <- caret::train(
  x = train_data[, model_features],
  y = train_data$Churn,
  method = "rf",
  metric = "ROC",
  trControl = caret::trainControl(
    method = "cv", number = 5, classProbs = TRUE,
    summaryFunction = caret::twoClassSummary
  ),
  tuneLength = 3,
  importance = TRUE
)

test_probability <- predict(rf_model, newdata = test_data, type = "prob")[, "Yes"]
test_class <- factor(ifelse(test_probability >= 0.5, "Yes", "No"), levels = c("Yes", "No"))
test_confusion <- caret::confusionMatrix(test_class, test_data$Churn, positive = "Yes")
tp <- unname(test_confusion$table["Yes", "Yes"])
fp <- unname(test_confusion$table["Yes", "No"])
fn <- unname(test_confusion$table["No", "Yes"])
tn <- unname(test_confusion$table["No", "No"])
safe_ratio <- function(numerator, denominator) if (denominator == 0) 0 else numerator / denominator
test_roc <- pROC::roc(
  response = test_data$Churn,
  predictor = test_probability,
  levels = c("No", "Yes"), direction = "<", quiet = TRUE
)
precision <- safe_ratio(tp, tp + fp)
recall <- safe_ratio(tp, tp + fn)
specificity <- safe_ratio(tn, tn + fp)
f1 <- safe_ratio(2 * precision * recall, precision + recall)
accuracy <- safe_ratio(tp + tn, tp + tn + fp + fn)
model_metrics <- data.frame(
  Metric = c("ROC AUC", "Accuracy", "Precision", "Recall", "F1 score", "Specificity"),
  Value = c(
    as.numeric(pROC::auc(test_roc)),
    accuracy, precision, recall, f1, specificity
  )
)

theme_set(theme_minimal(base_size = 13) + theme(
  plot.title = element_text(face = "bold", color = "#17324D"),
  panel.grid.minor = element_blank(),
  legend.position = "bottom"
))
brand_blue <- "#2563EB"
ui <- dashboardPage(
  skin = "blue",
  dashboardHeader(title = "Customer Churn | Telco"),
  dashboardSidebar(disable = TRUE),
  dashboardBody(
    tags$head(tags$style(HTML("
      .content-wrapper, .right-side { background-color: #f4f7fb; }
      .main-header .logo { font-weight: 700; }
      .small-box { border-radius: 8px; }
      .box { border-top: 0; border-radius: 8px; box-shadow: 0 2px 10px rgba(23,50,77,.08); }
      .intro { color: #425466; margin: 2px 0 14px; }
      .metric-note { color: #607080; font-size: 12px; }
    "))),
    fluidRow(column(12, h2("Customer churn overview"),
      p(class = "intro", "Explore churn patterns, review held-out model performance, and estimate risk for a customer profile."))),
    fluidRow(
      valueBoxOutput("customers_box", width = 3),
      valueBoxOutput("churn_box", width = 3),
      valueBoxOutput("tenure_box", width = 3),
      valueBoxOutput("auc_box", width = 3)
    ),
    fluidRow(
      box(title = "Explore the customer base", width = 4, status = "primary", solidHeader = TRUE,
        selectInput("contract", "Contract type", choices = c("All contracts", levels(telco$Contract))),
        sliderInput("tenure", "Tenure range (months)", min = 0, max = 72, value = c(0, 72)),
        plotlyOutput("churn_plot", height = 280),
        plotlyOutput("tenure_plot", height = 250)
      ),
      box(title = "Model evaluation", width = 4, status = "primary", solidHeader = TRUE,
        p(class = "metric-note", "Metrics use a stratified 20% holdout set. The churn class (Yes) is treated as positive."),
        tableOutput("metrics_table"),
        plotlyOutput("confusion_plot", height = 260),
        plotlyOutput("importance_plot", height = 300)
      ),
      box(title = "Estimate churn risk", width = 4, status = "warning", solidHeader = TRUE,
        p(class = "metric-note", "This is a model estimate for exploration, not a decision about an individual customer."),
        numericInput("tenure_input", "Tenure (months)", value = 12, min = 0, max = 72),
        selectInput("contract_input", "Contract", choices = levels(telco$Contract)),
        numericInput("charges_input", "Monthly charges ($)", value = 50, min = 0),
        selectInput("internet_input", "Internet service", choices = levels(telco$InternetService)),
        selectInput("payment_input", "Payment method", choices = levels(telco$PaymentMethod)),
        actionButton("predict_btn", "Estimate risk", class = "btn-primary"),
        br(), br(), uiOutput("prediction_result"),
        h4("Recent estimates"), tableOutput("pred_history")
      )
    ),
    fluidRow(column(12, p(class = "metric-note",
      "Data: IBM Telco Customer Churn sample. Estimates use a random forest trained on a single split; results may vary by population and do not establish causation.")))
  )
)

server <- function(input, output, session) {
  filtered_data <- reactive({
    data <- telco
    if (!is.null(input$contract) && input$contract != "All contracts") {
      data <- data %>% filter(Contract == input$contract)
    }
    data %>% filter(tenure >= input$tenure[1], tenure <= input$tenure[2])
  })

  output$customers_box <- renderValueBox({
    valueBox(scales::comma(nrow(filtered_data())), "Customers in selected view", icon = icon("users"), color = "blue")
  })
  output$churn_box <- renderValueBox({
    rate <- mean(filtered_data()$Churn == "Yes")
    valueBox(scales::percent(rate, accuracy = 0.1), "Churn in selected view", icon = icon("line-chart"), color = "red")
  })
  output$tenure_box <- renderValueBox({
    valueBox(paste0(round(mean(filtered_data()$tenure), 1), " mo"), "Average tenure", icon = icon("calendar"), color = "aqua")
  })
  output$auc_box <- renderValueBox({
    valueBox(sprintf("%.3f", model_metrics$Value[model_metrics$Metric == "ROC AUC"]), "Holdout ROC AUC", icon = icon("bullseye"), color = "green")
  })

  output$churn_plot <- renderPlotly({
    plot_data <- filtered_data()
    req(nrow(plot_data) > 0)
    p <- ggplot(plot_data, aes(x = Contract, fill = Churn)) +
      geom_bar(position = "fill") + scale_y_continuous(labels = scales::percent) +
      scale_fill_manual(values = c("Yes" = "#E45756", "No" = "#4C78A8")) +
      labs(title = "Churn share by contract", x = NULL, y = "Customers", fill = "Churn")
    ggplotly(p, tooltip = c("x", "fill", "y"))
  })
  output$tenure_plot <- renderPlotly({
    plot_data <- filtered_data()
    req(nrow(plot_data) > 0)
    p <- ggplot(plot_data, aes(x = TenureGroup, fill = Churn)) +
      geom_bar(position = "dodge") +
      scale_fill_manual(values = c("Yes" = "#E45756", "No" = "#4C78A8")) +
      labs(title = "Customers by tenure", x = NULL, y = "Customer count", fill = "Churn") +
      theme(axis.text.x = element_text(angle = 25, hjust = 1))
    ggplotly(p)
  })
  output$metrics_table <- renderTable({
    transform(model_metrics, Value = ifelse(Metric == "ROC AUC", sprintf("%.3f", Value), scales::percent(Value, accuracy = 0.1)))
  }, colnames = FALSE, striped = TRUE, bordered = FALSE, spacing = "s")
  output$confusion_plot <- renderPlotly({
    cm <- as.data.frame(test_confusion$table)
    names(cm) <- c("Predicted", "Actual", "Count")
    p <- ggplot(cm, aes(x = Actual, y = Predicted, fill = Count, text = paste("Count:", Count))) +
      geom_tile(color = "white", linewidth = 1) + geom_text(aes(label = Count), color = "#17324D", size = 6) +
      scale_fill_gradient(low = "#DBEAFE", high = brand_blue) +
      labs(title = "Holdout confusion matrix", x = "Actual", y = "Predicted")
    ggplotly(p, tooltip = "text")
  })
  output$importance_plot <- renderPlotly({
    importance <- caret::varImp(rf_model)$importance
    importance$Feature <- rownames(importance)
    p <- ggplot(importance, aes(x = reorder(Feature, Overall), y = Overall)) +
      geom_col(fill = brand_blue, width = 0.7) + coord_flip() +
      labs(title = "Relative feature importance", x = NULL, y = "Importance")
    ggplotly(p)
  })

  prediction_history <- reactiveVal(data.frame(
    Tenure = numeric(), Contract = character(), MonthlyCharges = numeric(),
    InternetService = character(), PaymentMethod = character(), ChurnProbability = numeric()
  ))
  prediction <- eventReactive(input$predict_btn, {
    new_data <- data.frame(
      tenure = input$tenure_input,
      Contract = factor(input$contract_input, levels = levels(telco$Contract)),
      MonthlyCharges = input$charges_input,
      # TotalCharges is approximated as monthly charge × tenure for this form.
      TotalCharges = input$charges_input * input$tenure_input,
      InternetService = factor(input$internet_input, levels = levels(telco$InternetService)),
      PaymentMethod = factor(input$payment_input, levels = levels(telco$PaymentMethod))
    )
    probability <- as.numeric(predict(rf_model, newdata = new_data, type = "prob")[, "Yes"])
    entry <- data.frame(
      Tenure = input$tenure_input, Contract = input$contract_input,
      MonthlyCharges = input$charges_input, InternetService = input$internet_input,
      PaymentMethod = input$payment_input, ChurnProbability = probability
    )
    prediction_history(rbind(entry, head(prediction_history(), 9)))
    probability
  })
  output$prediction_result <- renderUI({
    req(prediction())
    probability <- prediction()
    tags$div(
      style = "padding:14px; border-radius:8px; background:#eef4ff; color:#17324D;",
      tags$strong(sprintf("Estimated churn probability: %s", scales::percent(probability, accuracy = 0.1))),
      tags$div(class = "metric-note", "The estimate depends on the selected profile and model assumptions.")
    )
  })
  output$pred_history <- renderTable({
    history <- prediction_history()
    history$ChurnProbability <- scales::percent(history$ChurnProbability, accuracy = 0.1)
    history
  }, striped = TRUE, bordered = FALSE, spacing = "s")
}

shinyApp(ui = ui, server = server)

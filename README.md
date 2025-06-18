# Customer Churn Prediction Dashboard

A Shiny dashboard built in R to analyze customer churn using the Telco Customer Churn dataset. Features include:
- Interactive filters for contract type and tenure.
- Visualizations of churn rate, tenure distribution, and feature importance.
- A prediction tool to estimate churn probability for new customers.

## Files
- `churn_dashboard.R`: The Shiny app script.
- `telco-customer-churn.csv`: The raw dataset (from [Kaggle](https://www.kaggle.com/datasets/blastchar/telco-customer-churn)).
- `telco.rds`: Preprocessed dataset (optional).
- `rf_model.rds`: Trained random forest model (optional).

## Setup
1. Install required packages:
```R
install.packages(c('shiny', 'shinydashboard', 'plotly', 'dplyr', 'caret', 'data.table', 'ggplot2', 'randomForest'))
```
2. Run the app:
```R
source('churn_dashboard.R')
shinyApp(ui, server)
```

## Dependencies
- R version 4.4.1 or later
- Packages: shiny, shinydashboard, plotly, dplyr, caret, data.table, ggplot2, randomForest

# Build the saved model bundle used by app.R. Run from the project directory.
required_packages <- c("data.table", "dplyr", "caret", "pROC", "randomForest")
missing_packages <- required_packages[
  !vapply(required_packages, requireNamespace, logical(1), quietly = TRUE)
]
if (length(missing_packages)) {
  stop("Install required packages first: ", paste(missing_packages, collapse = ", "))
}

data_file <- "telco_customer_churn.csv"
if (!file.exists(data_file)) stop("Missing telco_customer_churn.csv in the project directory.")

telco <- data.table::fread(data_file, na.strings = "", data.table = FALSE) |>
  dplyr::mutate(TotalCharges = suppressWarnings(as.numeric(trimws(TotalCharges)))) |>
  dplyr::filter(!is.na(TotalCharges), !is.na(Churn)) |>
  dplyr::mutate(
    dplyr::across(where(is.character), as.factor),
    Churn = factor(Churn, levels = c("Yes", "No"))
  )

model_features <- c("tenure", "Contract", "MonthlyCharges", "TotalCharges", "InternetService", "PaymentMethod")
set.seed(2025)
train_rows <- caret::createDataPartition(telco$Churn, p = 0.8, list = FALSE)
train_data <- telco[train_rows, c("Churn", model_features)]
test_data <- telco[-train_rows, c("Churn", model_features)]

set.seed(2025)
rf_model <- caret::train(
  x = train_data[, model_features],
  y = train_data$Churn,
  method = "rf",
  metric = "ROC",
  trControl = caret::trainControl(
    method = "cv", number = 3, classProbs = TRUE,
    summaryFunction = caret::twoClassSummary
  ),
  tuneLength = 2,
  ntree = 150,
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
  response = test_data$Churn, predictor = test_probability,
  levels = c("No", "Yes"), direction = "<", quiet = TRUE
)
precision <- safe_ratio(tp, tp + fp)
recall <- safe_ratio(tp, tp + fn)
specificity <- safe_ratio(tn, tn + fp)
f1 <- safe_ratio(2 * precision * recall, precision + recall)
accuracy <- safe_ratio(tp + tn, tp + tn + fp + fn)
model_metrics <- data.frame(
  Metric = c("ROC AUC", "Accuracy", "Precision", "Recall", "F1 score", "Specificity"),
  Value = c(as.numeric(pROC::auc(test_roc)), accuracy, precision, recall, f1, specificity)
)

saveRDS(
  list(rf_model = rf_model, test_confusion = test_confusion, model_metrics = model_metrics),
  file = "churn_model_bundle.rds",
  version = 3
)
message("Saved churn_model_bundle.rds")

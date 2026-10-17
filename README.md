# Customer Churn Dashboard

An interactive R Shiny portfolio project for exploring customer churn in a telecom sample and reviewing a random forest classifier on unseen holdout data.

## What it does

- Summarizes customer count, churn share, and average tenure for the selected filters.
- Compares churn across contract types and tenure groups.
- Trains a random forest using tenure, contract, monthly and total charges, internet service, and payment method.
- Reports ROC AUC, accuracy, precision, recall, F1 score, specificity, and a confusion matrix on a stratified 20% test split.
- Estimates churn probability from a customer profile and keeps the latest estimates in the current browser session.

## Why this matters

Customers who leave represent lost recurring revenue. A churn model can help a business investigate patterns and plan retention work. The dashboard is an educational analysis: its estimates are not causal explanations, and they should not be used alone to make decisions about individual customers.

## Data

The included `telco_customer_churn.csv` is the IBM Telco Customer Churn sample, distributed via [Kaggle](https://www.kaggle.com/datasets/blastchar/telco-customer-churn). It contains customer service, contract, billing, tenure, and churn fields. The app parses `TotalCharges` as numeric before factor conversion and drops rows with blank total charges; the source file has a small number of such rows.

## Model and evaluation

The app uses a fixed random seed and stratified 80/20 train/test split. Cross-validation and tuning happen inside the training portion only. The final metrics are computed once on the held-out test portion, with `Churn = Yes` treated as the positive class. The probability-to-class cutoff for the confusion matrix is 0.50. ROC AUC measures ranking across cutoffs; precision and recall describe performance at the chosen cutoff. The split is for reproducibility, not a guarantee of future performance. For stronger evidence, repeat the split or use an external, time-based validation set.

The prediction form does not request total charges, so it uses `MonthlyCharges × tenure` as a simple proxy. Actual customer billing history may differ, and that approximation can affect the estimate.

## Run locally

Install R, then install the packages used by the app:

```r
install.packages(c(
  "shiny", "shinydashboard", "plotly", "dplyr", "caret",
  "data.table", "ggplot2", "randomForest", "pROC", "scales"
))
```

Open this repository folder as the working directory in R or RStudio, then run:

```r
shiny::runApp("churn_dashboard.R")
```

The CSV must stay beside `churn_dashboard.R`. The app trains the model at startup, so the first load can take a little longer.

## Deploy online with shinyapps.io

This repository is prepared for deployment as a single-file Shiny app. Deployment requires your own shinyapps.io account and credentials; those are not stored in this repository.

1. Create a free or paid account at [shinyapps.io](https://www.shinyapps.io/) and create an application token in its dashboard.
2. Install and open RStudio, then install the deployment package: `install.packages("rsconnect")`.
3. In RStudio, choose **Tools → Global Options → Publishing → Connect**, select shinyapps.io, and enter the account token and secret. Keep credentials private; do not commit them.
4. Set the R working directory to this repository folder and run:

   ```r
   rsconnect::deployApp(appDir = ".", appPrimaryDoc = "churn_dashboard.R")
   ```

5. Wait for deployment to finish, open the URL shown by RStudio, and check that the dashboard loads and the prediction form responds.

Deployment has not been performed from this repository because it needs account-specific shinyapps.io credentials and an account choice from the repository owner.

## Project files

| File | Purpose |
| --- | --- |
| `churn_dashboard.R` | Shiny interface, data preparation, model training, evaluation, charts, and prediction form. |
| `telco_customer_churn.csv` | Included source dataset. |
| `README.md` | Project overview, methodology, setup, and deployment guide. |

## Next improvements

- Add repeated cross-validation or a time-based test set to measure how stable the results are.
- Compare the random forest with a simple baseline and report confidence intervals.
- Replace the proxy total charges in the form with a validated billing input.
- Add a screenshot and a live demo link after deployment.

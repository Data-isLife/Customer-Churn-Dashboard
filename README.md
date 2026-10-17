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

##Live model
(https://data-islife-james-churn-random-forest.share.connect.posit.cloud/)

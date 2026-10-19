# Customer Churn Dashboard

An R Shiny app for exploring telecom customer churn and reviewing a random forest model. The app uses the included `telco_customer_churn.csv`; it does not need an API key or an external data service.

## Run locally

Use R 4.5.3 to match the included lockfile. From this folder's R console, install renv and restore the exact package versions from `renv.lock`:

```r
dir.create(".Rlib", showWarnings = FALSE)
.libPaths(c(normalizePath(".Rlib", winslash = "/"), .libPaths()))
install.packages("renv", lib = ".Rlib")
renv::restore(project = ".", library = ".Rlib")
```

Then open this folder in RStudio or VS Code and run:

```r
shiny::runApp(".")
```

The app's entry point is `app.R`. Keep `telco_customer_churn.csv` and `churn_model_bundle.rds` beside it. The saved model bundle lets the hosted app start without retraining the random forest each time. If the data or model settings change, run `source("build_model.R")` from the project folder and commit the refreshed bundle with the source.

## Deploy on Posit Connect Cloud

1. Push `app.R`, `build_model.R`, `churn_model_bundle.rds`, `DESCRIPTION`, `telco_customer_churn.csv`, and `renv.lock` to GitHub.
2. On Connect Cloud, create a deployment from the repository and select `app.R` as the primary file.
3. Wait for the build to finish, then open the app and check the charts and prediction form.

Connect Cloud's GitHub deployment requires `renv.lock` or `manifest.json`; this project includes `renv.lock`. If I change packages, run `renv::snapshot(project = ".", library = ".Rlib")` and commit the updated lockfile. Do not install packages from inside `app.R`.

On the Connect Cloud free plan, GitHub publishing requires a public repository. Anyone can then download the repository data, so publish only data you have permission to make public. Free plan limits and provider terms can change; no free hosting service can promise uninterrupted service forever. Keep a copy of the source files and check the plan limits before relying on the app.

## Model notes

The app parses `TotalCharges` as a number and removes rows where it is blank. It uses a seeded, stratified 80/20 split; model tuning happens within the training portion, and the reported metrics use the held-out portion. The prediction form approximates total charges as monthly charges multiplied by tenure. Treat its probabilities as educational estimates, not decisions about individual customers.

## Files

- `app.R`: Shiny interface, data preparation, charts, and prediction form.
- `build_model.R`: reproducibly trains the model and computes the held-out metrics.
- `churn_model_bundle.rds`: pre-trained model and evaluation results loaded at app startup.
- `telco_customer_churn.csv`: included sample data.
- `DESCRIPTION`: direct R package dependencies.
- `renv.lock`: package versions for local setup and hosted deployment.

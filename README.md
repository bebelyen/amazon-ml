# Household Size Prediction from E-Commerce Purchase Behavior

Predicting customer household size using transaction data from the open e-commerce dataset (Berke et al., 2024). Built as part of a supervised regression project comparing four modeling approaches: Baseline (mean), Lasso Regression, Random Forest, and XGBoost.

---

## Project Overview

Companies often collect basic demographic information at sign-up, but transaction history can reveal richer signals about a customer's household. This project explores whether purchasing patterns — such as spend volume, product categories, and item types — can be used to predict how many people live in a household.

**Target variable:** `Q.amazon.use.hh.size.num` (self-reported household size from survey)  
**Evaluation metric:** Root Mean Squared Error (RMSE)  
**Dataset:** [Open E-Commerce v1.0 — Berke et al. (2024)](https://dataverse.harvard.edu/dataset.xhtml?persistentId=doi:10.7910/DVN/YGLYDY)

---

## Repository Structure

```
.
├── tubi_interview.Rmd       # Main analysis: preprocessing, feature engineering, modeling
├── README.md                # This file
├── .gitignore                      # Excludes data files and outputs
├── submission.csv            # (Generated on run) Final test set predictions
└── feature_queries.sql      # mirrors feature engineering demonstrating how the same pipeline would be implemented in SQL on a production data warehouse.
```

> **Note:** The raw data files (`survey_train_test.csv`, `amazon-purchases.csv`) are not included in this repository due to size and licensing. See [Data Setup](#data-setup) below.

---

## How to Run

### Prerequisites

Install R (≥ 4.1) and the following packages:

```r
install.packages(c(
  "tidyverse",
  "lubridate",
  "randomForest",
  "glmnet",
  "xgboost"
))
```

### Data Setup

Download the dataset from the Harvard Dataverse link above and place the following files in the project root directory:

```
amazon-purchases.csv
survey_train_test.csv
```

### Running the Analysis

Open `tubi_interview.Rmd` in RStudio and click **Knit**, or run from the command line:

```bash
Rscript -e "rmarkdown::render('tubi_interview.Rmd')"
```

This will generate:
- A rendered HTML or PDF report with all visualizations
- `submission.csv` — final predictions on the test set using the best-performing model

---

## Methodology

### Feature Engineering

Raw purchase records were aggregated per user into numeric features. Key design choices:

- **Behavioral aggregates** — total spend, order count, unique product categories, distinct shipping states, and quantity per order give a picture of overall purchasing scale and diversity.
- **Recency and duration** — days since last order and days active as a customer capture engagement patterns that may differ across household types.
- **Log transformations** — spend and order count are right-skewed, so log1p transforms were applied to stabilize variance before modeling.
- **Domain-specific keyword features** — two binary category flags were engineered:
  - `n_household_items`: purchases in categories like paper products, cleaning supplies, groceries
  - `n_kid_items`: purchases in categories like diapers, toys, baby gear

  These were motivated by the hypothesis that larger or family households purchase consumables and child products at higher rates.

## My Contributions

This project was completed in a team of three. My personal contributions were:

**Feature Engineering**
I designed and implemented the full feature engineering pipeline in both R and SQL.
This included behavioral aggregates (total spend, order count, price statistics),
recency and duration features (days active, days since last order), per-order
averages, and two domain-specific keyword flags (household consumables and
kid/baby products) motivated by the hypothesis that purchasing patterns in these
categories scale with household size. The SQL file (`feature_queries.sql`)
additionally demonstrates how this pipeline would be built in a production
data warehouse environment, including exploratory queries to validate feature
assumptions against the target variable.

**Machine Learning Models**
I implemented and evaluated three of the four models: Lasso Regression, Random Forest, and XGBoost. This included data preparation specific to each model, hyperparameter tuning, feature importance analysis for each model, and the full 5-fold cross-validation evaluation framework used to compare all models fairly.

### Models

| Model | Description |
|---|---|
| **Baseline** | Predicts the training mean for all observations |
| **Lasso Regression** | Linear model with L1 regularization; lambda selected via 10-fold CV |
| **Random Forest** | Ensemble of 500 trees; `mtry` tuned via OOB error |
| **XGBoost** | Gradient boosted trees; hyperparameters tuned via grid search over `max_depth`, `eta`, `subsample`, `colsample_bytree` |

### Evaluation

All models were compared using 5-fold cross-validation RMSE. The best-performing model by mean CV RMSE is used to generate final test predictions.

---

## Key Design Choices

- **Consistent factor levels across train/test:** Factor columns are aligned before modeling to prevent prediction errors on unseen levels.
- **Missing value handling:** Numeric columns filled with training-set medians; factor columns get an explicit `"Missing"` level to preserve information.
- **Column alignment for XGBoost:** Test matrix columns are padded with zeros for any features present in training but absent in test.
- **Prediction floor:** All test predictions are clipped to a minimum of 1, since household size cannot be zero or negative.
- **Reproducibility:** `set.seed()` is used consistently before any stochastic operation (model training, fold assignment, tuning).

---

## Authors

Bebel Yen, Victoria Yee, Kaitlyn Wu  
UCLA STAT 101C — December 2025

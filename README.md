# Synthetic Healthcare Dataset: Cleaning, EDA & Faker-Detection Audit (SQL)

A two-part SQL portfolio project demonstrating data cleaning and exploratory
data analysis on a synthetic 55,500-row healthcare admissions dataset,
including a step-by-step audit that proves the dataset is randomly generated
rather than clinically realistic.

## Overview

This project takes a raw, messy healthcare dataset from Kaggle through two
stages: cleaning (parsing malformed fields, standardizing formats, handling
data quality issues) and exploratory analysis (demographic, clinical,
financial, and time-based patterns). Every finding in the analysis is
verified against a real-world benchmark, sourced from CDC, CMS, the American
Red Cross, and other public health data, to build a case for whether the
dataset reflects real clinical behavior.

**Spoiler: it doesn't**, and the project shows exactly how you can prove
that with SQL alone.

## Tools Used

- **MySQL 9.7** (MySQL Workbench)
- **TablePlus** (CSV import)
- **Dataset:** [Synthetic Healthcare Dataset (Kaggle)](https://www.kaggle.com/datasets/prasad22/healthcare-dataset)

## Project Structure

| File | Purpose |
|---|---|
| `Healthcare_Cleaning.sql` | Loads the raw dataset, removes duplicates, parses malformed name fields, standardizes categorical data, converts types, and flags unreliable columns |
| `Healthcare_EDA.sql` | Explores the cleaned dataset across demographics, clinical patterns, billing, length of stay, and time-based trends, benchmarking each finding against real-world data |

The EDA file depends on columns created in the cleaning file
(`first_name`, `last_name`, `dr_first_name`, `dr_last_name`, `age_range`,
etc.), so the cleaning script should be run first if reproducing this
end-to-end.

## Key Skills Demonstrated

- **Data cleaning:** duplicate detection and removal with `ROW_NUMBER()`,
  multi-pattern string parsing (`SUBSTRING_INDEX`) to split unstructured
  name fields into components, data type conversion, systematic NULL
  auditing
- **Window functions:** `RANK()`, `SUM() OVER(PARTITION BY ...)`, and
  rolling averages (`ROWS BETWEEN ... PRECEDING`) used for ranking,
  percentage-of-total calculations, and trend smoothing
- **CTEs and self-joins:** used to identify duplicate records and repeat
  patient admissions
- **Data quality auditing:** identifying and documenting CSV import
  corruption, invalid values (negative billing amounts), and verifying
  every summary claim against an actual query result before writing it down
- **External benchmarking:** every major finding is checked against a
  real-world source (CDC/NCHS, CMS, American Red Cross, AHRQ/HCUP, AMA)
  rather than asserted from assumption
- **Self-correction:** the project includes a documented bug fix (a
  double-counting error in a repeat-patient self-join, corrected from
  1,507 to 1,080 patients) as evidence of a verify-your-own-work habit

## Highlights

- **Every categorical variable in the dataset is distributed almost
  perfectly evenly** — blood type (~12.5% each), test results (~33% each),
  medications (~20% each), admission types (~33% each) — which is
  statistically implausible in real healthcare data and confirms
  synthetic, unmodeled data generation.
- **Real US average hospital length of stay is 6.3–6.6 days** (CDC/NCHS,
  2020–2023). This dataset averages **15.5 days** — roughly 2.4x higher,
  with zero year-over-year variation.
- **A statistical independence check** across medication, test result, and
  medical condition (90 possible combinations) found every combination
  landing within ~5% of the mathematically expected random count,
  confirming no clinical relationship exists between these fields in the
  dataset.
- **No COVID-19 signal** appears in 2020–2021 admission data, despite the
  real-world dramatic drop in elective procedures during that period —
  a strong tell that the data has no temporal modeling behind it.

**Recommendation:** This dataset is well-suited for SQL practice, but
should not be used for clinical modeling, prescribing analysis, or any
healthcare decision-making. Anyone evaluating similar Faker-generated
datasets for real use should run the same category of check
demonstrated here (distribution flatness, cross-variable independence)
before trusting it.

## How to Use

1. Import the [Kaggle healthcare dataset](https://www.kaggle.com/datasets/prasad22/healthcare-dataset)
   into a MySQL schema named `healthcare` as table `healthcare_dataset`.
2. Run `Healthcare_Cleaning.sql` top to bottom to build the cleaned
   `health_staging` table.
3. Run `Healthcare_EDA.sql` to reproduce the analysis.

Both files are commented throughout with inline query results and
explanatory notes, so they can also be read without being run.

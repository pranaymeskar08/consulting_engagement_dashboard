# Consulting Engagement Performance Dashboard

**PostgreSQL · SQL · Python · Power BI**

An end-to-end analysis of **60,000 messy consulting engagement records**: loading text-only data safely, cleaning it with reusable SQL functions and a view, answering five business questions with SQL, and presenting the result in a decision-focused Power BI dashboard.

> **Note:** The dataset is **fictional and synthetic**. It is not real firm data and says nothing about the performance of any real company.

---

## Table of contents

1. [Business problem](#business-problem)
2. [Dataset](#dataset)
3. [Tools](#tools)
4. [Project workflow](#project-workflow)
5. [Data cleaning approach](#data-cleaning-approach)
6. [Metric definitions](#metric-definitions)
7. [Business questions and SQL outputs](#business-questions-and-sql-outputs)
8. [Dashboard](#dashboard)
9. [Key findings](#key-findings)
10. [Recommendations](#recommendations)
11. [Data quality log](#data-quality-log)
12. [Limitations and caveats](#limitations-and-caveats)
13. [How to reproduce](#how-to-reproduce)
14. [Repository structure](#repository-structure)
15. [Skills demonstrated](#skills-demonstrated)

---

## Business problem

The operating committee of a fictional consulting firm wants one view of **engagement delivery, utilization, project risk and commercial performance**. The dashboard has to answer a single question:

> **What needs leadership attention, and why?**

The goal is not a gallery of charts. It is to find the few operational or commercial issues leadership should act on, quantify them, and state the limits of the evidence.

## Dataset

| Item | Detail |
|---|---|
| Records | 60,000 |
| Columns | 31 |
| Period | January 2024 to September 2026 |
| Currency | INR |
| Grain | **1 row = 1 engagement record** |
| Nature | Synthetic and intentionally messy |

Fields cover client, industry, service line, project label, region, office, employee, grade, work type, hours, utilization, progress, budget, cost, revenue, margin, status, milestone, partner, risk type, risk severity, and planned and actual end dates.

**Messy values include:** `TBD`, `Not Recorded`, `Unknown`, `N/A`, `Pending`, blanks, mixed date formats (`DD-MM-YYYY` and `YYYY-MM-DD`), inconsistent capitalisation, and numeric fields stored as text.

**Grain note:** the data has no project ID. `Project_Name` is a reused label and project budget changes from row to row, so **budget is never summed** and counts are **records, not distinct projects or employees**.

## Tools

| Tool | Use |
|---|---|
| PostgreSQL | Storage, cleaning functions, view, KPI queries |
| DBeaver | SQL editor and CSV export |
| Python (pandas, SQLAlchemy) | Loading the CSV as text without type errors |
| Power BI | Dashboard, slicers, DAX measures |

## Project workflow

```
CSV (60,000 rows)
   │  Python: load every column as TEXT
   ▼
raw_engagement  (original values preserved, never edited)
   │  SQL functions: fn_num, fn_date, fn_txt
   ▼
vw_engagement   (typed, normalised, with 1/0 flag columns)
   │  SQL queries, one per business question
   ▼
Exports / Power BI model  →  Dashboard
```

### Why the data is loaded as text

A direct CSV import failed because DBeaver guessed numeric types and could not parse placeholder values such as `TBD`. The fix was to load **everything as text** with Python and convert in SQL. This keeps the raw table identical to the source and makes the cleaning repeatable.

## Data cleaning approach

Cleaning happens in the `vw_engagement` view through three functions.

| Function | Job | Rule |
|---|---|---|
| `fn_num(text)` | Text to number | Strips symbols; `TBD`, `Not Recorded`, `Unknown`, `N/A` and blanks become **0** |
| `fn_date(text)` | Text to date | Reads `DD-MM-YYYY` and `YYYY-MM-DD`; `Pending`, `TBD` and blanks become **NULL** |
| `fn_txt(text)` | Tidy labels | Trims spaces, fixes capitalisation; placeholders become `'Unknown'` |

Further rules in the view:

- **Status** is normalised to `Active`, `At Risk`, `On Hold`, `Completed`, `Cancelled` or `Unknown`.
- **Progress** outside 0 to 100 is set to 0.
- **Employee ID** is kept only when it matches the `EMP-` pattern.
- **Dates after 30 Sep 2026** fall outside the stated data window and are set to blank (see the data quality log). The rows are kept so totals still reconcile to 60,000.

### Flag columns

The view adds 1/0 flags so every metric is a simple `SUM` or ratio:

| Flag | Meaning |
|---|---|
| `is_at_risk_hold` | Status is At Risk or On Hold |
| `is_open` | Status is Active, At Risk or On Hold |
| `is_overdue` | Open and planned end date is before the as-of date |
| `is_high_critical` | Risk severity is High or Critical |
| `is_late_high_risk` | High or Critical severity and progress of 75% or more |
| `is_billed` | Revenue is greater than 0 |

## Metric definitions

| Metric | Definition | Denominator |
|---|---|---|
| At-risk or on-hold share | `SUM(is_at_risk_hold) / COUNT(*)` | All records |
| Overdue % of open | `SUM(is_overdue) / SUM(is_open)` | Open records |
| High/critical rate | `SUM(is_high_critical) / COUNT(*)` | All records |
| Reported utilization | `AVG(utilization_pct)` | Row-level field, **not employee utilization** |
| Margin % (billed rows) | `SUM(margin) / SUM(revenue)` where revenue > 0 | Billed rows only |
| Zero-revenue rows | Count of rows with revenue = 0 | Validation item, not a confirmed loss |

**Why margin uses billed rows only:** rows with cost but no revenue would otherwise show as negative margin by construction.

## Business questions and SQL outputs

| # | Question | Output | Key columns |
|---|---|---|---|
| Headline | Overall numbers | `01_kpi_cards` | at-risk %, overdue, high/critical, utilization, margin |
| Q1 | Where are projects at risk? | `02_delivery_risk` | at-risk/hold %, overdue by segment |
| Q2 | Are teams deployed effectively? | `03_utilization` | utilization by grade, office, region, service line, month |
| Q3 | Which work looks commercially healthy? | `04_commercial` | revenue, cost, margin %, zero-revenue rows |
| Q4 | What risk pattern should be escalated? | `05_risk_patterns` | high/critical rate, late-stage high risk |
| Q5 | Where is work concentrated? | `06_portfolio_mix` | record share, revenue share |
| Part A | How reliable is the data? | `07_data_quality` | placeholder counts per field |
| Action | Which open items to review first? | `08_exception_register` | overdue High/Critical records |

Most outputs use a long layout (`dimension`, `segment`, metrics) built with `CROSS JOIN LATERAL (VALUES ...)`, which keeps each query to a single clean result.

## Dashboard

Two pages built in Power BI from the `vw_engagement` view, so slicers filter every visual.

**Page 1: Executive engagement**
- KPI cards: at-risk or on-hold share, overdue % of open, utilization, margin % (billed rows)
- Top areas needing attention (service lines ranked by at-risk share)
- Engagement status distribution
- Utilization vs risk by service line
- Risk type by severity

**Page 2: Portfolio and operations**
- High/critical risks by risk type
- High/critical rate by delivery stage
- Exception register (overdue open engagements with High or Critical risk)
- Portfolio mix: share of revenue vs share of records

**Slicers:** date range, service line, region, client industry, engagement status, office.

<!-- Add screenshots here: -->
<!-- ![Executive page](D:\codeeeee\Practice projects\consulting-engagement-dashboard\Images) -->
<!-- ![Portfolio page](D:\codeeeee\Practice projects\consulting-engagement-dashboard\Images) -->

## Key findings

> Fill in the bracketed values from your final, verified dashboard. Do not publish a number you have not reconciled to the SQL output.

1. **Risk is spread evenly, not concentrated.** About **33% of records are At Risk or On Hold** and the share is almost the same in every service line (roughly 32.5% to 33.5%). This is a portfolio-wide pattern.
2. **Risk severity is largely unrecorded.** Around **84% of records have no risk severity**, so the true risk picture is unclear and "no risk" cannot be assumed.
3. **Utilization looks uniform.** Reported utilization averages about **11.6** with service lines within roughly 11.4 to 12.0. Because the field is row-level, this cannot support a capacity conclusion.
4. **Revenue share tracks record share.** Each service line holds roughly 10% of both, so there is no strong concentration by service line.
5. **Zero-revenue rows limit the margin story.** Margin on billed rows is about **70.5%**, but a large number of rows per project label have cost and no revenue, so the margin needs validation before any claim.
6. **Overdue work: [VERIFY]** The overdue share of open engagements came out at about **89%**. Check planned end dates against record dates and the as-of date before relying on this figure. If planned dates are unreliable, say so.

## Recommendations

1. **Review overdue High/Critical engagements first**, using the exception register, starting with the longest overdue.
2. **Require a risk severity on every active engagement.** With about 84% blank, leadership cannot tell low risk from unreported risk.
3. **Validate zero-revenue and negative-margin rows** before drawing any commercial conclusion about a service line.

## Data quality log

| Issue | Field | Rows affected | Treatment | Remaining uncertainty |
|---|---|---|---|---|
| Numeric fields stored as text | hours, revenue, cost, budget | [fill from file 07] | Converted with `fn_num` | Cannot tell a true 0 from a missing value |
| Placeholders (`TBD`, `Not Recorded`, `N/A`) in numeric fields | multiple | [fill] | Set to 0 | Missing cost or revenue looks like zero |
| Placeholders in labels | partner, risk, status | [fill] | Set to `Unknown` | Unknown may hide real values |
| `Pending` and unparseable dates | actual end date, planned end date | [fill] | Set to NULL | On-time delivery not computable for most completed work |
| Mixed date formats | record date | all rows | Parsed both `DD-MM-YYYY` and `YYYY-MM-DD` | Day/month swaps cannot be ruled out |
| Dates outside the stated window | record date | **15** (1 Oct to 8 Dec 2026) | Date set to blank, row kept | True date unknown; some are in the future |
| Inconsistent label case and spacing | client, service line, region | [fill] | Trimmed and normalised | Aliases with different spelling may remain |
| Missing employee IDs | employee ID | [fill] | Left as NULL | Employee-level metrics not reliable |

## Limitations and caveats

- **Grain:** one row is one engagement record. There is no project ID, so counts are records, not distinct projects, clients or employees.
- **Utilization** is a row-level reported field. Accurate utilization needs employee-week data: hours worked, available capacity, leave and bench time.
- **Zero conversion:** setting `TBD` and `Not Recorded` to 0 means a missing value and a real zero look identical in the view. Original values remain in `raw_engagement`.
- **Margin** is computed on billed rows only. Project budget is not summed because it varies by row under the same label.
- **Correlation is not causation.** Risk, utilization and margin patterns do not show cause.
- **Slicers** only work when visuals are built from the single `vw_engagement` table, not from separate pre-aggregated exports.
- **Synthetic data:** results describe this dataset only.

### Data requested to improve the analysis

- A true project ID and project-level budget table
- Employee-week hours, capacity, leave and bench time
- Completed engagements with valid actual end dates
- Mandatory risk severity capture

## How to reproduce

### 1. Create the database
```sql
CREATE DATABASE consulting_db;
```

### 2. Load the CSV as text (Python)
```python
import pandas as pd
from sqlalchemy import create_engine

engine = create_engine("postgresql://USER:PASSWORD@localhost:5432/consulting_db")
df = pd.read_csv("data/Consulting_Engagements_Cleaned_Dataset.csv",
                 dtype=str, keep_default_na=False, encoding="utf-8-sig")
df.columns = df.columns.str.lower()
df.to_sql("raw_engagement", engine, if_exists="replace", index=False,
          method="multi", chunksize=5000)
```

### 3. Create the functions and view
Run `sql/02_functions_and_view.sql` from the `consulting_db` connection.

### 4. Check the load
```sql
SELECT COUNT(*) FROM raw_engagement;   -- expect 60000
```

### 5. Run the analysis queries
Run the files in `sql/03_analysis_queries.sql` one at a time and export as CSV if needed.

### 6. Open the dashboard
Open `dashboard/consulting_dashboard.pbix`, or connect Power BI to `vw_engagement` and rebuild the visuals.

> Run every script from the **`consulting_db`** connection, not the default `postgres` database, or the queries will point at an empty table.

## Repository structure

```
consulting-engagement-dashboard/
├── README.md
├── data/
│   └── Consulting_Engagements_Cleaned_Dataset.csv
├── sql/
│   ├── 01_create_database.sql
│   ├── 02_functions_and_view.sql
│   └── 03_analysis_queries.sql
├── python/
│   └── load_data.py
├── dashboard/
│   ├── consulting_dashboard.pbix
│   └── consulting_theme.json
└── images/
    ├── dashboard_page1.png
    └── dashboard_page2.png
```

## Skills demonstrated

- Handling messy data: text-only loading, placeholder handling, date parsing
- SQL: functions, views, CTEs, window functions, `FILTER`, `CROSS JOIN LATERAL`
- Grain and metric correctness: records vs projects vs employees, billed-row margin
- Data quality auditing and documenting assumptions
- Dashboard design: KPI cards, ranked visuals, slicers, exception register
- Communicating findings with caveats and next steps

## Author

**[Your Name]** · [LinkedIn] · [GitHub]

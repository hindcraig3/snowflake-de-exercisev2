# TastyBytes Data Engineering Exercise

## Purpose

This hands-on exercise walks you through building a complete data pipeline in Snowflake. Starting from raw source data, you will create staging tables, a dimensional model, and a reporting view — using only Snowflake-native features.

By the end of this exercise you will have practical experience with:

- **DDL design** — creating tables with appropriate data types, handling data quality issues in source data
- **Semi-structured data** — flattening JSON (VARIANT) columns into relational columns
- **SQL stored procedures** — writing reusable load procedures using TRUNCATE-reload and MERGE patterns
- **Task graphs** — orchestrating pipeline execution with Snowflake Tasks and dependencies
- **Data governance** — applying enterprise tags, column-level masking policies, and catalog documentation (COMMENTs)
- **RBAC** — granting role-based access to the objects you create
- **Dimensional modelling** — building SCD Type 1 and Type 2 dimensions and a fact table
- **Reporting views** — creating a data product that answers a specific business question

---

## Documentation Site (MkDocs)

This project uses [MkDocs](https://www.mkdocs.org/) to publish the exercise instructions as a GitHub Pages site. Rather than reading the raw Markdown files in this repository, refer to the published site for a formatted, navigable version of all exercises, setup guides, and model answers.

After making changes to any documentation pages, deploy the updated site by running:

```bash
mkdocs gh-deploy
```

This builds the site from the Markdown source and pushes it to the `gh-pages` branch, making the changes live on GitHub Pages.

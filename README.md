# Flowt

HR analytics tool for people teams and change managers. Upload messy CSV exports from your HRIS, and Flowt cleans them, builds department profiles, and surfaces insights, engagement trends, turnover patterns, attendance, feedback sentiment, without you having to wrangle spreadsheets.

## Stack

- Rails 7.1 / Ruby 3.3
- PostgreSQL (JSONB for row data + stats)
- Hotwire + Stimulus, Tailwind, Chart.js via importmap
- Sidekiq + Redis for background imports
- Prawn for PDF exports

## Running locally

```sh
bundle install
bin/rails db:create db:migrate db:seed
bin/dev
```

Sidekiq handles imports in the background, so you'll want Redis running. In a second terminal:

```sh
bundle exec sidekiq
```

Set your Anthropic key in `.env` if you want AI department summaries (the app works without it, just falls back to a stat-based summary):

```
ANTHROPIC_API_KEY=sk-ant-...
```

## Tests

```sh
bundle exec rspec
```

## How it works

Upload a CSV on the Datasets page. Flowt detects column types, runs a cleaning pipeline (trims whitespace, normalises dates, flags IQR outliers, deduplicates), and writes cleaned rows to the database. If the file has a `department` column, it automatically maps rows to departments — typos and abbreviations included (`Mktg` → Marketing, `Enginering` → Engineering, etc).

Department profiles are computed from all linked datasets. The overview page shows engagement trends, turnover by month, attendance rate, and feedback sentiment, updated every time you upload new data.

## Structure

```
app/services/
  csv_parser_service.rb            type detection, warnings
  data_cleaning_pipeline.rb        cleaning + diff output
  department_profile_service.rb    rolls up row data into a snapshot
  insight_engine_service.rb        flags critical/warning/positive signals
  text_analytics_service.rb        keyword frequency + sentiment
  ai_summary_service.rb            Claude-powered plain-English brief
  benchmark_service.rb             cross-department comparison rows
  progressive_dataset_import_service.rb  step-by-step import with live progress
```

PDF export covers the full department brief, snapshot metrics, insight cards, feedback themes, and the AI summary if available.

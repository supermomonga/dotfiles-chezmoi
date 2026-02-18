---
name: notebook
description: Generates reproducible Quarto-based Python script notebooks (# %% percent format), executes them, and produces iterative Markdown reports and final HTML reports. Use when the user requests structured data analysis, alpha research, quantitative experiments, or automated report generation with per-task directory isolation.
compatibility: Requires Python 3.10+, Quarto CLI installed via `uv`, and ability to execute local shell commands.
allowed-tools: Bash(uv run quarto:*) Bash(jq:*) Read
metadata:
  version: "1.0"
---

# Notebook Skill

## Purpose

The `notebook` skill creates fully reproducible analytical research tasks using Quarto and Python script-based notebooks (percent format using `# %%`).

It is designed for agent-driven research workflows where:

* The user requests exploratory analysis or alpha discovery
* Multiple hypotheses must be decomposed into independent tasks
* Each task must generate its own notebook and report
* Iterative execution is required during development
* Final deliverables must be human-readable (HTML reports)

This skill ensures strict directory isolation per task and deterministic output paths.

---

## Invocation Pattern

Use this skill when the user provides instructions such as:

* "Generate 10 alpha ideas and analyze each"
* "Create notebooks for each hypothesis"
* "Run experiments and generate reports"
* "Decompose research into tasks and produce structured outputs"

The agent must:

1. Decompose the request into independent research tasks
2. Create one notebook per task
3. Execute each notebook
4. Generate Markdown output for analysis loop
5. Generate HTML output for final report

---

## Directory Structure

For each task, create:

```
./notebooks/[report_name]/
    notebook.py
    report/
        report.html
    artifacts/
        (generated figures, csv, json, etc.)
```

Constraints:

* `report_name` must be lowercase kebab-case
* Each task must use a unique directory
* No cross-task file mutation

---

## Notebook Template Requirements

Each `notebook.py` must:

1. Use Quarto YAML frontmatter
2. Use `# %%` percent-style cells
3. Disable noisy output
4. Save large artifacts to `artifacts/`
5. Avoid printing large DataFrames

### Required YAML Header

```python
# ---
# title: "[Human Readable Title]"
# execute:
#   echo: false
#   warning: false
#   message: false
# format:
#   gfm:
#     embed-resources: false
#   html:
#     embed-resources: true
# ---
```

Markdown (`gfm`) is used during iterative analysis.
HTML is used for final delivery.

---

## Execution Workflow

For each task:

### 1. Generate notebook.py

Create a fully executable analysis script.

### 2. Iterative Render (Analysis Loop)

```
quarto render notebook.py --to gfm --output-dir .
```

This produces:

```
notebook.md
notebook_files/
```

The agent reads `notebook.md` to evaluate results and determine whether updates are needed.

### 3. Final Render

```
quarto render notebook.py --to html --output-dir report
```

This produces:

```
report/report.html
```

---

## Task Decomposition Rules

When the user requests multiple alpha ideas or experiments:

1. Generate a numbered list of hypotheses
2. Convert each hypothesis into an independent notebook task
3. Name directories descriptively
4. Ensure reproducibility (fixed seeds if applicable)
5. Clearly document methodology in Markdown cells

Example report names:

* binance-leads-bybit-lag-returns
* cross-exchange-volume-imbalance
* lead-lag-cross-correlation

---

## Coding Constraints

* Use pandas, numpy, matplotlib, seaborn by default
* Use deterministic randomness (`np.random.seed`)
* Save plots explicitly when necessary
* Avoid global state across tasks
* Do not rely on interactive widgets

---

## Failure Handling

If execution fails:

1. Inspect error from render output
2. Modify notebook.py
3. Re-render
4. Repeat until successful

Do not abandon a task unless explicitly instructed.

---

## Completion Criteria

The skill is complete when:

* All requested tasks have separate directories
* Each contains a working notebook.py
* Each contains report/report.html
* Iterative Markdown output was successfully generated

---

## Design Principles

* Deterministic outputs
* Minimal console noise
* Strict directory isolation
* Reproducibility first
* Human-readable final reports

This skill standardizes automated research pipelines using Quarto-backed Python notebooks while keeping execution lightweight and LLM-friendly.

# 🚀 GCP Platform Foundation - CI/CD Pipeline Architecture (`cloudbuild-pipelines/`)

This directory contains the production-grade **Google Cloud Build CI/CD pipelines** and automation engines designed for orchestrating multi-layer **Terraform Infrastructure as Code (IaC)** on Google Cloud Platform.

---

## 📑 Table of Contents

- [Architectural Overview](#architectural-overview)
- [Pipeline Architecture & Triggers](#pipeline-architecture--triggers)
  - [1. Continuous Integration (CI) — `terraform-ci.yaml`](#1-continuous-integration-ci--terraform-ciyaml)
  - [2. Continuous Deployment (CD) — `terraform-cd.yaml`](#2-continuous-deployment-cd--terraform-cdyaml)
- [Core Concepts & Design Patterns](#core-concepts--design-patterns)
  - [Config-as-Data & Dynamic Scope Detection](#config-as-data--dynamic-scope-detection)
  - [Sequential Layer Ordering & Dependency Hierarchy](#sequential-layer-ordering--dependency-hierarchy)
  - [Multi-Tier Security & IaC Governance](#multi-tier-security--iac-governance)
  - [GitHub App Bot Integration & In-Place PR Reporting](#github-app-bot-integration--in-place-pr-reporting)
  - [Dynamic GCS Remote State Management](#dynamic-gcs-remote-state-management)
- [Directory Structure](#directory-structure)
- [Pipeline Configuration & Substitutions Reference](#pipeline-configuration--substitutions-reference)
- [Troubleshooting & Best Practices](#troubleshooting--best-practices)

---

## 🏛️ Architectural Overview

The CI/CD subsystem implements an automated, secure GitOps workflow for managing multi-tier GCP infrastructure across multiple environments (`dev`, `qat`, `prod`). 

Rather than executing monolithic Terraform runs or maintaining redundant pipeline files for each layer, the architecture leverages **Config-as-Data** and **Dynamic Scope Discovery**. Changes declared in YAML configuration files or requested through Pull Request metadata trigger scoped, ordered executions.

```
                      ┌──────────────────────────────────────────────┐
                      │              Developer GitOps                │
                      │   (Pull Request / Merge to 'main' Branch)    │
                      └──────────────────────┬───────────────────────┘
                                             │
                      ┌──────────────────────▼───────────────────────┐
                      │      Google Cloud Build Orchestrator         │
                      │  (Managed Serverless Execution Environment)  │
                      └──────┬───────────────────────────────┬───────┘
                             │                               │
             Pull Request    │                               │   Merge to 'main'
             Event           ▼                               ▼   Event
┌──────────────────────────────────────────┐   ┌──────────────────────────────────────────┐
│      1. CI Pipeline (terraform-ci.yaml)   │   │      2. CD Pipeline (terraform-cd.yaml)   │
│  - PR Scope Resolution                   │   │  - Merge Scope Detection (Git diff)      │
│  - Config & Schema Pre-Flight Validation │   │  - Config Integrity Validation           │
│  - Gitleaks (Secret Detection)           │   │  - Sequential Terraform Apply (set -e)   │
│  - Trivy (Vulnerabilities & Misconfig)   │   │  - GCS Remote State Update               │
│  - Terraform Format & Validate           │   │  - Cloud Logging Deployment Audit        │
│  - Checkov (CIS IaC Compliance)          │   │  - GitHub App Deployment Audit Bot       │
│  - Terraform Plan & JSON Archival (GCS)  │   │                                          │
│  - GitHub App Interactive Bot Comment    │   │                                          │
└──────────────────────────────────────────┘   └──────────────────────────────────────────┘
```

---

## 🔄 Pipeline Architecture & Triggers

### 1. Continuous Integration (CI) — [`terraform-ci.yaml`](file:///d:/GCP-DevOps-WorkSpace/gcp-platform-foundation-terraform/cloudbuild-pipelines/terraform-ci.yaml)

- **Trigger Event**: Pull Request creation or synchronization targeting the `main` branch.
- **Goal**: Validate syntax and schema contracts, enforce security guardrails, generate Terraform plans, and present an actionable audit report on the PR before merging.

#### Execution Pipeline Steps:

1. **`parse-pr-scope`**:
   - Queries the GitHub API for the PR description or falls back to `pr_body.txt`.
   - Executes [`validate-request.sh`](file:///d:/GCP-DevOps-WorkSpace/gcp-platform-foundation-terraform/cloudbuild-pipelines/scripts/validate-request.sh) to extract target `environment` and `infrastructure` layers, verifying physical paths and emitting `deployment_scope.json`.
2. **`validate-configs`**:
   - Runs [`validate-config.sh`](file:///d:/GCP-DevOps-WorkSpace/gcp-platform-foundation-terraform/cloudbuild-pipelines/scripts/validate-config.sh) against each target configuration YAML to verify schema conformance via Python `jsonschema`.
3. **`secret-scan-gitleaks`**:
   - Runs `zricethezav/gitleaks:latest` across repository commits and working tree, capturing logs to `gitleaks_report.txt`.
4. **`vuln-scan-trivy`**:
   - Runs `aquasec/trivy:latest` filesystem scanner (`fs --scanners vuln,misconfig --severity HIGH,CRITICAL`) and writes to `trivy_report.txt`.
5. **`terraform-validate`**:
   - Runs `terraform fmt -check`, generates a dynamic backend file (`<name>-<env>-backend.hcl`), executes `terraform init`, and runs `terraform validate` across all targets.
6. **`iac-scan-checkov`**:
   - Runs `bridgecrew/checkov:latest` against target directories for GCP CIS Benchmark violations, outputting to `checkov_report.txt`.
7. **`terraform-plan`**:
   - Executes `terraform plan -var="environment=${ENV}" -out=tfplan.binary` and converts the plan to structured JSON via `terraform show -json tfplan.binary > tfplan.json`.
8. **`upload-plan-to-gcs`**:
   - Stores the generated `tfplan.json` in the Plan Review bucket: `gs://${_PLAN_BUCKET}/tf-plan-review/${_PR_NUMBER}/${SHORT_SHA}/<name>-<env>-tfplan.json`.
9. **`post-pr-comment-bot`**:
   - Runs [`bot.js`](file:///d:/GCP-DevOps-WorkSpace/gcp-platform-foundation-terraform/cloudbuild-pipelines/scripts/bot.js) inside `node:20-alpine`, signs a JWT using the GitHub App Private Key from Secret Manager, parses the scan reports and `tfplan.json`, and updates/creates the ultra-compact PR review comment.

---

### 2. Continuous Deployment (CD) — [`terraform-cd.yaml`](file:///d:/GCP-DevOps-WorkSpace/gcp-platform-foundation-terraform/cloudbuild-pipelines/terraform-cd.yaml)

- **Trigger Event**: Push / merge event into the `main` branch.
- **Goal**: Sequentially apply Terraform changes to live GCP infrastructure following strict platform tier dependencies and record deployment provenance.

#### Execution Pipeline Steps:

1. **`detect-cd-scope`**:
   - Authenticates via GitHub App JWT and queries the GitHub API for merged PR metadata or inspects `git diff` against `HEAD~1`.
   - Identifies changed YAML files in `environments/<env>/` and orders tiers: `network` ➔ `security` ➔ `compute` ➔ `availability`.
2. **`validate-configs`**:
   - Runs pre-flight schema validation on all detected environment configurations.
3. **`sequential-terraform-apply`**:
   - Dynamically initializes each layer against its remote GCS backend prefix.
   - Executes `terraform apply -auto-approve -var="environment=${ENV}"` under `set -e` fail-fast semantics.
   - Collects exported outputs into `outputs.json`.
4. **`post-cd-audit-bot`**:
   - Executes [`cd-bot.js`](file:///d:/GCP-DevOps-WorkSpace/gcp-platform-foundation-terraform/cloudbuild-pipelines/scripts/cd-bot.js) to comment on the merged PR with apply summaries, updated GCS state paths, and exported outputs.

---

## 🧩 Core Concepts & Design Patterns

### 1. Sequential Layer Ordering & Dependency Hierarchy
To guarantee zero race conditions, the CI/CD orchestrator strictly orders layer execution:
```
1-network-infrastructure ➔ 2-security-infrastructure ➔ 3-compute-infrastructure ➔ 4-availability-infrastructure
```

### 2. Multi-Tier Security & IaC Governance
Every PR is gated by three independent security scans:
- **Gitleaks**: Scans for leaked private keys, GCP service account credentials, and API secrets.
- **Trivy**: Scans for known CVEs and repository misconfigurations.
- **Checkov**: Audits HCL code against CIS Google Cloud Platform Foundations Benchmarks.

### 3. GitHub App Bot Integration
Uses GitHub App authentication (App ID + RS256 JWT minted from Secret Manager private key) instead of personal developer tokens:
- Posts structured comments with security scan statuses, resource change counts (`+add`, `~modify`, `-destroy`), and collapsible details.
- Avoids GitHub's 65,000-character comment limit via ultra-compact formatting in [`bot.js`](file:///d:/GCP-DevOps-WorkSpace/gcp-platform-foundation-terraform/cloudbuild-pipelines/scripts/bot.js).

---

## 📁 Directory Structure

```text
cloudbuild-pipelines/
├── terraform-ci.yaml        # CI Pipeline definition (PR Triggers)
├── terraform-cd.yaml        # CD Pipeline definition (Merge Triggers)
├── README.md                # Pipeline architecture guide
└── scripts/                 # Pipeline helper scripts & GitHub App bots
    ├── bot.js               # PR plan & security comment bot
    ├── cd-bot.js            # CD deployment audit reporter bot
    ├── detect-cd-scope.sh   # Git merge & PR scope detector
    ├── post-pr-comment.sh   # Fallback PAT PR commenter
    ├── README.md            # Scripts documentation
    ├── validate-config.sh   # YAML & JSON schema validator
    └── validate-request.sh  # PR payload parser
```

---

## ⚙️ Pipeline Configuration & Substitutions Reference

| Substitution Variable | Default Value | Description |
| :--- | :--- | :--- |
| `_PLAN_BUCKET` | `gcp-tfplans-instancetemplate-strorage-bucket` | GCS bucket where `tfplan.json` review files are archived. |
| `_APP_ID_SECRET` | `github-app-id` | Secret Manager secret name containing GitHub App ID. |
| `_INSTALLATION_ID_SECRET` | `github-app-installation-id` | Secret Manager secret name containing App Installation ID. |
| `_PRIVATE_KEY_SECRET` | `github-app-private-key` | Secret Manager secret name containing GitHub App PEM private key. |

---

## 🛡️ Troubleshooting & Best Practices

1. **Fast-Fail on Validation**: If schema validation fails, fix the offending YAML in `environments/<env>/` rather than editing Terraform HCL.
2. **Comment Truncation Prevention**: `bot.js` limits plan diff outputs to prevent hitting GitHub's API 65k character limits.
3. **State Locking**: Remote state locking prevents concurrent Cloud Build builds from modifying the same layer state simultaneously.

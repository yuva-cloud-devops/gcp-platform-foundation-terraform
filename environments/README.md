# 🌐 Environment Configurations (`environments/`)

This directory houses the **declarative YAML configuration contracts** for all infrastructure layers and deployment environments across Google Cloud Platform. 

In this repository, Terraform HCL is designed as a reusable, parameterized execution engine; all environment-specific topologies, CIDRs, instance sizing, security rules, and scaling parameters are declared in pure YAML.

---

## 📁 Directory Structure

```text
environments/
├── bootstrap.yaml               # Layer 0: Organization/Project baseline, GCS buckets, CI/CD SA & IAM
├── dev/                         # Development Environment
│   ├── network.yaml             # Layer 1: VPCs, Dual-Region Subnets, Cloud NATs, Firewall Rules
│   ├── security.yaml            # Layer 2: Cloud Armor Security Policy, Workload SAs & IAM, Secret Access
│   ├── compute.yaml             # Layer 3: Instance Templates, Autoscaled Multi-Region MIGs (Mumbai & Singapore)
│   └── availability.yaml        # Layer 4: Global External Application Load Balancer (ALB) & Backend Services
├── qat/                         # Quality Assurance / Testing Environment
│   ├── network.yaml
│   ├── security.yaml
│   ├── compute.yaml
│   └── availability.yaml
└── prod/                        # Production Environment (High Availability & Stricter Security)
    ├── network.yaml
    ├── security.yaml
    ├── compute.yaml
    └── availability.yaml
```

---

## 🏗️ Layer-by-Layer Configuration Reference

### 1. Baseline Bootstrap (`bootstrap.yaml`)
Declared at the root of `environments/`, this config bootstraps the GCP project before any layer pipelines can execute.

| Section | Description | Key Fields |
| :--- | :--- | :--- |
| `project_id` | GCP Project ID hosting all platform resources | `yuvaraj-internal-project` |
| `region` | Primary administrative GCP region | `asia-south1` |
| `apis` | Cloud APIs to enable on the project | `compute`, `iam`, `cloudbuild`, `iap`, `secretmanager` |
| `buckets` | State and artifact GCS buckets | `state_bucket` (versioned), `plan_bucket` (14-day lifecycle) |
| `service_account`| Cloud Build CI/CD Service Account | `sa-cloudbuild-terraform` with required project IAM roles |

---

### 2. Network Infrastructure (`<env>/network.yaml`)
Defines the software-defined network boundary, isolation zones, and egress gateways.

```yaml
project_id: yuvaraj-internal-project
region: asia-south1
state_bucket: gcp-remote-backend-tfstate-management-bucket

tags:
  provisioned_by: terraform
  environment: dev
  project: gcp-platform-foundation-terraform

network:
  vpcs:
    - name: vpc-workload
      auto_create_subnetworks: false
      routing_mode: GLOBAL
      subnets:
        - name: subnet-workload-mumbai
          region: asia-south1
          ip_cidr_range: 10.10.1.0/24
          private_ip_google_access: true
        - name: subnet-workload-singapore
          region: asia-southeast1
          ip_cidr_range: 10.30.1.0/24
          private_ip_google_access: true
      routers:
        - name: router-mumbai
          region: asia-south1
          nats:
            - name: nat-mumbai
              source_subnetwork_ip_ranges_to_nat: ALL_SUBNETWORKS_ALL_IP_RANGES
      firewall_rules:
        - name: allow-iap-ssh
          direction: INGRESS
          priority: 1000
          source_ranges: ["35.235.240.0/20"]
          allow: [{ protocol: tcp, ports: ["22"] }]
```

---

### 3. Security Infrastructure (`<env>/security.yaml`)
Manages Cloud Armor Layer 7 WAF security policies, least-privilege workload identities, and key management access.

```yaml
project_id: yuvaraj-internal-project
region: asia-south1
state_bucket: gcp-remote-backend-tfstate-management-bucket

security:
  cloud_armor_policies:
    - name: ca-policy-web
      description: "Cloud Armor WAF for Public Load Balancer"
      rules:
        - action: allow
          priority: 1000
          src_ip_ranges: ["0.0.0.0/0"]
          preview: false
          description: "Default ingress access"
  service_accounts:
    - name: sa-mig-workload
      display_name: "MIG Compute Workload Service Account"
      roles:
        - roles/logging.logWriter
        - roles/monitoring.metricWriter
        - roles/secretmanager.secretAccessor
```

---

### 4. Compute Infrastructure (`<env>/compute.yaml`)
Specifies the workload templates, custom web server scripts, port configurations, and regional Managed Instance Groups (MIGs).

```yaml
project_id: yuvaraj-internal-project
region: asia-south1
state_bucket: gcp-remote-backend-tfstate-management-bucket

compute:
  instance_templates:
    - name: it-web-mumbai
      region: asia-south1
      machine_type: e2-medium
      source_image: projects/debian-cloud/global/images/family/debian-12
      service_account_ref: sa-mig-workload
      startup_script_path: scripts/startup.sh

  managed_instance_groups:
    - name: mig-web-mumbai
      region: asia-south1
      instance_template_ref: it-web-mumbai
      named_ports:
        - name: http
          port: 8080
      autoscaler:
        min_replicas: 2
        max_replicas: 5
        cooldown_period: 60
        cpu_utilization_target: 0.75
```

---

### 5. Availability Infrastructure (`<env>/availability.yaml`)
Configures the Global External Application Load Balancer (ALB), multi-region backend services, health check thresholds, and traffic distribution policies.

```yaml
project_id: yuvaraj-internal-project
region: asia-south1
state_bucket: gcp-remote-backend-tfstate-management-bucket

availability:
  load_balancer:
    name: glb-web
    load_balancing_scheme: EXTERNAL_MANAGED
    create_address: true
    http_forward: true
    ssl: false

    backend:
      protocol: HTTP
      port: 8080
      port_name: http
      locality_lb_policy: ROUND_ROBIN
      balancing_mode: UTILIZATION
      max_utilization: 0.8
      target_migs:
        - mig-web-mumbai
        - mig-web-singapore
      health_check:
        request_path: /
        port: 8080
        check_interval_sec: 10
        timeout_sec: 5
        healthy_threshold: 2
        unhealthy_threshold: 3
```

---

## 🚦 Environment Differences Matrix

| Configuration Attribute | `dev` | `qat` | `prod` |
| :--- | :--- | :--- | :--- |
| **MIG Sizing (Replicas)** | 2 Min / 5 Max | 2 Min / 8 Max | 4 Min / 20 Max |
| **Machine Type** | `e2-medium` | `e2-standard-2` | `c2-standard-4` |
| **Cloud Armor WAF Rules** | Permissive / Preview | Standard Filter / Rate Limit | Strict / Geo-fencing / OWASP Top 10 |
| **Health Check Interval** | 10 seconds | 5 seconds | 3 seconds |
| **GCS Bucket Destruction** | `force_destroy: true` (plan bucket) | `force_destroy: true` | `force_destroy: false` (immutability) |

---

## ➕ How to Onboard a New Environment (e.g., `uat` / `staging`)

To introduce a new environment into the platform foundation:

1. **Create the Environment Folder**:
   ```bash
   mkdir -p environments/uat
   ```
2. **Copy and Adapt Configuration Files**:
   ```bash
   cp environments/dev/*.yaml environments/uat/
   ```
3. **Customize Attributes in `environments/uat/*.yaml`**:
   - Update `tags.environment` to `uat`.
   - Adjust Subnet CIDR blocks if deploying in a shared network or separate project.
   - Set replica counts and autoscaling thresholds matching UAT capacity requirements.
4. **Validate Against Schemas**:
   ```bash
   for f in environments/uat/*.yaml; do
     ./cloudbuild-pipelines/scripts/validate-config.sh "$f"
   done
   ```
5. **Open a Pull Request**: Submit the new files via a Git branch to trigger the CI validation pipeline.

---

## 🏷️ Standard Tags & Metadata Governance

All YAML configurations support a top-level `tags` block that is automatically propagated to all GCP resources as native labels:

```yaml
tags:
  provisioned_by: terraform
  environment: <dev|qat|prod>
  project: gcp-platform-foundation-terraform
  cost_center: engineering
```

---

## 🛡️ Pre-Flight Validation

Before committing any modifications to `environments/`, run the local schema validator:

```bash
# Validate specific layer config
./cloudbuild-pipelines/scripts/validate-config.sh environments/dev/availability.yaml schemas/availability.schema.json

# Or using the auto-detection feature
./cloudbuild-pipelines/scripts/validate-config.sh environments/dev/network.yaml
```

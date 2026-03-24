# 🚀 Master Blueprint: Universal CloudTier Deployment Dashboard

If you want to replicate this project from scratch, use this prompt with a high-end AI coding assistant or follow these steps precisely to build the system.

---

## 1. High-Level Objective
Create a **Universal Terraform Deployment Dashboard** using **Next.js 14**, **Terraform 1.7.0**, and **Docker**. The app must allow one-click deployment of 1-tier, 2-tier, or 3-tier AWS infrastructure across any region/OS by simply entering a **GitHub Repository URL**. 

### Core Features:
- **Glassmorphic UI**: Premium dark-mode dashboard with real-time pulsing status and terminal logs.
- **Root-Driven Terraform**: Infrastructure modules (VPC, EC2, RDS, ALB, ASG) must be lean receivers; all logic (AMI lookups, SSH key generation, Smart Scripts) must live in the root `main.tf`.
- **Repo-Agnostic Execution**: The system must detect if a repo is **Node.js**, **Python**, or **Static HTML** and install dependencies automatically.
- **Secure Key Management**: Generate `ec2_key.pem` on-the-fly, store it locally (ignored by Git), and use a stable `cloudtier-key` in AWS to prevent resource conflicts.
- **Live Terminal Logging**: Use **Server-Sent Events (SSE)** to stream `terraform` binary output directly to the browser.
- **Safe Destruction**: A "Destroy" button with a security modal requiring the user to type "destroy" to confirm decommissioning.

---

## 2. The Frontend (Next.js 14 + Tailwind)
**Technical Requirements:**
- Use **Lucide React** for icons and **Framer Motion** for animations.
- **Layout**: A sidebar-less, wide-screen glassmorphic card.
- **Fields**: AWS Access Key, Secret Key, Region (Dropdown), Architecture (1/2/3 Tier), OS (Ubuntu/Amazon Linux), Preference (Cost/Performance), and GitHub Repo URL.
- **Terminal**: A fixed-height black box with `font-mono` and `ansi-to-html` or similar logic to show color-coded Terraform logs.

---

## 3. The Backend Engine (Next.js API)
**Technical Requirements:**
- **Route /api/deploy**:
    1. Receive JSON payload.
    2. Write a `terraform.tfvars` file on-the-fly using the received variables.
    3. Spawn `terraform init` and `terraform apply -auto-approve`.
    4. Stream stdout/stderr back via a `ReadableStream` (EventSource).
- **Route /api/destroy**:
    1. Run `terraform init` (mandatorily) then `terraform destroy -auto-approve`.
    2. Stream logs to the same terminal.

---

## 4. The Universal Terraform Architecture
**Root `main.tf` logic:**
- **Provider**: AWS region driven by variable.
- **SSH Logic**: `resource "tls_private_key"` + `resource "aws_key_pair"` with a fixed name `cloudtier-key`.
- **Smart Script**: Use separate HCL heredoc locals for `ubuntu_user_data` and `amazon_user_data`.
- **Detection Script Code**:
  ```bash
  git clone "$REPO_URL" "$REPO_DIR"
  if [ -f "package.json" ]; then npm install; fi
  if [ -f "requirements.txt" ]; then pip3 install -r requirements.txt; fi
  if [ -f "index.html" ]; then cp -r . /var/www/html/ && systemctl start nginx; fi
  ```
- **Constraint**: Use `version = ">= 5.0"` for the AWS provider to avoid lock-file conflicts.

**Modules Structure:**
- `./modules/vpc`: Pure networking.
- `./modules/ec2`: Receives `ami_id`, `user_data`, and `ssh_key_name`. No internal logic.
- `./modules/rds`: Simple DB instance.
- `./modules/alb`: Load balancer returning `dns_name`.
- `./modules/autoscaling`: Launch templates receiving the root's `user_data`.

---

## 5. Security & Stability Guardrails
1. **Output Safety**: Use `one(module.name[*].attribute)` in root `outputs.tf` to prevent "Invalid Index" errors when a tier is not active.
2. **Lifecycle Blocks**: Use `lifecycle { ignore_changes = [public_key] }` on the SSH key to prevent it being replaced during resource updates.
3. **Auto-Update**: Set `user_data_replace_on_change = true` on EC2 resources so that changing the GitHub URL in the UI forces a fresh deployment.

---

## 6. Deployment Wrapper (Docker)
**Dockerfile:**
- Base: `node:20-alpine`.
- Install `wget`, `unzip`, and `terraform` binary (v1.7.0).
- `COPY . .` after `npm install`.
- `CMD ["npm", "start"]`.
- **Docker Compose**: Mount the code directory if you want live-reloading during dev, but for production, rely on bake-in.

---

## 🏁 Replicate this and you will have a professional, production-ready universal cloud deployment platform.

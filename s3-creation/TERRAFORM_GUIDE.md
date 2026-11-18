# 🚀 Terraform & AWS Master Guide: Plain-English Edition

> **A beginner-friendly guide to everything we built, every error we encountered, and how we solved them.**

---

## 🗺️ The Big Picture: What We Built

We designed and built three core cloud projects using Terraform:
1. **A Serverless Static Website** hosted on an Amazon S3 Bucket.
2. **A Standalone EC2 Virtual Machine** with automated package installation.
3. **An End-to-End Enterprise VPC Network** with Public Subnet, Private Subnet, Internet Gateway, NAT Gateway, and a Dynamic EC2 Web Server.

```
+-----------------------------------------------------------------------------------+
| AWS CLOUD (Mumbai: ap-south-1)                                                    |
|                                                                                   |
|   +------------------------------------+   +----------------------------------+   |
|   | 1. S3 STATIC WEBSITE               |   | 2. CUSTOM VPC (10.0.0.0/16)      |   |
|   |    • index.html & error.html       |   |    • Internet Gateway (Front door) |   |
|   |    • Public Read Policy            |   |    • NAT Gateway (One-way bridge) |   |
|   |    • Website Endpoint URL          |   |    • Public Subnet (10.0.1.0/24)  |   |
|   +------------------------------------+   |    • Private Subnet (10.0.2.0/24) |   |
|                                            |    • Dynamic Ubuntu EC2 Instance  |   |
|                                            |      (Docker + Nginx + Git UI)    |   |
|                                            +----------------------------------+   |
+-----------------------------------------------------------------------------------+
```

---

## 🏛️ Chapter 1: The S3 Static Website

### 💡 The Layman Analogy
Think of an **S3 Bucket** like a **Google Drive folder**. By default, Google Drive folders are 100% private. To turn it into a website, you must:
1. Unlock the door to the public.
2. Tell AWS: *"If someone opens this folder URL, show them `index.html`."*

### ⚠️ Issues Faced & Fixes Given

| # | The Issue | Layman Explanation ("Why did it happen?") | The Solution ("What did we fix?") |
|---|---|---|---|
| **1** | **Missing Closing Brace `}`** | We had open curly braces `{` without matching closing braces `}`, breaking the code structure. | Added closing `}` after the bucket resource block. |
| **2** | **Duplicate Bucket Policy** | S3 buckets can only have **one** policy at a time. The file had two different policy blocks fighting each other. | Removed the duplicate and kept a single, clean `allow_public_read` policy. |
| **3** | **Placeholder `"path/to/file"`** | We copied documentation placeholder text that didn't point to any real file on the computer. | Pointed `source` to the real `${path.module}/practice/index.html`. |
| **4** | **Browser Auto-Downloading HTML** | Without specifying MIME type, AWS treats HTML as raw data files (`binary/octet-stream`). Browsers download it instead of rendering it. | Added `content_type = "text/html"`. |
| **5** | **Race Condition on Public Policy** | Terraform creates resources in parallel. It tried to apply the public policy *before* AWS finished disabling the public access block. | Added `depends_on = [aws_s3_bucket_public_access_block.example]`. |
| **6** | **IAM Error: `403 AccessDenied`** | The AWS credentials for user `s3-access` had no permissions in AWS to create buckets (`s3:CreateBucket`). | Logged into AWS IAM Console and attached the `AmazonS3FullAccess` policy. |

---

## 🖥️ Chapter 2: The Standalone EC2 Instance

### 💡 The Layman Analogy
An **EC2 Instance** is renting a computer in Amazon's Mumbai datacenter. 
* **AMI:** The pre-installed operating system (Windows, Ubuntu, Amazon Linux).
* **Instance Type:** The hardware specs (e.g., `t3.micro` = 2 vCPUs, 1GB RAM).
* **Security Group:** The security guard at the gate who checks who is allowed to visit (Firewall).

### ⚠️ Issues Faced & Fixes Given

| # | The Issue | Layman Explanation ("Why did it happen?") | The Solution ("What did we fix?") |
|---|---|---|---|
| **1** | **Provider Version Error: State Managed by Newer Provider** | The server was originally created using AWS Provider `v6.73.0`. Later, code was changed to `~> 5.0`. Terraform state refuses to let older provider versions touch state created by newer versions. | Changed `version = "6.73.0"` and ran `tf init -upgrade` to lock back onto the correct version. |
| **2** | **Duplicate `aws_instance` Error** | Having two `resource "aws_instance"` blocks in the same file caused Terraform to report duplicate resource definitions. | Removed the duplicate block and combined security groups and instance settings into one. |
| **3** | **SSH Port 2263 Trap** | Ubuntu servers only listen for terminal connections on **Port 22** by default. Setting the security group to port 2263 blocked all SSH access. | Changed the firewall port back to standard **Port 22**. |
| **4** | **No Outputs Found** | `output` blocks were added to `ec2.tf` after `apply` was already run. | Ran `tf apply` again to refresh state and print the IP address. |

---

## 🌐 Chapter 3: The Custom VPC Architecture

### 💡 The Layman Analogy: The City & Roads
* **VPC (`10.0.0.0/16`):** A private gated city.
* **Internet Gateway (IGW):** The main highway entrance connecting the city to the outside world.
* **Public Subnet (`10.0.1.0/24`):** The shopping mall / commercial district directly off the highway. Anyone with a car can drive in.
* **Private Subnet (`10.0.2.0/24`):** The residential district / bank vault. Outsiders cannot drive in directly.
* **NAT Gateway:** A guarded security courier. Private servers can send out orders to the internet for food/packages, but strangers on the internet cannot walk in.
* **Route Tables:** The road signs directing traffic (`0.0.0.0/0` ➔ go to highway or go to courier).

```
                  ┌────────────────────────┐
                  │    INTERNET (0.0.0.0/0)│
                  └───────────▲────────────┘
                              │
                  ┌───────────▼────────────┐
                  │ Internet Gateway (IGW) │  <-- FREE: Front door to internet
                  └───────────▲────────────┘
                              │
  ╔═══════════════════════════╪═══════════════════════════════════════════╗
  ║ CUSTOM VPC: 10.0.0.0/16   │                                           ║
  ║                           │                                           ║
  ║   ┌───────────────────────▼───────────────────────────────────────┐   ║
  ║   │ PUBLIC SUBNET (10.0.1.0/24)                                   │   ║
  ║   │  • Routes traffic to Internet Gateway                         │   ║
  ║   │  • Web Server (EC2) with Public IP lives here                 │   ║
  ║   │  • NAT Gateway + Elastic IP lives here                        │   ║
  ║   └───────────────────────┬───────────────────────────────────────┘   ║
  ║                           │ Outbound updates only                     ║
  ║                           ▼                                           ║
  ║   ┌───────────────────────────────────────────────────────────────┐   ║
  ║   │ PRIVATE SUBNET (10.0.2.0/24)                                  │   ║
  ║   │  • Routes traffic through NAT Gateway                         │   ║
  ║   │  • Databases / internal servers live here                     │   ║
  ║   │  • Inbound internet traffic is 100% BLOCKED                   │   ║
  ║   └───────────────────────────────────────────────────────────────┘   ║
  ╚═══════════════════════════════════════════════════════════════════════╝
```

> [!CAUTION]
> **NAT Gateway Billing Reminder:**
> AWS charges **~$0.045 per hour** (~$32/month) for a running NAT Gateway. Always run `tf destroy` when you are finished practicing!

---

## 🚀 Chapter 4: Dynamic EC2 & User Data Lifecycle

### 💡 What does "Zero Hardcoding" Mean?
Instead of copying fixed IDs that can expire or break in other regions:
* **Dynamic AMI:** `data "aws_ami" "ubuntu"` automatically looks up Canonical's newest Ubuntu 22.04 LTS release in Mumbai.
* **Dynamic Subnet:** `subnet_id = aws_subnet.public.id` attaches the instance directly to our custom subnet.
* **Dynamic Security Group:** `vpc_security_group_ids = [aws_security_group.ec2_web_sg.id]` connects our firewall directly.

---

### ⚠️ The User Data & Browser Traps

#### 1. Why `ERR_CONNECTION_TIMED_OUT` Happened
* **What you saw in Chrome:** `3.110.143.139 took too long to respond`.
* **Why it happened:**
  1. Modern Google Chrome automatically adds **`https://` (Port 443)** when you enter a raw IP address.
  2. Our security group only opened **Port 80 (`http://`)**.
  3. AWS firewall dropped port 443 packets silently, causing Chrome to time out after 30 seconds.
* **The Fix:** Explicitly type **`http://3.110.143.139`** in the address bar.

#### 2. Why the "Old UI" Stayed on Screen
* **What you saw in Chrome:**
  `Server Deployed in Custom VPC! Git, Docker, and Nginx are live.`
  *(Instead of the new Super Modern Glassmorphism Dashboard).*
* **Why it happened (The Golden AWS Rule):**
  > **`user_data` runs ONLY ONCE when an EC2 instance is born.**
  > **AWS NEVER re-runs `user_data` on an existing running server.**
* When you updated the script in `vpc.tf`, Terraform did not destroy the running server. The old server was still serving its old `index.html`.
* **The Fix:** Run Terraform's targeted replacement command:
  ```powershell
  tf apply -replace="aws_instance.web_server" -auto-approve
  ```
  * **What this command does:**
    * Destroys **ONLY** the EC2 instance (your VPC, Subnets, IGW, and NAT Gateway stay completely safe).
    * Launches a fresh new EC2 instance.
    * Executes the **new Super UI script** on its first boot.
    * Gives you a fresh public IP address.

---

## 📋 Essential Command Cheat Sheet

```powershell
# Quick PowerShell alias
Set-Alias tf terraform

# 1. Initialize and download provider plugins
tf init
tf init -upgrade

# 2. Preview planned changes without applying
tf plan

# 3. Apply infrastructure changes
tf apply
tf apply -auto-approve

# 4. Replace only a specific resource (e.g. to re-run user_data)
tf apply -replace="aws_instance.web_server" -auto-approve

# 5. View outputs anytime
tf output
tf output -raw website_url

# 6. Open website directly in default browser
Start-Process (tf output -raw website_url)

# 7. Destroy all resources to prevent AWS billing
tf destroy
```

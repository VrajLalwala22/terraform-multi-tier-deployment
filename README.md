# CloudTier Terraform Deployer

A fully automated, full-stack Next.js web application that provides a gorgeous Glassmorphic dashboard to deploy AWS infrastructure dynamically using Terraform.

## Features
- **Modern UI**: Dark-mode Glassmorphism built with Tailwind CSS.
- **Dynamic Infrastructure**: Configure 1-Tier, 2-Tier, or 3-Tier architectures seamlessly.
- **Background Execution**: A Node.js backend streams live `terraform init` and `apply` output back to your browser using Server-Sent Events.

## How to Run (No Node.js Required)

Since this project bundles both **Node.js** and **Terraform CLI**, you do not need to install them locally. You can securely launch the entire application using Docker!

### 1. Start the Application
Open your terminal in this repository's folder and run:
\`\`\`bash
docker compose up -d --build
\`\`\`
*(This will automatically download Terraform, install dependencies, build the Next.js app, and start the server).*

### 2. Access the Dashboard
Once the container is running, open your web browser and go to:
**http://localhost:3000**

### 3. Deploy Infrastructure
1. Enter your AWS Access Key, Secret Key, and preferred Region.
2. Select your infrastructure configurations (Tier, OS, Goal, and App URL).
3. Click "Launch" and watch the live deployment logs directly within the browser!

## Stopping the Application
To stop the web server, simply run:
\`\`\`bash
docker compose down
\`\`\`

# 📝 Azure Wiz Technical Exercise Task List

## 1. Initial Setup

- [ ] Sign up for an Azure account and activate free credits
- [ ] Set up billing alerts in Azure portal
- [ ] Install required tools:
    - [ ] Azure CLI
    - [ ] Docker Desktop
    - [ ] kubectl
    - [ ] Terraform
    - [ ] Git
- [ ] Verify installations of all tools


## 2. Azure CLI \& Resource Group

- [ ] Log in to Azure CLI (`az login`)
- [ ] Set default subscription
- [ ] Create a resource group (e.g., `wiz-exercise-rg`)


## 3. Networking

- [ ] Create a virtual network (`wiz-vnet`)
- [ ] Create a subnet for the database (`database-subnet`)
- [ ] Create a subnet for Kubernetes (`kubernetes-subnet`)


## 4. Virtual Machine with MongoDB

- [ ] Create a Network Security Group (NSG) for the VM
    - [ ] Add a rule to allow SSH from anywhere (0.0.0.0/0) (intentional weakness)
- [ ] Create an Ubuntu 20.04 VM in the database subnet
- [ ] Assign an overly permissive role (e.g., Contributor) to the VM (intentional weakness)
- [ ] Connect to the VM via SSH
- [ ] Install MongoDB 4.4 on the VM
- [ ] Configure MongoDB:
    - [ ] Enable authentication
    - [ ] Bind to local and Kubernetes subnet IPs
    - [ ] Create a database user with credentials
    - [ ] Restart MongoDB


## 5. Cloud Storage for Backups

- [ ] Create an Azure Storage Account
- [ ] Create a Blob container with public read/list access (intentional weakness)
- [ ] On the VM, install the Azure CLI
- [ ] Write a backup script to:
    - [ ] Dump MongoDB data
    - [ ] Compress the backup
    - [ ] Upload to Azure Blob Storage
    - [ ] Remove local backup files
- [ ] Schedule the backup script to run daily (e.g., via cron)


## 6. Azure Kubernetes Service (AKS)

- [ ] Create an AKS cluster in the Kubernetes subnet (private)
- [ ] Configure `kubectl` to access the cluster
- [ ] Create an Azure Container Registry (ACR)
- [ ] Connect ACR to AKS


## 7. Application Containerization \& Deployment

- [ ] Prepare a sample Node.js (or other) Todo app that connects to MongoDB
- [ ] Add a file called `wizexercise.txt` with your name to the project
- [ ] Write a Dockerfile that copies `wizexercise.txt` into the image
- [ ] Build the Docker image locally
- [ ] Tag and push the image to ACR


## 8. Kubernetes Resources

- [ ] Create a Kubernetes ServiceAccount with cluster-admin privileges (intentional weakness)
- [ ] Create a Kubernetes Deployment for the app:
    - [ ] Use the image from ACR
    - [ ] Set the `MONGODB_URI` environment variable
    - [ ] Use the privileged ServiceAccount
- [ ] Create a Kubernetes Service (ClusterIP) for the app
- [ ] Install NGINX Ingress Controller on AKS
- [ ] Create a Kubernetes Ingress resource to expose the app via a public load balancer


## 9. DevOps (Bonus/If Required)

- [ ] Create a Git repository for all code and configuration
- [ ] Set up Azure DevOps project and pipelines:
    - [ ] Pipeline for Infrastructure as Code (IaC) deployment (Terraform)
    - [ ] Pipeline for building, pushing, and deploying the app
- [ ] Implement security controls in your repository and pipelines
    - [ ] Enable code scanning for IaC and containers


## 10. Cloud Native Security Controls

- [ ] Enable Azure Security Center
- [ ] Enable control plane audit logging
- [ ] Implement at least one preventative policy (e.g., block public blob creation)
- [ ] Implement at least one detective control (e.g., alert on SSH access)
- [ ] Demonstrate detection of misconfigurations in Security Center


## 11. Testing \& Validation

- [ ] Use `kubectl` to verify pods, services, and ingress are running
- [ ] Access the web app via the ingress public IP
- [ ] Create/read/update/delete data in the app and verify in MongoDB
- [ ] Check that `wizexercise.txt` exists in the running container
- [ ] Confirm backups appear in Azure Blob Storage and are publicly accessible


## 12. Presentation Preparation

- [ ] Create an architecture diagram
- [ ] Prepare slides covering:
    - [ ] Approach and methodology
    - [ ] Challenges and solutions
    - [ ] Security weaknesses and their risks
    - [ ] Security tool findings
- [ ] Prepare for a live walkthrough:
    - [ ] Show Azure Portal resources
    - [ ] Demonstrate `kubectl` usage
    - [ ] Show the web app and database
    - [ ] Display security findings
# Complete Azure Implementation Plan for Wiz Technical Exercise

This detailed implementation plan will guide you through building the complete two-tier web application environment using Microsoft Azure services, customized specifically for the Azure platform.

## Phase 1: Setting Up Your Azure Environment

### Step 1: Create Azure Account and Initial Setup

1. **Sign up for Azure Account**
    - Visit portal.azure.com and create a free account[^3_6]
    - New accounts receive \$200 in free credits for the first 30 days
    - Set up billing alerts to monitor usage and avoid unexpected charges
2. **Install Required Tools**
    - **Azure CLI**: Download from Microsoft's official documentation for your operating system[^3_2]
    - **Docker Desktop**: Install from docker.com for container management
    - **kubectl**: Required for Kubernetes cluster management[^3_2]
    - **Terraform**: Download from terraform.io for Infrastructure as Code
    - **Git**: Install from git-scm.com for version control
3. **Verify Tool Installation**

```bash
az --version
docker --version
kubectl version --client
terraform --version
git --version
```


### Step 2: Configure Azure CLI and Authentication

1. **Login to Azure**

```bash
az login
```

2. **Set Default Subscription**

```bash
az account set --subscription "your-subscription-id"
```

3. **Create Resource Group**

```bash
az group create --name wiz-exercise-rg --location eastus2
```


## Phase 2: Building the Database Layer (Virtual Machine with MongoDB)

### Step 3: Create Virtual Machine with Security Weaknesses

1. **Create Virtual Network and Subnet**

```bash
az network vnet create \
  --resource-group wiz-exercise-rg \
  --name wiz-vnet \
  --address-prefix 10.0.0.0/16 \
  --subnet-name database-subnet \
  --subnet-prefix 10.0.1.0/24
```

2. **Create Network Security Group with Overly Permissive SSH Access**[^3_15][^3_16]

```bash
# Create NSG
az network nsg create \
  --resource-group wiz-exercise-rg \
  --name mongodb-nsg

# Allow SSH from anywhere (security weakness as required)
az network nsg rule create \
  --resource-group wiz-exercise-rg \
  --nsg-name mongodb-nsg \
  --name allow-ssh-from-anywhere \
  --protocol tcp \
  --priority 1000 \
  --destination-port-range 22 \
  --source-address-prefixes 0.0.0.0/0 \
  --access allow
```

3. **Create Virtual Machine with Ubuntu 20.04 (1+ year old as required)**[^3_9][^3_10]

```bash
az vm create \
  --resource-group wiz-exercise-rg \
  --name mongodb-vm \
  --image Canonical:0001-com-ubuntu-server-focal:20_04-lts-gen2:latest \
  --admin-username azureuser \
  --generate-ssh-keys \
  --size Standard_B2s \
  --vnet-name wiz-vnet \
  --subnet database-subnet \
  --nsg mongodb-nsg \
  --public-ip-sku Standard
```

4. **Assign Overly Permissive Role to VM (Security Weakness)**[^3_19]

```bash
# Get VM's managed identity
az vm identity assign --name mongodb-vm --resource-group wiz-exercise-rg

# Assign Contributor role (overly permissive as required)
az role assignment create \
  --assignee $(az vm identity show --name mongodb-vm --resource-group wiz-exercise-rg --query principalId -o tsv) \
  --role Contributor \
  --scope /subscriptions/$(az account show --query id -o tsv)
```


### Step 4: Install and Configure MongoDB

1. **Connect to VM via SSH**

```bash
# Get VM public IP
VM_IP=$(az vm show --resource-group wiz-exercise-rg --name mongodb-vm --show-details --query publicIps -o tsv)
ssh azureuser@$VM_IP
```

2. **Install MongoDB 4.4 (1+ year old version as required)**[^3_10]

```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Install prerequisites
sudo apt install -y gnupg curl

# Add MongoDB GPG key
curl -fsSL https://www.mongodb.org/static/pgp/server-4.4.asc | sudo gpg -o /usr/share/keyrings/mongodb-server-4.4.gpg --dearmor

# Add MongoDB repository
echo "deb [ arch=amd64,arm64 signed-by=/usr/share/keyrings/mongodb-server-4.4.gpg ] https://repo.mongodb.org/apt/ubuntu focal/mongodb-org/4.4 multiverse" | sudo tee /etc/apt/sources.list.d/mongodb-org-4.4.list

# Install MongoDB 4.4
sudo apt update
sudo apt install -y mongodb-org=4.4.* mongodb-org-server=4.4.*

# Start and enable MongoDB
sudo systemctl start mongod
sudo systemctl enable mongod
```

3. **Configure MongoDB Security and Authentication**[^3_10]

```bash
# Edit MongoDB configuration
sudo nano /etc/mongod.conf
```

Add these lines to enable authentication:

```yaml
security:
  authorization: enabled
net:
  bindIp: 127.0.0.1,10.0.1.4  # Allow connections from Kubernetes subnet
```

4. **Create Database User**

```bash
# Connect to MongoDB
mongosh

# Create admin user
use admin
db.createUser({
  user: "dbuser",
  pwd: "SecurePassword123!",
  roles: ["readWriteAnyDatabase"]
})
exit

# Restart MongoDB
sudo systemctl restart mongod
```


## Phase 3: Setting Up Cloud Storage with Security Weakness

### Step 5: Create Storage Account with Public Access

1. **Create Storage Account**[^3_6]

```bash
az storage account create \
  --resource-group wiz-exercise-rg \
  --name wizexercisestorage$(date +%s) \
  --location eastus2 \
  --sku Standard_LRS \
  --allow-blob-public-access true
```

2. **Create Container with Public Read Access (Security Weakness)**[^3_18]

```bash
# Get storage account key
STORAGE_KEY=$(az storage account keys list --resource-group wiz-exercise-rg --account-name wizexercisestorage$(date +%s) --query '[^3_0].value' -o tsv)

# Create container with public read access
az storage container create \
  --name mongodb-backups \
  --account-name wizexercisestorage$(date +%s) \
  --account-key $STORAGE_KEY \
  --public-access blob
```


### Step 6: Set Up Automated Database Backups

1. **Create Backup Script on VM**

```bash
sudo nano /opt/backup-mongodb.sh
```

2. **Add Backup Script Content**

```bash
#!/bin/bash
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="/tmp/mongodb_backup_$DATE"

# Create backup
mongodump --host 127.0.0.1 --port 27017 --username dbuser --password SecurePassword123! --out $BACKUP_DIR

# Compress backup
tar -czf /tmp/mongodb_backup_$DATE.tar.gz -C /tmp mongodb_backup_$DATE

# Upload to Azure Blob Storage
az storage blob upload \
  --file /tmp/mongodb_backup_$DATE.tar.gz \
  --name mongodb_backup_$DATE.tar.gz \
  --container-name mongodb-backups \
  --account-name YOUR_STORAGE_ACCOUNT_NAME

# Cleanup local files
rm -rf $BACKUP_DIR /tmp/mongodb_backup_$DATE.tar.gz
```

3. **Make Script Executable and Schedule**

```bash
sudo chmod +x /opt/backup-mongodb.sh

# Add to crontab for daily execution at 2 AM
echo "0 2 * * * /opt/backup-mongodb.sh" | sudo crontab -
```


## Phase 4: Creating Kubernetes Infrastructure

### Step 7: Set Up Azure Kubernetes Service (AKS)

1. **Create Private Subnet for AKS**[^3_20]

```bash
az network vnet subnet create \
  --resource-group wiz-exercise-rg \
  --vnet-name wiz-vnet \
  --name kubernetes-subnet \
  --address-prefixes 10.0.2.0/24 \
  --disable-private-endpoint-network-policies false
```

2. **Create AKS Cluster in Private Subnet**[^3_2][^3_3]

```bash
az aks create \
  --resource-group wiz-exercise-rg \
  --name wiz-aks-cluster \
  --node-count 2 \
  --node-vm-size Standard_D2s_v3 \
  --network-plugin azure \
  --vnet-subnet-id /subscriptions/$(az account show --query id -o tsv)/resourceGroups/wiz-exercise-rg/providers/Microsoft.Network/virtualNetworks/wiz-vnet/subnets/kubernetes-subnet \
  --docker-bridge-address 172.17.0.1/16 \
  --dns-service-ip 10.0.3.10 \
  --service-cidr 10.0.3.0/24 \
  --generate-ssh-keys \
  --attach-acr wizexerciseacr
```

3. **Configure kubectl Access**[^3_2]

```bash
az aks get-credentials --resource-group wiz-exercise-rg --name wiz-aks-cluster
kubectl get nodes
```


## Phase 5: Container Registry and Application Deployment

### Step 8: Create Azure Container Registry

1. **Create ACR Instance**[^3_6]

```bash
az acr create \
  --resource-group wiz-exercise-rg \
  --name wizexerciseacr \
  --sku Standard \
  --admin-enabled true
```

2. **Login to ACR**[^3_6]

```bash
az acr login --name wizexerciseacr
```


### Step 9: Build and Push Container Image

1. **Create Sample Todo Application Directory**

```bash
mkdir todo-app && cd todo-app
```

2. **Create Dockerfile**

```dockerfile
FROM node:14-alpine
WORKDIR /app
COPY package*.json ./
RUN npm install
COPY . .
RUN echo "Your Name Here" > wizexercise.txt
EXPOSE 3000
CMD ["npm", "start"]
```

3. **Create Sample Package.json**

```json
{
  "name": "todo-app",
  "version": "1.0.0",
  "main": "server.js",
  "dependencies": {
    "express": "^4.18.0",
    "mongodb": "^4.10.0"
  },
  "scripts": {
    "start": "node server.js"
  }
}
```

4. **Create Sample Application (server.js)**

```javascript
const express = require('express');
const { MongoClient } = require('mongodb');
const app = express();
const port = 3000;

app.use(express.json());

const mongoUri = process.env.MONGODB_URI || 'mongodb://dbuser:SecurePassword123!@10.0.1.4:27017/todoapp';

app.get('/', (req, res) => {
    res.send('Todo App is running!');
});

app.get('/health', (req, res) => {
    res.json({ status: 'healthy', timestamp: new Date() });
});

app.listen(port, () => {
    console.log(`Todo app listening at http://localhost:${port}`);
});
```

5. **Build and Push Image**

```bash
# Build image
docker build -t wizexerciseacr.azurecr.io/todo-app:latest .

# Push to ACR
docker push wizexerciseacr.azurecr.io/todo-app:latest
```


## Phase 6: Kubernetes Deployment with Security Weaknesses

### Step 10: Create Kubernetes Resources with Admin Privileges

1. **Create Service Account with Admin Role (Security Weakness)**

```yaml
# admin-service-account.yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: admin-user
  namespace: default
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: admin-user-binding
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
- kind: ServiceAccount
  name: admin-user
  namespace: default
```

2. **Create Application Deployment**

```yaml
# todo-app-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: todo-app
  labels:
    app: todo-app
spec:
  replicas: 2
  selector:
    matchLabels:
      app: todo-app
  template:
    metadata:
      labels:
        app: todo-app
    spec:
      serviceAccountName: admin-user
      containers:
      - name: todo-app
        image: wizexerciseacr.azurecr.io/todo-app:latest
        ports:
        - containerPort: 3000
        env:
        - name: MONGODB_URI
          value: "mongodb://dbuser:SecurePassword123!@10.0.1.4:27017/todoapp"
```

3. **Create Service**

```yaml
# todo-app-service.yaml
apiVersion: v1
kind: Service
metadata:
  name: todo-app-service
spec:
  selector:
    app: todo-app
  ports:
  - port: 80
    targetPort: 3000
  type: ClusterIP
```

4. **Deploy Resources**

```bash
kubectl apply -f admin-service-account.yaml
kubectl apply -f todo-app-deployment.yaml
kubectl apply -f todo-app-service.yaml
```


## Phase 7: Load Balancer and Ingress Configuration

### Step 11: Set Up Azure Load Balancer and Ingress

1. **Install NGINX Ingress Controller**[^3_23]

```bash
# Add ingress-nginx repository
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update

# Install ingress controller
helm install nginx-ingress ingress-nginx/ingress-nginx \
  --set controller.replicaCount=2 \
  --set controller.nodeSelector."kubernetes\.io/os"=linux \
  --set defaultBackend.nodeSelector."kubernetes\.io/os"=linux
```

2. **Create Ingress Resource**[^3_22]

```yaml
# todo-app-ingress.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: todo-app-ingress
  annotations:
    kubernetes.io/ingress.class: nginx
    nginx.ingress.kubernetes.io/rewrite-target: /
spec:
  rules:
  - http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: todo-app-service
            port:
              number: 80
```

3. **Apply Ingress Configuration**

```bash
kubectl apply -f todo-app-ingress.yaml

# Get external IP
kubectl get services -o wide
```


## Phase 8: CI/CD Implementation with Azure DevOps

### Step 12: Set Up Azure DevOps Project

1. **Create Azure DevOps Organization**[^3_11]
    - Navigate to dev.azure.com
    - Sign in with your Azure account
    - Create new organization: "wiz-exercise-org"
2. **Create New Project**[^3_11]
    - Click "New project"
    - Name: "wiz-technical-exercise"
    - Visibility: Private
    - Version control: Git

### Step 13: Create CI/CD Pipelines

1. **Create Infrastructure Pipeline (azure-pipelines-infra.yml)**[^3_24][^3_27]

```yaml
trigger:
  branches:
    include:
    - main
  paths:
    include:
    - terraform/*

pool:
  vmImage: 'ubuntu-latest'

variables:
  terraformVersion: '1.0.0'

stages:
- stage: Plan
  jobs:
  - job: TerraformPlan
    steps:
    - task: TerraformInstaller@0
      inputs:
        terraformVersion: $(terraformVersion)
    - task: TerraformTaskV2@2
      inputs:
        provider: 'azurerm'
        command: 'init'
        workingDirectory: 'terraform'
    - task: TerraformTaskV2@2
      inputs:
        provider: 'azurerm'
        command: 'plan'
        workingDirectory: 'terraform'

- stage: Apply
  condition: and(succeeded(), eq(variables['Build.SourceBranch'], 'refs/heads/main'))
  jobs:
  - job: TerraformApply
    steps:
    - task: TerraformInstaller@0
      inputs:
        terraformVersion: $(terraformVersion)
    - task: TerraformTaskV2@2
      inputs:
        provider: 'azurerm'
        command: 'apply'
        workingDirectory: 'terraform'
```

2. **Create Application Pipeline (azure-pipelines-app.yml)**[^3_24][^3_27]

```yaml
trigger:
  branches:
    include:
    - main
  paths:
    include:
    - src/*

pool:
  vmImage: 'ubuntu-latest'

variables:
  containerRegistry: 'wizexerciseacr.azurecr.io'
  imageName: 'todo-app'
  imageTag: '$(Build.BuildId)'

stages:
- stage: Build
  jobs:
  - job: BuildAndPush
    steps:
    - task: Docker@2
      inputs:
        command: 'build'
        dockerfile: 'src/Dockerfile'
        repository: '$(imageName)'
        tags: '$(imageTag)'
    - task: Docker@2
      inputs:
        command: 'push'
        containerRegistry: '$(containerRegistry)'
        repository: '$(imageName)'
        tags: '$(imageTag)'

- stage: Deploy
  jobs:
  - job: DeployToAKS
    steps:
    - task: KubernetesManifest@0
      inputs:
        action: 'deploy'
        kubernetesServiceConnection: 'aks-connection'
        manifests: 'k8s/*.yaml'
        containers: '$(containerRegistry)/$(imageName):$(imageTag)'
```


## Phase 9: Security Controls Implementation

### Step 14: Configure Azure Security Center and Monitoring

1. **Enable Azure Security Center**[^3_25]

```bash
# Enable Security Center on subscription
az security auto-provisioning-setting update \
  --name default \
  --auto-provision on
```

2. **Configure Audit Logging**[^3_26]

```bash
# Create Log Analytics Workspace
az monitor log-analytics workspace create \
  --resource-group wiz-exercise-rg \
  --workspace-name wiz-log-analytics

# Enable activity log
az monitor diagnostic-settings create \
  --name audit-logs \
  --resource /subscriptions/$(az account show --query id -o tsv) \
  --workspace wiz-log-analytics \
  --logs '[{"category": "Administrative", "enabled": true}]'
```

3. **Implement Preventative Control (Policy)**

```bash
# Create policy to prevent public blob access
az policy assignment create \
  --name prevent-public-blob-access \
  --policy "Secure transfer to storage accounts should be enabled" \
  --scope /subscriptions/$(az account show --query id -o tsv)
```

4. **Implement Detective Control (Alert)**

```bash
# Create alert for SSH access attempts
az monitor metrics alert create \
  --name ssh-access-alert \
  --resource-group wiz-exercise-rg \
  --scopes /subscriptions/$(az account show --query id -o tsv)/resourceGroups/wiz-exercise-rg/providers/Microsoft.Compute/virtualMachines/mongodb-vm \
  --condition "count NetworkIn > 100" \
  --description "Alert on high network activity"
```


## Phase 10: Testing and Validation

### Step 15: Verify Complete Deployment

1. **Test Database Connectivity**

```bash
# Connect to a pod and test MongoDB connection
kubectl exec -it deployment/todo-app -- curl localhost:3000/health
```

2. **Verify wizexercise.txt File**

```bash
kubectl exec -it deployment/todo-app -- cat wizexercise.txt
```

3. **Test Web Application**

```bash
# Get ingress external IP
EXTERNAL_IP=$(kubectl get ingress todo-app-ingress -o jsonpath='{.status.loadBalancer.ingress[^3_0].ip}')
curl http://$EXTERNAL_IP
```

4. **Verify Backup Accessibility**

```bash
# List blobs in storage container (should be publicly accessible)
az storage blob list \
  --container-name mongodb-backups \
  --account-name YOUR_STORAGE_ACCOUNT_NAME \
  --output table
```


## Phase 11: Preparation for Presentation

### Step 16: Documentation and Demo Preparation

1. **Create Architecture Diagram**
    - Document the complete infrastructure setup
    - Highlight security weaknesses implemented
    - Show data flow between components
2. **Prepare Live Demonstrations**
    - kubectl commands to show running pods
    - Web application functionality
    - Database connectivity tests
    - Security findings in Azure Security Center
3. **Security Weakness Summary**
    - VM with overly permissive IAM roles
    - SSH access from anywhere (0.0.0.0/0)
    - Public blob storage access
    - Kubernetes admin privileges for application pods
    - Outdated software versions (Ubuntu 20.04, MongoDB 4.4)

## Key Azure-Specific Considerations

### Cost Optimization

- Use Azure Cost Management to monitor spending[^3_6]
- Implement auto-shutdown for VMs during non-working hours
- Choose appropriate VM sizes for workload requirements


### Networking

- Azure Virtual Networks provide isolation between resources[^3_15]
- Network Security Groups act as virtual firewalls[^3_15]
- Private subnets enhance security for Kubernetes clusters[^3_20]


### Monitoring and Compliance

- Azure Monitor integrates with all Azure services[^3_26]
- Azure Security Center provides unified security management[^3_25]
- Azure Policy ensures compliance with organizational standards[^3_25]

This comprehensive Azure implementation plan provides all the necessary steps to complete the Wiz Technical Exercise while incorporating the required security weaknesses and demonstrating modern cloud architecture patterns using Azure-native services.

<div style="text-align: center">⁂</div>

[^3_1]: Wiz-Tech-Exercise-v4.pdf

[^3_2]: https://learn.microsoft.com/en-us/azure/aks/tutorial-kubernetes-deploy-cluster

[^3_3]: https://learn.microsoft.com/en-us/azure/aks/learn/quick-kubernetes-deploy-portal

[^3_4]: https://k21academy.com/microsoft-azure/architect/aks-cluster/

[^3_5]: https://www.pluralsight.com/labs/azure/deploy-mongodb-on-microsoft-azure

[^3_6]: https://learn.microsoft.com/en-us/azure/container-registry/container-registry-get-started-portal

[^3_7]: https://learn.microsoft.com/en-us/answers/questions/2075421/how-to-enable-public-access-for-allowed-domains-fo

[^3_8]: https://spot.io/resources/ci-cd/azure-ci-cd/

[^3_9]: https://www.youtube.com/watch?v=oGqDMHPmI38

[^3_10]: https://www.fosstechnix.com/how-to-install-mongodb-on-ubuntu-20-04/

[^3_11]: https://www.scholarhat.com/tutorial/devops/building-ci-cd-pipeline-with-the-azure-devops

[^3_12]: https://learn.microsoft.com/en-us/azure/load-balancer/manage

[^3_13]: https://learn.microsoft.com/en-us/azure/virtual-machines/windows/connect-ssh

[^3_14]: https://articentgroup.com/guidance-on-usage-mongodb-server-on-ubuntu-20-04/

[^3_15]: https://learn.microsoft.com/en-us/azure/virtual-network/network-security-groups-overview

[^3_16]: https://trendmicro.com/cloudoneconformity/knowledge-base/azure/Network/unrestricted-ssh-access.html

[^3_17]: https://learn.microsoft.com/en-us/answers/questions/1168404/how-to-fix-add-an-inbound-network-security-group-r

[^3_18]: https://support.icompaas.com/support/solutions/articles/62000219786-ensure-that-public-access-level-is-disabled-for-storage-accounts-with-blob-containers-automated-

[^3_19]: https://learn.microsoft.com/en-us/azure/role-based-access-control/role-assignments-steps

[^3_20]: https://skylinetechnology.org/azure/what-is-a-private-subnet-in-azure/

[^3_21]: https://github.com/alfonsof/terraform-azure-examples

[^3_22]: https://learn.microsoft.com/en-us/azure/container-apps/ingress-how-to

[^3_23]: https://learn.microsoft.com/en-us/troubleshoot/azure/azure-kubernetes/load-bal-ingress-c/create-unmanaged-ingress-controller

[^3_24]: https://faun.pub/azure-devops-build-release-with-yaml-templates-d55f25a4928c

[^3_25]: https://www.linkedin.com/pulse/understanding-microsoft-cloud-security-posture-cspm-enhanced-bairagi-qoyef

[^3_26]: https://docs.azure.cn/en-us/mysql/flexible-server/tutorial-configure-audit

[^3_27]: https://www.azuredevopslabs.com/labs/azuredevops/yaml/

[^3_28]: https://learn.microsoft.com/en-us/azure/aks/

[^3_29]: https://www.youtube.com/watch?v=ba0reoJLIdA

[^3_30]: https://tutorialsdojo.com/azure-kubernetes-service-aks/

[^3_31]: https://cloudinfrastructureservices.co.uk/how-to-setup-mongodb-community-server-on-azure-aws/

[^3_32]: https://azuremarketplace.microsoft.com/en-us/marketplace/apps/supportedimagesllc1615494954880.mongodb-ubuntu-20?tab=Overview

[^3_33]: https://www.mongodb.com/docs/manual/tutorial/install-mongodb-on-ubuntu/

[^3_34]: https://docs.prismacloud.io/en/enterprise-edition/policy-reference/azure-policies/azure-networking-policies/bc-azr-networking-3

[^3_35]: https://learn.microsoft.com/en-us/azure/virtual-network/tutorial-filter-network-traffic

[^3_36]: https://docs.datadoghq.com/security/default_rules/azure-security-group-security-group-should-restrict-ssh-access-from-the-internet/

[^3_37]: https://learn.microsoft.com/en-us/azure/container-apps/ingress-overview

[^3_38]: https://www.youtube.com/watch?v=UlUI2ke0Bmw

[^3_39]: https://spacelift.io/blog/kubernetes-ingress

[^3_40]: https://learn.microsoft.com/en-us/answers/questions/2069512/azure-container-app-environment-with-built-in-ingr


---

# convert the azure implementation plan in to a markdown based task list

Certainly! Here is your **Azure implementation plan** for the Wiz Technical Exercise, formatted as a markdown-based task list. Each task is broken down into actionable steps. You can copy this list directly into your favorite markdown editor or task manager.

---

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

---

**Tip:** Check off each task as you complete it. This list covers all major requirements and Azure-specific steps for the Wiz Technical Exercise. Good luck! 🚀

<div style="text-align: center">⁂</div>

[^4_1]: Wiz-Tech-Exercise-v4.pdf


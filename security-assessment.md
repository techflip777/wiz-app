# Security Assessment Report

## Overview of Implemented Vulnerabilities

### Virtual Machine with MongoDB Server
| Vulnerability | Implemented | Details |
|--------------|------------|---------|
| [Public Readable Cloud Storage](#public-storage) | ✅ | Backup storage is publicly accessible |
| [Outdated Linux Version](#linux-version) | ✅ | Using Ubuntu 20.04 LTS (released 2020) |
| [SSH Public Exposure](#ssh-exposure) | ✅ | SSH exposed to 0.0.0.0/0 |
| [Overly Permissive VM Permissions](#vm-permissions) | ✅ | VM has Owner role on subscription |
| [Outdated Database Version](#db-version) | ✅ | MongoDB 4.4 (outdated) |
| [Database Network Access](#db-access) | ✅ | Restricted to Kubernetes subnet with authentication |
| [Daily Database Backups](#db-backups) | ✅ | Configured via cron at 2 AM UTC |
| [Public Storage Listing](#storage-listing) | ✅ | Container access type set to "blob" |

### Web Application on Kubernetes
| Requirement | Implemented | Details |
|------------|------------|---------|
| [Containerized Application](#container-app) | ✅ | Todo list application using MongoDB |
| [Private Subnet Deployment](#private-subnet) | ✅ | AKS deployed in private subnet (10.0.2.0/24) |
| [MongoDB Environment Variables](#mongodb-env) | ✅ | Configured via Kubernetes secrets |
| [wizexercise.txt File](#wiz-file) | ✅ | File present in container with name |
| [Kubernetes Admin Role](#k8s-admin) | ✅ | Application has cluster-admin role |
| [Ingress & Load Balancer](#ingress-lb) | ✅ | Exposed via Azure Load Balancer |
| [kubectl CLI Access](#kubectl) | ✅ | Available for demonstration |
| [Web App & DB Integration](#web-db) | ✅ | Application connected to MongoDB |

## Detailed Findings

### Virtual Machine with MongoDB Server

#### <a name="public-storage"></a>Public Readable Cloud Storage
- ✅ **Implemented**: Yes
- **Details**: Backup storage account is configured with public access
- **Evidence**: 
  ```terraform
  public_network_access_enabled = true
  allow_nested_items_to_be_public = true
  ```

#### <a name="linux-version"></a>Outdated Linux Version
- ✅ **Implemented**: Yes
- **Details**: Using Ubuntu 20.04 LTS (Focal Fossa) released in April 2020
- **Evidence**:
  ```terraform
  offer     = "0001-com-ubuntu-server-focal"
  sku       = "20_04-lts-gen2"
  ```

#### <a name="ssh-exposure"></a>SSH Public Exposure
- ✅ **Implemented**: Yes
- **Details**: SSH port 22 exposed to all IPs
- **Evidence**:
  ```terraform
  source_address_prefix      = "0.0.0.0/0"
  destination_port_range     = "22"
  ```

#### <a name="vm-permissions"></a>Overly Permissive VM Permissions
- ✅ **Implemented**: Yes
- **Details**: VM has Owner role on subscription
- **Evidence**:
  ```terraform
  role_definition_name = "Owner"
  scope                = "/subscriptions/${data.azurerm_client_config.current.subscription_id}"
  ```

#### <a name="db-version"></a>Outdated Database Version
- ✅ **Implemented**: Yes
- **Details**: MongoDB 4.4 (released in 2020)
- **Evidence**:
  ```terraform
  "curl -fsSL https://pgp.mongodb.com/server-4.4.asc"
  ```

#### <a name="db-access"></a>Database Network Access
- ✅ **Implemented**: Yes
- **Details**: MongoDB access is properly restricted:
  - Network access limited to Kubernetes subnet (10.0.1.4)
  - Authentication enabled with required credentials
  - Default credentials set for initial access
- **Evidence**:
  ```terraform
  # Network restriction
  bindIp: 127.0.0.1,10.0.1.4  # Allow connections from Kubernetes subnet
  
  # Authentication enabled
  security:
    authorization: enabled
  ```

#### <a name="db-backups"></a>Daily Database Backups
- ✅ **Implemented**: Yes
- **Details**: Automated daily backups at 2 AM UTC
- **Evidence**:
  ```terraform
  "0 2 * * * /home/azureuser/scripts/mongodb_backup.sh"
  ```

#### <a name="storage-listing"></a>Public Storage Listing
- ✅ **Implemented**: Yes
- **Details**: Container configured for public blob access
- **Evidence**:
  ```terraform
  container_access_type = "blob"  # Public read access for blobs
  ```

### Web Application on Kubernetes

#### <a name="container-app"></a>Containerized Application
- ✅ **Implemented**: Yes
- **Details**: Todo list application containerized and using MongoDB
- **Evidence**:
  ```yaml
  apiVersion: apps/v1
  kind: Deployment
  metadata:
    name: todo-app
  spec:
    template:
      spec:
        containers:
        - name: todo-app
          image: ${ACR_NAME}.azurecr.io/todo-app:latest
  ```

#### <a name="private-subnet"></a>Private Subnet Deployment
- ✅ **Implemented**: Yes
- **Details**: AKS cluster deployed in private subnet
- **Evidence**:
  ```terraform
  subnet_id = azurerm_subnet.kubernetes.id  # 10.0.2.0/24
  ```

#### <a name="mongodb-env"></a>MongoDB Environment Variables
- ✅ **Implemented**: Yes
- **Details**: MongoDB connection configured via Kubernetes secrets
- **Evidence**:
  ```yaml
  env:
  - name: MONGODB_URI
    valueFrom:
      secretKeyRef:
        name: mongodb-secret
        key: uri
  ```

#### <a name="wiz-file"></a>wizexercise.txt File
- ✅ **Implemented**: Yes
- **Details**: File present in container with name "Dhiwakar Kusuma"
- **Implementation Steps**:
  1. Created wizexercise.txt file in project root:
     ```bash
     echo "Dhiwakar Kusuma" > wizexercise.txt
     ```
  2. Modified Dockerfile to include the file:
     ```dockerfile
     # In the release stage
     COPY wizexercise.txt .
     ```
  3. Built and pushed the container image:
     ```bash
     # Build the image
     docker build -t todo-app .

     # Tag for ACR
     docker tag todo-app wizacr.azurecr.io/todo-app:latest

     # Push to ACR
     docker push wizacr.azurecr.io/todo-app:latest
     ```
- **Validation Commands**:
  ```bash
  # Get the pod name
  kubectl get pods -n wiz-app

  # Verify file exists in the container
  kubectl exec -n wiz-app <pod-name> -- ls -l /app/wizexercise.txt

  # Check file contents
  kubectl exec -n wiz-app <pod-name> -- cat /app/wizexercise.txt

  # Alternative: Copy file from container to local machine
  kubectl cp wiz-app/<pod-name>:/app/wizexercise.txt ./wizexercise.txt
  cat wizexercise.txt
  ```

#### <a name="k8s-admin"></a>Kubernetes Admin Role
- ✅ **Implemented**: Yes
- **Details**: Application has cluster-admin role
- **Evidence**:
  ```yaml
  apiVersion: rbac.authorization.k8s.io/v1
  kind: ClusterRoleBinding
  metadata:
    name: todo-app-admin
  roleRef:
    kind: ClusterRole
    name: cluster-admin
  ```

#### <a name="ingress-lb"></a>Ingress & Load Balancer
- ✅ **Implemented**: Yes
- **Details**: Application exposed via Azure Load Balancer
- **Evidence**:
  ```yaml
  apiVersion: v1
  kind: Service
  metadata:
    name: todo-app
    annotations:
      service.beta.kubernetes.io/azure-load-balancer-internal: "false"
  spec:
    type: LoadBalancer
  ```

#### <a name="kubectl"></a>kubectl CLI Access
- ✅ **Implemented**: Yes
- **Details**: kubectl configured and available with demonstration commands
- **Evidence**:
  ```bash

  # Verify cluster access and node status
  kubectl get nodes
  kubectl get nodes -o wide  # Shows IP addresses and other details

  # Check namespace and resources
  kubectl get all -n wiz-app
  kubectl get pods -n wiz-app -o wide  # Shows pod details and node assignment

  # Verify application deployment
  kubectl get deployment todo-app -n wiz-app
  kubectl describe deployment todo-app -n wiz-app

  # Check service and ingress configuration
  kubectl get service todo-app -n wiz-app
  kubectl get ingress -n wiz-app

  # Verify MongoDB connection secret
  kubectl get secret mongodb-connection -n wiz-app
  kubectl describe secret mongodb-connection -n wiz-app

  # Check application logs
  kubectl logs -l app=todo-app -n wiz-app
  kubectl logs -l app=todo-app -n wiz-app --tail=50  # Last 50 lines

  # Verify RBAC configuration
  kubectl get clusterrolebinding todo-app-admin
  kubectl describe clusterrolebinding todo-app-admin
  ```

#### <a name="web-db"></a>Web App & DB Integration
- ✅ **Implemented**: Yes
- **Details**: Application successfully connected to MongoDB
- **Evidence**:
  ```yaml
  # Application logs showing successful DB connection
  "Connected to MongoDB successfully"
  ```

## Notes
- All vulnerabilities marked as implemented are intentionally configured for security testing purposes
- The configuration includes multiple security risks that would be unacceptable in a production environment
- Database access is properly secured with network restrictions and authentication
- Kubernetes application has intentionally elevated privileges for demonstration purposes 
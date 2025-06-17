# Wiz Application Deployment Architecture

This document outlines the high-level deployment architecture of the Wiz application in Azure.

## Infrastructure Overview

```mermaid
graph TB
    subgraph Azure Cloud
        RG[Resource Group]
        
        subgraph Network
            VNET[Virtual Network]
            
            subgraph Database_Subnet[Database Subnet<br/>10.0.1.0/24]
                MONGODB_VM[MongoDB VM]
                MONGODB_NSG[Network Security Group]
                MONGODB_NIC[Network Interface]
                MONGODB_PIP[Public IP]
            end
            
            subgraph Kubernetes_Subnet[Kubernetes Subnet<br/>10.0.2.0/24]
                AKS_NODES[AKS Nodes<br/>2x Standard_D2s_v3]
                AKS_NSG[Network Security Group]
            end
        end
        
        subgraph Container_Platform[Container Platform]
            AKS[AKS Cluster]
            ACR[Azure Container Registry]
            KUBE_NS[Kubernetes Namespace<br/>wiz-app]
            KUBE_SECRETS[Kubernetes Secrets]
        end
        
        subgraph Storage_Platform[Storage Platform]
            STORAGE[Storage Account]
            BACKUP_STORAGE[Backup Storage<br/>Public Access]
            BACKUP_CONTAINER[Backup Container<br/>mongodb-backups]
        end
    end
    
    %% Relationships within Database Subnet
    MONGODB_VM --> MONGODB_NIC
    MONGODB_NIC --> MONGODB_PIP
    MONGODB_NSG --> MONGODB_NIC
    MONGODB_VM --> BACKUP_STORAGE
    
    %% Relationships within Kubernetes Subnet
    AKS --> AKS_NODES
    AKS_NSG --> AKS_NODES
    
    %% Cross-subnet relationships
    AKS --> ACR
    AKS --> MONGODB_VM
    AKS --> KUBE_NS
    KUBE_NS --> KUBE_SECRETS
    
    %% Storage relationships
    STORAGE --> BACKUP_STORAGE
    BACKUP_STORAGE --> BACKUP_CONTAINER
    
    %% Styling
    classDef azure fill:#0072C6,stroke:#333,stroke-width:2px,color:white;
    classDef subnet fill:#2B579A,stroke:#333,stroke-width:2px,color:white;
    classDef service fill:#00A2ED,stroke:#333,stroke-width:2px,color:white;
    classDef security fill:#FF0000,stroke:#333,stroke-width:2px,color:white;
    classDef storage fill:#107C10,stroke:#333,stroke-width:2px,color:white;
    
    class RG,VNET azure;
    class Database_Subnet,Kubernetes_Subnet subnet;
    class MONGODB_VM,AKS,ACR,KUBE_NS service;
    class MONGODB_NSG,AKS_NSG security;
    class STORAGE,BACKUP_STORAGE,BACKUP_CONTAINER storage;
```

## Component Details

### Network Layer
- **Virtual Network**: 10.0.0.0/16
  - Database Subnet: 10.0.1.0/24
  - Kubernetes Subnet: 10.0.2.0/24

### Database Layer
- **MongoDB VM**:
  - Size: Standard_B2s
  - OS: Ubuntu 20.04 LTS
  - MongoDB Version: 4.4
  - Authentication: Enabled
  - Backup: Daily at 2:00 AM UTC

### Container Platform
- **AKS Cluster**:
  - Node Count: 2
  - Node Size: Standard_D2s_v3
  - Network Plugin: Azure
  - Network Policy: Azure
  - RBAC: Enabled

- **Azure Container Registry**:
  - SKU: Basic
  - Admin Access: Enabled

### Storage Platform
- **Main Storage Account**:
  - Tier: Standard
  - Replication: LRS

- **Backup Storage**:
  - Public Access: Enabled (for testing)
  - Container: mongodb-backups
  - Retention: 30 days

## Security Notes
- The backup storage is intentionally configured with public access for security testing purposes
- Network Security Groups are configured with permissive rules for testing
- MongoDB authentication is enabled with default credentials (should be changed in production)

## Deployment Flow
1. Resource Group creation
2. Network infrastructure setup
3. MongoDB VM deployment
4. Storage accounts creation
5. AKS cluster deployment
6. Container Registry setup
7. Kubernetes namespace and secrets creation 
# Expensy DevOps Final Project

Expensy is an expense tracker application deployed with a local Kubernetes GitOps platform.

The project uses a local Kind cluster for the runtime environment. Azure is used for Azure Key Vault (secret storage) and Azure AD (authentication/authorization via Service Principals).

## What Is Included

- **Frontend**: Next.js application.
- **Backend**: Express/TypeScript API.
- **Database**: MongoDB deployed with the Bitnami Helm chart.
- **Cache**: Redis deployed with the Bitnami Helm chart.
- **Containerization**: Dockerfiles for frontend and backend.
- **CI/CD**: GitHub Actions for build, test/typecheck/lint, scan, image push, image signing, and GitOps manifest updates.
- **GitOps**: Argo CD App-of-Apps pattern under `gitops/apps`.
- **Secrets Management**: 
  - External Secrets Operator (ESO) connected to Azure Key Vault
  - Terraform automation for Azure infrastructure (Service Principal, Key Vault, RBAC)
  - GitHub Actions pipeline for infrastructure-as-code
- **Ingress and mesh**: Istio Gateway, VirtualService, and mesh configuration.
- **Monitoring**: Prometheus and Grafana with ServiceMonitor configuration.
- **Logging and tracing**: Loki and Jaeger.
- **Security**: Kyverno policies, Falco, NetworkPolicy, non-root containers, read-only root filesystems, Trivy/Snyk scans, and Cosign image signing.

## Repository Structure

```text
expensy_backend/          Express/TypeScript backend API
expensy_frontend/         Next.js frontend
.github/workflows/        GitHub Actions CI/CD pipelines
  ├── backend-ci.yml      Backend build, test, push, sign
  ├── frontend-ci.yml     Frontend build, test, push, sign
  └── terraform.yml       Infrastructure as Code (Terraform)
gitops/                   Argo CD applications and Kubernetes manifests
docs/                     Architecture, CI/CD, security, and Terraform documentation
terraform/                Terraform configuration for Azure infrastructure
  ├── provider.tf
  ├── variables.tf
  ├── main.tf
  ├── outputs.tf
  └── terraform.tfvars.example
```

## Deployment Model

The deployment consists of two main components:

### 1. Infrastructure as Code (Terraform + GitHub Actions)

Azure infrastructure is managed entirely through Terraform and GitHub Actions:

```bash
# Create PR with Terraform changes
git checkout -b terraform/update-config
git add terraform/
git push origin terraform/update-config

# GitHub Actions pipeline automatically:
# 1. Validates Terraform configuration
# 2. Creates and comments plan in PR
# 3. Scans for security issues (TfSec)
# 4. Applies changes on merge to main
# 5. Generates Kubernetes manifests
# 6. Commits updated manifests to git
```

**Infrastructure created by Terraform:**
- Azure Resource Group
- Azure Service Principal (for External Secrets Operator)
- Azure Key Vault (for storing application secrets)
- RBAC configuration (access policies)

**Kubernetes manifests auto-generated:**
- `azure-sp-secret.yaml` - Credentials for ESO to access Key Vault
- `cluster-secret-store.yaml` - ESO configuration pointing to Key Vault

### 2. Local Kubernetes Platform (Kind + Argo CD)

The local bootstrap script prepares the Kind-based platform and applies the Argo CD root application:

```bash
bash gitops/argocd/install-argocd.sh
```

After the root app is applied, Argo CD manages the rest of the platform and application from Git:

1. Platform controllers are installed first.
2. Security policies and External Secrets configuration are synced.
3. MongoDB and Redis are deployed.
4. Frontend and backend workloads are deployed last.
5. Later application releases happen through GitOps image tag updates from CI.

## CI/CD Pipelines

### Application CI/CD (Backend & Frontend)

**Backend workflow** (`.github/workflows/backend-ci.yml`):
- Installs dependencies
- Runs SonarCloud and Snyk code scans
- Runs backend unit tests
- Builds TypeScript
- Builds and scans Docker image with Trivy
- Pushes image to Docker Hub
- Signs image with Cosign
- Updates the backend GitOps manifest image tag

**Frontend workflow** (`.github/workflows/frontend-ci.yml`):
- Installs dependencies
- Runs SonarCloud and Snyk code scans
- Runs TypeScript typecheck
- Runs ESLint
- Builds Next.js
- Builds and scans Docker image with Trivy
- Pushes image to Docker Hub
- Signs image with Cosign
- Updates the frontend GitOps manifest image tag

### Infrastructure CI/CD (Terraform)

**Terraform workflow** (`.github/workflows/terraform.yml`):

**On Pull Request:**
- Validates Terraform configuration
- Runs format check (`terraform fmt`)
- Creates and comments plan in PR
- Security scanning (TfSec)
- Blocks deploy if tests fail

**On Merge to Main:**
- Applies Terraform changes (`terraform apply`)
- Gets outputs (credentials, Key Vault URL, etc.)
- Auto-generates Kubernetes manifests:
  - `azure-sp-secret.yaml` (in `.gitignore`, applied manually)
  - `cluster-secret-store.yaml` (committed and synced via ArgoCD)
- Commits updated manifests to git
- Creates GitHub Deployment record
- Sends Slack notification (if configured)

## Required GitHub Secrets

### Application CI/CD Secrets
- `DOCKERHUB_USERNAME`
- `DOCKERHUB_TOKEN`
- `SONAR_TOKEN`
- `SONAR_TOKEN2`
- `SNYK_TOKEN`
- `COSIGN_PRIVATE_KEY`
- `COSIGN_PASSWORD`

### Infrastructure CI/CD Secrets (Terraform)
- `AZURE_SUBSCRIPTION_ID`
- `AZURE_TENANT_ID`
- `AZURE_CLIENT_ID`
- `AZURE_CLIENT_SECRET`
- `SLACK_WEBHOOK` (optional, for notifications)

## Azure Infrastructure Setup

Azure infrastructure is automatically managed through Terraform:

### Architecture

```
GitHub Actions (CI/CD)
  ↓
Terraform Code
  ↓
Azure Resources:
  ├── Resource Group (expensy-rg)
  ├── Service Principal (expensy-sp)
  ├── Key Vault (expensy-vault-kv)
  └── RBAC Policies
  ↓
Kubernetes Manifests (auto-generated)
  ├── azure-sp-secret.yaml (credentials)
  └── cluster-secret-store.yaml (ESO config)
  ↓
External Secrets Operator
  ↓
Kubernetes Secrets
```

### Getting Started with Terraform

1. **Create Service Principal** for GitHub Actions:
   ```bash
   az ad sp create-for-rbac \
     --name expensy-terraform-ci \
     --role Contributor \
     --scopes /subscriptions/{SUBSCRIPTION_ID}
   ```

2. **Add GitHub Secrets**:
   - `AZURE_SUBSCRIPTION_ID`
   - `AZURE_TENANT_ID`
   - `AZURE_CLIENT_ID`
   - `AZURE_CLIENT_SECRET`

3. **Create Pull Request** with Terraform changes:
   ```bash
   git checkout -b terraform/setup
   git add terraform/ .github/workflows/terraform.yml
   git push origin terraform/setup
   ```

4. **Review pipeline output** in PR comments

5. **Merge to main** → Terraform automatically creates resources

For detailed instructions, see [GITHUB_ACTIONS_TERRAFORM.md](GITHUB_ACTIONS_TERRAFORM.md).

## Secrets Management

Two-tier secrets architecture:

1. **GitHub Secrets**: CI/CD credentials (read-only)
   - Docker Hub token
   - SonarCloud token
   - Azure Service Principal (for Terraform)
   - Zsh encrypted in GitHub's secure storage

2. **Azure Key Vault**: Application secrets (managed by Terraform)
   - Database credentials
   - API keys
   - Configuration values
   - Accessed via External Secrets Operator

3. **Kubernetes Secrets**: Runtime secrets (created by ESO)
   - Auto-synced from Key Vault
   - Never stored in git
   - Mounted as environment variables or volumes

## Autoscaling

The current project uses fixed replica counts because it runs in a local Kind cluster. This demonstrates multi-pod availability, but not real cloud node autoscaling.

Local autoscaling can still be demonstrated with Kubernetes HPA if metrics-server is installed in the Kind cluster. Details are documented in [Autoscaling Notes](docs/AUTOSCALING.md).

## Documentation

- [Architecture](docs/ARCHITECTURE.md) - System design and components
- [CI/CD](docs/CI-CD.md) - GitHub Actions pipelines
- [Infrastructure as Code](docs/TERRAFORM.md) - Terraform and Azure setup
- [Security Overview](docs/SECURITY.md) - Security policies and practices
- [Autoscaling Notes](docs/AUTOSCALING.md) - Horizontal Pod Autoscaling

## Quick Start

### Prerequisites

- Docker & Kind
- kubectl
- Azure CLI
- GitHub CLI (optional)

### 1. Deploy Local Kubernetes Platform

```bash
bash gitops/argocd/install-argocd.sh
```

### 2. Setup Azure Infrastructure (Terraform)

See [Infrastructure as Code](docs/TERRAFORM.md) for detailed setup.

### 3. Verify Deployment

```bash
# Check Argo CD
kubectl get applications -A

# Check External Secrets
kubectl get secretstores,externalsecrets -A

# Check Application
kubectl port-forward -n expensy svc/expensy-frontend 3000:3000
```

Access at `http://localhost:3000`
- [Terraform Proposal](docs/TERRAFORM_PROPOSAL.md)

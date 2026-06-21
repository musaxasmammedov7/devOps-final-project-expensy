# Expensy DevOps Final Project

Expensy is an expense tracker application deployed with a local Kubernetes GitOps platform.

The project uses a local Kind cluster for the runtime environment. Azure is used only for Azure Key Vault, which stores application secrets consumed by External Secrets Operator.

## What Is Included

- Frontend: Next.js application.
- Backend: Express/TypeScript API.
- Database: MongoDB deployed with the Bitnami Helm chart.
- Cache: Redis deployed with the Bitnami Helm chart.
- Containerization: Dockerfiles for frontend and backend.
- CI/CD: GitHub Actions for build, test/typecheck/lint, scan, image push, image signing, and GitOps manifest updates.
- GitOps: Argo CD App-of-Apps pattern under `gitops/apps`.
- Secrets: External Secrets Operator connected to Azure Key Vault.
- Ingress and mesh: Istio Gateway, VirtualService, and mesh configuration.
- Monitoring: Prometheus and Grafana with ServiceMonitor configuration.
- Logging and tracing: Loki and Jaeger.
- Security: Kyverno policies, Falco, NetworkPolicy, non-root containers, read-only root filesystems, Trivy/Snyk scans, and Cosign image signing.

## Repository Structure

```text
expensy_backend/      Express/TypeScript backend API
expensy_frontend/     Next.js frontend
.github/workflows/    Backend and frontend CI pipelines
gitops/               Argo CD applications and Kubernetes manifests
docs/                 Architecture, CI/CD, security, and optional improvement notes
```

## Deployment Model

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

## CI/CD

Backend workflow:

- installs dependencies,
- runs SonarCloud and Snyk,
- runs backend unit tests,
- builds TypeScript,
- builds and scans Docker image with Trivy,
- pushes image to Docker Hub,
- signs image with Cosign,
- updates the backend GitOps manifest image tag.

Frontend workflow:

- installs dependencies,
- runs SonarCloud and Snyk,
- runs TypeScript typecheck,
- runs ESLint,
- builds Next.js,
- builds and scans Docker image with Trivy,
- pushes image to Docker Hub,
- signs image with Cosign,
- updates the frontend GitOps manifest image tag.

## Required GitHub Secrets

- `DOCKERHUB_USERNAME`
- `DOCKERHUB_TOKEN`
- `SONAR_TOKEN`
- `SONAR_TOKEN2`
- `SNYK_TOKEN`
- `COSIGN_PRIVATE_KEY`
- `COSIGN_PASSWORD`

## Azure Key Vault Usage

Azure is not used as the runtime platform for this project. Only Azure Key Vault is used as an external secret store.

External Secrets Operator reads values from Key Vault and creates Kubernetes Secrets for the application, MongoDB, and Redis.

## Autoscaling

The current project uses fixed replica counts because it runs in a local Kind cluster. This demonstrates multi-pod availability, but not real cloud node autoscaling.

Local autoscaling can still be demonstrated with Kubernetes HPA if metrics-server is installed in the Kind cluster. Details are documented in [Autoscaling Notes](docs/AUTOSCALING.md).

## Documentation

- [Architecture](docs/ARCHITECTURE.md)
- [CI/CD](docs/CI-CD.md)
- [Security Overview](docs/SECURITY.md)
- [Autoscaling Notes](docs/AUTOSCALING.md)
- [Terraform Proposal](docs/TERRAFORM_PROPOSAL.md)

# Security Overview

This project includes several security controls across CI, container runtime, Kubernetes admission, network access, and secrets management.

## Secrets

Application secrets are not committed to Git. External Secrets Operator reads secret values from Azure Key Vault and materializes them as Kubernetes Secrets inside the cluster.

Azure is used only for Key Vault in the current design. The Kubernetes cluster itself is local Kind.

## Container and supply chain security

- Docker images are built in CI.
- Snyk scans Node.js dependencies.
- Trivy scans built container images before push/signing.
- Cosign signs pushed images.
- Kyverno verifies image signatures for Expensy images.
- Kubernetes workloads run as non-root where configured.
- Privilege escalation is disabled.
- Linux capabilities are dropped.
- Read-only root filesystems are used for frontend/backend containers.

## Kubernetes security

- NetworkPolicy starts with default deny rules.
- Explicit ingress/egress rules allow only required traffic between frontend, backend, MongoDB, Redis, DNS, and Istio control plane.
- ServiceAccount tokens are disabled for MongoDB and Redis where Kubernetes API access is not needed.
- Kyverno policies enforce runtime and image rules.

## Known follow-ups

- Move Grafana admin password from static Helm values to a secret managed through External Secrets.
- Replace hardcoded local demo domains with documented environment variables.
- Add HPA manifests if the project moves beyond local Kind.
- Switch Kyverno image signature policy from `Audit` to `Enforce` after the public key and CI signing flow are fully validated.


# Terraform Proposal

Terraform is not currently implemented in this repository.

This document explains where Terraform could be added without changing the current architecture. The project runs on a local Kind cluster, and Azure is used only for Azure Key Vault.

## What Terraform Could Manage

For the current project scope, Terraform makes sense for:

- creating or managing Azure Key Vault,
- creating Key Vault secrets used by the app,
- managing Key Vault access permissions for External Secrets Operator,
- documenting secret names and outputs,
- optionally installing Argo CD and applying the root Argo CD application.

Terraform should not claim to manage AKS, Azure VNet, Azure node pools, or cloud load balancers unless the project is actually moved to Azure Kubernetes Service.

## Recommended Boundary

Use Terraform for external infrastructure and initial platform bootstrap.

Use Argo CD/GitOps for Kubernetes application state:

- frontend/backend workloads,
- MongoDB and Redis Helm applications,
- Istio resources,
- Kyverno policies,
- observability stack,
- ExternalSecret resources.

This avoids Terraform and Argo CD fighting over the same Kubernetes manifests.

## Possible Future Structure

```text
infra/
  terraform/
    providers.tf
    main.tf
    variables.tf
    outputs.tf
    terraform.tfvars.example
    modules/
      keyvault/
      argocd-bootstrap/
```

## Why Keep The Bootstrap Script

The current bootstrap script is still useful for a local demo because it checks local tools, creates the Kind cluster, installs platform basics, and prints local access commands.

Terraform would make most sense as an optional improvement for Key Vault and Argo CD bootstrap, not as a fake full-cloud implementation.

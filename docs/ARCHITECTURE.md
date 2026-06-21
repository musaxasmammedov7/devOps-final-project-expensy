# Expensy Architecture

Expensy is deployed as a local Kubernetes-based DevOps platform using Kind, Argo CD, GitOps manifests, and a small external Azure dependency for secret storage.

The project intentionally does not provision a full Azure infrastructure. Azure Key Vault is used only as the external source of secrets through External Secrets Operator. The application runtime, GitOps control plane, service mesh, observability, and security tooling run inside the local Kubernetes cluster.

## Main components

- Frontend: Next.js application, containerized and deployed as `expensy-frontend`.
- Backend: Express/TypeScript API, containerized and deployed as `expensy-backend`.
- Database: MongoDB deployed through the Bitnami Helm chart.
- Cache: Redis deployed through the Bitnami Helm chart.
- GitOps: Argo CD App-of-Apps pattern under `gitops/apps`.
- Secrets: External Secrets Operator reads from Azure Key Vault and creates Kubernetes Secrets.
- Service mesh: Istio provides ingress routing, mTLS-ready traffic management, and mesh telemetry.
- Monitoring: kube-prometheus-stack, Grafana dashboards, ServiceMonitor for the backend and exporters for MongoDB/Redis.
- Logging/tracing/security: Loki, Jaeger, Falco, Kyverno, and Cosign image signature verification.

## Deployment flow

1. A local Kind cluster is created.
2. Argo CD is installed and the root application is applied.
3. Argo CD syncs child applications in waves:
   - platform controllers first,
   - policies and secret store next,
   - application secrets,
   - data services,
   - frontend/backend workloads last.
4. GitHub Actions builds, scans, pushes, and signs Docker images.
5. CI updates the GitOps manifests with immutable image tags.
6. Argo CD detects the Git change and reconciles the cluster.

## Autoscaling note

The current environment is a local Kind cluster, so cloud node autoscaling is intentionally out of scope. The project uses fixed replicas for frontend and backend to demonstrate availability across multiple pods.

If the project is moved to a managed Kubernetes service, add:

- HPA for frontend/backend based on CPU or custom Prometheus metrics.
- Cluster autoscaler or managed node pool autoscaling.
- Load testing documentation to prove scale-out behavior.


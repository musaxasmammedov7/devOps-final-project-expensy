# Autoscaling Notes

The current project runs in a local Kind cluster. Because there is no cloud node pool, cloud autoscaling is not available.

The project currently uses fixed replicas for frontend and backend. This is enough to demonstrate multiple pods and basic availability in a local cluster.

## Does Autoscaling Make Sense Locally?

Yes, but only for demonstrating Kubernetes Horizontal Pod Autoscaler behavior.

In a local Kind cluster, HPA can scale pods up and down if:

- metrics-server is installed,
- workloads define CPU requests,
- HPA resources are added for frontend/backend,
- load is generated against the service.

This demonstrates pod autoscaling, not node autoscaling. If the local machine has no free CPU/memory, the cluster cannot add more real capacity.

## Possible Local HPA Example

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: expensy-backend-hpa
  namespace: expensy
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: expensy-backend
  minReplicas: 2
  maxReplicas: 5
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 70
```

## Why It Is Not Enabled By Default

HPA requires metrics-server. The current platform already contains a large local stack: Argo CD, Istio, Prometheus, Grafana, Loki, Jaeger, Falco, Kyverno, MongoDB, Redis, frontend, and backend.

Enabling autoscaling by default can make the local demo heavier and less predictable on laptops. For this reason, autoscaling is documented as an optional local demo improvement.

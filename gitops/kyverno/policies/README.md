Все политики сейчас в режиме Audit — они логируют нарушения, но НЕ блокируют деплой. Это сделано намеренно, чтобы сначала проверить, что существующие манифесты проекта (expensy backend/frontend, Bitnami MongoDB/Redis, Istio, observability) не вызывают неожиданных нарушений.

Как проверить нарушения:
kubectl get policyreport -n expensy
kubectl get clusterpolicyreport

Как посмотреть детали конкретного нарушения:
kubectl describe policyreport <report-name> -n expensy

После того как убедились, что отчётов о нарушениях нет (или все найденные нарушения осознанно исправлены), переключить режим вручную в каждом файле ClusterPolicy: изменить validationFailureAction: Audit на validationFailureAction: Enforce, закоммитить изменение — Argo CD applies автоматически благодаря selfHeal: true.

ВАЖНО про verify-image-signature.yaml: публичный ключ Cosign уже вставлен в policy. Перед переключением на Enforce нужно проверить policy reports и убедиться, что CI действительно подписывает образы тем же приватным ключом, публичная часть которого лежит в gitops/argocd/cosign.pub.

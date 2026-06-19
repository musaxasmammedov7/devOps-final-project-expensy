# Argo CD Application Sync Order (Sync Waves)

Этот документ описывает порядок автоматической синхронизации (sync waves) приложений в нашем Argo CD App-of-Apps. 

Порядок синхронизации определяется аннотацией `argocd.argoproj.io/sync-wave` в манифестах приложений. Argo CD применяет ресурсы волнами, начиная с наименьшего номера. Переход к следующей волне происходит только после успешного завершения и готовности (healthy status) ресурсов предыдущей волны.

## Таблица порядка синхронизации

| Wave (Волна) | Manifest (Манифест) | Application Name (Имя в Argo) | Описание / Зависимости |
| :---: | :--- | :--- | :--- |
| **0** | [kyverno-app.yaml](file:///Users/musaxasmammedov/devops/devOps-final-project-expensy/gitops/apps/kyverno-app.yaml) | `kyverno` | Контроллер Kyverno для валидации политик безопасности. Должен быть готов к работе, чтобы избежать отказов при создании ClusterPolicy. |
| **0** | [external-secrets-app.yaml](file:///Users/musaxasmammedov/devops/devOps-final-project-expensy/gitops/apps/external-secrets-app.yaml) | `external-secrets` | External Secrets Operator (ESO). Необходим для регистрации CRD `ClusterSecretStore` и `ExternalSecret`. |
| **0** | [istio-config-app.yaml](file:///Users/musaxasmammedov/devops/devOps-final-project-expensy/gitops/apps/istio-config-app.yaml) | `istio-config` | Базовая конфигурация Istio (Gateway, VirtualServices и сетевые правила). |
| **1** | [kyverno-policies-app.yaml](file:///Users/musaxasmammedov/devops/devOps-final-project-expensy/gitops/apps/kyverno-policies-app.yaml) | `kyverno-policies` | Ограничивающие политики безопасности Kyverno (ClusterPolicy), применяются после запуска контроллера. |
| **1** | [external-secrets-store-app.yaml](file:///Users/musaxasmammedov/devops/devOps-final-project-expensy/gitops/apps/external-secrets-store-app.yaml) | `external-secrets-store` | Подключение источника секретов (ClusterSecretStore) к Azure Key Vault. |
| **1** | [kiali-app.yaml](file:///Users/musaxasmammedov/devops/devOps-final-project-expensy/gitops/apps/kiali-app.yaml) | `kiali` | Визуализатор сервис-меша Kiali. |
| **1** | [prometheus-grafana-app.yaml](file:///Users/musaxasmammedov/devops/devOps-final-project-expensy/gitops/apps/prometheus-grafana-app.yaml) | `prometheus-grafana` | Базовый стек мониторинга Prometheus & Grafana. |
| **1** | [loki-app.yaml](file:///Users/musaxasmammedov/devops/devOps-final-project-expensy/gitops/apps/loki-stack` | `loki-stack` | Сборщик логов Loki Stack. |
| **1** | [jaeger-app.yaml](file:///Users/musaxasmammedov/devops/devOps-final-project-expensy/gitops/apps/jaeger` | `jaeger` | Распределенная трассировка Jaeger. |
| **2** | [expensy-mongodb-app.yaml](file:///Users/musaxasmammedov/devops/devOps-final-project-expensy/gitops/apps/expensy-mongodb-app.yaml) | `expensy-mongodb` | СУБД MongoDB. Ожидает готовности `ClusterSecretStore` для создания root-пароля. |
| **2** | [expensy-redis-app.yaml](file:///Users/musaxasmammedov/devops/devOps-final-project-expensy/gitops/apps/expensy-redis-app.yaml) | `expensy-redis` | Хранилище Redis. Ожидает готовности `ClusterSecretStore` для создания пароля доступа. |
| **2** | [falco-app.yaml](file:///Users/musaxasmammedov/devops/devOps-final-project-expensy/gitops/apps/falco-app.yaml) | `falco` | Система аудита безопасности Falco. Начинает работу после Kyverno и ESO. |
| **3** | [expensy-app.yaml](file:///Users/musaxasmammedov/devops/devOps-final-project-expensy/gitops/apps/expensy-app.yaml) | `expensy-apps` | Микросервисы приложения Expensy (backend, frontend). Разворачиваются в последнюю очередь после готовности баз данных и секретов. |

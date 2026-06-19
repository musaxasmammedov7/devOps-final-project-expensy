# Чеклист проверки после деплоя приложения Expensy

Пожалуйста, выполните следующие шаги после применения манифестов, чтобы убедиться в работоспособности системы:

1. **Проверка меток (Labels) баз данных для NetworkPolicy**
   - Выполнить `kubectl get pods -n expensy --show-labels` после того, как Bitnami MongoDB и Redis полностью поднялись.
   - Сверить реальные labels с тем, что указано в `networkpolicy.yaml` в правилах `allow-backend-to-mongo` и `allow-backend-to-redis` (ожидается `app.kubernetes.io/instance`, но нужно подтвердить точное значение). При несовпадении — вручную поправить selector в `networkpolicy.yaml`.

2. **Проверка имен сервисов баз данных для ConfigMap/Secret**
   - Выполнить `kubectl get svc -n expensy` и сверить реальные имена Service MongoDB/Redis с тем, что указано в `DATABASE_URI` внутри `backend-secret.yaml` (ожидается `expensy-mongo`) и `REDIS_HOST` внутри `backend-configmap.yaml` (ожидается `expensy-redis-master`). При несовпадении — обновить значения вручную.

3. **Проверка статуса подов и инъекции Istio**
   - Проверить `kubectl get pods -n expensy` — все Pod (backend, frontend, mongo, redis) должны показывать READY `2/2` (основной контейнер + istio-proxy sidecar), а не `1/2` или зависание в Init.

4. **Проверка хелсчеков (Readiness/Liveness Probes)**
   - Если backend или frontend Pod в состоянии `CrashLoopBackOff` или долго не переходит в Ready — первым делом проверить, реализован ли в коде Express `GET /health` (возвращающий статус 200) и доступен ли Next.js на пути `/` без ошибок. Без `/health` readinessProbe backend будет фейлить бесконечно — это нужно физически дописать в код, манифесты Kubernetes этот эндпоинт сами не создают.

5. **Проверка сетевой связности с Istio Control Plane**
   - Если sidecar `istio-proxy` не может связаться с `istiod` (проверить через `kubectl logs -n expensy <pod-name> -c istio-proxy`) — это обычно означает, что `allow-istio-control-plane-egress` правило в `networkpolicy.yaml` не сработало или применилось неправильно. Проверить `kubectl describe networkpolicy allow-istio-control-plane-egress -n expensy`.

6. **Проверка наличия метки (Label) на Namespace**
   - Проверить, что namespace `expensy` реально имеет label `istio-injection=enabled` (`kubectl get namespace expensy --show-labels`) — без него sidecar не инжектится вообще, и поды будут работать без mesh, без ошибок, но и без mTLS/observability через Istio.

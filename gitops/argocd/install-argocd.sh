#!/usr/bin/env bash
# =============================================================================
# install-argocd.sh — Idempotent bootstrap: Kind cluster + Argo CD + Cosign + Istio + cert-manager
# Usage: bash gitops/argocd/install-argocd.sh
# =============================================================================
set -euo pipefail

# ── Colour helpers ────────────────────────────────────────────────────────────
RED='\033[0;31m'; YELLOW='\033[1;33m'; GREEN='\033[0;32m'
CYAN='\033[0;36m'; BOLD='\033[1m'; RESET='\033[0m'

info()    { echo -e "${CYAN}[INFO]${RESET}  $*"; }
success() { echo -e "${GREEN}[OK]${RESET}    $*"; }
warn()    { echo -e "${YELLOW}[WARN]${RESET}  $*"; }
error()   { echo -e "${RED}[ERROR]${RESET} $*" >&2; }

# ── Paths ─────────────────────────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
KIND_CONFIG="${SCRIPT_DIR}/kind-config.yaml"
ROOT_APP_MANIFEST="${REPO_ROOT}/gitops/apps/root-app.yaml"
GITIGNORE_FILE="${REPO_ROOT}/.gitignore"
CLUSTER_NAME="expensy-cluster"
COSIGN_KEY="${SCRIPT_DIR}/cosign.key"
COSIGN_PUB="${SCRIPT_DIR}/cosign.pub"
SP_SECRET_FILE="${REPO_ROOT}/gitops/external-secrets/azure-sp-secret.yaml"
SP_SECRET_GITIGNORE_PATTERN="gitops/external-secrets/azure-sp-secret.yaml"

echo ""
echo -e "${BOLD}══════════════════════════════════════════════════════════════${RESET}"
echo -e "${BOLD}   Expensy DevOps Bootstrap — Cluster & Services Setup       ${RESET}"
echo -e "${BOLD}══════════════════════════════════════════════════════════════${RESET}"
echo ""

# =============================================================================
# STEP 1 — Check dependencies
# =============================================================================
info "STEP 1 — Checking required dependencies..."

check_tool() {
  local tool="$1"
  local brew_pkg="${2:-$1}"
  local apt_pkg="${3:-$1}"
  local extra_hint="${4:-}"

  if command -v "$tool" &>/dev/null; then
    success "$tool is installed ($(${tool} --version 2>&1 | head -1))"
  else
    error "$tool is NOT installed."
    echo ""
    echo -e "  ${YELLOW}macOS (Homebrew):${RESET}  brew install ${brew_pkg}"
    echo -e "  ${YELLOW}Linux (apt):${RESET}       sudo apt-get install -y ${apt_pkg}"
    if [[ -n "$extra_hint" ]]; then
      echo -e "  ${YELLOW}More info:${RESET}         ${extra_hint}"
    fi
    echo ""
    MISSING_TOOLS+=("$tool")
  fi
}

MISSING_TOOLS=()

check_tool "kind"    "kind"    "kind" \
  "https://kind.sigs.k8s.io/docs/user/quick-start/#installation"

check_tool "kubectl" "kubernetes-cli" "kubectl" \
  "https://kubernetes.io/docs/tasks/tools/"

check_tool "helm"    "helm"    "helm" \
  "https://helm.sh/docs/intro/install/"

if [[ ${#MISSING_TOOLS[@]} -gt 0 ]]; then
  error "Missing tools: ${MISSING_TOOLS[*]}"
  error "Please install them using the commands shown above, then re-run this script."
  exit 1
fi

success "All required dependencies are present."
echo ""

# =============================================================================
# STEP 2 — Create Kind cluster
# =============================================================================
info "STEP 2 — Creating Kind cluster '${CLUSTER_NAME}'..."

if kind get clusters 2>/dev/null | grep -q "^${CLUSTER_NAME}$"; then
  warn "Kind cluster '${CLUSTER_NAME}' already exists — skipping creation."
else
  if [[ ! -f "$KIND_CONFIG" ]]; then
    error "kind-config.yaml not found at: $KIND_CONFIG"
    exit 1
  fi

  # Prepare host directory for Kind persistence.
  # Создаём ТОЛЬКО корень — подпапки local-path-provisioner создаст сам
  # при первом PVC-запросе от MongoDB, Prometheus, Loki, Jaeger и т.д.
  DATA_DIR="${HOME}/expensy-data"
  info "Preparing host storage directory under ${DATA_DIR}..."
  mkdir -p "${DATA_DIR}"
  info "Cluster data will persist at: ${DATA_DIR} (survives cluster deletion)."
  info "To wipe data completely, delete this folder manually."

  # Dynamically replace CURRENT_USER placeholder in kind-config.yaml
  # (hostPath does not support ~ or $HOME — must be absolute path)
  sed -i.bak "s|/Users/CURRENT_USER/expensy-data|${DATA_DIR}|g" "$KIND_CONFIG"
  rm -f "${KIND_CONFIG}.bak"

  info "Creating cluster from config: $KIND_CONFIG"
  kind create cluster --config "$KIND_CONFIG" --name "$CLUSTER_NAME"
  success "Kind cluster '${CLUSTER_NAME}' created."
fi

info "Current kubectl context: $(kubectl config current-context)"
echo ""

# =============================================================================
# STEP 3 — Install Cosign CLI
# =============================================================================
info "STEP 3 — Checking Cosign CLI..."

if command -v cosign &>/dev/null; then
  success "Cosign is already installed."
  cosign version 2>&1 | head -3
else
  warn "Cosign not found — downloading from GitHub releases..."

  OS="$(uname -s | tr '[:upper:]' '[:lower:]')"
  ARCH="$(uname -m)"

  case "$ARCH" in
    x86_64)        ARCH_SUFFIX="amd64" ;;
    arm64|aarch64) ARCH_SUFFIX="arm64" ;;
    *)
      error "Unsupported architecture: $ARCH"
      exit 1
      ;;
  esac

  LATEST_TAG="$(curl -fsSL https://api.github.com/repos/sigstore/cosign/releases/latest \
    | grep '"tag_name"' | head -1 | sed 's/.*"tag_name": *"\(.*\)".*/\1/')"

  if [[ -z "$LATEST_TAG" ]]; then
    error "Could not determine latest Cosign release tag. Check your internet connection."
    exit 1
  fi

  BINARY_NAME="cosign-${OS}-${ARCH_SUFFIX}"
  DOWNLOAD_URL="https://github.com/sigstore/cosign/releases/download/${LATEST_TAG}/${BINARY_NAME}"

  info "Downloading: ${DOWNLOAD_URL}"
  TMP_BIN="$(mktemp)"
  curl -fsSL -o "$TMP_BIN" "$DOWNLOAD_URL"
  chmod +x "$TMP_BIN"

  if [[ -w /usr/local/bin ]]; then
    mv "$TMP_BIN" /usr/local/bin/cosign
    success "Cosign installed to /usr/local/bin/cosign"
  else
    DEST="${HOME}/.local/bin/cosign"
    mkdir -p "$(dirname "$DEST")"
    mv "$TMP_BIN" "$DEST"
    warn "No write permission to /usr/local/bin."
    warn "Cosign placed at: ${DEST}"
    warn "Add it to your PATH:  export PATH=\"\$HOME/.local/bin:\$PATH\""
    export PATH="${HOME}/.local/bin:${PATH}"
  fi

  info "Cosign version:"
  cosign version 2>&1 | head -3
fi
echo ""

# =============================================================================
# STEP 4 — Generate Cosign key pair
# =============================================================================
info "STEP 4 — Generating Cosign key pair in ${SCRIPT_DIR}..."

if [[ -f "$COSIGN_KEY" && -f "$COSIGN_PUB" ]]; then
  warn "cosign.key and cosign.pub already exist in ${SCRIPT_DIR}."
  warn "Generation skipped — delete them manually if you need to regenerate."
else
  info "Running: cosign generate-key-pair"
  info "You will be prompted to enter (and confirm) a passphrase."
  info "Remember it — it becomes your GitHub Secret COSIGN_PASSWORD."
  echo ""

  (cd "$SCRIPT_DIR" && cosign generate-key-pair)

  echo ""
  echo -e "${BOLD}${YELLOW}╔══════════════════════════════════════════════════════════════╗${RESET}"
  echo -e "${BOLD}${YELLOW}║  ВАЖНО — Инструкции после генерации ключей                  ║${RESET}"
  echo -e "${BOLD}${YELLOW}╠══════════════════════════════════════════════════════════════╣${RESET}"
  echo -e "${YELLOW}║                                                              ║${RESET}"
  echo -e "${YELLOW}║  Созданы cosign.key (приватный) и cosign.pub (публичный)     ║${RESET}"
  echo -e "${YELLOW}║  в директории: ${SCRIPT_DIR}${RESET}"
  echo -e "${YELLOW}║                                                              ║${RESET}"
  echo -e "${RED}║  1) НЕ КОММИТЬТЕ cosign.key в git!                           ║${RESET}"
  echo -e "${YELLOW}║     gitops/argocd/cosign.key добавлен в .gitignore           ║${RESET}"
  echo -e "${YELLOW}║     автоматически (см. ниже).                                ║${RESET}"
  echo -e "${YELLOW}║                                                              ║${RESET}"
  echo -e "${YELLOW}║  2) Откройте cosign.key, скопируйте содержимое целиком      ║${RESET}"
  echo -e "${YELLOW}║     в GitHub Secret: COSIGN_PRIVATE_KEY                      ║${RESET}"
  echo -e "${YELLOW}║                                                              ║${RESET}"
  echo -e "${YELLOW}║  3) Пароль, введённый выше → GitHub Secret: COSIGN_PASSWORD  ║${RESET}"
  echo -e "${YELLOW}║                                                              ║${RESET}"
  echo -e "${GREEN}║  4) cosign.pub можно закоммитить — он нужен Kyverno          ║${RESET}"
  echo -e "${GREEN}║     для верификации подписи образов.                          ║${RESET}"
  echo -e "${YELLOW}║                                                              ║${RESET}"
  echo -e "${BOLD}${YELLOW}╚══════════════════════════════════════════════════════════════╝${RESET}"
  echo ""
fi

# Auto-add cosign.key to .gitignore if missing
COSIGN_GITIGNORE_PATTERN="gitops/argocd/cosign.key"
if [[ -f "$GITIGNORE_FILE" ]]; then
  if grep -qF "$COSIGN_GITIGNORE_PATTERN" "$GITIGNORE_FILE"; then
    success ".gitignore already contains '${COSIGN_GITIGNORE_PATTERN}'."
  else
    echo "" >> "$GITIGNORE_FILE"
    echo "# Cosign private key — NEVER commit this" >> "$GITIGNORE_FILE"
    echo "$COSIGN_GITIGNORE_PATTERN" >> "$GITIGNORE_FILE"
    success "Added '${COSIGN_GITIGNORE_PATTERN}' to ${GITIGNORE_FILE}."
  fi
else
  warn ".gitignore not found at ${GITIGNORE_FILE} — creating it."
  {
    echo "# Cosign private key — NEVER commit this"
    echo "$COSIGN_GITIGNORE_PATTERN"
  } > "$GITIGNORE_FILE"
  success "Created ${GITIGNORE_FILE} with cosign.key entry."
fi
echo ""

# =============================================================================
# STEP 5 — Install Argo CD
# =============================================================================
info "STEP 5 — Installing Argo CD..."

if kubectl get namespace argocd &>/dev/null; then
  warn "Namespace 'argocd' already exists — skipping creation."
else
  kubectl create namespace argocd
  success "Namespace 'argocd' created."
fi

info "Applying Argo CD install manifest (stable)..."
kubectl apply -n argocd \
  -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

info "Waiting for Argo CD deployments to become available..."
kubectl rollout status deployment/argocd-repo-server          -n argocd --timeout=180s
kubectl rollout status deployment/argocd-server               -n argocd --timeout=180s
kubectl rollout status deployment/argocd-application-controller -n argocd --timeout=180s

success "Argo CD is fully up and running."
echo ""

# =============================================================================
# STEP 5b — Install Istio via istioctl
# =============================================================================
info "STEP 5b — Installing Istio Service Mesh..."

if command -v istioctl &>/dev/null; then
  success "istioctl is already installed."
else
  warn "istioctl not found — downloading Istio installer..."

  TMP_DIR="$(mktemp -d)"
  (
    cd "$TMP_DIR"
    curl -L https://istio.io/downloadIstio | sh -
  )

  ISTIO_DIR="$(find "$TMP_DIR" -maxdepth 2 -type d -name "istio-*" | head -n 1)"
  if [[ -z "$ISTIO_DIR" ]]; then
    error "Failed to locate downloaded Istio folder."
    exit 1
  fi

  if [[ -w /usr/local/bin ]]; then
    cp "${ISTIO_DIR}/bin/istioctl" /usr/local/bin/istioctl
    success "istioctl installed to /usr/local/bin/istioctl"
  else
    DEST="${HOME}/.local/bin/istioctl"
    mkdir -p "$(dirname "$DEST")"
    cp "${ISTIO_DIR}/bin/istioctl" "$DEST"
    warn "No write permission to /usr/local/bin."
    warn "istioctl placed at: ${DEST}"
    warn "Add it to your PATH: export PATH=\"\$HOME/.local/bin:\$PATH\""
    export PATH="${HOME}/.local/bin:${PATH}"
  fi

  rm -rf "$TMP_DIR"
fi

istioctl version

info "Running: istioctl install --set profile=default -y"
istioctl install --set profile=default -y

info "Waiting for Istio pods to become Ready..."
kubectl wait --for=condition=Ready pods --all -n istio-system --timeout=300s
success "Istio Control Plane is fully operational."

# Create expensy namespace and enable sidecar injection
if kubectl get namespace expensy &>/dev/null; then
  success "Namespace 'expensy' already exists."
else
  kubectl create namespace expensy
  success "Namespace 'expensy' created."
fi

info "Enabling Istio sidecar injection on 'expensy' namespace..."
kubectl label namespace expensy istio-injection=enabled --overwrite
success "Istio injection enabled on 'expensy' namespace."
echo ""

# =============================================================================
# STEP 5c — Install cert-manager
# =============================================================================
info "STEP 5c — Installing cert-manager..."

helm repo add jetstack https://charts.jetstack.io --force-update
helm repo update

helm upgrade --install cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --set installCRDs=true

info "Waiting for cert-manager deployments to become ready..."
kubectl rollout status deployment/cert-manager            -n cert-manager --timeout=120s
kubectl rollout status deployment/cert-manager-cainjector -n cert-manager --timeout=120s
kubectl rollout status deployment/cert-manager-webhook    -n cert-manager --timeout=120s
success "cert-manager is successfully installed and running."
echo ""

# =============================================================================
# STEP 5d — Check ngrok CLI
# =============================================================================
info "STEP 5d — Checking ngrok CLI status..."

# ВАЖНО: Никогда не хардкодьте реальный ngrok authtoken здесь!
# Этот скрипт хранится в публичном git-репозитории.
# Передавайте токен через переменную окружения при запуске:
#   NGROK_AUTHTOKEN=ваш_токен ./install-argocd.sh
# Получить токен: https://dashboard.ngrok.com/authtokens
NGROK_TOKEN="${NGROK_AUTHTOKEN:-}"

if command -v ngrok &>/dev/null; then
  success "ngrok CLI is installed ($(ngrok --version 2>&1 | head -1))."

  if [[ -n "$NGROK_TOKEN" ]]; then
    info "Configuring ngrok authtoken from NGROK_AUTHTOKEN env var..."
    ngrok config add-authtoken "$NGROK_TOKEN"
    success "ngrok authtoken successfully configured."
  else
    # Проверяем, уже ли настроен authtoken в конфиг-файле ngrok
    NGROK_CONFIG_MAC="${HOME}/Library/Application Support/ngrok/ngrok.yml"
    NGROK_CONFIG_UNIX="${HOME}/.config/ngrok/ngrok.yml"

    if [[ -f "$NGROK_CONFIG_MAC" || -f "$NGROK_CONFIG_UNIX" ]]; then
      success "ngrok config file found — authtoken likely already configured."
    else
      warn "ngrok authtoken is NOT configured."
      echo ""
      echo -e "  ${YELLOW}Для настройки выполните одно из следующих:${RESET}"
      echo -e "  ${CYAN}# Вариант 1 — передать при запуске скрипта:${RESET}"
      echo -e "  NGROK_AUTHTOKEN=ваш_токен ./install-argocd.sh"
      echo ""
      echo -e "  ${CYAN}# Вариант 2 — настроить один раз вручную:${RESET}"
      echo -e "  ngrok config add-authtoken <ваш_токен>"
      echo ""
      echo -e "  ${YELLOW}Получить токен: ${CYAN}https://dashboard.ngrok.com/authtokens${RESET}"
      echo ""
    fi
  fi
else
  warn "ngrok CLI is NOT installed."
  echo -e "  ${YELLOW}Install commands:${RESET}"
  echo -e "    macOS:  ${CYAN}brew install ngrok/ngrok/ngrok${RESET}"
  echo -e "    Linux:  Visit ${CYAN}https://ngrok.com/download${RESET}"
  echo ""
fi

# =============================================================================
# STEP 6 — Apply root Application (App of Apps)
# =============================================================================
info "STEP 6 — Applying root Application manifest..."

if [[ ! -f "$ROOT_APP_MANIFEST" ]]; then
  warn "root-app.yaml not found at: ${ROOT_APP_MANIFEST}"
  warn "Skipping — create gitops/apps/root-app.yaml and re-run the script."
else
  kubectl apply -f "$ROOT_APP_MANIFEST" -n argocd
  success "root-app applied to Argo CD."
fi
echo ""

# =============================================================================
# STEP 6b — Apply Azure Service Principal Secret for External Secrets Operator
# =============================================================================
info "STEP 6b — Applying Azure Service Principal credentials for ESO..."

# Автоматически добавляем azure-sp-secret.yaml в .gitignore —
# этот файл содержит реальные credentials и НЕ должен попадать в git.
if [[ -f "$GITIGNORE_FILE" ]]; then
  if grep -qF "$SP_SECRET_GITIGNORE_PATTERN" "$GITIGNORE_FILE"; then
    success "'${SP_SECRET_GITIGNORE_PATTERN}' already in .gitignore."
  else
    echo "" >> "$GITIGNORE_FILE"
    echo "# Azure Service Principal credentials — NEVER commit this" >> "$GITIGNORE_FILE"
    echo "$SP_SECRET_GITIGNORE_PATTERN" >> "$GITIGNORE_FILE"
    success "Added '${SP_SECRET_GITIGNORE_PATTERN}' to .gitignore automatically."
  fi
fi

if [[ ! -f "$SP_SECRET_FILE" ]]; then
  # Файл не найден — выводим подробную инструкцию как его создать
  warn "Файл ${SP_SECRET_FILE} не найден."
  warn "Этот файл содержит Azure Service Principal credentials и намеренно НЕ хранится в Git."
  echo ""
  echo -e "${BOLD}${YELLOW}╔══════════════════════════════════════════════════════════════╗${RESET}"
  echo -e "${BOLD}${YELLOW}║  Как создать azure-sp-secret.yaml                           ║${RESET}"
  echo -e "${BOLD}${YELLOW}╠══════════════════════════════════════════════════════════════╣${RESET}"
  echo -e "${YELLOW}║                                                              ║${RESET}"
  echo -e "${YELLOW}║  1) Создайте Service Principal (если ещё не создан):         ║${RESET}"
  echo -e "${CYAN}║     az ad sp create-for-rbac --name expensy-eso-sp \\         ║${RESET}"
  echo -e "${CYAN}║       --skip-assignment                                       ║${RESET}"
  echo -e "${YELLOW}║     Сохраните appId → client-id                              ║${RESET}"
  echo -e "${YELLOW}║     Сохраните password → client-secret                       ║${RESET}"
  echo -e "${YELLOW}║                                                              ║${RESET}"
  echo -e "${YELLOW}║  2) Создайте файл:                                           ║${RESET}"
  echo -e "${CYAN}║     cat > ${SP_SECRET_FILE} << 'EOF'${RESET}"
  echo -e "${CYAN}║     apiVersion: v1                                            ║${RESET}"
  echo -e "${CYAN}║     kind: Secret                                              ║${RESET}"
  echo -e "${CYAN}║     metadata:                                                 ║${RESET}"
  echo -e "${CYAN}║       name: azure-sp-credentials                              ║${RESET}"
  echo -e "${CYAN}║       namespace: external-secrets                             ║${RESET}"
  echo -e "${CYAN}║     type: Opaque                                              ║${RESET}"
  echo -e "${CYAN}║     stringData:                                               ║${RESET}"
  echo -e "${CYAN}║       client-id: \"ВАШ_AZURE_CLIENT_ID\"                        ║${RESET}"
  echo -e "${CYAN}║       client-secret: \"ВАШ_AZURE_CLIENT_SECRET\"                ║${RESET}"
  echo -e "${CYAN}║     EOF                                                       ║${RESET}"
  echo -e "${YELLOW}║                                                              ║${RESET}"
  echo -e "${YELLOW}║  3) Повторно запустите скрипт — он применит Secret           ║${RESET}"
  echo -e "${YELLOW}║     автоматически при следующем запуске.                      ║${RESET}"
  echo -e "${YELLOW}║                                                              ║${RESET}"
  echo -e "${BOLD}${YELLOW}╚══════════════════════════════════════════════════════════════╝${RESET}"
  echo ""
  warn "ESO не сможет подключиться к Azure Key Vault без этого Secret."
  warn "External Secrets будут в состоянии ошибки до применения этого файла."
  echo ""
elif grep -q "CHANGE_ME" "$SP_SECRET_FILE"; then
  # Файл существует, но содержит плейсхолдеры
  warn "Файл ${SP_SECRET_FILE} содержит плейсхолдеры CHANGE_ME!"
  warn "Замените их на реальные значения Azure Service Principal:"
  echo -e "  ${YELLOW}client-id:${RESET}     appId из вывода az ad sp create-for-rbac"
  echo -e "  ${YELLOW}client-secret:${RESET} password из вывода az ad sp create-for-rbac"
  echo ""
  warn "Пропускаем применение — заполните файл и перезапустите скрипт."
  echo ""
else
  # Файл существует и не содержит CHANGE_ME — применяем
  # Namespace external-secrets создаётся заранее (ESO установится позже через Argo CD Wave 0)
  if ! kubectl get namespace external-secrets &>/dev/null; then
    info "Namespace 'external-secrets' не существует — создаём заранее..."
    kubectl create namespace external-secrets
    success "Namespace 'external-secrets' создан."
  fi

  info "Применяем Azure SP credentials Secret в namespace external-secrets..."
  kubectl apply -f "$SP_SECRET_FILE"
  success "azure-sp-credentials Secret применён успешно."
  echo ""
  echo -e "  ${GREEN}✓ ESO сможет использовать эти credentials для подключения к Azure Key Vault${RESET}"
  echo -e "  ${GREEN}  после того, как сам ESO будет задеплоен через Argo CD (Wave 0).${RESET}"
  echo ""
fi

# =============================================================================
# STEP 7 — Final instructions
# =============================================================================
echo -e "${BOLD}${GREEN}══════════════════════════════════════════════════════════════${RESET}"
echo -e "${BOLD}${GREEN}   ✅  Bootstrap complete!                                    ${RESET}"
echo -e "${BOLD}${GREEN}══════════════════════════════════════════════════════════════${RESET}"
echo ""
echo -e "${BOLD}Получить начальный пароль admin Argo CD:${RESET}"
echo -e "  ${CYAN}kubectl -n argocd get secret argocd-initial-admin-secret \\${RESET}"
echo -e "  ${CYAN}  -o jsonpath=\"{.data.password}\" | base64 -d && echo${RESET}"
echo ""
echo -e "${BOLD}Открыть Argo CD UI (https://localhost:8080):${RESET}"
echo -e "  ${CYAN}kubectl port-forward svc/argocd-server -n argocd 8080:443${RESET}"
echo -e "  Логин: admin | Пароль: команда выше"
echo ""
echo -e "${BOLD}Проброс портов на Istio Ingress Gateway (HTTPS):${RESET}"
echo -e "  ${CYAN}kubectl port-forward svc/istio-ingressgateway -n istio-system 8443:443${RESET}"
echo ""
echo -e "${BOLD}Запуск ngrok туннеля (в отдельном окне терминала):${RESET}"
echo -e "  ${CYAN}ngrok http --domain=security-duly-outrage.ngrok-free.dev https://localhost:8443${RESET}"
echo -e "  ${YELLOW}Пояснение:${RESET} флаг ${BOLD}https://${RESET} указывает ngrok делать TLS passthrough —"
echo -e "  трафик не расшифровывается на стороне ngrok, а доходит зашифрованным"
echo -e "  до самого Istio Gateway, который терминирует TLS своим сертификатом."
echo -e "  Браузер выдаст предупреждение о self-signed сертификате — нажмите 'продолжить'."
echo ""
echo -e "${BOLD}${YELLOW}📋 Чеклист следующих шагов:${RESET}"
echo ""
echo -e "  ${YELLOW}1)${RESET} Скопируйте ${BOLD}COSIGN_PRIVATE_KEY${RESET} (содержимое cosign.key) и"
echo -e "     ${BOLD}COSIGN_PASSWORD${RESET} (пароль от ключа) в"
echo -e "     GitHub → Settings → Secrets and variables → Actions"
echo ""
echo -e "  ${YELLOW}2)${RESET} Закоммитьте ${BOLD}gitops/argocd/cosign.pub${RESET} в репозиторий"
echo ""
echo -e "  ${YELLOW}3)${RESET} Запустите CI пайплайны пушем изменений в"
echo -e "     ${BOLD}expensy_backend/${RESET} или ${BOLD}expensy_frontend/${RESET}"
echo ""
echo -e "  ${YELLOW}4)${RESET} Если ещё не создан файл с Azure credentials:"
echo -e "     ${CYAN}gitops/external-secrets/azure-sp-secret.yaml${RESET}"
echo -e "     (подробная инструкция выведена в STEP 6b выше)"
echo ""
echo -e "  ${YELLOW}5)${RESET} Проверьте подключение ESO к Azure Key Vault:"
echo -e "     ${CYAN}kubectl get clustersecretstore azure-keyvault-backend${RESET}"
echo -e "     (должно быть STATUS: Valid)"
echo ""
echo -e "  ${YELLOW}6)${RESET} Проверьте синхронизацию всех External Secrets:"
echo -e "     ${CYAN}kubectl get externalsecret -A${RESET}"
echo -e "     (все должны показывать SYNCED: True)"
echo ""
echo -e "  ${YELLOW}7)${RESET} Проверьте статус подов приложения:"
echo -e "     ${CYAN}kubectl get pods -n expensy${RESET}"
echo -e "     (все должны быть 2/2 Ready — основной контейнер + istio-proxy sidecar)"
echo ""
echo -e "  ${YELLOW}8)${RESET} Демонстрация Falco runtime security (для защиты проекта):"
echo -e "     ${CYAN}kubectl exec -it -n expensy \\"
echo -e "       \$(kubectl get pod -n expensy -l app=expensy-backend \\"
echo -e "       -o jsonpath='{.items[0].metadata.name}') -- sh${RESET}"
echo -e "     Через 10-30 секунд проверьте Gmail — должен прийти Falco alert."
echo ""
echo -e "  ${YELLOW}9)${RESET} Проверьте Kyverno policy reports (перед переключением на Enforce):"
echo -e "     ${CYAN}kubectl get policyreport -n expensy${RESET}"
echo ""
echo -e "  ${YELLOW}10)${RESET} Доступ к UI компонентов:"
echo -e "     Grafana:  ${CYAN}kubectl port-forward svc/kube-prometheus-stack-grafana -n monitoring 3000:80${RESET}"
echo -e "     Kiali:    ${CYAN}istioctl dashboard kiali${RESET}"
echo -e "     Jaeger:   ${CYAN}kubectl port-forward svc/jaeger-query -n monitoring 16686:16686${RESET}"
echo ""
# CI/CD

The repository uses separate GitHub Actions workflows for different deployment stages:

- **Application CI/CD** (Backend & Frontend): Build, test, scan, push images
- **Infrastructure CI/CD** (Terraform): Manage Azure resources

## Application Pipelines

The repository uses separate GitHub Actions workflows for backend and frontend changes.

### Backend Pipeline

The backend workflow (`.github/workflows/backend-ci.yml`) runs when files under `expensy_backend/` change.

**Main steps:**

1. Checkout source code
2. Install Node.js dependencies with `npm ci`
3. Run SonarCloud analysis
4. Run Snyk dependency scan
5. Run backend unit tests with `npm test`
6. Build TypeScript into `dist/`
7. Build Docker image locally
8. Scan the image with Trivy
9. Push the image to Docker Hub
10. Sign the image with Cosign
11. Update the backend Kubernetes deployment image tag in GitOps manifests

The backend test suite uses Node.js built-in test runner. It does not require MongoDB or Redis in CI because service dependencies are mocked.

### Why Tests Are Still Needed

SonarCloud, Snyk, Trivy, Kyverno, and Cosign check code quality, dependencies, container vulnerabilities, Kubernetes policy, and image trust. They do not prove that the application logic works.

The backend unit tests cover behavior that scanners cannot verify, such as:

- returning cached expenses from Redis
- loading expenses from MongoDB when cache is empty
- invalidating cache after creating an expense
- returning the expected HTTP status codes from controllers

This gives the CI pipeline a real application behavior gate before building and publishing an image.

### Frontend Pipeline

The frontend workflow (`.github/workflows/frontend-ci.yml`) runs when files under `expensy_frontend/` change.

**Main steps:**

1. Checkout source code
2. Install Node.js dependencies with `npm ci --legacy-peer-deps`
3. Run SonarCloud analysis
4. Run Snyk dependency scan
5. Run TypeScript type checking
6. Run linting
7. Build the Next.js production application
8. Build Docker image locally
9. Scan the image with Trivy
10. Push the image to Docker Hub
11. Sign the image with Cosign
12. Update the frontend Kubernetes deployment image tag in GitOps manifests

## Infrastructure Pipeline (Terraform)

The Terraform workflow (`.github/workflows/terraform.yml`) manages Azure infrastructure as code.

### On Pull Request

When a PR is created with Terraform changes:

1. **Validate** - Checks Terraform syntax
2. **Format Check** - Ensures consistent formatting
3. **Security Scan** - TfSec scans for security issues
4. **Plan** - Creates a plan showing what will change
5. **Comment** - Posts plan results to PR for review
6. **Block Merge** - Requires plan approval before merging

**Reviewers can see:**
- What resources will be created
- What resources will be modified
- What resources will be destroyed
- Security issues found

### On Merge to Main

When Terraform PR is merged to main:

1. **Download Plan** - Gets the reviewed plan from artifact
2. **Apply** - Executes `terraform apply` to create/modify resources
3. **Get Outputs** - Retrieves credentials and URLs from Terraform
4. **Generate Manifests** - Creates Kubernetes manifests with real values:
   - `azure-sp-secret.yaml` (Service Principal credentials)
   - `cluster-secret-store.yaml` (Key Vault connection config)
5. **Commit Manifests** - Auto-commits updated manifests to git
6. **Notification** - Sends Slack notification with deployment status

### Secrets Involved

**Application CI/CD Secrets:**
- `DOCKERHUB_USERNAME` - Docker Hub account
- `DOCKERHUB_TOKEN` - Docker Hub access token
- `SONAR_TOKEN` - SonarCloud analysis token
- `SONAR_TOKEN2` - Secondary SonarCloud token (if needed)
- `SNYK_TOKEN` - Snyk security scanning token
- `COSIGN_PRIVATE_KEY` - Private key for image signing
- `COSIGN_PASSWORD` - Password for Cosign key

**Infrastructure CI/CD Secrets:**
- `AZURE_SUBSCRIPTION_ID` - Azure subscription ID
- `AZURE_TENANT_ID` - Azure tenant ID
- `AZURE_CLIENT_ID` - Service Principal client ID
- `AZURE_CLIENT_SECRET` - Service Principal client secret
- `SLACK_WEBHOOK` - (optional) Slack webhook for notifications

## Workflow Triggers

### Application Pipelines

**Backend** - Triggered on:
- Push to `main` with changes in `expensy_backend/`
- PR to `main` with changes in `expensy_backend/`
- Manual workflow dispatch

**Frontend** - Triggered on:
- Push to `main` with changes in `expensy_frontend/`
- PR to `main` with changes in `expensy_frontend/`
- Manual workflow dispatch

### Infrastructure Pipeline

**Terraform** - Triggered on:
- Push to `main` with changes in `terraform/`
- PR to `main` with changes in `terraform/` or `.github/workflows/terraform.yml`
- Manual workflow dispatch

## Pipeline Outputs

### Application Pipelines

- Docker image pushed to Docker Hub
- Image signed with Cosign
- GitOps manifest updated with new image tag
- Argo CD automatically syncs the updated manifest

### Infrastructure Pipeline

- Azure resources created/updated
- Kubernetes secrets auto-generated and committed to git
- GitHub Deployment created for tracking
- Slack notification sent (if webhook configured)

## Debugging

### Check Pipeline Status

```bash
# List recent runs
gh run list

# View specific run details
gh run view <run-id>

# Download logs
gh run download <run-id>
```

### Common Issues

**Backend/Frontend Pipeline**
- Test failures: Check logs, run locally with `npm test`
- Image push fails: Verify Docker Hub token is valid
- SonarCloud fails: Check SonarCloud project settings

**Terraform Pipeline**
- Validation fails: Check Terraform syntax locally with `terraform validate`
- Plan fails: Check Azure credentials in GitHub Secrets
- Apply fails: Check Azure provider status and permissions

## Best Practices

1. **Run tests locally** before pushing
   ```bash
   cd expensy_backend
   npm test
   ```

2. **Review pipeline logs** if something fails

3. **Terraform changes** require PR review
   - Always review the plan before merging
   - Ensure security scan passes

4. **Keep secrets secure**
   - Never commit secrets to git
   - Rotate tokens periodically
   - Use GitHub Secret rotation features

5. **Monitor deployments**
   - Check Argo CD for successful sync
   - Monitor application pods
   - Check logs for runtime issues
8. Build Docker image locally.
9. Scan the image with Trivy.
10. Push the image to Docker Hub.
11. Sign the image with Cosign.
12. Update the frontend Kubernetes deployment image tag in GitOps manifests.

## Image promotion model

Images are tagged with the Git commit SHA. After an image passes scans and signing, the workflow commits the new tag into the GitOps deployment manifest. Argo CD then performs the deployment from Git.

This keeps the cluster deployment state traceable to Git history.

## Required GitHub secrets

- `DOCKERHUB_USERNAME`
- `DOCKERHUB_TOKEN`
- `SONAR_TOKEN`
- `SONAR_TOKEN2`
- `SNYK_TOKEN`
- `COSIGN_PRIVATE_KEY`
- `COSIGN_PASSWORD`

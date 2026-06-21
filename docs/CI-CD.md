# CI/CD

The repository uses separate GitHub Actions workflows for backend and frontend changes.

## Backend pipeline

The backend workflow runs when files under `expensy_backend/` change.

Main steps:

1. Checkout source code.
2. Install Node.js dependencies with `npm ci`.
3. Run SonarCloud analysis.
4. Run Snyk dependency scan.
5. Run backend unit tests with `npm test`.
6. Build TypeScript into `dist/`.
7. Build Docker image locally.
8. Scan the image with Trivy.
9. Push the image to Docker Hub.
10. Sign the image with Cosign.
11. Update the backend Kubernetes deployment image tag in GitOps manifests.

The backend test suite uses Node.js built-in test runner. It does not require MongoDB or Redis in CI because service dependencies are mocked.

## Why Tests Are Still Needed

SonarCloud, Snyk, Trivy, Kyverno, and Cosign check code quality, dependencies, container vulnerabilities, Kubernetes policy, and image trust. They do not prove that the application logic works.

The backend unit tests cover behavior that scanners cannot verify, such as:

- returning cached expenses from Redis,
- loading expenses from MongoDB when cache is empty,
- invalidating cache after creating an expense,
- returning the expected HTTP status codes from controllers.

This gives the CI pipeline a real application behavior gate before building and publishing an image.

## Frontend pipeline

The frontend workflow runs when files under `expensy_frontend/` change.

Main steps:

1. Checkout source code.
2. Install Node.js dependencies with `npm ci --legacy-peer-deps`.
3. Run SonarCloud analysis.
4. Run Snyk dependency scan.
5. Run TypeScript type checking.
6. Run linting.
7. Build the Next.js production application.
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

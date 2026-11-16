# Consensys GitHub Actions

https://github.com/Consensys-Incorporated/github-actions acts as a single source of truth (sot) for actions that we use

## Reusable workflows

- [`trivy`](.github/workflows/trivy.yml): scans the repository with Trivy and uploads the results to the Security tab. The usage example is in the file header. It replaces the removed `trivy` and `trivy-update-cache` actions; callers delete their `trivy-cache.yml`.


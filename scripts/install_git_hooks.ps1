# Configures local repository to use versioned .githooks directory (Phase 8.2)
git config core.hooksPath .githooks
Write-Host "Git pre-commit hooks configured via core.hooksPath = .githooks"


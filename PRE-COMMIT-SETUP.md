# Pre-commit and Detect-Secrets Setup Guide

This guide will help you set up pre-commit hooks and detect-secrets for this repository to prevent committing sensitive information.

## Table of Contents
1. [Prerequisites](#prerequisites)
2. [Installation](#installation)
3. [Configuration](#configuration)
4. [Usage](#usage)
5. [Troubleshooting](#troubleshooting)

---

## Prerequisites

- Python 3.7 or higher
- pip (Python package manager)
- Git

Check your Python version:
```bash
python3 --version
# Should show: Python 3.7.x or higher
```

---

## Installation

### Step 1: Install pre-commit and detect-secrets

```bash
# Install using pip
pip3 install pre-commit detect-secrets

# Or install globally
sudo pip3 install pre-commit detect-secrets

# Or install with homebrew (macOS)
brew install pre-commit
pip3 install detect-secrets

# Verify installation
pre-commit --version
detect-secrets --version
```

### Step 2: Install pre-commit hooks

```bash
# Navigate to repository root
cd /Users/niravsoni/repos/CKA

# Install the git hooks
pre-commit install

# Install commit-msg hook (for commit message linting)
pre-commit install --hook-type commit-msg

# Install pre-push hook
pre-commit install --hook-type pre-push
```

**Expected output:**
```
pre-commit installed at .git/hooks/pre-commit
pre-commit installed at .git/hooks/commit-msg
pre-commit installed at .git/hooks/pre-push
```

---

## Configuration

The repository includes three configuration files:

### 1. `.pre-commit-config.yaml`
Main configuration file with all hooks:
- **General checks**: Large files, case conflicts, trailing whitespace
- **Syntax checks**: YAML, JSON validation
- **Security checks**: Private keys, AWS credentials, secrets detection
- **Linting**: YAML, Markdown, Shell scripts, Dockerfiles
- **Formatting**: Go, Python, Terraform
- **Git**: Commit message linting, branch protection

### 2. `.yamllint.yaml`
YAML linting configuration:
- Line length: 120 characters
- Indentation: 2 spaces
- Excludes Helm templates (they use Go template syntax)

### 3. `.secrets.baseline`
Baseline file for detect-secrets:
- Tracks known false positives
- Prevents re-alerting on approved patterns
- Can be updated as needed

---

## Usage

### Automatic Checks (On Commit)

Pre-commit hooks run automatically when you commit:

```bash
# Make changes to files
git add .

# Commit (hooks run automatically)
git commit -m "Your commit message"
```

**What happens:**
1. Pre-commit runs all configured hooks
2. If any hook fails, the commit is blocked
3. You fix the issues and try again
4. Once all hooks pass, commit succeeds

### Manual Checks (Before Commit)

Run checks manually on all files:

```bash
# Run all hooks on all files
pre-commit run --all-files

# Run specific hook
pre-commit run detect-secrets --all-files
pre-commit run check-yaml --all-files
pre-commit run shellcheck --all-files

# Run on specific files
pre-commit run --files demo-app/Dockerfile
pre-commit run --files *.yaml
```

### Update Hooks

Update to latest versions:

```bash
# Update all hooks to latest versions
pre-commit autoupdate

# Update specific hook
pre-commit autoupdate --repo https://github.com/Yelp/detect-secrets
```

---

## Detect-Secrets Specific Usage

### Scan for Secrets

```bash
# Scan all files
detect-secrets scan

# Scan specific directory
detect-secrets scan demo-app/

# Scan and update baseline
detect-secrets scan --baseline .secrets.baseline

# Scan with specific plugins
detect-secrets scan --all-files \
  --exclude-files '.*\.lock$' \
  --exclude-files 'go\.sum$'
```

### Audit Secrets

Review detected secrets:

```bash
# Audit the baseline file
detect-secrets audit .secrets.baseline

# Interactive audit
# Press:
#   'y' - Mark as real secret (will fail pre-commit)
#   'n' - Mark as false positive (will be ignored)
#   's' - Skip for now
#   'q' - Quit
```

### Update Baseline

After auditing, update the baseline:

```bash
# Update baseline with new scan results
detect-secrets scan --baseline .secrets.baseline --update

# Force update (overwrite)
detect-secrets scan --baseline .secrets.baseline --force-use-all-plugins
```

---

## Common Workflows

### Workflow 1: First Time Setup

```bash
# 1. Install tools
pip3 install pre-commit detect-secrets

# 2. Install hooks
pre-commit install
pre-commit install --hook-type commit-msg

# 3. Run initial scan
pre-commit run --all-files

# 4. Fix any issues
# ... make fixes ...

# 5. Commit
git add .
git commit -m "Setup pre-commit hooks"
```

### Workflow 2: Daily Development

```bash
# 1. Make changes
vim demo-app/main.go

# 2. Stage changes
git add demo-app/main.go

# 3. Commit (hooks run automatically)
git commit -m "Add new feature"

# If hooks fail:
# 4. Fix issues
# 5. Stage fixes
git add demo-app/main.go

# 6. Commit again
git commit -m "Add new feature"
```

### Workflow 3: Handling False Positives

```bash
# 1. Detect-secrets finds a false positive
# Example: "password" in a comment

# 2. Audit the baseline
detect-secrets audit .secrets.baseline

# 3. Mark as false positive (press 'n')

# 4. Update baseline
detect-secrets scan --baseline .secrets.baseline --update

# 5. Commit the updated baseline
git add .secrets.baseline
git commit -m "Update secrets baseline"
```

### Workflow 4: Bypassing Hooks (Emergency Only)

```bash
# Skip all hooks (NOT RECOMMENDED)
git commit --no-verify -m "Emergency fix"

# Skip specific hook
SKIP=detect-secrets git commit -m "Skip secrets check"

# Skip multiple hooks
SKIP=detect-secrets,check-yaml git commit -m "Skip multiple checks"
```

**⚠️ Warning:** Only bypass hooks in emergencies. Always run checks manually afterward.

---

## Hooks Included

### Security Hooks ✅
- `detect-private-key` - Detect private keys
- `detect-aws-credentials` - Detect AWS credentials
- `detect-secrets` - Comprehensive secret detection
- `check-merge-conflict` - Prevent merge conflict markers

### File Checks ✅
- `check-added-large-files` - Prevent large files (>1MB)
- `check-case-conflict` - Case-insensitive filename conflicts
- `end-of-file-fixer` - Ensure files end with newline
- `trailing-whitespace` - Remove trailing whitespace
- `mixed-line-ending` - Fix line endings

### Syntax Checks ✅
- `check-yaml` - YAML syntax validation
- `check-json` - JSON syntax validation
- `yamllint` - YAML linting
- `shellcheck` - Shell script linting
- `hadolint` - Dockerfile linting

### Code Quality ✅
- `go-fmt` - Go code formatting
- `go-vet` - Go code analysis
- `go-imports` - Go import organization
- `black` - Python code formatting
- `isort` - Python import sorting

### Git Checks ✅
- `no-commit-to-branch` - Prevent commits to main/master
- `gitlint` - Commit message linting

---

## Troubleshooting

### Issue 1: Pre-commit not found

```bash
# Error: command not found: pre-commit

# Solution: Add to PATH
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc

# Or reinstall
pip3 install --user pre-commit
```

### Issue 2: Hooks not running

```bash
# Check if hooks are installed
ls -la .git/hooks/

# Reinstall hooks
pre-commit uninstall
pre-commit install
```

### Issue 3: Detect-secrets failing on legitimate code

```bash
# Audit and mark as false positive
detect-secrets audit .secrets.baseline

# Or add to allowlist in .pre-commit-config.yaml
# Add under detect-secrets hook:
args:
  - '--exclude-lines'
  - 'password.*=.*example'
```

### Issue 4: YAML validation failing on Helm templates

```bash
# Helm templates use Go template syntax
# They're already excluded in .pre-commit-config.yaml

# If you need to exclude more:
# Edit .pre-commit-config.yaml and add to exclude pattern
```

### Issue 5: Slow pre-commit execution

```bash
# Run only on changed files (default)
git commit -m "message"

# Skip slow hooks for quick commits
SKIP=terraform_validate,go-vet git commit -m "Quick fix"

# Update hook versions (may improve performance)
pre-commit autoupdate
```

### Issue 6: Can't commit due to line endings

```bash
# Fix line endings
pre-commit run mixed-line-ending --all-files

# Or configure git
git config core.autocrlf input  # Linux/Mac
git config core.autocrlf true   # Windows
```

---

## Best Practices

### 1. Run Before Committing
```bash
# Always run manually first
pre-commit run --all-files

# Then commit
git commit -m "Your message"
```

### 2. Keep Hooks Updated
```bash
# Update monthly
pre-commit autoupdate
```

### 3. Review Baseline Regularly
```bash
# Audit secrets baseline quarterly
detect-secrets audit .secrets.baseline
```

### 4. Don't Bypass Hooks
```bash
# ❌ Bad
git commit --no-verify

# ✅ Good
# Fix the issues, then commit
```

### 5. Add Custom Hooks
```bash
# Edit .pre-commit-config.yaml
# Add your team's custom hooks
```

---

## Additional Tools

### Git-secrets (Alternative)

```bash
# Install
brew install git-secrets

# Setup
git secrets --install
git secrets --register-aws

# Scan
git secrets --scan
```

### TruffleHog (Deep History Scan)

```bash
# Install
pip3 install trufflehog

# Scan entire history
trufflehog git file://. --only-verified
```

### GitLeaks (Alternative)

```bash
# Install
brew install gitleaks

# Scan
gitleaks detect --source . --verbose
```

---

## Configuration Files Reference

### .pre-commit-config.yaml
- Location: Repository root
- Purpose: Main pre-commit configuration
- Modify: To add/remove hooks

### .yamllint.yaml
- Location: Repository root
- Purpose: YAML linting rules
- Modify: To adjust YAML standards

### .secrets.baseline
- Location: Repository root
- Purpose: Track known false positives
- Modify: Via `detect-secrets audit`

---

## Support

For issues:
1. Check this guide
2. Run `pre-commit run --all-files --verbose`
3. Check `.git/hooks/` directory
4. Review hook documentation: https://pre-commit.com

---

## Quick Reference

```bash
# Install
pip3 install pre-commit detect-secrets
pre-commit install

# Run manually
pre-commit run --all-files

# Update hooks
pre-commit autoupdate

# Audit secrets
detect-secrets audit .secrets.baseline

# Update baseline
detect-secrets scan --baseline .secrets.baseline --update

# Skip hooks (emergency)
git commit --no-verify

# Uninstall
pre-commit uninstall
```

---

**Remember:** Pre-commit hooks are your first line of defense against committing sensitive information. Use them consistently!

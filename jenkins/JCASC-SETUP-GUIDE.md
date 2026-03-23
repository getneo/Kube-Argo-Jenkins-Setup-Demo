# Jenkins Configuration as Code (JCasC) - Setup Guide

This guide explains how to apply the `jcasc-security.yaml` configuration to your Jenkins instance.

## Table of Contents
1. [What is JCasC?](#what-is-jcasc)
2. [Understanding jcasc-security.yaml](#understanding-jcasc-securityyaml)
3. [Method 1: Apply During Installation](#method-1-apply-during-installation)
4. [Method 2: Apply to Existing Jenkins](#method-2-apply-to-existing-jenkins)
5. [Method 3: Using ConfigMap](#method-3-using-configmap)
6. [Verification](#verification)
7. [Troubleshooting](#troubleshooting)

---

## What is JCasC?

**Jenkins Configuration as Code (JCasC)** allows you to define Jenkins configuration in YAML files instead of using the UI.

### Benefits:
- ✅ **Version Control**: Configuration in Git
- ✅ **Reproducible**: Same config across environments
- ✅ **Automated**: No manual UI clicks
- ✅ **Auditable**: Track all changes
- ✅ **Disaster Recovery**: Quick restoration

### How It Works:
```
YAML File → JCasC Plugin → Jenkins Configuration
```

---

## Understanding jcasc-security.yaml

Let's break down what this file configures:

### 1. Security Realm (Authentication)

```yaml
jenkins:
  securityRealm:
    local:
      allowsSignup: false
      users:
        - id: "admin"
          name: "Administrator"
          password: "${ADMIN_PASSWORD}"
```

**What it does**:
- Uses local user database (not LDAP/AD)
- Disables self-registration
- Creates admin user
- Password from environment variable

**Why `${ADMIN_PASSWORD}`?**
- Keeps password out of YAML file
- Loaded from environment variable or secret
- More secure than hardcoding

### 2. Authorization Strategy

```yaml
  authorizationStrategy:
    loggedInUsersCanDoAnything:
      allowAnonymousRead: false
```

**What it does**:
- Logged-in users have full access
- Anonymous users have no access
- Simple but not fine-grained

**Alternatives**:
```yaml
# Matrix-based security (more control)
authorizationStrategy:
  globalMatrix:
    permissions:
      - "Overall/Administer:admin"
      - "Overall/Read:authenticated"
      - "Job/Build:developers"
      - "Job/Read:developers"

# Role-based security
authorizationStrategy:
  roleBased:
    roles:
      global:
        - name: "admin"
          permissions:
            - "Overall/Administer"
        - name: "developer"
          permissions:
            - "Job/Build"
            - "Job/Read"
```

### 3. Remoting Security

```yaml
  remotingSecurity:
    enabled: true
```

**What it does**:
- Enables agent-to-master security
- Prevents unauthorized agent connections
- Required for production

### 4. CSRF Protection

```yaml
  crumbIssuer:
    standard:
      excludeClientIPFromCrumb: false
```

**What it does**:
- Enables CSRF (Cross-Site Request Forgery) protection
- Requires crumb token for API calls
- Includes client IP in crumb validation

**Why important?**
- Prevents malicious websites from making requests
- Required for secure Jenkins

### 5. API Token Settings

```yaml
security:
  apiToken:
    creationOfLegacyTokenEnabled: false
    tokenGenerationOnCreationEnabled: false
    usageStatisticsEnabled: true
```

**What it does**:
- Disables legacy API tokens (less secure)
- Doesn't auto-generate tokens
- Tracks token usage

### 6. SSH Server

```yaml
  sSHD:
    port: -1  # Disable SSH server
```

**What it does**:
- Disables Jenkins SSH server
- Reduces attack surface
- Use kubectl exec instead

### 7. Jenkins URL

```yaml
unclassified:
  location:
    url: "http://jenkins.local:8080"
```

**What it does**:
- Sets Jenkins URL for links in emails
- Used for webhook callbacks
- Update to your actual URL

---

## Method 1: Apply During Installation

This is the **recommended method** for new Jenkins installations.

### Step 1: Create Kubernetes Secret

```bash
# Create secret with admin password
kubectl create secret generic jenkins-admin-secret \
  --from-literal=ADMIN_PASSWORD='YourSecurePassword123!' \  # pragma: allowlist secret
  -n jenkins

# Verify secret
kubectl get secret jenkins-admin-secret -n jenkins
```

### Step 2: Create ConfigMap with JCasC

```bash
# Create ConfigMap from jcasc-security.yaml
kubectl create configmap jenkins-casc-config \
  --from-file=jcasc-security.yaml=jenkins/jcasc-security.yaml \
  -n jenkins

# Verify ConfigMap
kubectl get configmap jenkins-casc-config -n jenkins
kubectl describe configmap jenkins-casc-config -n jenkins
```

### Step 3: Update Helm Values

Create or update `jenkins/values-with-jcasc.yaml`:

```yaml
controller:
  # Admin credentials
  adminSecret: true
  adminUser: admin

  # JCasC configuration
  JCasC:
    enabled: true
    defaultConfig: false  # Don't use default config
    configScripts:
      security: |
        jenkins:
          securityRealm:
            local:
              allowsSignup: false
              users:
                - id: "admin"
                  name: "Administrator"
                  password: "${ADMIN_PASSWORD}"

          authorizationStrategy:
            loggedInUsersCanDoAnything:
              allowAnonymousRead: false

          remotingSecurity:
            enabled: true

          crumbIssuer:
            standard:
              excludeClientIPFromCrumb: false

        security:
          apiToken:
            creationOfLegacyTokenEnabled: false
            tokenGenerationOnCreationEnabled: false
            usageStatisticsEnabled: true

          sSHD:
            port: -1

        unclassified:
          location:
            url: "http://jenkins.local:8080"

  # Environment variables
  containerEnv:
    - name: ADMIN_PASSWORD
      valueFrom:
        secretKeyRef:
          name: jenkins-admin-secret
          key: ADMIN_PASSWORD

  # Install required plugins
  installPlugins:
    - configuration-as-code:latest
    - configuration-as-code-support:latest

# Persistence
persistence:
  enabled: true
  size: 8Gi
```

### Step 4: Install Jenkins with JCasC

```bash
# Install Jenkins with JCasC configuration
helm install jenkins jenkins/jenkins \
  --namespace jenkins \
  --create-namespace \
  --values jenkins/values-with-jcasc.yaml \
  --wait

# Or upgrade existing installation
helm upgrade jenkins jenkins/jenkins \
  --namespace jenkins \
  --values jenkins/values-with-jcasc.yaml \
  --wait
```

### Step 5: Verify Installation

```bash
# Check pod status
kubectl get pods -n jenkins

# Check logs for JCasC
kubectl logs -n jenkins jenkins-0 | grep -i "configuration as code"

# Expected output:
# Configuration as Code plugin initialized
# Applying configuration from /var/jenkins_home/casc_configs/security.yaml
```

---

## Method 2: Apply to Existing Jenkins

If Jenkins is already running, you can apply JCasC configuration.

### Step 1: Access Jenkins UI

```bash
# Port forward to Jenkins
kubectl port-forward -n jenkins svc/jenkins 8080:8080

# Get admin password
kubectl exec -n jenkins jenkins-0 -- cat /run/secrets/additional/chart-admin-password

# Open browser: http://localhost:8080
# Login with admin credentials
```

### Step 2: Install JCasC Plugin

```bash
# Option A: Via UI
# 1. Manage Jenkins → Manage Plugins
# 2. Available tab
# 3. Search "Configuration as Code"
# 4. Install without restart

# Option B: Via CLI
kubectl exec -n jenkins jenkins-0 -- \
  jenkins-plugin-cli --plugins configuration-as-code:latest
```

### Step 3: Copy JCasC File to Jenkins

```bash
# Copy jcasc-security.yaml to Jenkins pod
kubectl cp jenkins/jcasc-security.yaml \
  jenkins/jenkins-0:/var/jenkins_home/casc_configs/security.yaml

# Verify file
kubectl exec -n jenkins jenkins-0 -- \
  cat /var/jenkins_home/casc_configs/security.yaml
```

### Step 4: Set Admin Password Environment Variable

```bash
# Create secret
kubectl create secret generic jenkins-admin-secret \
  --from-literal=ADMIN_PASSWORD='YourSecurePassword123!' \  # pragma: allowlist secret
  -n jenkins

# Patch deployment to add environment variable
kubectl patch statefulset jenkins -n jenkins --type='json' -p='[
  {
    "op": "add",
    "path": "/spec/template/spec/containers/0/env/-",
    "value": {
      "name": "ADMIN_PASSWORD",
      "valueFrom": {
        "secretKeyRef": {
          "name": "jenkins-admin-secret",
          "key": "ADMIN_PASSWORD"
        }
      }
    }
  }
]'

# Wait for pod to restart
kubectl rollout status statefulset/jenkins -n jenkins
```

### Step 5: Reload Configuration

```bash
# Option A: Via UI
# 1. Manage Jenkins → Configuration as Code
# 2. Click "Reload existing configuration"

# Option B: Via API
JENKINS_URL="http://localhost:8080"
ADMIN_USER="admin"
ADMIN_PASSWORD="your-password"  # pragma: allowlist secret

curl -X POST "${JENKINS_URL}/configuration-as-code/reload" \
  --user "${ADMIN_USER}:${ADMIN_PASSWORD}"

# Option C: Restart Jenkins
kubectl rollout restart statefulset/jenkins -n jenkins
```

---

## Method 3: Using ConfigMap

This method uses Kubernetes ConfigMap for JCasC configuration.

### Step 1: Create ConfigMap

```bash
# Create ConfigMap from file
kubectl create configmap jenkins-casc-config \
  --from-file=security.yaml=jenkins/jcasc-security.yaml \
  -n jenkins

# Or create from literal
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: jenkins-casc-config
  namespace: jenkins
data:
  security.yaml: |
$(cat jenkins/jcasc-security.yaml | sed 's/^/    /')
EOF
```

### Step 2: Mount ConfigMap in Jenkins Pod

Update Helm values:

```yaml
controller:
  # Mount ConfigMap as volume
  additionalExistingSecrets:
    - name: jenkins-admin-secret
      keyName: ADMIN_PASSWORD

  sidecars:
    configAutoReload:
      enabled: true
      folder: /var/jenkins_home/casc_configs

  # Mount ConfigMap
  additionalVolumes:
    - name: casc-config
      configMap:
        name: jenkins-casc-config

  additionalVolumeMounts:
    - name: casc-config
      mountPath: /var/jenkins_home/casc_configs
      readOnly: true
```

### Step 3: Upgrade Jenkins

```bash
helm upgrade jenkins jenkins/jenkins \
  --namespace jenkins \
  --values jenkins/values-with-jcasc.yaml \
  --wait
```

---

## Verification

### 1. Check JCasC Plugin Status

```bash
# Via UI
# Manage Jenkins → Configuration as Code
# Should show: "Configuration loaded successfully"

# Via logs
kubectl logs -n jenkins jenkins-0 | grep -i "configuration as code"
```

### 2. Verify Security Settings

```bash
# Test anonymous access (should fail)
curl -I http://localhost:8080/

# Expected: HTTP/1.1 403 Forbidden

# Test with credentials (should succeed)
curl -I -u admin:YourPassword http://localhost:8080/

# Expected: HTTP/1.1 200 OK
```

### 3. Check User Configuration

```bash
# Via UI
# Manage Jenkins → Manage Users
# Should show: admin user

# Via API
curl -u admin:YourPassword http://localhost:8080/api/json?tree=users[id,fullName]
```

### 4. Verify CSRF Protection

```bash
# Get crumb
CRUMB=$(curl -u admin:YourPassword \
  'http://localhost:8080/crumbIssuer/api/xml?xpath=concat(//crumbRequestField,":",//crumb)')

echo "CSRF Crumb: $CRUMB"

# Should output: Jenkins-Crumb:abc123...
```

---

## Troubleshooting

### Issue 1: Configuration Not Applied

**Symptom**: JCasC file exists but configuration not applied

**Solution**:
```bash
# Check JCasC plugin is installed
kubectl exec -n jenkins jenkins-0 -- \
  jenkins-plugin-cli --list | grep configuration-as-code

# Check file location
kubectl exec -n jenkins jenkins-0 -- \
  ls -la /var/jenkins_home/casc_configs/

# Check logs for errors
kubectl logs -n jenkins jenkins-0 | grep -i error

# Reload configuration
kubectl exec -n jenkins jenkins-0 -- \
  curl -X POST http://localhost:8080/configuration-as-code/reload
```

### Issue 2: ADMIN_PASSWORD Not Found

**Symptom**: Error: "ADMIN_PASSWORD environment variable not set"

**Solution**:
```bash
# Check secret exists
kubectl get secret jenkins-admin-secret -n jenkins

# Check environment variable in pod
kubectl exec -n jenkins jenkins-0 -- env | grep ADMIN_PASSWORD

# If missing, create secret and restart
kubectl create secret generic jenkins-admin-secret \
  --from-literal=ADMIN_PASSWORD='YourPassword' \  # pragma: allowlist secret
  -n jenkins

kubectl rollout restart statefulset/jenkins -n jenkins
```

### Issue 3: Permission Denied

**Symptom**: Can't access Jenkins after applying JCasC

**Solution**:
```bash
# Reset admin password
kubectl exec -n jenkins jenkins-0 -- \
  groovy /var/jenkins_home/init.groovy.d/reset-admin-password.groovy

# Or disable security temporarily
kubectl exec -n jenkins jenkins-0 -- \
  sed -i 's/<useSecurity>true<\/useSecurity>/<useSecurity>false<\/useSecurity>/' \
  /var/jenkins_home/config.xml

kubectl rollout restart statefulset/jenkins -n jenkins
```

### Issue 4: YAML Syntax Error

**Symptom**: "Failed to load configuration"

**Solution**:
```bash
# Validate YAML syntax
kubectl exec -n jenkins jenkins-0 -- \
  cat /var/jenkins_home/casc_configs/security.yaml | \
  python3 -c "import yaml, sys; yaml.safe_load(sys.stdin)"

# Check indentation (must be 2 spaces)
kubectl exec -n jenkins jenkins-0 -- \
  cat -A /var/jenkins_home/casc_configs/security.yaml
```

### Issue 5: Plugin Compatibility

**Symptom**: "Unknown field" or "Unsupported configuration"

**Solution**:
```bash
# Check JCasC plugin version
kubectl exec -n jenkins jenkins-0 -- \
  jenkins-plugin-cli --list | grep configuration-as-code

# Update to latest version
kubectl exec -n jenkins jenkins-0 -- \
  jenkins-plugin-cli --plugins configuration-as-code:latest

# Check schema
curl http://localhost:8080/configuration-as-code/schema
```

---

## Best Practices

### 1. Use Secrets for Passwords

✅ **Good**:
```yaml
password: "${ADMIN_PASSWORD}"  # From secret
```

❌ **Bad**:
```yaml
password: "hardcoded-password"  # pragma: allowlist secret - In YAML file
```

### 2. Version Control JCasC Files

```bash
# Store in Git
git add jenkins/jcasc-security.yaml
git commit -m "Add Jenkins security configuration"
git push
```

### 3. Test in Development First

```bash
# Test in dev environment
helm install jenkins-dev jenkins/jenkins \
  --namespace jenkins-dev \
  --values jenkins/values-with-jcasc.yaml

# Verify configuration
# Then apply to production
```

### 4. Use ConfigMap for Easy Updates

```bash
# Update ConfigMap
kubectl create configmap jenkins-casc-config \
  --from-file=security.yaml=jenkins/jcasc-security.yaml \
  -n jenkins \
  --dry-run=client -o yaml | kubectl apply -f -

# Reload configuration (no restart needed)
kubectl exec -n jenkins jenkins-0 -- \
  curl -X POST http://localhost:8080/configuration-as-code/reload
```

### 5. Enable Auto-Reload

```yaml
controller:
  sidecars:
    configAutoReload:
      enabled: true
      folder: /var/jenkins_home/casc_configs
```

---

## Summary

### Quick Reference

```bash
# Create secret
kubectl create secret generic jenkins-admin-secret \
  --from-literal=ADMIN_PASSWORD='YourPassword' \  # pragma: allowlist secret
  -n jenkins

# Create ConfigMap
kubectl create configmap jenkins-casc-config \
  --from-file=security.yaml=jenkins/jcasc-security.yaml \
  -n jenkins

# Install/Upgrade Jenkins
helm upgrade --install jenkins jenkins/jenkins \
  --namespace jenkins \
  --values jenkins/values-with-jcasc.yaml

# Reload configuration
kubectl exec -n jenkins jenkins-0 -- \
  curl -X POST http://localhost:8080/configuration-as-code/reload

# Verify
kubectl logs -n jenkins jenkins-0 | grep -i "configuration as code"
```

### What JCasC Configures

- ✅ Security realm (authentication)
- ✅ Authorization strategy (permissions)
- ✅ CSRF protection
- ✅ API token settings
- ✅ SSH server (disabled)
- ✅ Jenkins URL

### Benefits

- 🚀 Automated configuration
- 📝 Version controlled
- 🔄 Reproducible
- 🔒 Secure (passwords in secrets)
- ⚡ Fast disaster recovery

Your Jenkins is now configured as code! 🎉

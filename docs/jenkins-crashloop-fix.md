# Jenkins CrashLoopBackOff - Complete Fix Guide

## Problem Summary

Jenkins pod has been in CrashLoopBackOff for 2+ days with 670+ restarts due to JCasC (Jenkins Configuration as Code) configuration errors.

### Root Causes Identified

1. **Initial Issue**: `excludeClientIPFromCrumb: false` causing ConfiguratorConflictException
2. **Secondary Issue**: Kubernetes cloud configuration failing with "No hudson.slaves.Cloud implementation found for kubernetes"

### Error Messages

```
SEVERE jenkins.InitReactorRunner$1#onTaskFailed: Failed ConfigurationAsCode.init
io.jenkins.plugins.casc.UnknownAttributesException: cloud: No hudson.slaves.Cloud implementation found for kubernetes
```

---

## Quick Fix Options

### Option 1: Complete Jenkins Reinstall (RECOMMENDED)

This is the cleanest approach - start fresh with a working configuration.

```bash
# 1. Backup any important data (if needed)
kubectl exec -n jenkins jenkins-0 -- tar czf /tmp/jenkins-backup.tar.gz \
  /var/jenkins_home/jobs \
  /var/jenkins_home/users \
  /var/jenkins_home/credentials.xml \
  2>/dev/null || true

# 2. Uninstall Jenkins completely
helm uninstall jenkins -n jenkins

# 3. Delete the namespace to clean everything
kubectl delete namespace jenkins

# 4. Wait for namespace deletion
kubectl wait --for=delete namespace/jenkins --timeout=60s

# 5. Recreate namespace
kubectl create namespace jenkins

# 6. Create admin password secret
kubectl create secret generic jenkins-admin-secret \
  --from-literal=jenkins-admin-password='YourSecurePassword123!' \  # pragma: allowlist secret
  -n jenkins

# 7. Install Jenkins with minimal configuration (NO JCasC initially)
helm repo add jenkins https://charts.jenkins.io
helm repo update

helm install jenkins jenkins/jenkins \
  --namespace jenkins \
  --set controller.admin.existingSecret=jenkins-admin-secret \
  --set controller.admin.userKey=jenkins-admin-user \
  --set controller.admin.passwordKey=jenkins-admin-password \
  --set controller.serviceType=NodePort \
  --set controller.nodePort=32000 \
  --set controller.installPlugins[0]=kubernetes:4360.v0e4e4e0e0e0e \
  --set controller.installPlugins[1]=workflow-aggregator:latest \
  --set controller.installPlugins[2]=git:latest \
  --set controller.installPlugins[3]=configuration-as-code:latest \
  --set controller.JCasC.enabled=false \
  --wait

# 8. Wait for Jenkins to be ready
kubectl wait --for=condition=ready pod -l app.kubernetes.io/component=jenkins-controller \
  -n jenkins --timeout=300s

# 9. Get Jenkins URL
minikube service jenkins -n jenkins --url

# 10. Login with admin/YourSecurePassword123!
```

### Option 2: Disable JCasC Temporarily

Keep existing installation but disable JCasC to let Jenkins start.

```bash
# 1. Delete all JCasC ConfigMaps
kubectl delete configmap jenkins-casc-config -n jenkins
kubectl delete configmap jenkins-jenkins-jcasc-config -n jenkins
kubectl delete configmap jenkins-jenkins-config-security -n jenkins 2>/dev/null || true
kubectl delete configmap jenkins-jenkins-config-kubernetes-cloud -n jenkins 2>/dev/null || true

# 2. Scale down Jenkins
kubectl scale statefulset jenkins -n jenkins --replicas=0

# 3. Wait for pod to terminate
kubectl wait --for=delete pod/jenkins-0 -n jenkins --timeout=60s

# 4. Edit the StatefulSet to disable JCasC
kubectl edit statefulset jenkins -n jenkins

# Find and remove or comment out these volume mounts:
# - name: jenkins-casc-config
# - name: jenkins-config

# Find and remove these volumes:
# - name: jenkins-casc-config
#   configMap:
#     name: jenkins-casc-config
# - name: jenkins-config
#   configMap:
#     name: jenkins-jenkins-jcasc-config

# 5. Scale back up
kubectl scale statefulset jenkins -n jenkins --replicas=1

# 6. Monitor startup
kubectl logs -n jenkins jenkins-0 -f
```

### Option 3: Fix JCasC Configuration

Fix the configuration issues without reinstalling.

```bash
# 1. Create a minimal working JCasC config
cat <<'EOF' > /tmp/jenkins-minimal-jcasc.yaml
jenkins:
  securityRealm:
    local:
      allowsSignup: false
      users:
        - id: "admin"
          password: "${ADMIN_PASSWORD}"

  authorizationStrategy:
    loggedInUsersCanDoAnything:
      allowAnonymousRead: false

  crumbIssuer:
    standard: {}

  numExecutors: 0
  mode: NORMAL

security:
  apiToken:
    creationOfLegacyTokenEnabled: false

unclassified:
  location:
    url: "http://jenkins.local:8080"
EOF

# 2. Delete problematic ConfigMaps
kubectl delete configmap jenkins-jenkins-jcasc-config -n jenkins
kubectl delete configmap jenkins-jenkins-config-security -n jenkins 2>/dev/null || true
kubectl delete configmap jenkins-jenkins-config-kubernetes-cloud -n jenkins 2>/dev/null || true

# 3. Create new minimal ConfigMap
kubectl create configmap jenkins-jenkins-jcasc-config \
  --from-file=jcasc-default-config.yaml=/tmp/jenkins-minimal-jcasc.yaml \
  -n jenkins

# 4. Add required labels
kubectl label configmap jenkins-jenkins-jcasc-config \
  -n jenkins \
  app.kubernetes.io/component=jenkins-controller \
  app.kubernetes.io/instance=jenkins \
  app.kubernetes.io/managed-by=Helm \
  app.kubernetes.io/name=jenkins \
  jenkins-jenkins-config=true

# 5. Delete the pod to restart
kubectl delete pod jenkins-0 -n jenkins

# 6. Monitor logs
kubectl logs -n jenkins jenkins-0 -f
```

---

## Verification Steps

After applying any fix:

```bash
# 1. Check pod status
kubectl get pods -n jenkins
# Should show: jenkins-0   2/2   Running

# 2. Check logs for success
kubectl logs -n jenkins jenkins-0 | grep -i "jenkins is fully up"

# 3. Check for errors
kubectl logs -n jenkins jenkins-0 | grep -i "error\|severe\|failed"

# 4. Access Jenkins
minikube service jenkins -n jenkins --url

# 5. Login and verify
# - Can login with admin credentials
# - Dashboard loads properly
# - No error messages
```

---

## Post-Recovery: Add Kubernetes Cloud Configuration

Once Jenkins is running, add Kubernetes cloud configuration through the UI or JCasC:

### Method 1: Through Jenkins UI

1. Go to **Manage Jenkins** → **Manage Nodes and Clouds** → **Configure Clouds**
2. Click **Add a new cloud** → **Kubernetes**
3. Configure:
   - **Name**: kubernetes
   - **Kubernetes URL**: https://kubernetes.default
   - **Kubernetes Namespace**: jenkins
   - **Jenkins URL**: http://jenkins:8080
   - **Jenkins tunnel**: jenkins-agent:50000
4. Click **Test Connection** - should show "Connected to Kubernetes"
5. Save

### Method 2: Add JCasC Configuration Gradually

```yaml
# Add this AFTER Jenkins is running successfully
jenkins:
  clouds:
    - kubernetes:
        name: "kubernetes"
        serverUrl: "https://kubernetes.default"
        namespace: "jenkins"
        jenkinsUrl: "http://jenkins:8080"
        jenkinsTunnel: "jenkins-agent:50000"
        containerCapStr: "10"
        connectTimeout: 5
        readTimeout: 15
        retentionTimeout: 5
```

---

## Prevention: Best Practices

### 1. Test JCasC Configuration Before Applying

```bash
# Use Jenkins Configuration as Code plugin's validation
# Install jenkins-cli
wget http://jenkins.local:8080/jnlpJars/jenkins-cli.jar

# Validate configuration
java -jar jenkins-cli.jar -s http://jenkins.local:8080/ \
  -auth admin:password \
  configuration-as-code-validate < your-config.yaml
```

### 2. Use Minimal Configuration Initially

Start with minimal JCasC and add features incrementally:

```yaml
# Stage 1: Basic security only
jenkins:
  securityRealm:
    local:
      allowsSignup: false
  authorizationStrategy:
    loggedInUsersCanDoAnything:
      allowAnonymousRead: false

# Stage 2: Add after Stage 1 works
jenkins:
  crumbIssuer:
    standard: {}

# Stage 3: Add after Stage 2 works
jenkins:
  clouds:
    - kubernetes:
        name: "kubernetes"
        # ... configuration
```

### 3. Always Have Rollback Plan

```bash
# Before making changes, backup current config
kubectl get configmap jenkins-jenkins-jcasc-config -n jenkins -o yaml > jenkins-jcasc-backup.yaml

# If issues occur, restore
kubectl apply -f jenkins-jcasc-backup.yaml
kubectl delete pod jenkins-0 -n jenkins
```

### 4. Monitor Logs During Changes

```bash
# Watch logs in real-time when applying changes
kubectl logs -n jenkins jenkins-0 -f

# Look for these success indicators:
# - "Configuration as Code plugin initialized"
# - "Jenkins is fully up and running"

# Look for these error indicators:
# - "SEVERE"
# - "ERROR"
# - "Failed ConfigurationAsCode"
# - "ConfiguratorConflictException"
```

---

## Troubleshooting Common Issues

### Issue: "No hudson.slaves.Cloud implementation found"

**Cause**: Kubernetes plugin not installed or not loaded properly

**Fix**:
```bash
# Install Kubernetes plugin
kubectl exec -n jenkins jenkins-0 -- \
  jenkins-plugin-cli --plugins kubernetes:latest

# Restart Jenkins
kubectl delete pod jenkins-0 -n jenkins
```

### Issue: "excludeClientIPFromCrumb" conflict

**Cause**: Conflicting CSRF protection settings

**Fix**: Use simplified crumbIssuer configuration:
```yaml
jenkins:
  crumbIssuer:
    standard: {}  # Don't specify excludeClientIPFromCrumb
```

### Issue: Pod stuck in Init state

**Cause**: Init containers failing, often due to plugin installation issues

**Fix**:
```bash
# Check init container logs
kubectl logs -n jenkins jenkins-0 -c init

# If plugin installation failing, reduce plugins
helm upgrade jenkins jenkins/jenkins \
  --namespace jenkins \
  --set controller.installPlugins={kubernetes:latest,workflow-aggregator:latest} \
  --reuse-values
```

### Issue: "Permission denied" errors

**Cause**: PVC permissions or SecurityContext issues

**Fix**:
```bash
# Check PVC
kubectl get pvc -n jenkins

# If PVC issues, delete and recreate
kubectl delete pvc jenkins -n jenkins
kubectl delete pod jenkins-0 -n jenkins
# StatefulSet will recreate both
```

---

## Emergency Recovery Commands

### Complete Reset (Nuclear Option)

```bash
#!/bin/bash
# jenkins-emergency-reset.sh

echo "=== Jenkins Emergency Reset ==="
echo "This will DELETE ALL Jenkins data!"
read -p "Are you sure? (type 'yes'): " confirm

if [ "$confirm" != "yes" ]; then
    echo "Aborted"
    exit 1
fi

# Uninstall
helm uninstall jenkins -n jenkins 2>/dev/null || true

# Delete namespace
kubectl delete namespace jenkins --timeout=60s

# Wait
sleep 10

# Recreate
kubectl create namespace jenkins

# Create secret
kubectl create secret generic jenkins-admin-secret \
  --from-literal=jenkins-admin-password='Admin123!' \  # pragma: allowlist secret
  -n jenkins

# Reinstall with minimal config
helm install jenkins jenkins/jenkins \
  --namespace jenkins \
  --set controller.admin.existingSecret=jenkins-admin-secret \
  --set controller.admin.passwordKey=jenkins-admin-password \
  --set controller.serviceType=NodePort \
  --set controller.nodePort=32000 \
  --set controller.JCasC.enabled=false \
  --wait

echo "=== Jenkins Reset Complete ==="
echo "Access: minikube service jenkins -n jenkins --url"
echo "Login: admin / Admin123!"
```

---

## Recommended Solution for Your Case

Given that Jenkins has been crashing for 2+ days, I recommend **Option 1: Complete Reinstall**.

### Step-by-Step Recovery Plan

```bash
# 1. Clean slate
helm uninstall jenkins -n jenkins
kubectl delete namespace jenkins
kubectl create namespace jenkins

# 2. Create admin secret
kubectl create secret generic jenkins-admin-secret \
  --from-literal=jenkins-admin-password='SecurePass123!' \  # pragma: allowlist secret
  -n jenkins

# 3. Install with minimal config
helm install jenkins jenkins/jenkins \
  --namespace jenkins \
  --set controller.admin.existingSecret=jenkins-admin-secret \
  --set controller.admin.passwordKey=jenkins-admin-password \
  --set controller.serviceType=NodePort \
  --set controller.nodePort=32000 \
  --set controller.installPlugins[0]=kubernetes:latest \
  --set controller.installPlugins[1]=workflow-aggregator:latest \
  --set controller.installPlugins[2]=git:latest \
  --set controller.installPlugins[3]=configuration-as-code:latest \
  --set controller.JCasC.enabled=false \
  --wait

# 4. Verify it's running
kubectl get pods -n jenkins
kubectl logs -n jenkins jenkins-0 | tail -20

# 5. Access Jenkins
minikube service jenkins -n jenkins --url

# 6. Once confirmed working, gradually add JCasC configuration
```

This approach ensures:
- ✅ Clean start without corrupted state
- ✅ Minimal configuration reduces failure points
- ✅ Can verify each component works before adding more
- ✅ JCasC disabled initially, add later when stable

---

## Next Steps After Recovery

1. **Verify Jenkins is accessible and functional**
2. **Configure Kubernetes cloud through UI first**
3. **Test that agents can be spawned**
4. **Export working configuration to JCasC**
5. **Apply JCasC configuration incrementally**
6. **Document your working configuration**

---

## Support Resources

- Jenkins Configuration as Code: https://github.com/jenkinsci/configuration-as-code-plugin
- Jenkins Kubernetes Plugin: https://plugins.jenkins.io/kubernetes/
- Helm Chart Documentation: https://github.com/jenkinsci/helm-charts

---

**Created**: 2026-03-23  
**Status**: Active troubleshooting guide  
**Last Updated**: 2026-03-23

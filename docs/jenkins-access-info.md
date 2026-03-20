# Jenkins Access Information

## 🎉 Jenkins Successfully Installed!

Jenkins is now running in your Kubernetes cluster and ready to use.

---

## 📋 Access Details

### **Jenkins URL**
- **Ingress**: http://jenkins.local
- **Port Forward**: `kubectl port-forward -n jenkins svc/jenkins 8080:8080`
  - Then access: http://localhost:8080


**To retrieve password anytime:**
```bash
kubectl get secret jenkins -n jenkins -o jsonpath='{.data.jenkins-admin-password}' | base64 -d
```

---

## 🚀 Quick Start

### **1. Access Jenkins UI**

**Option A: Using Ingress (Recommended)**
```bash
# Add to /etc/hosts if not already done
echo "192.168.49.2 jenkins.local" | sudo tee -a /etc/hosts

# Open in browser
open http://jenkins.local
```

**Option B: Using Port Forward**
```bash
# Forward port in terminal
kubectl port-forward -n jenkins svc/jenkins 8080:8080

# Open in browser (in another terminal)
open http://localhost:8080
```

### **2. Login**
1. Enter username: `admin`
2. Enter password: `kubectl get secret jenkins -n jenkins -o jsonpath='{.data.jenkins-admin-password}' | base64 -d`
3. Click "Sign in"

### **3. Verify Installation**
Once logged in, you should see:
- Jenkins dashboard
- "New Item" option to create jobs
- "Manage Jenkins" for configuration

---

## 📊 Deployment Status

### **Pod Status**
```bash
kubectl get pods -n jenkins
```
**Expected Output:**
```
NAME        READY   STATUS    RESTARTS   AGE
jenkins-0   2/2     Running   2          131m
```

### **Services**
```bash
kubectl get svc -n jenkins
```
**Output:**
```
NAME            TYPE        CLUSTER-IP       PORT(S)
jenkins         ClusterIP   10.107.204.171   8080/TCP
jenkins-agent   ClusterIP   10.109.35.21     50000/TCP
```

### **Ingress**
```bash
kubectl get ingress -n jenkins
```
**Output:**
```
NAME      CLASS   HOSTS           ADDRESS        PORTS
jenkins   nginx   jenkins.local   192.168.49.2   80
```

---

## 🔧 Configuration Details

### **Installed Version**
- **Jenkins**: 2.541.2 (Latest LTS)
- **Chart Version**: 5.9.8
- **JDK**: 17

### **Resources Allocated**
- **CPU Request**: 500m (0.5 cores)
- **Memory Request**: 2Gi
- **CPU Limit**: 2000m (2 cores)
- **Memory Limit**: 4Gi
- **Storage**: 20Gi persistent volume

### **Key Features Enabled**
✅ Kubernetes cloud integration  
✅ Dynamic agent provisioning  
✅ Persistent storage (20GB)  
✅ Ingress access  
✅ RBAC enabled  
✅ Non-root containers  
✅ Health probes configured  

---

## 🔌 Kubernetes Integration

Jenkins is configured to use Kubernetes for dynamic agent provisioning:

### **Kubernetes Cloud Configuration**
- **Name**: kubernetes
- **Kubernetes URL**: https://kubernetes.default
- **Namespace**: jenkins
- **Jenkins URL**: http://jenkins:8080
- **Jenkins Tunnel**: jenkins-agent:50000

### **Test Kubernetes Integration**
1. Go to "Manage Jenkins" → "Clouds"
2. Click on "kubernetes"
3. Click "Test Connection"
4. Should see: "Connected to Kubernetes v1.28.0"

---

## 📦 Next Steps

### **1. Install Additional Plugins**
Navigate to: **Manage Jenkins** → **Plugins** → **Available plugins**

**Recommended plugins:**
- Docker Pipeline
- Git
- GitHub
- Pipeline
- Kubernetes CLI
- Blue Ocean (modern UI)
- Prometheus metrics

### **2. Create Your First Pipeline**
1. Click "New Item"
2. Enter name: "test-pipeline"
3. Select "Pipeline"
4. Add simple pipeline script:
```groovy
pipeline {
    agent {
        kubernetes {
            yaml '''
apiVersion: v1
kind: Pod
spec:
  containers:
  - name: shell
    image: ubuntu
    command:
    - sleep
    args:
    - infinity
'''
        }
    }
    stages {
        stage('Test') {
            steps {
                container('shell') {
                    sh 'echo "Hello from Kubernetes!"'
                    sh 'hostname'
                }
            }
        }
    }
}
```
5. Click "Build Now"
6. Watch the build run in a Kubernetes pod!

### **3. Configure GitHub Integration**
1. Go to "Manage Jenkins" → "System"
2. Add GitHub server
3. Configure webhooks for automatic builds

### **4. Set Up Credentials**
1. Go to "Manage Jenkins" → "Credentials"
2. Add credentials for:
   - Git repositories
   - Docker registries
   - Kubernetes secrets
   - Cloud providers

---

## 🔍 Monitoring & Logs

### **View Jenkins Logs**
```bash
# Controller logs
kubectl logs -n jenkins jenkins-0 -c jenkins -f

# Init container logs
kubectl logs -n jenkins jenkins-0 -c init

# All containers
kubectl logs -n jenkins jenkins-0 --all-containers -f
```

### **Check Resource Usage**
```bash
# Pod resource usage
kubectl top pod jenkins-0 -n jenkins

# Namespace resource usage
kubectl top pod -n jenkins
```

### **Describe Pod**
```bash
kubectl describe pod jenkins-0 -n jenkins
```

---

## 🛠️ Common Operations

### **Restart Jenkins**
```bash
# Delete pod (StatefulSet will recreate it)
kubectl delete pod jenkins-0 -n jenkins

# Or restart via Helm
helm upgrade jenkins jenkins/jenkins \
  --namespace jenkins \
  --values jenkins/values-minimal.yaml \
  --reuse-values
```

### **Update Configuration**
```bash
# Edit values file, then:
helm upgrade jenkins jenkins/jenkins \
  --namespace jenkins \
  --values jenkins/values-minimal.yaml
```

### **Backup Jenkins**
```bash
# Backup Jenkins home directory
kubectl exec -n jenkins jenkins-0 -- tar czf /tmp/jenkins-backup.tar.gz /var/jenkins_home

# Copy backup locally
kubectl cp jenkins/jenkins-0:/tmp/jenkins-backup.tar.gz ./jenkins-backup.tar.gz
```

### **Scale Down/Up**
```bash
# Scale down (for maintenance)
kubectl scale statefulset jenkins -n jenkins --replicas=0

# Scale up
kubectl scale statefulset jenkins -n jenkins --replicas=1
```

---

## 🔒 Security Considerations

### **Current Security Features**
✅ RBAC enabled with service account  
✅ Non-root containers (UID 1000)  
✅ Read-only root filesystem where possible  
✅ Network policies ready (currently disabled)  
✅ Secrets stored in Kubernetes secrets  
✅ Resource limits enforced  

### **Recommended Security Enhancements**
1. **Enable HTTPS**: Add TLS certificate to ingress
2. **Configure LDAP/SSO**: Integrate with corporate auth
3. **Enable Audit Logging**: Track all Jenkins actions
4. **Restrict Plugin Installation**: Lock down plugin management
5. **Enable Network Policies**: Restrict pod-to-pod communication
6. **Regular Updates**: Keep Jenkins and plugins updated

---

## 📚 Additional Resources

### **Jenkins Documentation**
- Official Docs: https://www.jenkins.io/doc/
- Pipeline Syntax: https://www.jenkins.io/doc/book/pipeline/syntax/
- Kubernetes Plugin: https://plugins.jenkins.io/kubernetes/

### **Helm Chart Documentation**
- Chart Repo: https://github.com/jenkinsci/helm-charts
- Values Reference: https://github.com/jenkinsci/helm-charts/blob/main/charts/jenkins/VALUES_SUMMARY.md

### **Kubernetes Integration**
- Jenkins on Kubernetes: https://www.jenkins.io/doc/book/installing/kubernetes/
- Dynamic Agents: https://plugins.jenkins.io/kubernetes/#plugin-content-pod-template

---

## 🐛 Troubleshooting

### **Issue: Can't Access Jenkins UI**
```bash
# Check pod status
kubectl get pods -n jenkins

# Check service
kubectl get svc -n jenkins

# Check ingress
kubectl get ingress -n jenkins

# Test with port-forward
kubectl port-forward -n jenkins svc/jenkins 8080:8080
```

### **Issue: Forgot Admin Password**
```bash
# Retrieve password from secret
kubectl get secret jenkins -n jenkins -o jsonpath='{.data.jenkins-admin-password}' | base64 -d
```

### **Issue: Pod Not Starting**
```bash
# Check pod events
kubectl describe pod jenkins-0 -n jenkins

# Check logs
kubectl logs jenkins-0 -n jenkins -c jenkins

# Check PVC
kubectl get pvc -n jenkins
```

### **Issue: Plugins Not Installing**
```bash
# Check init container logs
kubectl logs jenkins-0 -n jenkins -c init

# Manually install plugins via UI
# Go to Manage Jenkins → Plugins
```

---

## ✅ Verification Checklist

- [ ] Jenkins pod is running (2/2 Ready)
- [ ] Can access Jenkins UI via ingress or port-forward
- [ ] Can login with admin credentials
- [ ] Kubernetes cloud is configured
- [ ] Can create and run a test pipeline
- [ ] Persistent volume is mounted
- [ ] Resource limits are applied
- [ ] RBAC is working

---

**Jenkins is now ready for CI/CD workflows!** 🎉

Next steps:
1. Install additional plugins as needed
2. Create your first pipeline
3. Integrate with Git repositories
4. Set up ArgoCD for CD (next section)

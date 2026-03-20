# Jenkins Values.yaml - Detailed Explanation

## 📚 Source and Customization Guide

### **Official Source**

The Jenkins Helm chart values.yaml is based on the official Jenkins Helm chart:

**Official Repository:**
- GitHub: https://github.com/jenkinsci/helm-charts
- Chart Repository: https://charts.jenkins.io
- Default values.yaml: https://github.com/jenkinsci/helm-charts/blob/main/charts/jenkins/values.yaml

**How to view default values:**
```bash
# View all default values for the chart
helm show values jenkins/jenkins > jenkins-defaults.yaml

# Or view specific chart version
helm show values jenkins/jenkins --version 5.9.8 > jenkins-defaults-v5.yaml
```

---

## 🔧 Customizations Made for Your Environment

### **1. Image Configuration**

**Default:**
```yaml
controller:
  image:
    registry: docker.io
    repository: jenkins/jenkins
    tag: "2.479.2-jdk17"  # Latest version
```

**Our Customization:**
```yaml
controller:
  image:
    registry: "docker.io"
    repository: "jenkins/jenkins"
    tag: "2.440.1-lts-jdk17"  # Specific LTS version
    pullPolicy: "IfNotPresent"
```

**Why:**
- ✅ **LTS Version**: Using Long-Term Support (2.440.1) for stability
- ✅ **JDK 17**: Modern Java version with better performance
- ✅ **IfNotPresent**: Reduces image pulls, faster pod starts
- ✅ **Pinned Version**: Prevents unexpected updates

---

### **2. Resource Limits**

**Default:**
```yaml
resources:
  requests:
    cpu: "50m"
    memory: "256Mi"
  limits:
    cpu: "2000m"
    memory: "4096Mi"
```

**Our Customization:**
```yaml
resources:
  requests:
    cpu: "500m"      # 10x higher
    memory: "2Gi"    # 8x higher
  limits:
    cpu: "2000m"     # Same
    memory: "4Gi"    # Same
```

**Why:**
- ✅ **Higher Requests**: Ensures Jenkins gets adequate resources from start
- ✅ **Production-Ready**: Prevents slow startup and plugin installation
- ✅ **Matches Quota**: Fits within our jenkins namespace quota (4 CPU, 8GB)
- ✅ **Room for Bursts**: Can burst to 2 CPU / 4GB when needed

---

### **3. Java Options (JVM Tuning)**

**Default:**
```yaml
javaOpts: ""  # Empty
```

**Our Customization:**
```yaml
javaOpts: >-
  -Xms2048m                          # Initial heap size
  -Xmx2048m                          # Maximum heap size
  -XX:+UseG1GC                       # G1 Garbage Collector
  -XX:+UseStringDeduplication        # Reduce memory usage
  -XX:+ParallelRefProcEnabled        # Parallel reference processing
  -XX:+DisableExplicitGC             # Prevent manual GC calls
  -Djava.awt.headless=true           # Headless mode
```

**Why:**
- ✅ **Fixed Heap**: -Xms = -Xmx prevents heap resizing overhead
- ✅ **G1GC**: Better for large heaps, lower pause times
- ✅ **String Deduplication**: Saves memory (Jenkins has many strings)
- ✅ **Parallel Processing**: Faster garbage collection
- ✅ **Headless Mode**: No GUI needed in containers

---

### **4. Admin User Configuration**

**Default:**
```yaml
controller:
  admin:
    username: "admin"
    password: ""  # Auto-generated
```

**Our Customization:**
```yaml
controller:
  admin:
    username: "admin"
    # Password auto-generated and stored in secret
    # Retrieve: kubectl get secret jenkins -n jenkins -o jsonpath='{.data.jenkins-admin-password}' | base64 -d
```

**Why:**
- ✅ **Auto-Generated Password**: More secure than hardcoded
- ✅ **Stored in Secret**: Kubernetes secret management
- ✅ **Easy Retrieval**: Simple kubectl command to get password
- ✅ **No Plain Text**: Never stored in values.yaml

---

### **5. Executors Configuration**

**Default:**
```yaml
numExecutors: 2
```

**Our Customization:**
```yaml
numExecutors: 0
```

**Why:**
- ✅ **Best Practice**: Never run builds on controller
- ✅ **Scalability**: Forces use of dynamic agents
- ✅ **Resource Efficiency**: Controller only manages, doesn't build
- ✅ **Isolation**: Builds run in separate pods with proper resources

---

### **6. Plugin Installation**

**Default:**
```yaml
installPlugins:
  - kubernetes:latest
  - workflow-aggregator:latest
  - git:latest
  - configuration-as-code:latest
```

**Our Customization:**
```yaml
installPlugins:
  # Essential plugins with specific versions
  - kubernetes:4029.v5712230ccb_f8
  - workflow-aggregator:596.v8c21c963d92d
  - git:5.2.0
  - configuration-as-code:1670.v564dc8b_982d0

  # SCM plugins
  - github:1.37.3.1
  - github-branch-source:1728.v859147241f49

  # Build tools
  - docker-workflow:572.v950f58993843
  - pipeline-stage-view:2.33

  # Credentials
  - credentials-binding:631.v861e8e2d4d7a_
  - plain-credentials:143.v1b_df8b_d3b_e48

  # Monitoring
  - prometheus:2.2.3

  # Utilities
  - timestamper:1.25
  - ws-cleanup:0.45
  - ansicolor:1.0.2

additionalPlugins:
  - blueocean:1.27.9
  - kubernetes-cli:1.12.1
```

**Why:**
- ✅ **Pinned Versions**: Reproducible deployments
- ✅ **Essential Only**: Faster startup, less complexity
- ✅ **Production Tested**: Known working versions
- ✅ **Organized**: Grouped by functionality
- ✅ **Extensible**: Easy to add more plugins later

---

### **7. Kubernetes Cloud Configuration (JCasC)**

**Default:**
```yaml
JCasC:
  defaultConfig: true
  configScripts: {}
```

**Our Customization:**
```yaml
JCasC:
  defaultConfig: true
  configScripts:
    kubernetes-cloud: |
      jenkins:
        clouds:
          - kubernetes:
              name: "kubernetes"
              serverUrl: "https://kubernetes.default"
              namespace: "jenkins"
              jenkinsUrl: "http://jenkins:8080"
              jenkinsTunnel: "jenkins-agent:50000"

              templates:
                - name: "jenkins-agent"      # Standard agent
                - name: "docker-agent"       # For Docker builds
                - name: "go-agent"           # For Go builds
```

**Why:**
- ✅ **Configuration as Code**: Reproducible, version-controlled
- ✅ **Multiple Agent Types**: Different workloads need different tools
- ✅ **Dynamic Provisioning**: Agents created on-demand
- ✅ **Resource Limits**: Each agent type has appropriate limits
- ✅ **Security**: Non-root containers, proper security contexts

**Agent Types Explained:**

1. **jenkins-agent** (Standard)
   - General purpose builds
   - 500m CPU, 512Mi memory
   - Basic tools included

2. **docker-agent** (Docker-in-Docker)
   - Building container images
   - 500m-2000m CPU, 1-2Gi memory
   - Privileged mode for Docker daemon
   - Used for: Building and pushing Docker images

3. **go-agent** (Golang)
   - Go application builds
   - 500m-1000m CPU, 512Mi-1Gi memory
   - Go 1.21 toolchain
   - Used for: Your Go web application

---

### **8. Ingress Configuration**

**Default:**
```yaml
ingress:
  enabled: false
```

**Our Customization:**
```yaml
ingress:
  enabled: true
  apiVersion: "networking.k8s.io/v1"
  annotations:
    kubernetes.io/ingress.class: nginx
    nginx.ingress.kubernetes.io/ssl-redirect: "false"
    nginx.ingress.kubernetes.io/proxy-body-size: "50m"
    nginx.ingress.kubernetes.io/proxy-request-buffering: "off"
  hostName: jenkins.local
  path: /
  pathType: Prefix
```

**Why:**
- ✅ **Easy Access**: Access via http://jenkins.local
- ✅ **No SSL Redirect**: Simpler for local development
- ✅ **Large Uploads**: 50MB limit for artifacts
- ✅ **No Buffering**: Better for streaming logs
- ✅ **NGINX Integration**: Works with Minikube ingress addon

---

### **9. Persistence Configuration**

**Default:**
```yaml
persistence:
  enabled: true
  size: "8Gi"
```

**Our Customization:**
```yaml
persistence:
  enabled: true
  existingClaim: ""
  storageClass: "standard"
  accessMode: "ReadWriteOnce"
  size: "20Gi"  # 2.5x larger
```

**Why:**
- ✅ **Larger Storage**: 20GB for plugins, jobs, artifacts
- ✅ **Standard Class**: Uses Minikube's default provisioner
- ✅ **RWO Mode**: Single node access (sufficient for Minikube)
- ✅ **Production-Ready**: Room for growth

---

### **10. Health Probes**

**Default:**
```yaml
healthProbes: true
healthProbeLivenessInitialDelay: 90
healthProbeReadinessInitialDelay: 60
```

**Our Customization:**
```yaml
healthProbes: true
healthProbesLivenessTimeout: 5
healthProbesReadinessTimeout: 5
healthProbeLivenessPeriodSeconds: 10
healthProbeReadinessPeriodSeconds: 10
healthProbeLivenessFailureThreshold: 5
healthProbeReadinessFailureThreshold: 3
healthProbeLivenessInitialDelay: 90
healthProbeReadinessInitialDelay: 60
```

**Why:**
- ✅ **Liveness Probe**: Restarts if Jenkins becomes unresponsive
- ✅ **Readiness Probe**: Doesn't route traffic until ready
- ✅ **Initial Delays**: Gives time for plugin installation
- ✅ **Failure Thresholds**: Tolerates temporary issues
- ✅ **SRE Best Practice**: Proper health checking

---

### **11. RBAC Configuration**

**Default:**
```yaml
rbac:
  create: true
  readSecrets: false
```

**Our Customization:**
```yaml
rbac:
  create: true
  readSecrets: true
```

**Why:**
- ✅ **Secret Access**: Jenkins needs to read Kubernetes secrets
- ✅ **Credential Management**: Store credentials in K8s secrets
- ✅ **Security**: Least privilege with explicit permissions
- ✅ **Integration**: Required for Kubernetes plugin

---

### **12. Network Policy**

**Default:**
```yaml
networkPolicy:
  enabled: false
```

**Our Customization:**
```yaml
networkPolicy:
  enabled: false  # We have custom network policies
```

**Why:**
- ✅ **Custom Policies**: We created our own in k8s/setup/network-policies.yaml
- ✅ **More Control**: Fine-grained control over traffic
- ✅ **Zero-Trust**: Default deny with explicit allows
- ✅ **Namespace-Wide**: Consistent policy across namespace

---

## 📊 Comparison Summary

| Configuration | Default | Our Value | Reason |
|--------------|---------|-----------|--------|
| CPU Request | 50m | 500m | Faster startup, production-ready |
| Memory Request | 256Mi | 2Gi | Adequate for plugins |
| Storage | 8Gi | 20Gi | Room for artifacts |
| Executors | 2 | 0 | Force agent usage |
| Plugins | 4 basic | 15+ essential | Complete CI/CD toolkit |
| Ingress | Disabled | Enabled | Easy access |
| JVM Heap | Default | 2GB fixed | Optimized performance |
| Agent Types | 1 | 3 | Specialized workloads |

---

## 🔍 How to Customize Further

### **View Current Values:**
```bash
# See what's actually deployed
helm get values jenkins -n jenkins

# See all values (including defaults)
helm get values jenkins -n jenkins --all
```

### **Update Configuration:**
```bash
# Modify jenkins/values-v5.yaml, then:
helm upgrade jenkins jenkins/jenkins \
  --namespace jenkins \
  --values jenkins/values-v5.yaml
```

### **Add More Plugins:**
```yaml
installPlugins:
  - your-plugin:version
```

### **Adjust Resources:**
```yaml
resources:
  requests:
    cpu: "1000m"    # Increase if needed
    memory: "4Gi"
```

---

## 📚 Additional Resources

- **Jenkins Helm Chart Docs**: https://github.com/jenkinsci/helm-charts/tree/main/charts/jenkins
- **Jenkins Configuration as Code**: https://github.com/jenkinsci/configuration-as-code-plugin
- **Jenkins Kubernetes Plugin**: https://plugins.jenkins.io/kubernetes/
- **Helm Values Documentation**: https://helm.sh/docs/chart_template_guide/values_files/

---

## 🎯 Key Takeaways

1. **Start with Defaults**: Always check official values first
2. **Customize for Environment**: Adjust based on your cluster resources
3. **Pin Versions**: Use specific versions for reproducibility
4. **Document Changes**: Keep track of why you changed defaults
5. **Test Incrementally**: Make one change at a time
6. **Use JCasC**: Configuration as Code is the modern way
7. **Monitor Resources**: Adjust based on actual usage

This configuration is production-ready for a local Minikube environment and follows SRE best practices!

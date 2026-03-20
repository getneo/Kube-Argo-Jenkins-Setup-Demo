# 06 - CI/CD Pipeline (Jenkins + ArgoCD)

## Overview

This guide covers the complete CI/CD pipeline implementation using Jenkins for Continuous Integration and ArgoCD for Continuous Deployment. We'll implement a GitOps workflow with automated testing, building, security scanning, and deployment.

---

## Architecture

```mermaid
sequenceDiagram
    participant Dev as Developer
    participant Git as Git Repository
    participant Jenkins as Jenkins CI
    participant Registry as Docker Registry
    participant ArgoCD as ArgoCD
    participant K8s as Kubernetes
    participant Prom as Prometheus

    Dev->>Git: 1. Push code changes
    Git->>Jenkins: 2. Webhook trigger

    rect rgb(200, 220, 240)
        Note over Jenkins: CI Pipeline
        Jenkins->>Jenkins: 3. Checkout code
        Jenkins->>Jenkins: 4. Run unit tests
        Jenkins->>Jenkins: 5. Run linting
        Jenkins->>Jenkins: 6. Build Docker image
        Jenkins->>Jenkins: 7. Security scan (Trivy)
        Jenkins->>Registry: 8. Push image
        Jenkins->>Git: 9. Update manifests
    end

    rect rgb(220, 240, 200)
        Note over ArgoCD: CD Pipeline
        ArgoCD->>Git: 10. Detect changes
        ArgoCD->>ArgoCD: 11. Validate manifests
        ArgoCD->>K8s: 12. Apply changes
        K8s->>K8s: 13. Rolling update
        K8s->>ArgoCD: 14. Health status
    end

    K8s->>Prom: 15. Expose metrics
    Prom->>Dev: 16. Alert if issues
    ArgoCD->>Dev: 17. Deployment notification
```

### Pipeline Stages

**CI Pipeline (Jenkins):**

1. Code Checkout
2. Unit Testing
3. Code Linting
4. Build Docker Image
5. Security Scanning
6. Push to Registry
7. Update Kubernetes Manifests

**CD Pipeline (ArgoCD):**

1. Detect Manifest Changes
2. Validate Resources
3. Sync to Cluster
4. Health Assessment
5. Notification

---

## 1. Create Jenkinsfile

### 1.1 Complete Jenkinsfile

Create `Jenkinsfile`:

```groovy
// Jenkinsfile for Demo Application CI/CD Pipeline
// This pipeline builds, tests, and deploys the application

// Pipeline configuration
pipeline {
    agent {
        kubernetes {
            label 'docker-agent'
            yaml """
apiVersion: v1
kind: Pod
metadata:
  labels:
    jenkins: agent
spec:
  serviceAccountName: jenkins
  containers:
  - name: docker
    image: docker:24-dind
    command:
    - dockerd
    - --host=unix:///var/run/docker.sock
    - --host=tcp://0.0.0.0:2375
    securityContext:
      privileged: true
    volumeMounts:
    - name: docker-sock
      mountPath: /var/run
  - name: kubectl
    image: bitnami/kubectl:latest
    command:
    - cat
    tty: true
  - name: trivy
    image: aquasec/trivy:latest
    command:
    - cat
    tty: true
  - name: golang
    image: golang:1.21
    command:
    - cat
    tty: true
  volumes:
  - name: docker-sock
    emptyDir: {}
"""
        }
    }

    // Environment variables
    environment {
        // Docker registry
        DOCKER_REGISTRY = 'docker.io'
        DOCKER_REPO = 'your-username/demo-app'
        DOCKER_CREDENTIALS = 'docker-registry-creds'

        // Git repository
        GIT_REPO = 'https://github.com/your-username/your-repo.git'
        GIT_CREDENTIALS = 'git-credentials'

        // Application
        APP_NAME = 'demo-app'
        APP_NAMESPACE = 'demo-app'

        // Build info
        BUILD_VERSION = "${env.BUILD_NUMBER}"
        GIT_COMMIT_SHORT = sh(
            script: "git rev-parse --short HEAD",
            returnStdout: true
        ).trim()
        IMAGE_TAG = "${BUILD_VERSION}-${GIT_COMMIT_SHORT}"
    }

    // Build options
    options {
        buildDiscarder(logRotator(numToKeepStr: '10'))
        timestamps()
        timeout(time: 30, unit: 'MINUTES')
        disableConcurrentBuilds()
    }

    // Triggers
    triggers {
        // Poll SCM every 5 minutes
        pollSCM('H/5 * * * *')

        // GitHub webhook
        githubPush()
    }

    // Pipeline stages
    stages {
        stage('Checkout') {
            steps {
                script {
                    echo "🔄 Checking out code..."
                    checkout scm

                    // Get commit info
                    env.GIT_COMMIT_MSG = sh(
                        script: 'git log -1 --pretty=%B',
                        returnStdout: true
                    ).trim()
                    env.GIT_AUTHOR = sh(
                        script: 'git log -1 --pretty=%an',
                        returnStdout: true
                    ).trim()

                    echo "Commit: ${env.GIT_COMMIT_SHORT}"
                    echo "Author: ${env.GIT_AUTHOR}"
                    echo "Message: ${env.GIT_COMMIT_MSG}"
                }
            }
        }

        stage('Test') {
            steps {
                container('golang') {
                    script {
                        echo "🧪 Running tests..."
                        dir('app') {
                            sh '''
                                go mod download
                                go test -v -race -coverprofile=coverage.out ./...
                                go tool cover -func=coverage.out
                            '''
                        }
                    }
                }
            }
            post {
                always {
                    // Archive test results
                    archiveArtifacts artifacts: 'app/coverage.out', allowEmptyArchive: true
                }
            }
        }

        stage('Lint') {
            steps {
                container('golang') {
                    script {
                        echo "🔍 Running linter..."
                        dir('app') {
                            sh '''
                                go fmt ./...
                                go vet ./...
                            '''
                        }
                    }
                }
            }
        }

        stage('Build Image') {
            steps {
                container('docker') {
                    script {
                        echo "🏗️ Building Docker image..."
                        dir('app') {
                            sh """
                                docker build \
                                    --build-arg VERSION=${IMAGE_TAG} \
                                    -t ${DOCKER_REPO}:${IMAGE_TAG} \
                                    -t ${DOCKER_REPO}:latest \
                                    .
                            """
                        }
                    }
                }
            }
        }

        stage('Security Scan') {
            steps {
                container('trivy') {
                    script {
                        echo "🔒 Scanning image for vulnerabilities..."
                        sh """
                            trivy image \
                                --severity HIGH,CRITICAL \
                                --exit-code 0 \
                                --no-progress \
                                ${DOCKER_REPO}:${IMAGE_TAG}
                        """
                    }
                }
            }
        }

        stage('Push Image') {
            steps {
                container('docker') {
                    script {
                        echo "📦 Pushing image to registry..."
                        docker.withRegistry("https://${DOCKER_REGISTRY}", DOCKER_CREDENTIALS) {
                            sh """
                                docker push ${DOCKER_REPO}:${IMAGE_TAG}
                                docker push ${DOCKER_REPO}:latest
                            """
                        }
                        echo "✅ Image pushed: ${DOCKER_REPO}:${IMAGE_TAG}"
                    }
                }
            }
        }

        stage('Update Manifests') {
            steps {
                container('kubectl') {
                    script {
                        echo "📝 Updating Kubernetes manifests..."

                        // Clone manifest repository
                        withCredentials([usernamePassword(
                            credentialsId: GIT_CREDENTIALS,
                            usernameVariable: 'GIT_USERNAME',
                            passwordVariable: 'GIT_PASSWORD' //pragma: allowlist secret
                        )]) {
                            sh """
                                git config --global user.email "jenkins@example.com"
                                git config --global user.name "Jenkins CI"

                                # Update image tag in kustomization
                                cd k8s/overlays/dev
                                kustomize edit set image ${DOCKER_REPO}:${IMAGE_TAG}

                                # Commit and push
                                git add .
                                git commit -m "Update image to ${IMAGE_TAG}" || true
                                git push https://${GIT_USERNAME}:${GIT_PASSWORD}@github.com/your-username/your-repo.git HEAD:main
                            """
                        }

                        echo "✅ Manifests updated"
                    }
                }
            }
        }

        stage('Trigger ArgoCD Sync') {
            steps {
                container('kubectl') {
                    script {
                        echo "🔄 Triggering ArgoCD sync..."
                        sh """
                            # Install ArgoCD CLI
                            curl -sSL -o /usr/local/bin/argocd https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
                            chmod +x /usr/local/bin/argocd

                            # Login to ArgoCD
                            argocd login argocd-server.argocd.svc.cluster.local:443 \
                                --username admin \
                                --password \$(kubectl get secret argocd-initial-admin-secret -n argocd -o jsonpath="{.data.password}" | base64 -d) \
                                --insecure

                            # Sync application
                            argocd app sync ${APP_NAME} --force

                            # Wait for sync to complete
                            argocd app wait ${APP_NAME} --timeout 300
                        """
                        echo "✅ ArgoCD sync completed"
                    }
                }
            }
        }

        stage('Verify Deployment') {
            steps {
                container('kubectl') {
                    script {
                        echo "✅ Verifying deployment..."
                        sh """
                            # Wait for rollout
                            kubectl rollout status deployment/${APP_NAME} -n ${APP_NAMESPACE} --timeout=5m

                            # Check pod status
                            kubectl get pods -n ${APP_NAMESPACE} -l app=${APP_NAME}

                            # Test health endpoint
                            POD=\$(kubectl get pod -n ${APP_NAMESPACE} -l app=${APP_NAME} -o jsonpath='{.items[0].metadata.name}')
                            kubectl exec -n ${APP_NAMESPACE} \$POD -- wget -q -O- http://localhost:8080/health
                        """
                        echo "✅ Deployment verified"
                    }
                }
            }
        }
    }

    // Post-build actions
    post {
        success {
            script {
                echo "✅ Pipeline completed successfully!"

                // Send notification
                slackSend(
                    color: 'good',
                    message: """
                        ✅ Deployment Successful
                        Application: ${APP_NAME}
                        Version: ${IMAGE_TAG}
                        Commit: ${env.GIT_COMMIT_SHORT}
                        Author: ${env.GIT_AUTHOR}
                        Build: ${env.BUILD_URL}
                    """
                )
            }
        }

        failure {
            script {
                echo "❌ Pipeline failed!"

                // Send notification
                slackSend(
                    color: 'danger',
                    message: """
                        ❌ Deployment Failed
                        Application: ${APP_NAME}
                        Version: ${IMAGE_TAG}
                        Commit: ${env.GIT_COMMIT_SHORT}
                        Author: ${env.GIT_AUTHOR}
                        Build: ${env.BUILD_URL}
                    """
                )
            }
        }

        always {
            script {
                // Clean up
                echo "🧹 Cleaning up..."
                cleanWs()
            }
        }
    }
}
```

### 1.2 Simplified Jenkinsfile (for testing)

Create `Jenkinsfile.simple`:

```groovy
pipeline {
    agent {
        kubernetes {
            label 'docker-agent'
            defaultContainer 'docker'
        }
    }

    environment {
        DOCKER_REPO = 'your-username/demo-app'
        IMAGE_TAG = "${env.BUILD_NUMBER}"
    }

    stages {
        stage('Build') {
            steps {
                sh 'docker build -t ${DOCKER_REPO}:${IMAGE_TAG} app/'
            }
        }

        stage('Test') {
            steps {
                sh 'docker run --rm ${DOCKER_REPO}:${IMAGE_TAG} go test ./...'
            }
        }

        stage('Push') {
            steps {
                withDockerRegistry([credentialsId: 'docker-registry-creds']) {
                    sh 'docker push ${DOCKER_REPO}:${IMAGE_TAG}'
                }
            }
        }
    }
}
```

---

## 2. Create Jenkins Pipeline Job

### 2.1 Create Pipeline via UI

1. Open Jenkins: `http://localhost:8080`
2. Click **New Item**
3. Enter name: `demo-app-pipeline`
4. Select **Pipeline**
5. Click **OK**

Configure pipeline:

- **Description**: Demo application CI/CD pipeline
- **Build Triggers**:
  - ☑ GitHub hook trigger for GITScm polling
  - ☑ Poll SCM: `H/5 * * * *`
- **Pipeline**:
  - Definition: Pipeline script from SCM
  - SCM: Git
  - Repository URL: `https://github.com/your-username/your-repo.git`
  - Credentials: Select your Git credentials
  - Branch: `*/main`
  - Script Path: `Jenkinsfile`

### 2.2 Create Pipeline via JCasC

Add to Jenkins values.yaml:

```yaml
controller:
  JCasC:
    configScripts:
      jobs: |
        jobs:
          - script: >
              pipelineJob('demo-app-pipeline') {
                description('Demo application CI/CD pipeline')

                triggers {
                  githubPush()
                  scm('H/5 * * * *')
                }

                definition {
                  cpsScm {
                    scm {
                      git {
                        remote {
                          url('https://github.com/your-username/your-repo.git')
                          credentials('git-credentials')
                        }
                        branch('*/main')
                      }
                    }
                    scriptPath('Jenkinsfile')
                  }
                }
              }
```

---

## 3. Configure GitHub Webhook

### 3.1 Create Webhook in GitHub

1. Go to your GitHub repository
2. Navigate to **Settings** → **Webhooks**
3. Click **Add webhook**
4. Configure:
   - **Payload URL**: `http://jenkins.local/github-webhook/`
   - **Content type**: `application/json`
   - **Events**: Just the push event
   - **Active**: ☑
5. Click **Add webhook**

### 3.2 Test Webhook

```bash
# Make a commit and push
git commit --allow-empty -m "Test webhook"
git push origin main

# Check Jenkins for triggered build
```

---

## 4. Configure ArgoCD Application

### 4.1 Create ArgoCD Application

Create `argocd/application.yaml`:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: demo-app
  namespace: argocd
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: default

  source:
    repoURL: https://github.com/your-username/your-repo.git
    targetRevision: main
    path: k8s/overlays/dev

  destination:
    server: https://kubernetes.default.svc
    namespace: demo-app

  syncPolicy:
    automated:
      prune: true
      selfHeal: true
      allowEmpty: false

    syncOptions:
      - CreateNamespace=true
      - PrunePropagationPolicy=foreground
      - PruneLast=true

    retry:
      limit: 5
      backoff:
        duration: 5s
        factor: 2
        maxDuration: 3m

  revisionHistoryLimit: 10
```

Apply:

```bash
kubectl apply -f argocd/application.yaml

# Verify
argocd app get demo-app
argocd app sync demo-app
```

---

## 5. Create Kubernetes Manifests

### 5.1 Base Manifests

Create `k8s/base/deployment.yaml`:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: demo-app
  labels:
    app: demo-app
spec:
  replicas: 2
  selector:
    matchLabels:
      app: demo-app
  template:
    metadata:
      labels:
        app: demo-app
      annotations:
        prometheus.io/scrape: "true"
        prometheus.io/port: "8080"
        prometheus.io/path: "/metrics"
    spec:
      serviceAccountName: demo-app
      securityContext:
        runAsNonRoot: true
        runAsUser: 65534
        fsGroup: 65534

      containers:
        - name: demo-app
          image: your-username/demo-app:latest
          imagePullPolicy: Always

          ports:
            - name: http
              containerPort: 8080
              protocol: TCP

          env:
            - name: PORT
              value: "8080"
            - name: LOG_LEVEL
              value: "info"

          resources:
            requests:
              cpu: 100m
              memory: 128Mi
            limits:
              cpu: 500m
              memory: 512Mi

          livenessProbe:
            httpGet:
              path: /live
              port: http
            initialDelaySeconds: 30
            periodSeconds: 10
            timeoutSeconds: 3
            failureThreshold: 3

          readinessProbe:
            httpGet:
              path: /ready
              port: http
            initialDelaySeconds: 10
            periodSeconds: 5
            timeoutSeconds: 3
            failureThreshold: 3

          startupProbe:
            httpGet:
              path: /health
              port: http
            initialDelaySeconds: 0
            periodSeconds: 5
            timeoutSeconds: 3
            failureThreshold: 30

          securityContext:
            allowPrivilegeEscalation: false
            readOnlyRootFilesystem: true
            runAsNonRoot: true
            runAsUser: 65534
            capabilities:
              drop:
                - ALL

          volumeMounts:
            - name: tmp
              mountPath: /tmp

      volumes:
        - name: tmp
          emptyDir: {}
```

Create `k8s/base/service.yaml`:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: demo-app
  labels:
    app: demo-app
spec:
  type: ClusterIP
  ports:
    - port: 80
      targetPort: http
      protocol: TCP
      name: http
  selector:
    app: demo-app
```

Create `k8s/base/serviceaccount.yaml`:

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: demo-app
  labels:
    app: demo-app
```

Create `k8s/base/kustomization.yaml`:

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - deployment.yaml
  - service.yaml
  - serviceaccount.yaml

commonLabels:
  app: demo-app
  managed-by: kustomize

images:
  - name: your-username/demo-app
    newTag: latest
```

### 5.2 Development Overlay

Create `k8s/overlays/dev/kustomization.yaml`:

```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: demo-app

bases:
  - ../../base

namePrefix: dev-

commonLabels:
  environment: development

replicas:
  - name: demo-app
    count: 1

images:
  - name: your-username/demo-app
    newTag: latest

configMapGenerator:
  - name: app-config
    literals:
      - LOG_LEVEL=debug
      - ENVIRONMENT=development

patchesStrategicMerge:
  - deployment-patch.yaml
```

Create `k8s/overlays/dev/deployment-patch.yaml`:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: demo-app
spec:
  template:
    spec:
      containers:
        - name: demo-app
          env:
            - name: LOG_LEVEL
              value: "debug"
```

---

## 6. Pipeline Testing

### 6.1 Test CI Pipeline

```bash
# Trigger build manually
curl -X POST http://jenkins.local/job/demo-app-pipeline/build \
  --user admin:your-password

# Or via Jenkins UI
# Navigate to demo-app-pipeline → Build Now

# Watch build progress
# Navigate to demo-app-pipeline → Build #X → Console Output
```

### 6.2 Test CD Pipeline

```bash
# Check ArgoCD application status
argocd app get demo-app

# Sync manually
argocd app sync demo-app

# Watch sync progress
argocd app wait demo-app --timeout 300

# Check deployment
kubectl get pods -n demo-app
kubectl get deployment -n demo-app
```

### 6.3 End-to-End Test

```bash
# Make a code change
echo "// Test change" >> app/main.go

# Commit and push
git add .
git commit -m "Test CI/CD pipeline"
git push origin main

# Watch Jenkins build
# Jenkins should automatically trigger

# Watch ArgoCD sync
argocd app get demo-app --watch

# Verify deployment
kubectl get pods -n demo-app -w
```

---

## 7. Rollback Strategy

### 7.1 Rollback via ArgoCD

```bash
# View application history
argocd app history demo-app

# Rollback to previous version
argocd app rollback demo-app <revision-number>

# Or rollback to previous
argocd app rollback demo-app
```

### 7.2 Rollback via kubectl

```bash
# View rollout history
kubectl rollout history deployment/demo-app -n demo-app

# Rollback to previous version
kubectl rollout undo deployment/demo-app -n demo-app

# Rollback to specific revision
kubectl rollout undo deployment/demo-app -n demo-app --to-revision=2
```

### 7.3 Automated Rollback

Add to Jenkinsfile:

```groovy
stage('Verify Deployment') {
    steps {
        script {
            try {
                // Verify deployment
                sh 'kubectl rollout status deployment/demo-app -n demo-app --timeout=5m'

                // Run smoke tests
                sh './scripts/smoke-test.sh'
            } catch (Exception e) {
                echo "Deployment verification failed, rolling back..."
                sh 'kubectl rollout undo deployment/demo-app -n demo-app'
                error("Deployment failed verification")
            }
        }
    }
}
```

---

## 8. Blue-Green Deployment

### 8.1 Blue-Green Strategy

Create `k8s/base/deployment-blue.yaml` and `deployment-green.yaml`:

```yaml
# Blue deployment
apiVersion: apps/v1
kind: Deployment
metadata:
  name: demo-app-blue
  labels:
    app: demo-app
    version: blue
spec:
  replicas: 2
  selector:
    matchLabels:
      app: demo-app
      version: blue
  template:
    metadata:
      labels:
        app: demo-app
        version: blue
    spec:
      # ... same as before
```

Service with selector:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: demo-app
spec:
  selector:
    app: demo-app
    version: blue  # Switch to green for cutover
  ports:
    - port: 80
      targetPort: 8080
```

### 8.2 Canary Deployment

Use ArgoCD Rollouts:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Rollout
metadata:
  name: demo-app
spec:
  replicas: 5
  strategy:
    canary:
      steps:
        - setWeight: 20
        - pause: {duration: 1m}
        - setWeight: 40
        - pause: {duration: 1m}
        - setWeight: 60
        - pause: {duration: 1m}
        - setWeight: 80
        - pause: {duration: 1m}
  selector:
    matchLabels:
      app: demo-app
  template:
    # ... pod template
```

---

## 9. Pipeline Optimization

### 9.1 Parallel Stages

```groovy
stage('Parallel Tests') {
    parallel {
        stage('Unit Tests') {
            steps {
                sh 'go test ./...'
            }
        }
        stage('Integration Tests') {
            steps {
                sh './scripts/integration-test.sh'
            }
        }
        stage('Security Scan') {
            steps {
                sh 'trivy image demo-app:latest'
            }
        }
    }
}
```

### 9.2 Caching

```groovy
stage('Build with Cache') {
    steps {
        sh '''
            docker build \
                --cache-from ${DOCKER_REPO}:latest \
                -t ${DOCKER_REPO}:${IMAGE_TAG} \
                .
        '''
    }
}
```

### 9.3 Build Matrix

```groovy
matrix {
    axes {
        axis {
            name 'PLATFORM'
            values 'linux/amd64', 'linux/arm64'
        }
    }
    stages {
        stage('Build') {
            steps {
                sh "docker buildx build --platform ${PLATFORM} ."
            }
        }
    }
}
```

---

## 10. Monitoring Pipeline

### 10.1 Pipeline Metrics

Jenkins exposes metrics at `/prometheus`:

```yaml
# ServiceMonitor for Jenkins
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: jenkins
  namespace: monitoring
spec:
  selector:
    matchLabels:
      app.kubernetes.io/name: jenkins
  endpoints:
    - port: http
      path: /prometheus
```

### 10.2 Pipeline Alerts

```yaml
# Alert on pipeline failures
- alert: JenkinsPipelineFailure
  expr: jenkins_builds_failed_total > 0
  for: 5m
  labels:
    severity: warning
  annotations:
    summary: "Jenkins pipeline failures detected"
    description: "{{ $value }} pipeline failures in the last 5 minutes"
```

---

## 11. Troubleshooting

### Issue 1: Pipeline Fails at Build Stage

```bash
# Check Jenkins logs
kubectl logs -n jenkins jenkins-0 -c jenkins

# Check agent pod
kubectl get pods -n jenkins -l jenkins=agent

# Debug agent
kubectl logs -n jenkins <agent-pod>
```

### Issue 2: ArgoCD Not Syncing

```bash
# Check ArgoCD application
argocd app get demo-app

# Check sync status
argocd app diff demo-app

# Force sync
argocd app sync demo-app --force

# Check ArgoCD logs
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-application-controller
```

### Issue 3: Image Pull Errors

```bash
# Check image exists
docker pull your-username/demo-app:latest

# Check image pull secret
kubectl get secret -n demo-app

# Create image pull secret
kubectl create secret docker-registry regcred \
  --docker-server=docker.io \
  --docker-username=your-username \
  --docker-password=your-password \
  -n demo-app
```

---

## 12. Best Practices

### 12.1 Pipeline Best Practices

- ✅ Use declarative pipelines
- ✅ Implement proper error handling
- ✅ Add timeout to stages
- ✅ Use credentials securely
- ✅ Clean up after builds
- ✅ Send notifications
- ✅ Archive artifacts
- ✅ Run tests in parallel
- ✅ Use caching
- ✅ Implement rollback strategy

### 12.2 GitOps Best Practices

- ✅ Separate app code and manifests
- ✅ Use Kustomize or Helm
- ✅ Version control everything
- ✅ Implement RBAC
- ✅ Use sync waves
- ✅ Add health checks
- ✅ Enable auto-sync carefully
- ✅ Monitor sync status
- ✅ Test in lower environments first

---

## 13. Useful Commands

```bash
# Jenkins
kubectl port-forward -n jenkins svc/jenkins 8080:8080
kubectl logs -n jenkins jenkins-0 -c jenkins -f

# ArgoCD
argocd app list
argocd app get demo-app
argocd app sync demo-app
argocd app history demo-app
argocd app rollback demo-app

# Kubernetes
kubectl get pods -n demo-app
kubectl logs -n demo-app -l app=demo-app -f
kubectl describe deployment demo-app -n demo-app
kubectl rollout status deployment/demo-app -n demo-app
kubectl rollout history deployment/demo-app -n demo-app
kubectl rollout undo deployment/demo-app -n demo-app
```

---

## 14. Next Steps

Now that the CI/CD pipeline is set up, proceed to:

- **[07-security-practices.md](./07-security-practices.md)** - Implement security best practices

---

## Additional Resources

- [Jenkins Pipeline Documentation](https://www.jenkins.io/doc/book/pipeline/)
- [ArgoCD Documentation](https://argo-cd.readthedocs.io/)
- [GitOps Principles](https://www.gitops.tech/)
- [Kubernetes Deployment Strategies](https://kubernetes.io/docs/concepts/workloads/controllers/deployment/)
- [Jenkins Kubernetes Plugin](https://plugins.jenkins.io/kubernetes/)

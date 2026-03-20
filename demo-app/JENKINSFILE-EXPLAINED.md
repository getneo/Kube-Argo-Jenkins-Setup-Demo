# Jenkinsfile - Detailed Explanation

This document provides a comprehensive explanation of the Jenkins CI pipeline defined in the `Jenkinsfile`.

## Table of Contents
1. [Overview](#overview)
2. [Pipeline Structure](#pipeline-structure)
3. [Environment Variables](#environment-variables)
4. [Pipeline Options](#pipeline-options)
5. [Stages Breakdown](#stages-breakdown)
6. [Post Actions](#post-actions)
7. [Customization Guide](#customization-guide)
8. [Best Practices](#best-practices)

---

## Overview

### What is a Jenkinsfile?

A Jenkinsfile is a text file that contains the definition of a Jenkins Pipeline. It uses a Groovy-based DSL (Domain Specific Language) to define the CI/CD workflow.

### Pipeline Type

This is a **Declarative Pipeline**, which:
- Uses a predefined structure
- Is easier to read and write
- Has built-in syntax validation
- Supports most common use cases

**Alternative**: Scripted Pipeline (more flexible, more complex)

### What This Pipeline Does

```
1. Checkout code from Git
2. Build Go application
3. Run tests and generate coverage
4. Build Docker image
5. Scan image for vulnerabilities
6. Push image to registry
7. Update Kubernetes manifests
```

---

## Pipeline Structure

### Basic Structure

```groovy
pipeline {
    agent any              // Where to run
    environment { }        // Variables
    options { }           // Pipeline options
    stages { }            // What to do
    post { }              // Cleanup/notifications
}
```

### Agent Section

```groovy
agent any
```

**Explanation**:
- `agent`: Specifies where the pipeline runs
- `any`: Run on any available Jenkins agent/node

**Other Options**:
```groovy
// Run on specific label
agent {
    label 'docker'
}

// Run in Docker container
agent {
    docker {
        image 'golang:1.21'
    }
}

// Run on specific node
agent {
    node {
        label 'linux && docker'
    }
}

// No agent (define per stage)
agent none
```

---

## Environment Variables

```groovy
environment {
    APP_NAME = 'demo-app'
    APP_VERSION = "${env.BUILD_NUMBER}"
    DOCKER_REGISTRY = 'docker.io'
    DOCKER_IMAGE = "${DOCKER_REGISTRY}/your-username/${APP_NAME}"
    GIT_REPO = 'https://github.com/your-username/CKA.git'
    GIT_BRANCH = 'main'
    DOCKER_CREDENTIALS_ID = 'docker-registry-credentials'
    GIT_CREDENTIALS_ID = 'git-credentials'
    GIT_COMMIT_SHORT = sh(
        script: "git rev-parse --short HEAD",
        returnStdout: true
    ).trim()
    BUILD_TIME = sh(
        script: "date -u +%Y-%m-%dT%H:%M:%SZ",
        returnStdout: true
    ).trim()
}
```

### Variable Types

#### 1. Static Variables
```groovy
APP_NAME = 'demo-app'
```
- Fixed value
- Same for all builds

#### 2. Dynamic Variables
```groovy
APP_VERSION = "${env.BUILD_NUMBER}"
```
- Changes per build
- Uses Jenkins environment variables

#### 3. Computed Variables
```groovy
GIT_COMMIT_SHORT = sh(
    script: "git rev-parse --short HEAD",
    returnStdout: true
).trim()
```
- Executes shell command
- Captures output
- Trims whitespace

### Built-in Jenkins Variables

```groovy
${env.BUILD_NUMBER}      // Build number (1, 2, 3, ...)
${env.BUILD_ID}          // Build ID (timestamp)
${env.JOB_NAME}          // Job name
${env.BUILD_URL}         // Build URL
${env.WORKSPACE}         // Workspace directory
${env.GIT_COMMIT}        // Full Git commit SHA
${env.GIT_BRANCH}        // Git branch name
```

### Credentials

```groovy
DOCKER_CREDENTIALS_ID = 'docker-registry-credentials'
GIT_CREDENTIALS_ID = 'git-credentials'
```

**How to Use**:
```groovy
withCredentials([usernamePassword(
    credentialsId: "${DOCKER_CREDENTIALS_ID}",
    usernameVariable: 'DOCKER_USER',
    passwordVariable: 'DOCKER_PASS'// pragma: allowlist secret
)]) {
    sh 'echo $DOCKER_PASS | docker login -u $DOCKER_USER --password-stdin'
}
```

**Credential Types**:
- Username with password
- Secret text
- SSH key
- Certificate
- Secret file

---

## Pipeline Options

```groovy
options {
    buildDiscarder(logRotator(numToKeepStr: '10'))
    timeout(time: 30, unit: 'MINUTES')
    disableConcurrentBuilds()
    timestamps()
}
```

### buildDiscarder

```groovy
buildDiscarder(logRotator(numToKeepStr: '10'))
```

**Purpose**: Automatically delete old builds

**Options**:
```groovy
buildDiscarder(logRotator(
    numToKeepStr: '10',        // Keep last 10 builds
    daysToKeepStr: '30',       // Keep builds from last 30 days
    artifactNumToKeepStr: '5', // Keep artifacts from last 5 builds
    artifactDaysToKeepStr: '7' // Keep artifacts from last 7 days
))
```

### timeout

```groovy
timeout(time: 30, unit: 'MINUTES')
```

**Purpose**: Abort build if it takes too long

**Units**: SECONDS, MINUTES, HOURS, DAYS

**Why?**
- Prevents stuck builds
- Frees up resources
- Catches infinite loops

### disableConcurrentBuilds

```groovy
disableConcurrentBuilds()
```

**Purpose**: Only one build at a time

**Why?**
- Prevents resource conflicts
- Avoids Docker image tag conflicts
- Ensures sequential deployments

**Alternative**:
```groovy
// Allow concurrent builds
options {
    // No disableConcurrentBuilds()
}
```

### timestamps

```groovy
timestamps()
```

**Purpose**: Add timestamps to console output

**Output**:
```
[2024-01-01 10:30:45] Checking out code...
[2024-01-01 10:30:50] Building application...
```

---

## Stages Breakdown

### Stage 1: Checkout

```groovy
stage('Checkout') {
    steps {
        script {
            echo "Checking out code from ${GIT_REPO}"
        }
        checkout scm
        sh 'git log -1 --pretty=format:"Commit: %h%nAuthor: %an%nDate: %ad%nMessage: %s"'
    }
}
```

**What it does**:
1. Prints information about the checkout
2. Checks out code from Git
3. Displays last commit information

**`checkout scm`**:
- `scm`: Source Code Management
- Automatically uses Git configuration from Jenkins job
- Checks out the branch that triggered the build

**Alternative**:
```groovy
// Explicit Git checkout
checkout([
    $class: 'GitSCM',
    branches: [[name: '*/main']],
    userRemoteConfigs: [[
        url: 'https://github.com/user/repo.git',
        credentialsId: 'git-credentials'
    ]]
])
```

### Stage 2: Build & Test

```groovy
stage('Build & Test') {
    steps {
        dir('demo-app') {
            sh 'go mod download'
            sh 'go test -v -race -coverprofile=coverage.out ./...'
            sh 'go tool cover -html=coverage.out -o coverage.html'
            sh '''
                CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build \
                    -ldflags="-w -s \
                    -X main.Version=${APP_VERSION} \
                    -X main.BuildTime=${BUILD_TIME} \
                    -X main.GitCommit=${GIT_COMMIT_SHORT}" \
                    -o bin/demo-app \
                    cmd/server/main.go
            '''
        }
    }
}
```

**What it does**:
1. Downloads Go dependencies
2. Runs tests with race detection
3. Generates coverage report
4. Builds static binary

**`dir('demo-app')`**:
- Changes to demo-app directory
- All commands run in this directory
- Returns to original directory after block

**Go Build Flags**:
```bash
CGO_ENABLED=0          # Disable CGO (static binary)
GOOS=linux             # Target OS
GOARCH=amd64           # Target architecture

-ldflags="-w -s"       # Strip debug info (smaller binary)
-X main.Version=...    # Set version variable
```

**Test Flags**:
```bash
-v                     # Verbose output
-race                  # Race condition detection
-coverprofile=...      # Coverage report file
./...                  # All packages
```

### Stage 3: Docker Build

```groovy
stage('Docker Build') {
    steps {
        dir('demo-app') {
            sh """
                docker build \
                    --build-arg VERSION=${APP_VERSION} \
                    --build-arg BUILD_TIME=${BUILD_TIME} \
                    --build-arg GIT_COMMIT=${GIT_COMMIT_SHORT} \
                    -t ${DOCKER_IMAGE}:${APP_VERSION} \
                    -t ${DOCKER_IMAGE}:${GIT_COMMIT_SHORT} \
                    -t ${DOCKER_IMAGE}:latest \
                    .
            """
        }
    }
}
```

**What it does**:
1. Builds Docker image
2. Tags with multiple tags
3. Passes build arguments

**Multiple Tags**:
```bash
-t demo-app:1.0.0      # Version tag
-t demo-app:abc123     # Commit tag
-t demo-app:latest     # Latest tag
```

**Why multiple tags?**
- Version tag: For specific deployments
- Commit tag: For traceability
- Latest tag: For development

**Build Arguments**:
```dockerfile
# In Dockerfile
ARG VERSION
ARG BUILD_TIME
ARG GIT_COMMIT

# Used in labels
LABEL version="${VERSION}"
```

### Stage 4: Security Scan

```groovy
stage('Security Scan') {
    steps {
        sh """
            trivy image \
                --severity HIGH,CRITICAL \
                --format table \
                --output trivy-report.txt \
                ${DOCKER_IMAGE}:${APP_VERSION}
        """
    }
    post {
        always {
            archiveArtifacts artifacts: 'trivy-report.txt'
        }
    }
}
```

**What it does**:
1. Installs Trivy (if needed)
2. Scans Docker image
3. Generates report
4. Archives report

**Trivy Options**:
```bash
--severity HIGH,CRITICAL    # Only show high/critical
--format table              # Table format (also: json, sarif)
--output trivy-report.txt   # Save to file
--exit-code 1               # Fail on vulnerabilities
```

**Severity Levels**:
- CRITICAL: Immediate action required
- HIGH: Action required soon
- MEDIUM: Should be fixed
- LOW: Nice to fix
- UNKNOWN: Unknown severity

**Optional: Fail on Critical**:
```groovy
sh """
    trivy image \
        --exit-code 1 \
        --severity CRITICAL \
        ${DOCKER_IMAGE}:${APP_VERSION}
"""
```

### Stage 5: Push Image

```groovy
stage('Push Image') {
    steps {
        withCredentials([usernamePassword(
            credentialsId: "${DOCKER_CREDENTIALS_ID}",
            usernameVariable: 'DOCKER_USER',
            passwordVariable: 'DOCKER_PASS' //pragma: allowlist secret
        )]) {
            sh """
                echo \$DOCKER_PASS | docker login ${DOCKER_REGISTRY} -u \$DOCKER_USER --password-stdin
                docker push ${DOCKER_IMAGE}:${APP_VERSION}
                docker push ${DOCKER_IMAGE}:${GIT_COMMIT_SHORT}
                docker push ${DOCKER_IMAGE}:latest
                docker logout ${DOCKER_REGISTRY}
            """
        }
    }
}
```

**What it does**:
1. Retrieves credentials from Jenkins
2. Logs in to Docker registry
3. Pushes all image tags
4. Logs out

**withCredentials**:
- Securely injects credentials
- Credentials masked in logs
- Automatically cleaned up after block

**Security Best Practices**:
```bash
# ✅ Good: Use --password-stdin
echo $PASS | docker login -u $USER --password-stdin

# ❌ Bad: Password in command
docker login -u $USER -p $PASS  # Visible in logs!
```

### Stage 6: Update Manifests

```groovy
stage('Update Manifests') {
    steps {
        withCredentials([usernamePassword(
            credentialsId: "${GIT_CREDENTIALS_ID}",
            usernameVariable: 'GIT_USER',
            passwordVariable: 'GIT_PASS' //pragma: allowlist secret
        )]) {
            sh """
                git config user.email "jenkins@example.com"
                git config user.name "Jenkins CI"

                cd demo-app/helm-chart/demo-app
                sed -i 's/tag: .*/tag: "${APP_VERSION}"/' values.yaml

                git add values.yaml
                git commit -m "chore: update image tag to ${APP_VERSION} [skip ci]"
                git push https://\${GIT_USER}:\${GIT_PASS}@github.com/user/repo.git HEAD:${GIT_BRANCH}
            """
        }
    }
}
```

**What it does**:
1. Configures Git user
2. Updates image tag in values.yaml
3. Commits change
4. Pushes to Git

**`[skip ci]` in commit message**:
- Prevents infinite loop
- Jenkins won't trigger on this commit
- ArgoCD will still detect the change

**sed command**:
```bash
sed -i 's/tag: .*/tag: "1.0.0"/' values.yaml

# Before:
tag: "latest"

# After:
tag: "1.0.0"
```

**Alternative: Use yq**:
```bash
yq eval '.image.tag = "1.0.0"' -i values.yaml
```

---

## Post Actions

```groovy
post {
    always { }
    success { }
    failure { }
    unstable { }
}
```

### always

```groovy
always {
    echo "Pipeline Completed"
    sh 'docker system prune -f'
    archiveArtifacts artifacts: 'demo-app/coverage.html'
}
```

**Runs**: Always, regardless of result

**Use for**:
- Cleanup
- Archiving artifacts
- Logging

### success

```groovy
success {
    echo "✓ Pipeline Succeeded!"
    // slackSend(color: 'good', message: "Build Successful")
}
```

**Runs**: Only if pipeline succeeds

**Use for**:
- Success notifications
- Deployment triggers
- Metrics

### failure

```groovy
failure {
    echo "✗ Pipeline Failed!"
    // slackSend(color: 'danger', message: "Build Failed")
}
```

**Runs**: Only if pipeline fails

**Use for**:
- Failure notifications
- Alerting
- Rollback

### unstable

```groovy
unstable {
    echo "⚠ Pipeline Unstable"
}
```

**Runs**: If tests fail but build succeeds

**Use for**:
- Test failure notifications
- Quality gate warnings

---

## Customization Guide

### 1. Change Docker Registry

```groovy
// Docker Hub
DOCKER_REGISTRY = 'docker.io'
DOCKER_IMAGE = "${DOCKER_REGISTRY}/username/${APP_NAME}"

// AWS ECR
DOCKER_REGISTRY = '123456789.dkr.ecr.us-east-1.amazonaws.com'
DOCKER_IMAGE = "${DOCKER_REGISTRY}/${APP_NAME}"

// Google GCR
DOCKER_REGISTRY = 'gcr.io'
DOCKER_IMAGE = "${DOCKER_REGISTRY}/project-id/${APP_NAME}"

// Azure ACR
DOCKER_REGISTRY = 'myregistry.azurecr.io'
DOCKER_IMAGE = "${DOCKER_REGISTRY}/${APP_NAME}"
```

### 2. Add Slack Notifications

```groovy
post {
    success {
        slackSend(
            color: 'good',
            message: "Build Successful: ${env.JOB_NAME} #${env.BUILD_NUMBER}\n${env.BUILD_URL}"
        )
    }
    failure {
        slackSend(
            color: 'danger',
            message: "Build Failed: ${env.JOB_NAME} #${env.BUILD_NUMBER}\n${env.BUILD_URL}"
        )
    }
}
```

### 3. Add Email Notifications

```groovy
post {
    failure {
        emailext(
            subject: "Build Failed: ${env.JOB_NAME} #${env.BUILD_NUMBER}",
            body: "Check console output at ${env.BUILD_URL}",
            to: 'team@example.com'
        )
    }
}
```

### 4. Add SonarQube Analysis

```groovy
stage('Code Quality') {
    steps {
        withSonarQubeEnv('SonarQube') {
            sh 'sonar-scanner'
        }
    }
}
```

### 5. Add Parallel Stages

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
                sh 'go test -tags=integration ./...'
            }
        }
        stage('Lint') {
            steps {
                sh 'golangci-lint run'
            }
        }
    }
}
```

---

## Best Practices

### 1. Use Credentials Securely

✅ **Good**:
```groovy
withCredentials([...]) {
    sh 'echo $PASS | docker login --password-stdin'
}
```

❌ **Bad**:
```groovy
sh 'docker login -u user -p password'  // Visible in logs!
```

### 2. Clean Up Resources

✅ **Good**:
```groovy
post {
    always {
        sh 'docker system prune -f'
        cleanWs()  // Clean workspace
    }
}
```

### 3. Use Specific Image Tags

✅ **Good**:
```groovy
agent {
    docker {
        image 'golang:1.21-alpine'
    }
}
```

❌ **Bad**:
```groovy
agent {
    docker {
        image 'golang:latest'  // Unpredictable!
    }
}
```

### 4. Add Timeouts

✅ **Good**:
```groovy
options {
    timeout(time: 30, unit: 'MINUTES')
}
```

### 5. Archive Important Artifacts

✅ **Good**:
```groovy
post {
    always {
        archiveArtifacts artifacts: 'coverage.html, trivy-report.txt'
        junit 'test-results.xml'
    }
}
```

### 6. Use [skip ci] to Prevent Loops

✅ **Good**:
```groovy
git commit -m "chore: update version [skip ci]"
```

### 7. Validate Before Pushing

✅ **Good**:
```groovy
stage('Validate') {
    steps {
        sh 'helm lint demo-app/helm-chart/demo-app'
        sh 'kubectl apply --dry-run=client -f manifests/'
    }
}
```

---

## Summary

### Pipeline Flow

```
1. Checkout → 2. Build & Test → 3. Docker Build → 4. Security Scan → 5. Push Image → 6. Update Manifests
     ↓              ↓                  ↓                  ↓                ↓                  ↓
   Git SCM      Go Build          Multi-tag          Trivy Scan      Docker Push        Git Push
                Go Test           Image Build        Report Gen      All Tags           values.yaml
                Coverage                                                                 [skip ci]
```

### Key Features

- ✅ Automated build and test
- ✅ Multi-stage Docker build
- ✅ Security scanning with Trivy
- ✅ Multiple image tags
- ✅ GitOps integration
- ✅ Artifact archiving
- ✅ Proper cleanup
- ✅ Secure credential handling

### Customization Points

1. Docker registry URL
2. Git repository URL
3. Notification channels
4. Test commands
5. Security scan thresholds
6. Deployment targets

Happy CI/CD! 🚀

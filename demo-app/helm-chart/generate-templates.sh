#!/bin/bash

# Script to generate remaining Helm template files from Kubernetes manifests
# This converts the existing manifests to Helm templates

set -e

CHART_DIR="demo-app"
TEMPLATES_DIR="$CHART_DIR/templates"
K8S_DIR="../deployments/kubernetes"

echo "🚀 Generating Helm templates from Kubernetes manifests..."
echo ""

# Create templates directory if it doesn't exist
mkdir -p "$TEMPLATES_DIR"

# Function to create template header
create_header() {
    local file=$1
    local condition=$2

    if [ -n "$condition" ]; then
        echo "{{- if $condition -}}"
    fi
}

# Function to create template footer
create_footer() {
    local condition=$1

    if [ -n "$condition" ]; then
        echo "{{- end }}"
    fi
}

# Generate serviceaccount.yaml
echo "📝 Creating serviceaccount.yaml..."
cat > "$TEMPLATES_DIR/serviceaccount.yaml" << 'EOF'
{{- if .Values.serviceAccount.create -}}
apiVersion: v1
kind: ServiceAccount
metadata:
  name: {{ include "demo-app.serviceAccountName" . }}
  namespace: {{ include "demo-app.namespace" . }}
  labels:
    {{- include "demo-app.labels" . | nindent 4 }}
  {{- with .Values.serviceAccount.annotations }}
  annotations:
    {{- toYaml . | nindent 4 }}
  {{- end }}
automountServiceAccountToken: {{ .Values.serviceAccount.automountServiceAccountToken }}
{{- end }}
---
{{- if .Values.rbac.create -}}
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: {{ include "demo-app.fullname" . }}
  namespace: {{ include "demo-app.namespace" . }}
  labels:
    {{- include "demo-app.labels" . | nindent 4 }}
rules:
{{- toYaml .Values.rbac.rules | nindent 0 }}
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: {{ include "demo-app.fullname" . }}
  namespace: {{ include "demo-app.namespace" . }}
  labels:
    {{- include "demo-app.labels" . | nindent 4 }}
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: {{ include "demo-app.fullname" . }}
subjects:
- kind: ServiceAccount
  name: {{ include "demo-app.serviceAccountName" . }}
  namespace: {{ include "demo-app.namespace" . }}
{{- end }}
EOF

# Generate deployment.yaml
echo "📝 Creating deployment.yaml..."
cat > "$TEMPLATES_DIR/deployment.yaml" << 'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ include "demo-app.fullname" . }}
  namespace: {{ include "demo-app.namespace" . }}
  labels:
    {{- include "demo-app.labels" . | nindent 4 }}
    version: {{ .Values.app.version | quote }}
spec:
  {{- if not .Values.autoscaling.enabled }}
  replicas: {{ .Values.replicaCount }}
  {{- end }}
  strategy:
    {{- toYaml .Values.strategy | nindent 4 }}
  selector:
    matchLabels:
      {{- include "demo-app.selectorLabels" . | nindent 6 }}
  template:
    metadata:
      annotations:
        {{- with .Values.podAnnotations }}
        {{- toYaml . | nindent 8 }}
        {{- end }}
      labels:
        {{- include "demo-app.selectorLabels" . | nindent 8 }}
        {{- with .Values.podLabels }}
        {{- toYaml . | nindent 8 }}
        {{- end }}
        version: {{ .Values.app.version | quote }}
    spec:
      {{- with .Values.imagePullSecrets }}
      imagePullSecrets:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      serviceAccountName: {{ include "demo-app.serviceAccountName" . }}
      securityContext:
        {{- toYaml .Values.podSecurityContext | nindent 8 }}
      containers:
      - name: {{ .Chart.Name }}
        image: "{{ .Values.image.repository }}:{{ .Values.image.tag | default .Chart.AppVersion }}"
        imagePullPolicy: {{ .Values.image.pullPolicy }}
        securityContext:
          {{- toYaml .Values.securityContext | nindent 10 }}
        ports:
        - name: http
          containerPort: {{ .Values.service.targetPort }}
          protocol: TCP
        {{- if .Values.configMap.create }}
        envFrom:
        - configMapRef:
            name: {{ include "demo-app.fullname" . }}-config
        {{- end }}
        env:
        {{- toYaml .Values.env | nindent 8 }}
        resources:
          {{- toYaml .Values.resources | nindent 10 }}
        livenessProbe:
          {{- toYaml .Values.livenessProbe | nindent 10 }}
        readinessProbe:
          {{- toYaml .Values.readinessProbe | nindent 10 }}
        startupProbe:
          {{- toYaml .Values.startupProbe | nindent 10 }}
        volumeMounts:
        {{- toYaml .Values.volumeMounts | nindent 8 }}
      volumes:
      {{- toYaml .Values.volumes | nindent 6 }}
      {{- with .Values.nodeSelector }}
      nodeSelector:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with .Values.affinity }}
      affinity:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with .Values.tolerations }}
      tolerations:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      terminationGracePeriodSeconds: {{ .Values.terminationGracePeriodSeconds }}
EOF

# Generate service.yaml
echo "📝 Creating service.yaml..."
cat > "$TEMPLATES_DIR/service.yaml" << 'EOF'
apiVersion: v1
kind: Service
metadata:
  name: {{ include "demo-app.fullname" . }}
  namespace: {{ include "demo-app.namespace" . }}
  labels:
    {{- include "demo-app.labels" . | nindent 4 }}
  {{- with .Values.service.annotations }}
  annotations:
    {{- toYaml . | nindent 4 }}
  {{- end }}
spec:
  type: {{ .Values.service.type }}
  selector:
    {{- include "demo-app.selectorLabels" . | nindent 4 }}
  ports:
  - name: http
    port: {{ .Values.service.port }}
    targetPort: http
    protocol: TCP
  sessionAffinity: None
EOF

# Generate ingress.yaml
echo "📝 Creating ingress.yaml..."
cat > "$TEMPLATES_DIR/ingress.yaml" << 'EOF'
{{- if .Values.ingress.enabled -}}
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: {{ include "demo-app.fullname" . }}
  namespace: {{ include "demo-app.namespace" . }}
  labels:
    {{- include "demo-app.labels" . | nindent 4 }}
  {{- with .Values.ingress.annotations }}
  annotations:
    {{- toYaml . | nindent 4 }}
  {{- end }}
spec:
  {{- if .Values.ingress.className }}
  ingressClassName: {{ .Values.ingress.className }}
  {{- end }}
  {{- if .Values.ingress.tls }}
  tls:
    {{- range .Values.ingress.tls }}
    - hosts:
        {{- range .hosts }}
        - {{ . | quote }}
        {{- end }}
      secretName: {{ .secretName }}
    {{- end }}
  {{- end }}
  rules:
    {{- range .Values.ingress.hosts }}
    - host: {{ .host | quote }}
      http:
        paths:
          {{- range .paths }}
          - path: {{ .path }}
            pathType: {{ .pathType }}
            backend:
              service:
                name: {{ include "demo-app.fullname" $ }}
                port:
                  number: {{ $.Values.service.port }}
          {{- end }}
    {{- end }}
{{- end }}
EOF

# Generate networkpolicy.yaml
echo "📝 Creating networkpolicy.yaml..."
cat > "$TEMPLATES_DIR/networkpolicy.yaml" << 'EOF'
{{- if .Values.networkPolicy.enabled -}}
apiVersion: {{ include "demo-app.networkPolicy.apiVersion" . }}
kind: NetworkPolicy
metadata:
  name: {{ include "demo-app.fullname" . }}
  namespace: {{ include "demo-app.namespace" . }}
  labels:
    {{- include "demo-app.labels" . | nindent 4 }}
spec:
  podSelector:
    matchLabels:
      {{- include "demo-app.selectorLabels" . | nindent 6 }}
  policyTypes:
    {{- toYaml .Values.networkPolicy.policyTypes | nindent 4 }}
  {{- with .Values.networkPolicy.ingress }}
  ingress:
    {{- toYaml . | nindent 4 }}
  {{- end }}
  {{- with .Values.networkPolicy.egress }}
  egress:
    {{- toYaml . | nindent 4 }}
  {{- end }}
{{- end }}
EOF

# Generate servicemonitor.yaml
echo "📝 Creating servicemonitor.yaml..."
cat > "$TEMPLATES_DIR/servicemonitor.yaml" << 'EOF'
{{- if .Values.serviceMonitor.enabled -}}
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: {{ include "demo-app.fullname" . }}
  namespace: {{ include "demo-app.namespace" . }}
  labels:
    {{- include "demo-app.labels" . | nindent 4 }}
    {{- with .Values.serviceMonitor.labels }}
    {{- toYaml . | nindent 4 }}
    {{- end }}
spec:
  selector:
    matchLabels:
      {{- include "demo-app.selectorLabels" . | nindent 6 }}
  endpoints:
  - port: http
    path: {{ .Values.serviceMonitor.path }}
    interval: {{ .Values.serviceMonitor.interval }}
    scrapeTimeout: {{ .Values.serviceMonitor.scrapeTimeout }}
    scheme: {{ .Values.serviceMonitor.scheme }}
  namespaceSelector:
    matchNames:
    - {{ include "demo-app.namespace" . }}
{{- end }}
EOF

# Generate hpa.yaml
echo "📝 Creating hpa.yaml..."
cat > "$TEMPLATES_DIR/hpa.yaml" << 'EOF'
{{- if .Values.autoscaling.enabled -}}
apiVersion: {{ include "demo-app.hpa.apiVersion" . }}
kind: HorizontalPodAutoscaler
metadata:
  name: {{ include "demo-app.fullname" . }}
  namespace: {{ include "demo-app.namespace" . }}
  labels:
    {{- include "demo-app.labels" . | nindent 4 }}
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: {{ include "demo-app.fullname" . }}
  minReplicas: {{ .Values.autoscaling.minReplicas }}
  maxReplicas: {{ .Values.autoscaling.maxReplicas }}
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: {{ .Values.autoscaling.targetCPUUtilizationPercentage }}
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: {{ .Values.autoscaling.targetMemoryUtilizationPercentage }}
  {{- with .Values.autoscaling.behavior }}
  behavior:
    {{- toYaml . | nindent 4 }}
  {{- end }}
{{- end }}
EOF

# Generate pdb.yaml
echo "📝 Creating pdb.yaml..."
cat > "$TEMPLATES_DIR/pdb.yaml" << 'EOF'
{{- if .Values.podDisruptionBudget.enabled -}}
apiVersion: {{ include "demo-app.pdb.apiVersion" . }}
kind: PodDisruptionBudget
metadata:
  name: {{ include "demo-app.fullname" . }}
  namespace: {{ include "demo-app.namespace" . }}
  labels:
    {{- include "demo-app.labels" . | nindent 4 }}
spec:
  {{- if .Values.podDisruptionBudget.minAvailable }}
  minAvailable: {{ .Values.podDisruptionBudget.minAvailable }}
  {{- end }}
  {{- if .Values.podDisruptionBudget.maxUnavailable }}
  maxUnavailable: {{ .Values.podDisruptionBudget.maxUnavailable }}
  {{- end }}
  selector:
    matchLabels:
      {{- include "demo-app.selectorLabels" . | nindent 6 }}
{{- end }}
EOF

# Generate NOTES.txt
echo "📝 Creating NOTES.txt..."
cat > "$TEMPLATES_DIR/NOTES.txt" << 'EOF'
🎉 Thank you for installing {{ .Chart.Name }}!

Your release is named {{ .Release.Name }}.

To learn more about the release, try:

  $ helm status {{ .Release.Name }} -n {{ .Release.Namespace }}
  $ helm get all {{ .Release.Name }} -n {{ .Release.Namespace }}

📊 Application Information:
  - Name: {{ include "demo-app.fullname" . }}
  - Namespace: {{ include "demo-app.namespace" . }}
  - Version: {{ .Chart.AppVersion }}
  - Replicas: {{ .Values.replicaCount }}

{{- if .Values.ingress.enabled }}

🌐 Access your application:
{{- range .Values.ingress.hosts }}
  http{{ if $.Values.ingress.tls }}s{{ end }}://{{ .host }}
{{- end }}

{{- else if contains "NodePort" .Values.service.type }}

🌐 Access your application:
  export NODE_PORT=$(kubectl get --namespace {{ .Release.Namespace }} -o jsonpath="{.spec.ports[0].nodePort}" services {{ include "demo-app.fullname" . }})
  export NODE_IP=$(kubectl get nodes --namespace {{ .Release.Namespace }} -o jsonpath="{.items[0].status.addresses[0].address}")
  echo http://$NODE_IP:$NODE_PORT

{{- else if contains "LoadBalancer" .Values.service.type }}

🌐 Access your application:
  NOTE: It may take a few minutes for the LoadBalancer IP to be available.
  export SERVICE_IP=$(kubectl get svc --namespace {{ .Release.Namespace }} {{ include "demo-app.fullname" . }} --template "{{"{{ range (index .status.loadBalancer.ingress 0) }}{{.}}{{ end }}"}}")
  echo http://$SERVICE_IP:{{ .Values.service.port }}

{{- else if contains "ClusterIP" .Values.service.type }}

🌐 Access your application:
  export POD_NAME=$(kubectl get pods --namespace {{ .Release.Namespace }} -l "app.kubernetes.io/name={{ include "demo-app.name" . }},app.kubernetes.io/instance={{ .Release.Name }}" -o jsonpath="{.items[0].metadata.name}")
  export CONTAINER_PORT=$(kubectl get pod --namespace {{ .Release.Namespace }} $POD_NAME -o jsonpath="{.spec.containers[0].ports[0].containerPort}")
  echo "Visit http://127.0.0.1:8080 to use your application"
  kubectl --namespace {{ .Release.Namespace }} port-forward $POD_NAME 8080:$CONTAINER_PORT

{{- end }}

📝 Useful Commands:

  # View pods
  kubectl get pods -n {{ .Release.Namespace }} -l app={{ include "demo-app.name" . }}

  # View logs
  kubectl logs -n {{ .Release.Namespace }} -l app={{ include "demo-app.name" . }} --tail=50 -f

  # View service
  kubectl get svc -n {{ .Release.Namespace }} {{ include "demo-app.fullname" . }}

{{- if .Values.autoscaling.enabled }}

  # View HPA status
  kubectl get hpa -n {{ .Release.Namespace }} {{ include "demo-app.fullname" . }}
{{- end }}

{{- if .Values.serviceMonitor.enabled }}

  # View ServiceMonitor
  kubectl get servicemonitor -n {{ .Release.Namespace }} {{ include "demo-app.fullname" . }}
{{- end }}

🔍 Health Checks:
  - Liveness:  /health/live
  - Readiness: /health/ready
  - Health:    /health

📊 Metrics:
  - Prometheus: /metrics

📚 Documentation:
  - Chart README: https://github.com/example/demo-app/tree/main/helm-chart
  - Application README: https://github.com/example/demo-app

💡 Tips:
  - Use 'helm upgrade' to update your release
  - Use 'helm rollback' to rollback to a previous version
  - Use 'helm test' to run tests against your release

Happy Helming! ⛵
EOF

# Generate .helmignore
echo "📝 Creating .helmignore..."
cat > "$CHART_DIR/.helmignore" << 'EOF'
# Patterns to ignore when building packages.
# This supports shell glob matching, relative path matching, and
# negation (prefixed with !). Only one pattern per line.
.DS_Store
# Common VCS dirs
.git/
.gitignore
.bzr/
.bzrignore
.hg/
.hgignore
.svn/
# Common backup files
*.swp
*.bak
*.tmp
*.orig
*~
# Various IDEs
.project
.idea/
*.tmproj
.vscode/
# Custom
README.md.gotmpl
EOF

echo ""
echo "✅ All Helm templates generated successfully!"
echo ""
echo "📦 Chart structure:"
tree -L 2 "$CHART_DIR" 2>/dev/null || find "$CHART_DIR" -type f | sort

echo ""
echo "🧪 Next steps:"
echo "  1. Lint the chart:    helm lint $CHART_DIR"
echo "  2. Test rendering:    helm template demo-app $CHART_DIR"
echo "  3. Dry run install:   helm install demo-app $CHART_DIR --dry-run --debug"
echo "  4. Install chart:     helm install demo-app $CHART_DIR -n demo-app --create-namespace"
echo ""

# Made with Bob

# Jenkins Ingress Troubleshooting Guide

## 🔍 Issue: Cannot Access Jenkins via jenkins.local

If you can only access Jenkins via port-forward but not through the ingress (http://jenkins.local), follow these troubleshooting steps.

---

## ✅ **Quick Fix: Use Port-Forward (Recommended for Local Dev)**

The most reliable way to access Jenkins locally:

```bash
# Start port-forward (keep this terminal open)
kubectl port-forward -n jenkins svc/jenkins 8080:8080

# Access Jenkins in browser
open http://localhost:8080
```

**This is the recommended approach for local Minikube development.**

---

## 🔧 **Troubleshooting Ingress Access**

### **Step 1: Verify Ingress Controller is Running**

```bash
kubectl get pods -n ingress-nginx
```

**Expected output:**
```
NAME                                        READY   STATUS
ingress-nginx-controller-xxx                1/1     Running
```

If not running:
```bash
minikube addons enable ingress
kubectl wait --for=condition=ready pod -l app.kubernetes.io/component=controller -n ingress-nginx --timeout=120s
```

---

### **Step 2: Check Ingress Resource**

```bash
kubectl get ingress -n jenkins
kubectl describe ingress jenkins -n jenkins
```

**Expected output:**
```
NAME      CLASS   HOSTS           ADDRESS        PORTS   AGE
jenkins   nginx   jenkins.local   192.168.49.2   80      Xh
```

**Check for:**
- ✅ ADDRESS field has Minikube IP
- ✅ HOSTS shows jenkins.local
- ✅ No error events in describe output

---

### **Step 3: Verify /etc/hosts Entry**

```bash
cat /etc/hosts | grep jenkins.local
```

**Expected:**
```
192.168.49.2 jenkins.local
```

If missing, add it:
```bash
echo "$(minikube ip) jenkins.local" | sudo tee -a /etc/hosts
```

---

### **Step 4: Test Ingress Controller**

```bash
# Test if ingress controller is responding
curl -v http://$(minikube ip)

# Test with Host header
curl -H "Host: jenkins.local" http://$(minikube ip)
```

---

### **Step 5: Check Ingress Controller Logs**

```bash
kubectl logs -n ingress-nginx -l app.kubernetes.io/component=controller --tail=50
```

Look for errors related to:
- Backend service not found
- SSL/TLS issues
- Configuration errors

---

### **Step 6: Verify Service is Accessible**

```bash
# Check service exists
kubectl get svc -n jenkins

# Test service directly (from within cluster)
kubectl run test-pod --rm -it --image=curlimages/curl -- \
  curl -v http://jenkins.jenkins.svc.cluster.local:8080
```

---

## 🐛 **Common Issues and Solutions**

### **Issue 1: Ingress Controller Not Running**

**Symptom:** No ingress-nginx pods

**Solution:**
```bash
minikube addons enable ingress
kubectl wait --for=condition=ready pod -l app.kubernetes.io/component=controller -n ingress-nginx --timeout=120s
```

---

### **Issue 2: DNS Not Resolving**

**Symptom:** `curl: (6) Could not resolve host: jenkins.local`

**Solution:**
```bash
# Verify /etc/hosts
cat /etc/hosts | grep jenkins

# If missing, add it
echo "$(minikube ip) jenkins.local" | sudo tee -a /etc/hosts

# Test DNS resolution
ping -c 1 jenkins.local
```

---

### **Issue 3: Connection Timeout**

**Symptom:** `curl` hangs or times out

**Possible causes:**
1. **Network policies blocking traffic**
2. **Ingress controller not routing**
3. **Service not responding**

**Solution:**
```bash
# Check network policies
kubectl get networkpolicy -n jenkins
kubectl get networkpolicy -n demo-app

# Temporarily disable network policies for testing
kubectl delete networkpolicy -n jenkins --all

# Test again
curl -I http://jenkins.local

# Re-apply network policies after testing
kubectl apply -f k8s/setup/network-policies.yaml
---

### **Issue 4: Network Policy Blocking Ingress Traffic**

**Symptom:** Ingress controller logs show "Service does not have any active Endpoint"

**Root Cause:** Network policies may be blocking traffic from ingress-nginx namespace to Jenkins pods.

**Solution:**

```bash
# Check if network policy exists
kubectl get networkpolicy -n jenkins

# Apply ingress network policy
kubectl apply -f k8s/setup/jenkins-ingress-network-policy.yaml

# Verify policy is applied
kubectl describe networkpolicy allow-ingress-to-jenkins -n jenkins
```

The network policy allows:
- Traffic from `ingress-nginx` namespace to Jenkins on port 8080
- Internal traffic within `jenkins` namespace for agent communication

---

### **Issue 5: Minikube Docker Driver Limitation**

**Symptom:** Cannot connect to Minikube IP (192.168.49.2) from host machine

**Root Cause:** When using Docker driver on macOS, the Minikube cluster runs inside a Docker container. The cluster's internal IP (192.168.49.2) is not directly accessible from the host.

**Solution: Use Minikube Tunnel**

```bash
# Terminal 1: Start minikube tunnel (keep running)
minikube tunnel
# This will prompt for sudo password
# Keep this terminal open

# Terminal 2: Add DNS entry
echo "127.0.0.1 jenkins.local" | sudo tee -a /etc/hosts

# Terminal 3: Test access
curl http://jenkins.local

# Or open in browser
open http://jenkins.local
```

**Important Notes:**
- `minikube tunnel` creates a network route from host to cluster
- Must keep the tunnel terminal running
- Uses 127.0.0.1 (localhost) instead of Minikube IP
- Requires sudo password

**To stop:**
```bash
# Stop tunnel: Ctrl+C in tunnel terminal
# Remove DNS entry:
sudo sed -i '' '/jenkins.local/d' /etc/hosts
```

**Alternative: Use minikube service command**
```bash
# Get temporary tunnel URL
minikube service ingress-nginx-controller -n ingress-nginx --url
# Output: http://127.0.0.1:54042 (port varies)

# Access with Host header
curl -H "Host: jenkins.local" http://127.0.0.1:54042
```

---

```

---

### **Issue 4: 404 Not Found**

**Symptom:** Ingress responds but returns 404

**Solution:**
```bash
# Check ingress path configuration
kubectl get ingress jenkins -n jenkins -o yaml | grep -A 5 "paths:"

# Verify service backend
kubectl describe ingress jenkins -n jenkins | grep -A 5 "Backend"

# Check service endpoints
kubectl get endpoints jenkins -n jenkins
```

---

### **Issue 5: 502 Bad Gateway**

**Symptom:** Ingress returns 502 error

**Solution:**
```bash
# Check if Jenkins pod is ready
kubectl get pods -n jenkins

# Check Jenkins logs
kubectl logs -n jenkins jenkins-0 -c jenkins --tail=50

# Verify service is pointing to correct pod
kubectl describe svc jenkins -n jenkins
```

---

## 🔄 **Alternative Access Methods**

### **Method 1: Port-Forward (Recommended)**

```bash
kubectl port-forward -n jenkins svc/jenkins 8080:8080
# Access: http://localhost:8080
```

**Pros:**
- ✅ Always works
- ✅ No DNS configuration needed
- ✅ No ingress dependencies

**Cons:**
- ❌ Requires terminal to stay open
- ❌ Only accessible from localhost

---

### **Method 2: NodePort Service**

```bash
# Change service type to NodePort
kubectl patch svc jenkins -n jenkins -p '{"spec":{"type":"NodePort"}}'

# Get NodePort
kubectl get svc jenkins -n jenkins

# Access via Minikube IP and NodePort
minikube service jenkins -n jenkins --url
```

**Pros:**
- ✅ No ingress needed
- ✅ Direct access to service

**Cons:**
- ❌ Random high port number
- ❌ Not production-like

---

### **Method 3: Minikube Tunnel**

```bash
# Start minikube tunnel (requires sudo, keep terminal open)
minikube tunnel

# In another terminal, access Jenkins
curl http://jenkins.local
```

**Pros:**
- ✅ Works like production LoadBalancer
- ✅ Uses standard ports

**Cons:**
- ❌ Requires sudo
- ❌ Terminal must stay open

---

## 🛠️ **Fix Ingress Configuration**

If ingress is not working, you can update the configuration:

### **Option 1: Update Ingress Annotations**

```bash
kubectl annotate ingress jenkins -n jenkins \
  nginx.ingress.kubernetes.io/rewrite-target=/ \
  --overwrite
```

### **Option 2: Recreate Ingress**

```yaml
# Save as jenkins-ingress.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: jenkins
  namespace: jenkins
  annotations:
    nginx.ingress.kubernetes.io/ssl-redirect: "false"
    nginx.ingress.kubernetes.io/proxy-body-size: "50m"
spec:
  ingressClassName: nginx
  rules:
  - host: jenkins.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: jenkins
            port:
              number: 8080
```

```bash
# Apply new ingress
kubectl delete ingress jenkins -n jenkins
kubectl apply -f jenkins-ingress.yaml
```

---

## 📊 **Verification Commands**

Run these commands to verify everything:

```bash
echo "=== Minikube Status ==="
minikube status

echo -e "\n=== Minikube IP ==="
minikube ip

echo -e "\n=== Ingress Controller ==="
kubectl get pods -n ingress-nginx

echo -e "\n=== Jenkins Service ==="
kubectl get svc -n jenkins

echo -e "\n=== Jenkins Ingress ==="
kubectl get ingress -n jenkins

echo -e "\n=== /etc/hosts Entry ==="
cat /etc/hosts | grep jenkins

echo -e "\n=== Test Connection ==="
curl -I -m 5 http://jenkins.local || echo "Ingress not accessible"

echo -e "\n=== Port-Forward Test ==="
echo "Run: kubectl port-forward -n jenkins svc/jenkins 8080:8080"
echo "Then access: http://localhost:8080"
```

---

## ✅ **Recommended Solution**

For local Minikube development, **use port-forward**:

```bash
# Terminal 1: Start port-forward
kubectl port-forward -n jenkins svc/jenkins 8080:8080

# Terminal 2 or Browser: Access Jenkins
open http://localhost:8080
```

This is:
- ✅ Most reliable
- ✅ No configuration needed
- ✅ Works every time
- ✅ Standard practice for local development

---

## 📚 **Additional Resources**

- **Minikube Ingress**: https://minikube.sigs.k8s.io/docs/handbook/addons/ingress-dns/
- **NGINX Ingress**: https://kubernetes.github.io/ingress-nginx/
- **Troubleshooting Ingress**: https://kubernetes.io/docs/concepts/services-networking/ingress/#troubleshooting

---

**For local development, port-forward is the recommended and most reliable method!**

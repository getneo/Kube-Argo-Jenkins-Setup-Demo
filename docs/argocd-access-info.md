# ArgoCD Access Information


---

## 🌐 Access Methods

### Method 1: Port-Forward (Recommended for Local Development)

```bash
# Start port-forward (keep terminal open)
kubectl port-forward svc/argocd-server -n argocd 8080:443

# Access ArgoCD UI
open https://localhost:8080

# Accept the self-signed certificate warning in browser
```

**Access URL:** https://localhost:8080

---

### Method 2: Ingress with Minikube Tunnel

```bash
# Terminal 1: Start minikube tunnel (keep running)
minikube tunnel

# Terminal 2: Add DNS entry
echo "127.0.0.1 argocd.local" | sudo tee -a /etc/hosts

# Access ArgoCD UI
open https://argocd.local
```

**Access URL:** https://argocd.local

---

## 🔧 ArgoCD CLI Setup

### Install CLI (macOS)

```bash
# Using Homebrew
brew install argocd

# Or download directly
curl -sSL -o /usr/local/bin/argocd https://github.com/argoproj/argo-cd/releases/latest/download/argocd-darwin-amd64
chmod +x /usr/local/bin/argocd
```

### Login via CLI

```bash
# With port-forward running
argocd login localhost:8080 --insecure

# Or with ingress
argocd login argocd.local --insecure

# Enter credentials:
# Username: admin
# Password: 2800QklFONu-DRBV
```

### Change Password

```bash
# Via CLI
argocd account update-password

# Or via UI: User Info > Update Password
```

---

## 📊 Verify Installation

```bash
# Check all pods are running
kubectl get pods -n argocd

# Expected output (all Running):
# argocd-application-controller-0
# argocd-applicationset-controller-xxx
# argocd-dex-server-xxx
# argocd-notifications-controller-xxx
# argocd-redis-xxx
# argocd-repo-server-xxx
# argocd-server-xxx

# Check services
kubectl get svc -n argocd

# Check ingress
kubectl get ingress -n argocd

# Check network policies
kubectl get networkpolicy -n argocd
```

---

## 🎯 Quick Start Commands

```bash
# List applications
argocd app list

# Create an application
argocd app create demo-app \
  --repo https://github.com/yourusername/your-repo.git \
  --path k8s/manifests \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace demo-app

# Sync application
argocd app sync demo-app

# Get application status
argocd app get demo-app

# View application logs
argocd app logs demo-app --follow
```

---

## 🔒 Security Recommendations

1. **Change Default Password**
   ```bash
   argocd account update-password
   ```

2. **Enable RBAC**
   - Configure role-based access control
   - Create separate users for team members
   - Disable admin user after creating other users

3. **Configure SSO (Optional)**
   - Set up Dex for GitHub/Google/LDAP authentication
   - Improves security and user management

4. **Use Private Git Repositories**
   - Add SSH keys or tokens for private repos
   - Never commit secrets to Git

---

## 🐛 Troubleshooting

### Cannot Access UI

```bash
# Check if pods are running
kubectl get pods -n argocd

# Check service
kubectl get svc argocd-server -n argocd

# Check ingress
kubectl describe ingress argocd-server -n argocd

# View logs
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-server
```

### Login Failed

```bash
# Get password again
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d && echo

# Reset password (if needed)
kubectl -n argocd delete secret argocd-initial-admin-secret
kubectl -n argocd rollout restart deployment argocd-server
```

### Application Sync Issues

```bash
# Check application status
argocd app get <app-name>

# View sync errors
kubectl describe application <app-name> -n argocd

# Force sync
argocd app sync <app-name> --force
```

---

## 📚 Next Steps

1. ✅ ArgoCD installed and accessible
2. ⏭️ Change default admin password
3. ⏭️ Add Git repository
4. ⏭️ Create first application
5. ⏭️ Set up Jenkins integration for GitOps workflow

---

## 🔗 Resources

- **ArgoCD Documentation:** https://argo-cd.readthedocs.io/
- **Getting Started Guide:** https://argo-cd.readthedocs.io/en/stable/getting_started/
- **Best Practices:** https://argo-cd.readthedocs.io/en/stable/user-guide/best_practices/

---

**ArgoCD is ready for GitOps-based continuous delivery!**

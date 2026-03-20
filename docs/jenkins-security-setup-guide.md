# Jenkins Security Setup Guide

## 🔒 Manual Security Configuration

Since Jenkins is running without security enabled, follow these steps to secure it properly.

---

## ⚠️ Current Status

Jenkins is currently running with:
- ❌ **No authentication required** (anyone can access)
- ❌ **No authorization** (anonymous users have full access)
- ❌ **Security disabled**

This is **NOT production-ready** and must be fixed immediately.

---

## 📋 Step-by-Step Security Setup

### **Step 1: Access Jenkins**

Open Jenkins in your browser:
```bash
# Option A: Via ingress
open http://jenkins.local

# Option B: Via port-forward
kubectl port-forward -n jenkins svc/jenkins 8080:8080
# Then open: http://localhost:8080
```

---

### **Step 2: Navigate to Security Settings**

1. Click **"Manage Jenkins"** in the left sidebar
2. Click **"Security"** (or **"Configure Global Security"**)

---

### **Step 3: Configure Security Realm (Authentication)**

In the **Security Realm** section:

1. Select **"Jenkins' own user database"**
2. ✅ **Check** "Allow users to sign up" (temporarily - we'll disable this later)
3. Click **"Save"** at the bottom

![Security Realm](https://www.jenkins.io/doc/book/resources/managing/configure-global-security-choose-realm.png)

---

### **Step 4: Create Admin User**

After saving, you'll see a "Sign up" link:

1. Click **"Sign up"** in the top right
2. Fill in the form:
   - **Username**: `admin`
   - **Password**: `YourSecurePassword123!` (choose a strong password)
   - **Confirm password**: (same as above)
   - **Full name**: `Administrator`
   - **E-mail address**: `admin@jenkins.local`
3. Click **"Sign up"**

**Important:** Save this password securely! You'll need it to access Jenkins.

---

### **Step 5: Configure Authorization**

Go back to **Manage Jenkins** → **Security**:

1. In the **Authorization** section, select **"Logged-in users can do anything"**
2. ✅ **Uncheck** "Allow anonymous read access"
3. Click **"Save"**

This ensures:
- Only logged-in users can access Jenkins
- Anonymous users are blocked
- All authenticated users have full access (you can refine this later)

---

### **Step 6: Disable User Signup**

Now that you have an admin account, disable public signup:

1. Go to **Manage Jenkins** → **Security**
2. In **Security Realm**, find "Jenkins' own user database"
3. ❌ **Uncheck** "Allow users to sign up"
4. Click **"Save"**

This prevents unauthorized users from creating accounts.

---

### **Step 7: Enable Additional Security Features**

While in **Security** settings, configure these additional options:

#### **A. CSRF Protection**
- ✅ **Check** "Prevent Cross Site Request Forgery exploits"
- Keep default "Default Crumb Issuer"

#### **B. Agent → Controller Security**
- ✅ **Check** "Enable Agent → Controller Access Control"
- This prevents malicious agents from compromising the controller

#### **C. Markup Formatter**
- Select **"Plain text"** (safest option)
- Or **"Safe HTML"** if you need formatted descriptions

#### **D. SSH Server**
- Set **"SSH Server Port"** to **"Disable"** (unless you need SSH access)

Click **"Save"** after making these changes.

---

### **Step 8: Verify Security is Working**

1. **Logout**: Click your username → **"Log out"**
2. **Try to access Jenkins**: You should see a login page
3. **Login**: Use your admin credentials
4. **Verify**: You should now have full access

If you can't access Jenkins without logging in, security is working! ✅

---

## 🔐 Advanced Security Configuration (Optional)

### **Matrix-Based Security**

For more granular control, use Matrix-based security:

1. Go to **Manage Jenkins** → **Security**
2. Select **"Matrix-based security"**
3. Add users/groups and assign specific permissions:
   - **admin**: All permissions
   - **developers**: Read, Build, Cancel
   - **viewers**: Read only

### **Role-Based Access Control (RBAC)**

Install the **Role-based Authorization Strategy** plugin:

1. Go to **Manage Jenkins** → **Plugins**
2. Search for "Role-based Authorization Strategy"
3. Install and restart Jenkins
4. Configure roles in **Manage Jenkins** → **Security**

### **LDAP/Active Directory Integration**

For enterprise environments:

1. Install **LDAP** or **Active Directory** plugin
2. Go to **Manage Jenkins** → **Security**
3. Select **"LDAP"** or **"Active Directory"**
4. Configure your LDAP/AD server details

---

## 📊 Security Checklist

After completing the setup, verify:

- [ ] Jenkins requires login to access
- [ ] Admin user is created with strong password
- [ ] User signup is disabled
- [ ] CSRF protection is enabled
- [ ] Agent → Controller security is enabled
- [ ] Markup formatter is set to Plain text or Safe HTML
- [ ] SSH server is disabled (if not needed)
- [ ] Anonymous users cannot access Jenkins

---

## 🔑 Password Management

### **Change Admin Password**

1. Click your username (top right)
2. Click **"Configure"**
3. Enter new password in **"Password"** field
4. Click **"Save"**

### **Reset Forgotten Password**

If you forget the admin password:

```bash
# Option 1: Disable security temporarily
kubectl exec -n jenkins jenkins-0 -c jenkins -- \
  sed -i 's/<useSecurity>true<\/useSecurity>/<useSecurity>false<\/useSecurity>/g' \
  /var/jenkins_home/config.xml

# Restart Jenkins
kubectl delete pod jenkins-0 -n jenkins

# Access Jenkins without login, reset password, re-enable security
```

**Option 2: Reset via Kubernetes secret**

```bash
# Generate new password hash
NEW_PASSWORD=""
HASH=$(echo -n "$NEW_PASSWORD" | sha256sum | awk '{print $1}')

# Update user config (requires manual editing)
kubectl exec -n jenkins jenkins-0 -c jenkins -- bash
# Edit /var/jenkins_home/users/admin_*/config.xml
```

---

## 🛡️ Security Best Practices

### **1. Strong Passwords**
- Minimum 12 characters
- Mix of uppercase, lowercase, numbers, symbols
- Use a password manager

### **2. Regular Updates**
- Keep Jenkins updated
- Update plugins regularly
- Monitor security advisories

### **3. Audit Logging**
Install **Audit Trail** plugin:
- Tracks all user actions
- Helps with compliance
- Useful for troubleshooting

### **4. Backup Credentials**
```bash
# Backup Jenkins home (includes user configs)
kubectl exec -n jenkins jenkins-0 -c jenkins -- \
  tar czf /tmp/jenkins-backup.tar.gz /var/jenkins_home

kubectl cp jenkins/jenkins-0:/tmp/jenkins-backup.tar.gz ./jenkins-backup.tar.gz
```

### **5. Network Security**
- Use HTTPS (add TLS to ingress)
- Restrict access by IP (network policies)
- Use VPN for remote access

### **6. Secrets Management**
- Use Kubernetes secrets for credentials
- Never hardcode passwords in Jenkinsfiles
- Use credential binding in pipelines

---

## 🔍 Verify Security Configuration

### **Check Security Settings**

```bash
# View security configuration
kubectl exec -n jenkins jenkins-0 -c jenkins -- \
  cat /var/jenkins_home/config.xml | grep -A 10 "securityRealm\|authorizationStrategy"
```

**Expected output:**
```xml
<securityRealm class="hudson.security.HudsonPrivateSecurityRealm">
  <disableSignup>true</disableSignup>
  ...
</securityRealm>
<authorizationStrategy class="hudson.security.FullControlOnceLoggedInAuthorizationStrategy">
  <denyAnonymousReadAccess>true</denyAnonymousReadAccess>
</authorizationStrategy>
```

### **Test Anonymous Access**

```bash
# Try to access Jenkins API without auth (should fail)
curl -I http://jenkins.local

# Expected: 403 Forbidden or redirect to login
```

---

## 📚 Additional Resources

- **Jenkins Security**: https://www.jenkins.io/doc/book/security/
- **Securing Jenkins**: https://www.jenkins.io/doc/book/security/securing-jenkins/
- **Access Control**: https://www.jenkins.io/doc/book/security/access-control/
- **Managing Security**: https://www.jenkins.io/doc/book/managing/security/

---

## ✅ Next Steps

After securing Jenkins:

1. ✅ Install additional plugins (Git, Docker, Kubernetes CLI)
2. ✅ Create your first pipeline
3. ✅ Configure Kubernetes cloud for dynamic agents
4. ✅ Set up GitHub/GitLab integration
5. ✅ Configure build notifications

---

**Security is now configured! Jenkins is ready for production use.** 🔒

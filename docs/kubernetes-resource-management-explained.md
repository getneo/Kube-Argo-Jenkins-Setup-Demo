# Kubernetes Resource Management - Complete Hierarchy Explained

## Overview

This document explains how resources flow from your physical machine through Docker, Minikube, Kubernetes nodes, namespaces, pods, and finally to containers. We'll trace the exact path your setup takes.

---

## The Complete Resource Hierarchy

```
┌─────────────────────────────────────────────────────────────────┐
│ LEVEL 1: Physical Host Machine (Your Mac)                      │
│ ├─ CPU: 8+ cores (example)                                     │
│ ├─ Memory: 16GB+ (example)                                     │
│ └─ Disk: 500GB+ (example)                                      │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│ LEVEL 2: Docker Desktop / Colima (Container Runtime)           │
│ Command: colima start --cpu 6 --memory 8 --disk 100            │
│ ├─ Allocated CPU: 6 cores (from host)                          │
│ ├─ Allocated Memory: 8GB (from host)                           │
│ ├─ Allocated Disk: 100GB (from host)                           │
│ └─ Purpose: Runs Docker containers (including Minikube VM)     │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│ LEVEL 3: Minikube VM (Kubernetes Node)                         │
│ Command: minikube start --cpus=6 --memory=7922 --disk-size=30g │
│ ├─ Allocated CPU: 6 cores (from Docker)                        │
│ ├─ Allocated Memory: 7922Mi ≈ 7.7GB (from Docker)             │
│ ├─ Allocated Disk: 30GB (from Docker)                          │
│ └─ Purpose: Single-node Kubernetes cluster                     │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│ LEVEL 4: Kubernetes Node Resources (Allocatable)               │
│ ├─ Total Capacity: 6000m CPU, 7922Mi memory                    │
│ ├─ System Reserved: ~500m CPU, ~1Gi memory (kubelet, etc.)     │
│ ├─ Allocatable: ~5500m CPU, ~6.9Gi memory                      │
│ └─ Purpose: Available for pod scheduling                       │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│ LEVEL 5: Namespace-Level Controls (Optional)                   │
│ ├─ ResourceQuota: Limits total resources per namespace         │
│ ├─ LimitRange: Sets min/max/default per pod/container          │
│ └─ Purpose: Multi-tenancy, resource isolation                  │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│ LEVEL 6: Pod-Level Resources                                   │
│ ├─ Sum of all container requests/limits                        │
│ ├─ Scheduler uses this for placement decisions                 │
│ └─ Purpose: Scheduling unit                                    │
└─────────────────────────────────────────────────────────────────┘
                              ↓
┌─────────────────────────────────────────────────────────────────┐
│ LEVEL 7: Container-Level Resources (Actual Enforcement)        │
│ ├─ Requests: Guaranteed minimum (scheduling)                   │
│ ├─ Limits: Maximum allowed (enforcement via cgroups)           │
│ └─ Purpose: Actual resource consumption                        │
└─────────────────────────────────────────────────────────────────┘
```

---

## Detailed Breakdown of Each Level

### LEVEL 1: Physical Host Machine

**Your Mac (Example):**
```
CPU:    8 cores (Intel/Apple Silicon)
Memory: 16GB RAM
Disk:   500GB SSD
```

**What happens here:**
- This is your actual hardware
- All virtualization runs on top of this
- macOS uses some resources for itself
- Remaining resources available for Docker/Colima

**Resource allocation:**
- You decide how much to give to Docker/Colima
- Rest stays with macOS for other applications

---

### LEVEL 2: Docker Desktop / Colima

**Your Command:**
```bash
colima start --cpu 6 --memory 8 --disk 100
```

**What this does:**
```
┌─────────────────────────────────────────┐
│ Host Machine (Mac)                      │
│ ┌─────────────────────────────────────┐ │
│ │ macOS (2 CPUs, 8GB RAM)             │ │
│ └─────────────────────────────────────┘ │
│ ┌─────────────────────────────────────┐ │
│ │ Colima VM (6 CPUs, 8GB RAM)         │ │
│ │ ├─ Docker Engine                    │ │
│ │ ├─ Container Runtime                │ │
│ │ └─ Runs Minikube container          │ │
│ └─────────────────────────────────────┘ │
└─────────────────────────────────────────┘
```

**Resource Management:**
- **CPU:** 6 cores allocated to Colima VM
- **Memory:** 8GB allocated to Colima VM
- **Disk:** 100GB virtual disk for containers
- **Isolation:** Uses hypervisor (QEMU on Mac)

**Key Points:**
- Colima creates a Linux VM on macOS
- Docker runs inside this VM
- All containers (including Minikube) run in this VM
- Resources are hard-limited by these settings

**Check Colima resources:**
```bash
colima status
# Shows: cpu=6, memory=8, disk=100
```

---

### LEVEL 3: Minikube VM (Kubernetes Node)

**Your Command:**
```bash
minikube start --cpus=6 --memory=7922 --disk-size=30g --driver=docker
```

**What this does:**
```
┌─────────────────────────────────────────────────┐
│ Colima VM (6 CPUs, 8GB RAM)                     │
│ ┌─────────────────────────────────────────────┐ │
│ │ Docker Container: minikube                  │ │
│ │ ├─ Allocated: 6 CPUs, 7922Mi RAM, 30GB     │ │
│ │ ├─ Runs: Kubernetes components              │ │
│ │ │   ├─ kubelet                              │ │
│ │ │   ├─ kube-apiserver                       │ │
│ │ │   ├─ etcd                                 │ │
│ │ │   ├─ kube-scheduler                       │ │
│ │ │   └─ kube-controller-manager              │ │
│ │ └─ Hosts: All your application pods         │ │
│ └─────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────┘
```

**Resource Management:**
- **CPU:** Requests 6 CPUs from Docker (all available from Colima)
- **Memory:** Requests 7922Mi (~7.7GB) from Docker (leaving ~300MB for Docker overhead)
- **Disk:** 30GB virtual disk for Kubernetes data
- **Driver:** Uses Docker driver (runs as container, not separate VM)

**Why 7922Mi instead of 8GB?**
- Docker needs some memory for itself
- 7922Mi = 7.7GB leaves ~300MB for Docker daemon
- Prevents OOM (Out of Memory) issues

**Check Minikube resources:**
```bash
minikube ssh
# Inside Minikube:
nproc  # Shows 6 CPUs
free -h  # Shows ~7.7GB memory
df -h  # Shows 30GB disk
```

---

### LEVEL 4: Kubernetes Node Resources

**Node Capacity vs Allocatable:**

```bash
kubectl describe node minikube
```

**Output breakdown:**
```yaml
Capacity:
  cpu:                6        # Total CPUs in Minikube VM
  memory:             7922Mi   # Total memory in Minikube VM

Allocatable:
  cpu:                6        # Available for pods (after system reserved)
  memory:             7922Mi   # Available for pods (after system reserved)

Allocated resources:
  Resource           Requests      Limits
  --------           --------      ------
  cpu                5400m (90%)   9900m (165%)
  memory             6860Mi (86%)  12970Mi (163%)
```

**What this means:**

1. **Capacity:** Raw resources in the node
   - CPU: 6000m (6 cores × 1000 millicores)
   - Memory: 7922Mi

2. **Allocatable:** Resources available for pods
   - Usually same as capacity in Minikube
   - In production, some is reserved for system daemons

3. **Requests (5400m CPU, 6860Mi memory):**
   - What pods have **requested** (guaranteed minimum)
   - Scheduler uses this for placement decisions
   - 90% of CPU capacity is requested
   - 86% of memory capacity is requested

4. **Limits (9900m CPU, 12970Mi memory):**
   - Maximum pods can **use** (if available)
   - Can exceed node capacity (overcommitment)
   - 165% of CPU capacity (overcommitted)
   - 163% of memory capacity (overcommitted)

**Why limits exceed capacity?**
- Kubernetes allows overcommitment
- Assumes not all pods will hit limits simultaneously
- If they do, CPU is throttled, memory causes OOMKills

---

### LEVEL 5: Namespace-Level Controls

#### A. ResourceQuota (Namespace-wide limits)

**Example (we deleted this):**
```yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: monitoring-quota
  namespace: monitoring
spec:
  hard:
    requests.cpu: "5"        # Max 5 CPUs requested in namespace
    requests.memory: "10Gi"  # Max 10GB memory requested
    limits.cpu: "10"         # Max 10 CPUs limited in namespace
    limits.memory: "20Gi"    # Max 20GB memory limited
    pods: "50"               # Max 50 pods in namespace
```

**How it works:**
```
Namespace: monitoring
├─ ResourceQuota: 5 CPU requests allowed
├─ Current usage: 4.8 CPU requests
└─ New pod wants: 0.5 CPU
    ├─ Total would be: 5.3 CPU
    └─ Result: ❌ REJECTED (exceeds quota)
```

**Why we deleted it:**
- It was limiting us to 5 CPUs
- We needed more flexibility for development
- Production would have this for safety

**Check ResourceQuotas:**
```bash
kubectl get resourcequota -n monitoring
kubectl describe resourcequota monitoring-quota -n monitoring
```

#### B. LimitRange (Per-pod/container defaults and limits)

**Example (we deleted this):**
```yaml
apiVersion: v1
kind: LimitRange
metadata:
  name: default-limits
  namespace: monitoring
spec:
  limits:
  - max:
      cpu: "2"           # Max 2 CPUs per container
      memory: "4Gi"      # Max 4GB per container
    min:
      cpu: "100m"        # Min 100m CPU per container ← THIS BLOCKED US
      memory: "128Mi"    # Min 128Mi memory per container ← THIS BLOCKED US
    default:
      cpu: "500m"        # Default if not specified
      memory: "512Mi"    # Default if not specified
    defaultRequest:
      cpu: "100m"        # Default request if not specified
      memory: "128Mi"    # Default request if not specified
    type: Container
```

**How it blocked us:**
```
Container: prometheus-config-reloader
├─ Requested: 50m CPU, 50Mi memory
├─ LimitRange minimum: 100m CPU, 128Mi memory
└─ Result: ❌ REJECTED at admission time
    Error: "minimum cpu usage per Container is 100m, but request is 50m"
```

**Why we deleted it:**
- Enforced minimum 100m CPU per container
- Our optimized config needed 50m CPU for sidecars
- Blocked pod creation at admission webhook
- Development needs flexibility

**Check LimitRanges:**
```bash
kubectl get limitrange -n monitoring
kubectl describe limitrange default-limits -n monitoring
```

**LimitRange vs ResourceQuota:**
| Feature | LimitRange | ResourceQuota |
|---------|------------|---------------|
| Scope | Per pod/container | Entire namespace |
| Enforces | Min/max/default per resource | Total limits across namespace |
| When | Pod creation (admission) | Pod creation (admission) |
| Purpose | Standardize pod sizes | Prevent namespace resource hogging |

---

### LEVEL 6: Pod-Level Resources

**Pod = Collection of Containers**

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: prometheus-prometheus-kube-prometheus-prometheus-0
  namespace: monitoring
spec:
  containers:
  - name: prometheus
    resources:
      requests:
        cpu: 50m
        memory: 256Mi
      limits:
        cpu: 200m
        memory: 512Mi
  - name: config-reloader
    resources:
      requests:
        cpu: 50m
        memory: 50Mi
      limits:
        cpu: 100m
        memory: 100Mi
```

**Pod-level calculation:**
```
Pod Total Requests:
  CPU:    50m + 50m = 100m
  Memory: 256Mi + 50Mi = 306Mi

Pod Total Limits:
  CPU:    200m + 100m = 300m
  Memory: 512Mi + 100Mi = 612Mi
```

**Scheduler uses pod-level totals:**
```
Scheduler decision:
├─ Pod needs: 100m CPU, 306Mi memory (requests)
├─ Node has available: 600m CPU, 1062Mi memory
└─ Result: ✅ SCHEDULE (enough resources)
```

**Check pod resources:**
```bash
kubectl get pod prometheus-prometheus-kube-prometheus-prometheus-0 -n monitoring -o yaml | grep -A 10 resources
```

---

### LEVEL 7: Container-Level Resources (Actual Enforcement)

**This is where actual resource control happens!**

#### Container Resources Explained:

```yaml
resources:
  requests:
    cpu: 50m        # Guaranteed minimum
    memory: 256Mi   # Guaranteed minimum
  limits:
    cpu: 200m       # Maximum allowed
    memory: 512Mi   # Maximum allowed (hard limit)
```

**What each means:**

1. **CPU Request (50m):**
   - **Scheduling:** Scheduler ensures node has 50m available
   - **Guarantee:** Container gets at least 50m CPU time
   - **Sharing:** If node is idle, can use more than 50m
   - **Unit:** 50m = 0.05 cores = 5% of one CPU core

2. **CPU Limit (200m):**
   - **Maximum:** Container cannot use more than 200m
   - **Throttling:** If tries to use more, CPU is throttled
   - **No OOM:** CPU throttling doesn't kill the container
   - **Unit:** 200m = 0.2 cores = 20% of one CPU core

3. **Memory Request (256Mi):**
   - **Scheduling:** Scheduler ensures node has 256Mi available
   - **Guarantee:** Container gets at least 256Mi
   - **No sharing:** Memory is not shareable like CPU
   - **Unit:** 256Mi = 268,435,456 bytes

4. **Memory Limit (512Mi):**
   - **Maximum:** Container cannot use more than 512Mi
   - **OOMKill:** If exceeds, container is killed (OOM = Out Of Memory)
   - **Restart:** Pod restarts after OOMKill
   - **Unit:** 512Mi = 536,870,912 bytes

#### How Linux cgroups enforce this:

```bash
# Inside Minikube, for a container:
minikube ssh

# CPU limits (cgroups v2)
cat /sys/fs/cgroup/kubepods/pod<pod-id>/<container-id>/cpu.max
# Output: 20000 100000
# Means: 20000 microseconds per 100000 microseconds = 20% = 200m

# Memory limits
cat /sys/fs/cgroup/kubepods/pod<pod-id>/<container-id>/memory.max
# Output: 536870912
# Means: 512Mi in bytes
```

**What happens when limits are exceeded:**

| Resource | Exceeds Request | Exceeds Limit |
|----------|----------------|---------------|
| **CPU** | ✅ Allowed (if node has spare CPU) | ⚠️ Throttled (slowed down) |
| **Memory** | ✅ Allowed (if node has spare memory) | ❌ OOMKilled (container killed) |

---

## Your Specific Setup - Complete Flow

### 1. Initial Setup

```bash
# LEVEL 2: Allocate resources to Docker/Colima
colima start --cpu 6 --memory 8 --disk 100

# Result:
# ├─ Host Mac: Gives 6 CPUs, 8GB RAM to Colima VM
# └─ Colima VM: Has 6 CPUs, 8GB RAM available for containers
```

### 2. Minikube Setup

```bash
# LEVEL 3: Create Kubernetes node
minikube start --cpus=6 --memory=7922 --disk-size=30g --driver=docker

# Result:
# ├─ Colima VM: Runs Minikube as Docker container
# ├─ Minikube container: Gets 6 CPUs, 7922Mi RAM
# └─ Kubernetes node: Reports 6000m CPU, 7922Mi memory capacity
```

### 3. Namespace Setup (Initially)

```bash
# LEVEL 5: Namespace controls (created by Helm chart)
kubectl create namespace monitoring

# Helm chart created:
# ├─ ResourceQuota: Limited to 5 CPUs
# └─ LimitRange: Minimum 100m CPU, 128Mi memory per container
```

### 4. Pod Deployment Attempt

```yaml
# LEVEL 6-7: Try to create Prometheus pod
apiVersion: v1
kind: Pod
metadata:
  name: prometheus-0
  namespace: monitoring
spec:
  containers:
  - name: prometheus
    resources:
      requests:
        cpu: 250m
        memory: 1Gi
  - name: config-reloader
    resources:
      requests:
        cpu: 500m
        memory: 512Mi
```

**What happened:**

```
Step 1: Admission Webhook (LimitRange check)
├─ LimitRange requires: min 100m CPU per container
├─ config-reloader requests: 500m CPU
└─ Result: ✅ PASS (500m > 100m)

Step 2: ResourceQuota check
├─ Namespace quota: 5 CPUs max
├─ Current usage: 4.5 CPUs
├─ New pod needs: 0.75 CPUs (250m + 500m)
├─ Total would be: 5.25 CPUs
└─ Result: ❌ FAIL (exceeds quota)

Step 3: Scheduler (if passed above)
├─ Node allocatable: 6 CPUs
├─ Node allocated: 5.4 CPUs (90%)
├─ Node available: 0.6 CPUs
├─ Pod needs: 0.75 CPUs
└─ Result: ❌ FAIL (insufficient resources)
```

### 5. Our Solutions

**Solution A: Delete ResourceQuota**
```bash
kubectl delete resourcequota monitoring-quota -n monitoring
# Result: Removed namespace-wide limit
```

**Solution B: Reduce Pod Resources**
```yaml
# Reduced from 750m to 100m total
containers:
- name: prometheus
  resources:
    requests:
      cpu: 50m      # Was 250m
      memory: 256Mi # Was 1Gi
- name: config-reloader
  resources:
    requests:
      cpu: 50m      # Was 500m
      memory: 50Mi  # Was 512Mi
```

**Solution C: Delete LimitRange**
```bash
kubectl delete limitrange default-limits -n monitoring
# Result: Removed minimum resource requirements
```

**Final Result:**
```
Step 1: Admission Webhook
├─ No LimitRange
└─ Result: ✅ PASS

Step 2: ResourceQuota
├─ No ResourceQuota
└─ Result: ✅ PASS

Step 3: Scheduler
├─ Node available: 600m CPU
├─ Pod needs: 100m CPU (50m + 50m)
└─ Result: ✅ PASS (pod scheduled)

Step 4: Container Runtime
├─ Creates cgroups with limits
├─ Enforces CPU throttling at 200m
├─ Enforces memory limit at 512Mi
└─ Result: ✅ Pod running
```

---

## Resource Management Best Practices

### 1. Setting Requests and Limits

**Golden Rules:**

```yaml
# Good: Requests based on actual usage, limits allow bursts
resources:
  requests:
    cpu: 100m      # P95 actual usage
    memory: 256Mi  # P95 actual usage
  limits:
    cpu: 500m      # 5x requests (allow bursts)
    memory: 512Mi  # 2x requests (prevent OOM)

# Bad: Requests too high (wastes resources)
resources:
  requests:
    cpu: 2000m     # Way more than needed
    memory: 4Gi    # Way more than needed

# Bad: No limits (can starve other pods)
resources:
  requests:
    cpu: 100m
    memory: 256Mi
  # No limits = can use entire node!

# Bad: Limits too low (constant throttling/OOMKills)
resources:
  requests:
    cpu: 100m
    memory: 256Mi
  limits:
    cpu: 100m      # Same as request = no burst capacity
    memory: 256Mi  # Same as request = OOMKill on any spike
```

### 2. Monitoring Resource Usage

```bash
# Check actual usage
kubectl top pods -n monitoring
kubectl top nodes

# Check requests vs limits vs usage
kubectl describe node minikube

# Check for throttling
kubectl get pods -n monitoring -o yaml | grep -i throttl

# Check for OOMKills
kubectl get pods -n monitoring -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.containerStatuses[*].restartCount}{"\n"}{end}'
```

### 3. Right-Sizing Resources

**Process:**

1. **Start with defaults:**
   ```yaml
   requests:
     cpu: 100m
     memory: 128Mi
   limits:
     cpu: 500m
     memory: 512Mi
   ```

2. **Monitor for 1-2 weeks:**
   ```bash
   # Use Prometheus queries
   rate(container_cpu_usage_seconds_total[5m])
   container_memory_working_set_bytes
   ```

3. **Adjust based on P95:**
   ```yaml
   # If P95 usage is 50m CPU, 200Mi memory:
   requests:
     cpu: 50m       # P95 usage
     memory: 256Mi  # P95 usage + 25% buffer
   limits:
     cpu: 200m      # 4x requests
     memory: 512Mi  # 2x requests
   ```

4. **Test and iterate:**
   - Deploy changes
   - Monitor for throttling/OOMKills
   - Adjust if needed

---

## Common Issues and Solutions

### Issue 1: Pod Pending - Insufficient Resources

**Error:**
```
0/1 nodes are available: 1 Insufficient cpu, 1 Insufficient memory
```

**Diagnosis:**
```bash
kubectl describe node minikube | grep -A 5 "Allocated resources"
# Shows: cpu 5400m (90%), memory 6860Mi (86%)
```

**Solutions:**
1. Reduce pod requests
2. Delete unused pods
3. Increase node resources
4. Add more nodes (not possible in Minikube)

### Issue 2: Pod Rejected - LimitRange Violation

**Error:**
```
minimum cpu usage per Container is 100m, but request is 50m
```

**Diagnosis:**
```bash
kubectl get limitrange -n monitoring
kubectl describe limitrange default-limits -n monitoring
```

**Solutions:**
1. Delete LimitRange (dev environment)
2. Adjust LimitRange minimums
3. Increase pod requests to meet minimum

### Issue 3: Pod Rejected - ResourceQuota Exceeded

**Error:**
```
exceeded quota: monitoring-quota, requested: requests.cpu=500m, used: requests.cpu=4.5, limited: requests.cpu=5
```

**Diagnosis:**
```bash
kubectl describe resourcequota monitoring-quota -n monitoring
```

**Solutions:**
1. Delete ResourceQuota (dev environment)
2. Increase quota limits
3. Reduce other pod requests in namespace

### Issue 4: Container OOMKilled

**Error:**
```
Last State: Terminated
Reason: OOMKilled
Exit Code: 137
```

**Diagnosis:**
```bash
kubectl describe pod <pod-name> -n monitoring
# Check memory limit vs actual usage
```

**Solutions:**
1. Increase memory limit
2. Investigate memory leak
3. Optimize application memory usage

### Issue 5: CPU Throttling

**Symptom:** Application slow, high latency

**Diagnosis:**
```bash
# Check throttling metrics in Prometheus
rate(container_cpu_cfs_throttled_seconds_total[5m])
```

**Solutions:**
1. Increase CPU limit
2. Optimize application CPU usage
3. Scale horizontally (more replicas)

---

## Summary

### Resource Flow in Your Setup:

```
Mac (8 CPUs, 16GB)
  ↓ allocate
Colima (6 CPUs, 8GB)
  ↓ allocate
Minikube (6 CPUs, 7.9GB)
  ↓ schedule
Namespace (optional quotas/limits)
  ↓ schedule
Pod (sum of container requests)
  ↓ enforce
Container (actual cgroups limits)
```

### Key Takeaways:

1. **Requests** = Scheduling guarantee (minimum)
2. **Limits** = Enforcement boundary (maximum)
3. **LimitRange** = Per-container min/max/defaults
4. **ResourceQuota** = Per-namespace totals
5. **Node Capacity** = Physical/VM resources
6. **Overcommitment** = Limits can exceed capacity

### Why We Made Our Choices:

1. **Deleted LimitRange:** Too restrictive for optimized sidecars
2. **Deleted ResourceQuota:** Needed flexibility for development
3. **Reduced Requests:** Based on actual usage, not assumptions
4. **Kept Limits:** Safety net for runaway processes
5. **Didn't Increase Node:** Teaches resource optimization

---

## References

- [Kubernetes Resource Management](https://kubernetes.io/docs/concepts/configuration/manage-resources-containers/)
- [LimitRange Documentation](https://kubernetes.io/docs/concepts/policy/limit-range/)
- [ResourceQuota Documentation](https://kubernetes.io/docs/concepts/policy/resource-quotas/)
- [Linux cgroups](https://www.kernel.org/doc/Documentation/cgroup-v2.txt)
- [Minikube Resource Limits](https://minikube.sigs.k8s.io/docs/handbook/config/)

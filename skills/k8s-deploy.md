---
name: k8s-deploy
description: Scaffold Kubernetes manifests (Deployment, Service, ConfigMap, HPA) and a bin/k8s-deploy script for a containerized service
---

# Kubernetes Deploy

Scaffold Kubernetes manifests and a deployment script for a Dockerized service.

## Process

Ask the user:
1. **App name** (kebab-case, e.g. `user-service`) — used for manifest labels, image name, and k8s resource names
2. **Docker Hub username** (e.g. `pascalallen`) — used to construct the full image reference
3. **Container port** (e.g. `8080`) — the port your app listens on inside the container

Substitutions:
- `<app>` → app name as-is
- `<dockerhub-user>` → Docker Hub username
- `<port>` → container port

## Directory Structure to Generate

```
etc/
  k8s/
    <app>/
      deployment.yaml
      service.yaml
      configmap.yaml
      hpa.yaml
bin/
  k8s-deploy
```

If `bin/` already exists, only add `k8s-deploy` to it.

## File Templates

### `etc/k8s/<app>/deployment.yaml`
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: <app>
  labels:
    app: <app>
spec:
  replicas: 2
  selector:
    matchLabels:
      app: <app>
  template:
    metadata:
      labels:
        app: <app>
    spec:
      containers:
        - name: <app>
          image: <dockerhub-user>/<app>:latest
          ports:
            - containerPort: <port>
          envFrom:
            - configMapRef:
                name: <app>-config
          resources:
            requests:
              cpu: "100m"
              memory: "128Mi"
            limits:
              cpu: "500m"
              memory: "512Mi"
          livenessProbe:
            httpGet:
              path: /health
              port: <port>
            initialDelaySeconds: 15
            periodSeconds: 20
          readinessProbe:
            httpGet:
              path: /health
              port: <port>
            initialDelaySeconds: 5
            periodSeconds: 10
```

### `etc/k8s/<app>/service.yaml`
```yaml
apiVersion: v1
kind: Service
metadata:
  name: <app>
spec:
  selector:
    app: <app>
  ports:
    - protocol: TCP
      port: 80
      targetPort: <port>
  type: ClusterIP
```

### `etc/k8s/<app>/configmap.yaml`
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: <app>-config
data:
  APP_ENV: production
  # Add non-secret env vars here. Use Secrets for credentials.
```

### `etc/k8s/<app>/hpa.yaml`
```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: <app>
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: <app>
  minReplicas: 2
  maxReplicas: 10
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 70
```

### `bin/k8s-deploy`
```bash
#!/usr/bin/env bash
set -euo pipefail

APP="<app>"
IMAGE="<dockerhub-user>/<app>"
TAG="${1:-latest}"

cd "$(dirname "${BASH_SOURCE[0]}")/.."

echo "Building $IMAGE:$TAG"
docker build -t "$IMAGE:$TAG" .

echo "Pushing $IMAGE:$TAG"
docker push "$IMAGE:$TAG"

echo "Applying Kubernetes manifests"
kubectl apply -f etc/k8s/"$APP"

echo ""
echo "Deployment complete. Monitor with:"
echo "  kubectl get pods -l app=$APP"
echo "  kubectl get services -l app=$APP"
echo ""
echo "Rollback with:"
echo "  kubectl rollout undo deployment/$APP"
echo ""
echo "Teardown with:"
echo "  kubectl delete -f etc/k8s/$APP"
```

Make executable: `chmod +x bin/k8s-deploy`

## After Generating

Remind the user:
- Add a `/health` endpoint to the app if one does not exist (required by liveness/readiness probes)
- Use `kubectl create secret` (not ConfigMap) for database passwords, API keys, and other secrets
- Run `kubectl apply -f etc/k8s/<app>` to deploy; run `kubectl get pods` to verify pods are `Running`
- `deployment.yaml` uses `:latest` as a placeholder — always deploy via `bin/k8s-deploy [tag]` to ensure the image tag is built and pushed before applying
- Add `namespace: <app>` to each manifest's `metadata` if you use per-service namespaces

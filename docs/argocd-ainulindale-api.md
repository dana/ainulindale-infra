# Argo CD deployment for Ainulindale API

Chunk 9 wires Argo CD to the public `ainulindale-infra` repository.

## Application

Argo CD namespace:

```text
argocd
```

Application resource:

```text
Application/ainulindale-api
```

Project resource:

```text
AppProject/ainulindale
```

Source:

```text
https://github.com/dana/ainulindale-infra.git
main
apps/ainulindale-api/overlays/prod
```

Destination:

```text
https://kubernetes.default.svc
ainulindale-api
```

## Sync policy

The first-release mode is automated sync with prune and self-heal enabled.

This means the infra repo is the source of truth. Manual live Kubernetes
changes should be reverted by Argo CD.

## Validate

```bash
make validate-kustomize
make validate-argocd-application
make KUBECTL="microk8s kubectl" apply-argocd-application
make KUBECTL="microk8s kubectl" argocd-status
```

## Operator checks

```bash
microk8s kubectl -n argocd get application ainulindale-api
microk8s kubectl -n argocd get application ainulindale-api -o yaml
microk8s kubectl -n ainulindale-api get deploy,svc,ingress,sealedsecret
```

## Manual sync

```bash
argocd --core app sync ainulindale-api
argocd --core app wait ainulindale-api --sync --health --timeout 180
```

## Public smoke test

```bash
curl -fsS https://diederich.ai/api/v1/echo \
  -H 'Content-Type: application/json' \
  --data '{"message":"argocd smoke"}'
echo
```

## Rollout

Until Workflow 2 exists, image rollouts are manual Git changes to:

```text
apps/ainulindale-api/overlays/prod/kustomization.yaml
```

Use:

```bash
cd apps/ainulindale-api/overlays/prod
kustomize edit set image ghcr.io/dana/ainulindale-api=ghcr.io/dana/ainulindale-api:<40-char-sha>
cd ../../../..
```

Then validate, open a PR, merge it, and wait for Argo CD:

```bash
make validate-kustomize
make validate-argocd-application
make KUBECTL="microk8s kubectl" argocd-status
```

## Rollback

Rollback is the same mechanism: restore a previous known-good immutable SHA tag
in the infra repo, merge it to `main`, and wait for Argo CD to sync.

Example:

```bash
cd apps/ainulindale-api/overlays/prod
kustomize edit set image ghcr.io/dana/ainulindale-api=ghcr.io/dana/ainulindale-api:<previous-known-good-40-char-sha>
cd ../../../..

make validate-kustomize
make validate-argocd-application
```

## Reboot validation

After rebooting `elwing`, confirm MicroK8s, Argo CD, and the application recover:

```bash
microk8s status --wait-ready

microk8s kubectl -n argocd get pods -o wide
microk8s kubectl -n argocd rollout status deployment/argocd-server --timeout=180s
microk8s kubectl -n argocd rollout status deployment/argocd-repo-server --timeout=180s
microk8s kubectl -n argocd rollout status statefulset/argocd-application-controller --timeout=180s

make KUBECTL="microk8s kubectl" argocd-status

curl -fsS https://diederich.ai/api/v1/echo \
  -H 'Content-Type: application/json' \
  --data '{"message":"argocd reboot smoke"}'
echo
```

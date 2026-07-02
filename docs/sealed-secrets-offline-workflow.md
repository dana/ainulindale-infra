# Sealed Secrets offline workflow

This repository uses Bitnami Sealed Secrets so encrypted Kubernetes secret
material can be committed safely while plaintext Kubernetes Secret manifests are
never committed.

## Controller

The cluster-side controller is installed on `elwing` in the `kube-system`
namespace as:

    sealed-secrets-controller

Pinned version for this proof:

    0.37.0

## Public certificate

The public sealing certificate for `elwing` is committed at:

    sealed-secrets/certs/elwing-sealed-secrets.pub.pem

This certificate is public material. It is safe to commit, but developers must
make sure they are using the correct certificate for the intended cluster.

Certificate details are recorded in:

    docs/elwing-sealed-secrets-public-cert.txt

## Offline sealing rule

Developers may fetch the public certificate from the cluster when they have
cluster access. After that, sealing must work locally with only the saved public
certificate:

    kubeseal --cert sealed-secrets/certs/elwing-sealed-secrets.pub.pem --format yaml

The sealing step must not require CI, Argo CD, kubeconfig, repository secrets,
environment secrets, or cluster access.

## Strict scope

Proof secrets are sealed with strict scope, meaning the encrypted object is bound
to its intended name and namespace.

Do not rename or move a strict-scope SealedSecret unless you intentionally reseal
it.

## What may be committed

Allowed:

- SealedSecret YAML
- public certificate PEM
- public certificate fingerprint/details
- non-secret namespace/kustomization YAML
- documentation and validation scripts

Forbidden:

- plaintext Kubernetes Secret YAML
- stringData-containing manifests
- Sealed Secrets private/master key backups
- files containing private key material
- files containing literal secret values

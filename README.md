# Ainulindale Infra

Public infrastructure and manifests repository for the Ainulindale API project.

This repository is intended to hold declarative infrastructure, Kubernetes
manifests, GitOps configuration, and sealed secret resources for the
Ainulindale API deployment path.

## Current status

Chunk 1 establishes the repository baseline only:

- public repository visibility
- minimal documentation
- contribution notes
- license
- minimal ignore rules
- dependency update configuration
- GitHub-side ruleset documentation
- protected `main` workflow

No production Kubernetes deployment implementation is expected in this chunk.

## Secret handling note

Raw secrets, decrypted secrets, kubeconfigs, tokens, and personal access tokens
must not be committed. Future sealed secret files may be committed only after
they have been encrypted client-side with `kubeseal`.

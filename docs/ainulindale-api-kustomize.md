# Ainulindale API Kustomize manifests

This directory contains the manually editable Kubernetes manifests for the
Ainulindale API before Argo CD and the merged-PR deployment handoff are added.

## Render path

Production render path:

\`\`\`text
apps/ainulindale-api/overlays/prod
\`\`\`

Render locally:

\`\`\`sh
kustomize build apps/ainulindale-api/overlays/prod
\`\`\`

## Image tag rule

The production overlay must use the exact immutable PR-head SHA image produced
by Workflow 1:

\`\`\`text
ghcr.io/dana/ainulindale-api:<40-character-pr-head-sha>
\`\`\`

Do not deploy \`:main\`, \`:latest\`, or a placeholder tag from this overlay.

Current manually chosen image tag:

\`\`\`text
${IMAGE_SHA}
\`\`\`

## Public path

The API ingress serves:

\`\`\`text
https://diederich.ai/api/v1/
https://www.diederich.ai/api/v1/
\`\`\`

The ingress intentionally uses path \`/api/v1\` with \`pathType: Prefix\` so it
can coexist with the existing site ingress for \`/\`.

## Secret handling

The repository commits only a Bitnami SealedSecret resource for runtime/proof
secret material. Plaintext Kubernetes Secret manifests, \`stringData\`, tokens,
passwords, kubeconfigs, and Sealed Secrets private keys must not be committed.

## Validation

Run:

\`\`\`sh
make validate-kustomize
make server-dry-run
\`\`\`

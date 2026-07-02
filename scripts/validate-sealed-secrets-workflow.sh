#!/usr/bin/env bash
set -euo pipefail

KUBECTL_CMD="${KUBECTL_CMD:-microk8s kubectl}"
SS_NAMESPACE="${SS_NAMESPACE:-kube-system}"
SS_CONTROLLER="${SS_CONTROLLER:-sealed-secrets-controller}"

PROOF_NAMESPACE="${PROOF_NAMESPACE:-ainulindale-sealed-secrets-proof}"
PROOF_SECRET="${PROOF_SECRET:-chunk7-proof-secret}"
PROOF_KEY="${PROOF_KEY:-chunk7_proof}"

CERT_FILE="${CERT_FILE:-sealed-secrets/certs/elwing-sealed-secrets.pub.pem}"
MANIFEST_DIR="${MANIFEST_DIR:-sealed-secrets/proof}"
STATE_FILE="${STATE_FILE:-$HOME/.local/state/ainulindale/chunk7-proof-value.txt}"
BACKUP_ROOT="${BACKUP_ROOT:-$HOME/secure-offline/sealed-secrets-backups/elwing}"

fail() {
  echo "FAIL: $*" >&2
  exit 1
}

pass() {
  echo "PASS: $*"
}

need_file() {
  test -s "$1" || fail "missing or empty file: $1"
}

wait_for_secret_value() {
  expected="$1"

  for _ in $(seq 1 60); do
    encoded="$(
      $KUBECTL_CMD -n "$PROOF_NAMESPACE" \
        get secret "$PROOF_SECRET" \
        -o "jsonpath={.data.${PROOF_KEY}}" 2>/dev/null || true
    )"

    if [ -n "$encoded" ]; then
      actual="$(printf '%s' "$encoded" | base64 -d 2>/dev/null || true)"
      if [ "$actual" = "$expected" ]; then
        return 0
      fi
    fi

    sleep 2
  done

  return 1
}

git rev-parse --show-toplevel >/dev/null
cd "$(git rev-parse --show-toplevel)"

command -v kubeseal >/dev/null || fail "kubeseal is not installed"
command -v openssl >/dev/null || fail "openssl is not installed"

need_file "$CERT_FILE"

grep -q 'BEGIN CERTIFICATE' "$CERT_FILE" \
  || fail "$CERT_FILE is not a PEM certificate"

if grep -q 'PRIVATE KEY' "$CERT_FILE"; then
  fail "$CERT_FILE contains private key material"
fi

openssl x509 -in "$CERT_FILE" -noout >/dev/null

pass "public certificate exists and contains no private key"

need_file "$MANIFEST_DIR/kustomization.yaml"
need_file "$MANIFEST_DIR/chunk7-proof-sealedsecret.yaml"

grep -q 'kind: SealedSecret' "$MANIFEST_DIR/chunk7-proof-sealedsecret.yaml" \
  || fail "proof manifest is not a SealedSecret"

if grep -R -nE '^[[:space:]]*kind:[[:space:]]*Secret[[:space:]]*$|^[[:space:]]*stringData:' "$MANIFEST_DIR"; then
  fail "proof manifests contain unsealed Secret YAML or stringData"
fi

pass "proof manifests contain SealedSecret material only"

if git grep -nE 'BEGIN (RSA |EC |OPENSSH )?PRIVATE KEY|BEGIN PRIVATE KEY' -- .; then
  fail "private key material found in tracked repo content"
fi

if git ls-files | grep -E '(^|/)(main\.key|sealed-secrets-master-key-.*\.ya?ml|plain-secret.*\.ya?ml|.*unsealed.*\.ya?ml)$'; then
  fail "private backup or plaintext secret-like file is tracked"
fi

pass "tracked files do not include private key backups or plaintext secret files"

need_file "$STATE_FILE"

expected="$(cat "$STATE_FILE")"

if git grep -F "$expected" -- . >/dev/null; then
  fail "literal proof value appears in tracked repo content"
fi

pass "literal proof value is not tracked"

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

offline_value="offline-proof-$(date -u +%Y%m%dT%H%M%SZ)-$(openssl rand -hex 6)"

printf '%s' "$offline_value" > "$tmpdir/$PROOF_KEY"

$KUBECTL_CMD -n "$PROOF_NAMESPACE" create secret generic "$PROOF_SECRET" \
  --from-file="$PROOF_KEY=$tmpdir/$PROOF_KEY" \
  --dry-run=client \
  -o yaml \
  > "$tmpdir/plain-secret.yaml"

env -u KUBERNETES_SERVICE_HOST -u KUBERNETES_SERVICE_PORT \
  KUBECONFIG="$tmpdir/no-kubeconfig" \
  kubeseal \
    --cert "$CERT_FILE" \
    --format yaml \
    --scope strict \
    < "$tmpdir/plain-secret.yaml" \
    > "$tmpdir/offline-sealedsecret.yaml"

grep -q 'kind: SealedSecret' "$tmpdir/offline-sealedsecret.yaml" \
  || fail "offline kubeseal output was not a SealedSecret"

if grep -qF "$offline_value" "$tmpdir/offline-sealedsecret.yaml"; then
  fail "offline sealed output contains plaintext value"
fi

pass "offline sealing works with saved public certificate and invalid kubeconfig"

$KUBECTL_CMD get crd sealedsecrets.bitnami.com >/dev/null

$KUBECTL_CMD -n "$SS_NAMESPACE" rollout status "deployment/${SS_CONTROLLER}" --timeout=180s

pass "Sealed Secrets CRD and controller are healthy"

$KUBECTL_CMD apply -f "$MANIFEST_DIR/namespace.yaml" >/dev/null

pass "proof namespace exists"

$KUBECTL_CMD apply -k "$MANIFEST_DIR" --dry-run=server >/dev/null

pass "server-side dry run accepted proof manifests"

$KUBECTL_CMD apply -k "$MANIFEST_DIR" >/dev/null

wait_for_secret_value "$expected" \
  || fail "generated Secret did not reach expected value"

pass "controller decrypted SealedSecret into expected normal Secret"

owner="$(
  $KUBECTL_CMD -n "$PROOF_NAMESPACE" \
    get secret "$PROOF_SECRET" \
    -o jsonpath='{.metadata.ownerReferences[0].kind}' 2>/dev/null || true
)"

test "$owner" = "SealedSecret" \
  || fail "generated Secret ownerReference is not SealedSecret"

pass "generated Secret is owned by SealedSecret"

$KUBECTL_CMD -n "$PROOF_NAMESPACE" delete secret "$PROOF_SECRET" >/dev/null

wait_for_secret_value "$expected" \
  || fail "controller did not recreate deleted Secret"

pass "controller recreated deleted Secret from SealedSecret"

if [ ! -d "$BACKUP_ROOT" ]; then
  fail "backup directory does not exist: $BACKUP_ROOT"
fi

latest_backup="$(
  find "$BACKUP_ROOT" -maxdepth 1 -type f -name 'sealed-secrets-master-key-*.yaml' -printf '%T@ %p\n' \
    | sort -nr \
    | awk 'NR==1 { $1=""; sub(/^ /, ""); print }'
)"

test -n "$latest_backup" \
  || fail "no master-key backup found under $BACKUP_ROOT"

need_file "$latest_backup"

test "$(stat -c '%a' "$latest_backup")" = "600" \
  || fail "backup file permissions should be 600: $latest_backup"

grep -q 'sealedsecrets.bitnami.com/sealed-secrets-key' "$latest_backup" \
  || fail "backup does not appear to contain sealed-secrets key label"

grep -q 'tls.key:' "$latest_backup" \
  || fail "backup does not appear to contain tls.key data"

need_file "$latest_backup.sha256"

sha256sum -c "$latest_backup.sha256" >/dev/null

pass "master-key backup exists outside repo and checksum validates"

pass "Chunk 7 Sealed Secrets workflow validation completed"

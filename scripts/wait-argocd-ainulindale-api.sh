#!/usr/bin/env bash
set -Eeuo pipefail

app="${1:-ainulindale-api}"
namespace="${ARGOCD_NAMESPACE:-argocd}"
timeout_seconds="${ARGOCD_WAIT_TIMEOUT_SECONDS:-300}"
sleep_seconds=5

if [ -n "${KUBECTL:-}" ]; then
  read -r -a kubectl_cmd <<< "$KUBECTL"
else
  kubectl_cmd=(kubectl)
fi

deadline=$((SECONDS + timeout_seconds))

while [ "$SECONDS" -lt "$deadline" ]; do
  if ! json="$("${kubectl_cmd[@]}" -n "$namespace" get application.argoproj.io "$app" -o json 2>/dev/null)"; then
    echo "Waiting for Application/$app in namespace $namespace..."
    sleep "$sleep_seconds"
    continue
  fi

  sync="$(jq -r '.status.sync.status // "Unknown"' <<<"$json")"
  health="$(jq -r '.status.health.status // "Unknown"' <<<"$json")"
  revision="$(jq -r '.status.sync.revision // "unknown"' <<<"$json")"
  operation="$(jq -r '.status.operationState.phase // "NoOperation"' <<<"$json")"

  echo "Application/$app sync=$sync health=$health operation=$operation revision=$revision"

  if [ "$sync" = "Synced" ] && [ "$health" = "Healthy" ]; then
    echo "PASS: Application/$app is Synced and Healthy at revision $revision"
    exit 0
  fi

  sleep "$sleep_seconds"
done

echo "FAIL: Application/$app did not become Synced and Healthy within ${timeout_seconds}s" >&2
"${kubectl_cmd[@]}" -n "$namespace" get application.argoproj.io "$app" -o yaml >&2 || true
"${kubectl_cmd[@]}" -n "$namespace" describe application.argoproj.io "$app" >&2 || true
exit 1

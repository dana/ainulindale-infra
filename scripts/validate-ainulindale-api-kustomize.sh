#!/usr/bin/env bash
set -Eeuo pipefail

repo_root="$(git rev-parse --show-toplevel)"
cd "$repo_root"

overlay="${1:-apps/ainulindale-api/overlays/prod}"

if ! command -v kustomize >/dev/null 2>&1; then
  echo "FAIL: kustomize is required" >&2
  exit 1
fi

export PYTHON=python
if ! $PYTHON -c 'import yaml' >/dev/null 2>&1; then
  echo "FAIL: python3-yaml is required; install with: sudo apt-get install -y python3-yaml" >&2
  exit 1
fi

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

rendered="$tmpdir/rendered.yaml"

kustomize build "$overlay" > "$rendered"
test -s "$rendered"

if awk '
  BEGIN { RS="---" }
  $0 ~ /(^|\n)kind:[[:space:]]*Secret([[:space:]]|\n|$)/ { found=1 }
  END { exit found ? 0 : 1 }
' "$rendered"; then
  echo "FAIL: rendered YAML contains plaintext kind: Secret" >&2
  exit 1
fi

if grep -nE '(^|[[:space:]])stringData:' "$rendered"; then
  echo "FAIL: rendered YAML contains stringData" >&2
  exit 1
fi

$PYTHON - "$rendered" <<'PY'
from __future__ import annotations

import re
import sys
from pathlib import Path

import yaml

path = Path(sys.argv[1])
docs = [doc for doc in yaml.safe_load_all(path.read_text()) if doc]

def fail(message: str) -> None:
    raise SystemExit(f"FAIL: {message}")

def find_one(kind: str, name: str) -> dict:
    matches = [
        doc for doc in docs
        if doc.get("kind") == kind and doc.get("metadata", {}).get("name") == name
    ]
    if len(matches) != 1:
        fail(f"expected exactly one {kind}/{name}, found {len(matches)}")
    return matches[0]

required = [
    ("Namespace", "ainulindale-api"),
    ("Deployment", "ainulindale-api"),
    ("Service", "ainulindale-api"),
    ("Ingress", "ainulindale-api"),
    ("SealedSecret", "ainulindale-api-runtime"),
]

for kind, name in required:
    find_one(kind, name)

for doc in docs:
    if doc.get("kind") == "Secret":
        fail("plaintext Secret rendered")

namespace = find_one("Namespace", "ainulindale-api")
labels = namespace.get("metadata", {}).get("labels", {})
if labels.get("app.kubernetes.io/name") != "ainulindale-api":
    fail("namespace missing app.kubernetes.io/name label")

deployment = find_one("Deployment", "ainulindale-api")
dep_ns = deployment.get("metadata", {}).get("namespace")
if dep_ns != "ainulindale-api":
    fail(f"Deployment namespace should be ainulindale-api, got {dep_ns!r}")

containers = deployment["spec"]["template"]["spec"]["containers"]
if len(containers) != 1:
    fail(f"expected one Deployment container, found {len(containers)}")

container = containers[0]
image = container.get("image", "")
if not re.fullmatch(r"ghcr\.io/dana/ainulindale-api:[0-9a-f]{40}", image):
    fail(f"Deployment image must use full lowercase 40-char SHA tag, got {image!r}")

if image.endswith(":main") or image.endswith(":latest") or "placeholder" in image.lower():
    fail(f"Deployment image is mutable or placeholder: {image!r}")

ports = container.get("ports", [])
if not any(port.get("name") == "http" and port.get("containerPort") == 8000 for port in ports):
    fail("Deployment container must expose named port http:8000")

for probe_name in ("readinessProbe", "livenessProbe", "startupProbe"):
    probe = container.get(probe_name)
    if not probe:
        fail(f"Deployment container missing {probe_name}")
    http_get = probe.get("httpGet", {})
    if http_get.get("port") != "http":
        fail(f"{probe_name} must target named port http")

selector = deployment["spec"]["selector"]["matchLabels"]
pod_labels = deployment["spec"]["template"]["metadata"]["labels"]
for key, value in selector.items():
    if pod_labels.get(key) != value:
        fail(f"Deployment selector {key}={value} does not match pod labels")

service = find_one("Service", "ainulindale-api")
svc_ns = service.get("metadata", {}).get("namespace")
if svc_ns != "ainulindale-api":
    fail(f"Service namespace should be ainulindale-api, got {svc_ns!r}")

svc_selector = service["spec"]["selector"]
for key, value in svc_selector.items():
    if pod_labels.get(key) != value:
        fail(f"Service selector {key}={value} does not match pod labels")

svc_ports = service["spec"]["ports"]
if not any(
    port.get("name") == "http"
    and port.get("port") == 80
    and port.get("targetPort") == "http"
    for port in svc_ports
):
    fail("Service must expose port 80 targeting Deployment named port http")

ingress = find_one("Ingress", "ainulindale-api")
ingress_ns = ingress.get("metadata", {}).get("namespace")
if ingress_ns != "ainulindale-api":
    fail(f"Ingress namespace should be ainulindale-api, got {ingress_ns!r}")

spec = ingress["spec"]
if spec.get("ingressClassName") != "public":
    fail("Ingress ingressClassName must be public")

tls = spec.get("tls", [])
if not any(
    entry.get("secretName") == "diederich-tls-secret"
    and set(entry.get("hosts", [])) == {"diederich.ai", "www.diederich.ai"}
    for entry in tls
):
    fail("Ingress must reuse diederich-tls-secret for diederich.ai and www.diederich.ai")

hosts = {rule.get("host"): rule for rule in spec.get("rules", [])}
if set(hosts) != {"diederich.ai", "www.diederich.ai"}:
    fail(f"Ingress hosts are wrong: {sorted(hosts)}")

for host, rule in hosts.items():
    paths = rule.get("http", {}).get("paths", [])
    matching = [
        item for item in paths
        if item.get("path") == "/api/v1"
        and item.get("pathType") == "Prefix"
        and item.get("backend", {}).get("service", {}).get("name") == "ainulindale-api"
        and item.get("backend", {}).get("service", {}).get("port", {}).get("number") == 80
    ]
    if len(matching) != 1:
        fail(f"Ingress host {host} must have exactly one /api/v1 Prefix path to Service port 80")

sealed = find_one("SealedSecret", "ainulindale-api-runtime")
sealed_ns = sealed.get("metadata", {}).get("namespace")
if sealed_ns != "ainulindale-api":
    fail(f"SealedSecret namespace should be ainulindale-api, got {sealed_ns!r}")

encrypted_data = sealed.get("spec", {}).get("encryptedData", {})
if not encrypted_data:
    fail("SealedSecret missing spec.encryptedData")

template_meta = sealed.get("spec", {}).get("template", {}).get("metadata", {})
if template_meta.get("name") != "ainulindale-api-runtime":
    fail("SealedSecret template metadata.name mismatch")

if template_meta.get("namespace") != "ainulindale-api":
    fail("SealedSecret template metadata.namespace mismatch")

print("PASS: rendered Kustomize output passed structural validation")
print(f"PASS: image is {image}")
PY

echo "PASS: $overlay rendered and validated"

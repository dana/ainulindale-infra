#!/usr/bin/env bash
set -Eeuo pipefail

repo_root="$(git rev-parse --show-toplevel)"
cd "$repo_root"

manifest="argocd/ainulindale-api-application.yaml"
test -s "$manifest"

python - "$manifest" <<'PY'
from __future__ import annotations

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

project = find_one("AppProject", "ainulindale")
app = find_one("Application", "ainulindale-api")

if project.get("metadata", {}).get("namespace") != "argocd":
    fail("AppProject must live in argocd namespace")

if app.get("metadata", {}).get("namespace") != "argocd":
    fail("Application must live in argocd namespace")

source_repos = project.get("spec", {}).get("sourceRepos", [])
if source_repos != ["https://github.com/dana/ainulindale-infra.git"]:
    fail(f"unexpected AppProject sourceRepos: {source_repos!r}")

destinations = project.get("spec", {}).get("destinations", [])
expected_destination = {
    "server": "https://kubernetes.default.svc",
    "namespace": "ainulindale-api",
}
if expected_destination not in destinations:
    fail(f"AppProject destinations must include {expected_destination!r}")

cluster_whitelist = project.get("spec", {}).get("clusterResourceWhitelist", [])
if {"group": "", "kind": "Namespace"} not in cluster_whitelist:
    fail("AppProject must allow Namespace as a cluster resource")

spec = app.get("spec", {})
if spec.get("project") != "ainulindale":
    fail("Application must use project ainulindale")

source = spec.get("source", {})
if source.get("repoURL") != "https://github.com/dana/ainulindale-infra.git":
    fail(f"wrong repoURL: {source.get('repoURL')!r}")

if source.get("targetRevision") != "main":
    fail(f"wrong targetRevision: {source.get('targetRevision')!r}")

if source.get("path") != "apps/ainulindale-api/overlays/prod":
    fail(f"wrong source path: {source.get('path')!r}")

destination = spec.get("destination", {})
if destination.get("server") != "https://kubernetes.default.svc":
    fail(f"wrong destination server: {destination.get('server')!r}")

if destination.get("namespace") != "ainulindale-api":
    fail(f"wrong destination namespace: {destination.get('namespace')!r}")

sync_policy = spec.get("syncPolicy", {})
automated = sync_policy.get("automated", {})
if automated.get("prune") is not True:
    fail("automated.prune must be true")

if automated.get("selfHeal") is not True:
    fail("automated.selfHeal must be true")

if automated.get("allowEmpty") is not False:
    fail("automated.allowEmpty must be false")

sync_options = set(sync_policy.get("syncOptions", []))
for required in {
    "CreateNamespace=true",
    "ApplyOutOfSyncOnly=true",
    "PruneLast=true",
    "ServerSideApply=true",
}:
    if required not in sync_options:
        fail(f"missing sync option {required}")

text = path.read_text()
for forbidden in [
    "password:",
    "token:",
    "secret:",
    "kubeconfig",
    "KUBECONFIG",
    "argocd login",
]:
    if forbidden in text:
        fail(f"manifest contains forbidden credential-like text: {forbidden}")

print("PASS: Argo CD Application manifest is structurally valid")
PY

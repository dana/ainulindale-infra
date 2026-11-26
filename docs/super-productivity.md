# Super Productivity & SuperSync on Ainulindalë

## Overview
This document specifies the deployment architecture, configuration, secrets, and operations for Super Productivity and SuperSync on the Ainulindalë cluster (`elwing`).

## Architecture & Workloads
* **Namespace**: `super-productivity`
* **Frontend Web App (`super-productivity-web`)**:
  - Image: `docker.io/johannesjo/super-productivity:v20.1.0@sha256:6592ab5929bad174260cdc07b30c9c9b8943c7dba82596eddcb6a75d439d1756`
  - Port: `80` (ClusterIP `super-productivity-web:80`)
  - Role: Serves the static browser application; client working copy is stored in browser IndexedDB.
* **Sync Backend (`super-productivity-sync`)**:
  - Image: `ghcr.io/super-productivity/supersync:v20.1.0@sha256:ed76d4b4655e09afa58e8bb510742db96143c18e56f4855c53ed6e7d45e9060a`
  - Port: `1900` (ClusterIP `super-productivity-sync:1900`)
  - Strategy: `Recreate` (strictly 1 replica to protect in-memory auth/socket state and avoid dual backend split-brain)
  - Probes:
    - Readiness: `GET /health` on port 1900 (verifies PostgreSQL database connectivity via `SELECT 1`)
    - Liveness: `GET /live` on port 1900 (verifies process responsiveness without restarting on transient database hiccups)
* **Database (`postgres`)**:
  - Image: `docker.io/library/postgres:16-alpine@sha256:f2f98726820d0342055351c6e9d36e705f5bfffb3dd53ff556325114b08afb6d`
  - Port: `5432` (ClusterIP `postgres:5432`)
  - Storage: 10Gi PVC backed by `microk8s-hostpath` with `whenDeleted: Retain` and `whenScaled: Retain`
* **Database Migrations (`super-productivity-migration-v20-1-0`)**:
  - Release-specific batch Job running `sh scripts/migrate-deploy.sh`
  - Runs in sync wave 2 before the backend starts in sync wave 3.

## Public Routing & Ingress
* **Ingress Resource**: `super-productivity-ingress`
* **Ingress Class**: `public` (Traefik v3.6.2 DaemonSet)
* **TLS Certificate**: Automatic Let's Encrypt issuance via ClusterIssuer `letsencrypt-prod` (HTTP-01 solver)
* **Hostnames**:
  - Web UI: `https://tasks.diederich.ai`
  - Sync API & WebSockets: `https://tasks-sync.diederich.ai`

## ArgoCD Sync Wave Ordering
* **Wave 1**: Namespace, Secret, PostgreSQL StatefulSet & Service
* **Wave 2**: Release-specific Migration Job (`super-productivity-migration-v20-1-0`)
* **Wave 3**: SuperSync Deployment & Service, Web Deployment & Service, Ingress

## Client Configuration & Onboarding
1. Open web app (`https://tasks.diederich.ai`) and Android app.
2. Go to **Settings -> Sync & Backup**, select **SuperSync**.
3. Set **Server URL** to canonical public origin: `https://tasks-sync.diederich.ai`.
4. Initiate email sign-in with allowlisted email (`diederich@gmail.com`).
5. Configure identical End-to-End Encryption passphrase on both devices.

## Backup & Recovery
* PostgreSQL database dump: `pg_dump -h postgres.super-productivity.svc.cluster.local -U supersync supersync | gzip > /backup/supersync-$(date +%F).sql.gz`.
* Client E2E passphrase must be retained independently; database dumps do not contain the plaintext encryption keys.

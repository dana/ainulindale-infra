# Sealed Secrets master-key backup

The Sealed Secrets public certificate is not secret. The controller's private
master key is secret and must never be committed to this public repository.

## Backup location

Backups are stored outside the repository under:

    $HOME/secure-offline/sealed-secrets-backups/elwing/

The backup files are named like:

    sealed-secrets-master-key-YYYYMMDDTHHMMSSZ.yaml
    sealed-secrets-master-key-YYYYMMDDTHHMMSSZ.yaml.sha256

After creating the backup, copy it to encrypted offline storage or another
private backup location. Do not rely on the public Git repository as the backup.

## Create backup

Run from an account with cluster-admin access on `elwing`:

    backup_root="$HOME/secure-offline/sealed-secrets-backups/elwing"
    install -d -m 700 "$backup_root"

    backup_file="$backup_root/sealed-secrets-master-key-$(date -u +%Y%m%dT%H%M%SZ).yaml"

    umask 077
    microk8s kubectl -n kube-system get secret \
      -l sealedsecrets.bitnami.com/sealed-secrets-key \
      -o yaml \
      > "$backup_file"

    chmod 600 "$backup_file"
    sha256sum "$backup_file" > "$backup_file.sha256"
    chmod 600 "$backup_file.sha256"

## Non-destructive backup validation

    test -s "$backup_file"
    test "$(stat -c '%a' "$backup_file")" = "600"
    grep -q 'sealedsecrets.bitnami.com/sealed-secrets-key' "$backup_file"
    grep -q 'tls.key:' "$backup_file"
    sha256sum -c "$backup_file.sha256"

## Restore procedure

Only use this during disaster recovery or a deliberate restore rehearsal.

1. Stop or remove the newly created controller key material if rebuilding a
   cluster.
2. Apply the backed-up key material.
3. Restart the Sealed Secrets controller.
4. Re-apply a known SealedSecret and confirm the expected normal Kubernetes
   Secret is produced.

For the current controller install shape:

    microk8s kubectl apply -f /path/to/sealed-secrets-master-key-backup.yaml
    microk8s kubectl -n kube-system rollout restart deployment/sealed-secrets-controller
    microk8s kubectl -n kube-system rollout status deployment/sealed-secrets-controller --timeout=180s

## Backup rotation note

Whenever the controller creates a new sealing key, refresh this backup. Also
refresh the public certificate file periodically so developers seal with the
current public certificate.

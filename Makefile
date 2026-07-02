.PHONY: kustomize-build validate-kustomize server-dry-run ensure-namespace

kustomize-build:
	kustomize build apps/ainulindale-api/overlays/prod

validate-kustomize:
	scripts/validate-ainulindale-api-kustomize.sh

ensure-namespace:
	kubectl apply --server-side --field-manager=chunk-8-bootstrap -f apps/ainulindale-api/base/namespace.yaml

server-dry-run:
	kustomize build apps/ainulindale-api/overlays/prod | kubectl apply --server-side --dry-run=server -f -

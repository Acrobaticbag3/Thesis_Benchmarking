#!/usr/bin/env bash
set -euo pipefail
RELEASE="benchmark-helm"
NAMESPACE="test-namespace"
CHART_DIR="$(dirname "$0")"

case "$1" in
  deploy)
    helm upgrade --install "$RELEASE" "$CHART_DIR" \
      --namespace "$NAMESPACE" --create-namespace \
      --values "$CHART_DIR/values.yaml" \
      --wait --timeout 2m
    ;;
  update)
    helm upgrade "$RELEASE" "$CHART_DIR" \
      --namespace "$NAMESPACE" \
      --set image.tag=alpine --wait --timeout 2m
    ;;
  rollback)
    helm rollback "$RELEASE" 0 \
      --namespace "$NAMESPACE" --wait
    ;;
  teardown)
    helm uninstall "$RELEASE" --namespace "$NAMESPACE" || true
    kubectl delete namespace "$NAMESPACE" --ignore-not-found
    ;;
  deploy-mutation)
    MUTATION_TYPE=${2:-type-mismatch}
    case "$MUTATION_TYPE" in
      type-mismatch)
        helm upgrade --install "$RELEASE" "$CHART_DIR" \
          --namespace "$NAMESPACE" --create-namespace \
          --values "$CHART_DIR/values.yaml" \
          --set replicaCount="four" \
          --wait --timeout 2m
        ;;
      invalid-port)
        helm upgrade --install "$RELEASE" "$CHART_DIR" \
          --namespace "$NAMESPACE" --create-namespace \
          --values "$CHART_DIR/values.yaml" \
          --set service.port=70000 \
          --wait --timeout 2m
        ;;
      missing-image)
        helm upgrade --install "$RELEASE" "$CHART_DIR" \
          --namespace "$NAMESPACE" --create-namespace \
          --values "$CHART_DIR/values.yaml" \
          --set image.repository="" \
          --wait --timeout 2m
        ;;
      typo-field)
        helm upgrade --install "$RELEASE" "$CHART_DIR" \
          --namespace "$NAMESPACE" --create-namespace \
          --values "$CHART_DIR/values.yaml" \
          --set replicaCounts=5 \
          --wait --timeout 2m
        ;;
    esac
    ;;
esac
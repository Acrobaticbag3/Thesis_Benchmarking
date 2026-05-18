#!usr/bin/env bash
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
esac
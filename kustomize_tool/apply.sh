#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="test-namespace"
KUSTOMIZE_DIR="$(dirname "$0")"
RELEASE="kustomize-test-app"

case "$1" in
  deploy)
    kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -
    kubectl apply -k "$KUSTOMIZE_DIR" -n "$NAMESPACE"
    kubectl rollout status deployment/"$RELEASE" -n "$NAMESPACE" --timeout=2m
    ;;
  rollback)
    kubectl rollout undo deployment/"$RELEASE" -n "$NAMESPACE"
    kubectl rollout status deployment/"$RELEASE" -n "$NAMESPACE" --timeout=2m
    ;;
  teardown)
    kubectl delete -k "$KUSTOMIZE_DIR" -n "$NAMESPACE" --ignore-not-found
    kubectl delete namespace "$NAMESPACE" --ignore-not-found
    ;;
esac

#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="test-namespace"
TIMONI_DIR="$(dirname "$0")"
RELEASE="timoni-test-app"

case "$1" in
  deploy)
    kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -
    timoni apply "$RELEASE" "$TIMONI_DIR" -n "$NAMESPACE"
    kubectl rollout status deployment/"$RELEASE" -n "$NAMESPACE" --timeout=2m
    ;;
  update)
    # trigger a change so we have history
    kubectl set image deployment/"$RELEASE" test-app=nginx:alpine -n "$NAMESPACE"
    kubectl rollout status deployment/"$RELEASE" -n "$NAMESPACE" --timeout=2m
    ;;
  rollback)
    # Timoni rollback usually means applying a previous version, but let's just use standard kubectl rollout undo or timoni features if any. 
    # To keep it simple, we use kubectl rollout undo.
    kubectl rollout undo deployment/"$RELEASE" -n "$NAMESPACE"
    kubectl rollout status deployment/"$RELEASE" -n "$NAMESPACE" --timeout=2m
    ;;
  teardown)
    timoni delete "$RELEASE" -n "$NAMESPACE" || true
    kubectl delete namespace "$NAMESPACE" --ignore-not-found
    ;;
esac

#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="test-namespace"
TIMONI_DIR="$(dirname "$0")"
RELEASE="timoni-test-app"
MANIFEST="/tmp/timoni-rendered.yaml"

case "$1" in
  deploy)
    # Use cue to export YAML from our typed CUE definitions
    # This demonstrates CUE's schema-enforced configuration (Timoni's paradigm)
    cd "$TIMONI_DIR/templates"
    cue export . --out yaml -e deployment > "$MANIFEST"
    echo "---" >> "$MANIFEST"
    cue export . --out yaml -e service >> "$MANIFEST"
    cd - > /dev/null

    kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -
    kubectl apply -f "$MANIFEST" -n "$NAMESPACE"
    kubectl rollout status deployment/"$RELEASE" -n "$NAMESPACE" --timeout=2m
    ;;
  update)
    kubectl set image deployment/"$RELEASE" test-app=nginx:alpine -n "$NAMESPACE"
    kubectl rollout status deployment/"$RELEASE" -n "$NAMESPACE" --timeout=2m
    ;;
  rollback)
    kubectl rollout undo deployment/"$RELEASE" -n "$NAMESPACE"
    kubectl rollout status deployment/"$RELEASE" -n "$NAMESPACE" --timeout=2m
    ;;
  teardown)
    kubectl delete -f "$MANIFEST" -n "$NAMESPACE" --ignore-not-found || true
    kubectl delete namespace "$NAMESPACE" --ignore-not-found
    ;;
esac

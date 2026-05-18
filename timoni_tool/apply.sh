#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="test-namespace"
TIMONI_DIR="$(dirname "$0")"
RELEASE="timoni-test-app"

case "$1" in
  deploy)
    timoni apply "$RELEASE" "$TIMONI_DIR" -n "$NAMESPACE" --wait
    ;;
  update)
    timoni apply "$RELEASE" "$TIMONI_DIR" -n "$NAMESPACE" --values "$TIMONI_DIR/values-update.yaml" --wait
    ;;
  rollback)
    # Reapply the original module for rollback
    timoni apply "$RELEASE" "$TIMONI_DIR" -n "$NAMESPACE" --wait
    ;;
  teardown)
    timoni delete "$RELEASE" -n "$NAMESPACE" --wait || true
    kubectl delete namespace "$NAMESPACE" --ignore-not-found
    ;;
esac

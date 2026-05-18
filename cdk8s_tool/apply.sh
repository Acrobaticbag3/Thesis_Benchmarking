#!/usr/bin/env bash
set -euo pipefail

NAMESPACE="test-namespace"
CDK8S_DIR="$(dirname "$0")"
RELEASE="cdk8s-test-app"

case "$1" in
  deploy)
    # Generate the k8s manifests
    cd "$CDK8S_DIR"
    # Assuming node_modules is populated, otherwise run npm install.
    # For benchmarking, synth might be part of deployment time or separate?
    # Usually we include it.
    if [ ! -d "node_modules" ]; then
      npm install > /dev/null 2>&1
    fi
    npx -y cdk8s-cli synth > /dev/null 2>&1
    
    kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -
    kubectl apply -f dist/cdk8s-test-app.k8s.yaml -n "$NAMESPACE"
    kubectl rollout status deployment/"$RELEASE" -n "$NAMESPACE" --timeout=2m
    ;;
  update)
    # trigger a change so we have history
    kubectl set image deployment/"$RELEASE" test-app=nginx:alpine -n "$NAMESPACE"
    kubectl rollout status deployment/"$RELEASE" -n "$NAMESPACE" --timeout=2m
    ;;
  rollback)
    kubectl rollout undo deployment/"$RELEASE" -n "$NAMESPACE"
    kubectl rollout status deployment/"$RELEASE" -n "$NAMESPACE" --timeout=2m
    ;;
  teardown)
    cd "$CDK8S_DIR"
    kubectl delete -f dist/cdk8s-test-app.k8s.yaml -n "$NAMESPACE" --ignore-not-found || true
    kubectl delete namespace "$NAMESPACE" --ignore-not-found
    ;;
esac

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
  deploy-mutation)
    MUTATION_TYPE=${2:-type-mismatch}
    cd "$CDK8S_DIR"
    
    case "$MUTATION_TYPE" in
      type-mismatch)
        sed -i.bak 's/replicas: 4,/replicas: "four" as any,/' main.ts
        ;;
      invalid-port)
        sed -i.bak 's/portNumber: 80,/portNumber: 70000,/' main.ts
        ;;
      missing-image)
        sed -i.bak "s/image: 'nginx:latest',/image: '',/" main.ts
        ;;
      typo-field)
        sed -i.bak 's/replicas: 4,/replicaCounts: 5 as any,/' main.ts
        ;;
    esac
    
    exit_code=0
    npx -y cdk8s-cli synth > /dev/null 2>&1 || exit_code=$?
    
    case "$MUTATION_TYPE" in
      type-mismatch)
        sed -i.bak 's/replicas: "four" as any,/replicas: 4,/' main.ts
        ;;
      invalid-port)
        sed -i.bak 's/portNumber: 70000,/portNumber: 80,/' main.ts
        ;;
      missing-image)
        sed -i.bak "s/image: '',/image: 'nginx:latest',/" main.ts
        ;;
      typo-field)
        sed -i.bak 's/replicaCounts: 5 as any,/replicas: 4,/' main.ts
        ;;
    esac
    rm -f main.ts.bak
    
    if [ $exit_code -ne 0 ]; then
      exit $exit_code
    fi
    kubectl create namespace "$NAMESPACE" --dry-run=client -o yaml | kubectl apply -f -
    kubectl apply -f dist/cdk8s-test-app.k8s.yaml -n "$NAMESPACE"
    ;;
esac

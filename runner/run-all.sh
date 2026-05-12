#!/usr/bin/env bash
set -euo pipefail   # e - exit emedietly on fail
                    # u - undefined vars = failure instead of empty
                    # o pipefail - full pipe failure if any operation in said pipe fails

RESULTS="runner/results.csv"
# echo "tool_name, test_round, time_to_deploy, time_to_rollback, test_result" > "$RESULTS"

TOOLS=("helm" "kustomize" "timoni" "cdk8s")
ROUNDS=10

for tool in "${TOOLS[@]}"; do 
  for round in $(seq 1 $ROUNDS); do
    echo "=== $tool - round: $round ==="
  done
done 
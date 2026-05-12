#!/usr/bin/env bash
set -euo pipefail   # e - exit emedietly on fail
                    # u - undefined vars = failure instead of empty
                    # o pipefail - full pipe failure if any operation in said pipe fails

RESULTS="results.csv"
echo "tool_name,test_round,time_to_deploy,time_to_rollback,successfull_run" > "$RESULTS"

TOOLS=("helm_tool" "kustomize_tool" "timoni_tool" "cdk8s_tool")
ROUNDS=10

for tool in "${TOOLS[@]}"; do 
  for round in $(seq 1 $ROUNDS); do
    echo "=== $tool - round: $round ==="

    # Record time to deploy 
    time_deploy_start=$(date +%s%3N)
    if bash "${tool}/apply.sh" deploy >> "../${tool}/runner-log" 2>&1; then
      time_deploy_end=$(date +%s%3N)
      time_to_deploy=$(( time_deploy_end - time_deploy_start ))

      # Time to rollback
      time_rollback_start=$(date +%s%3N)
      bash "${tool}/apply.sh" rollback >> "../${tool}/runner-log" 2>&1
      time_rollback_end=$(date +%s%3N)
      time_to_rollback=$(( time_rollback_end - time_rollback_end ))
      
      # Record test success or failure
      echo "$tool_name,
        $test_round,
        $time_to_deploy,
        $time_to_rollback,
        true" >> "$RESULTS"
    else
      echo "$tool_name,$test_round,-1,-1,false" >> "$RESULTS"
    fi

    # Teardown
    bash "${tool}/apply.sh" teardown >> "../${tool}/runner-log" 2>&1
    sleep 5
  done

  # add execution for scenario tests later ====e49pewr0wuvr08sry
done 
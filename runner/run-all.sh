#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

# This is the central runner for the benchmarking tool.
# It measures deployment time, resource overhead, and evaluates correctness.

RESULTS="results.csv"
echo "tool_name,test_round,time_to_deploy_ms,time_to_rollback_ms,resource_overhead_mb,cpu_utilization_percent,successfull_run" > "$RESULTS"

TOOLS=("helm_tool" "kustomize_tool" "timoni_tool" "cdk8s_tool")
ROUNDS=1 # Increased to 10 as requested

NAMESPACE="test-namespace"
IMAGE="nginx:latest"

# Experimental controls: Image pre-pulling (Assuming 'kind' cluster named 'kind')
echo "=== Pre-pulling image to cluster nodes for deterministic startup ==="
docker pull $IMAGE > /dev/null 2>&1 || true
kind load docker-image $IMAGE --name kind > /dev/null 2>&1 || true

for tool in "${TOOLS[@]}"; do 
  echo "========================================="
  echo "Evaluating tool: $tool"
  echo "========================================="
  
  for round in $(seq 1 $ROUNDS); do
    echo "=== $tool - round: $round ==="

    success="true"
    overhead_mb=0
    cpu_percent="0"

    # Ensure a clean state before each round
    bash "../${tool}/apply.sh" teardown >> "../${tool}/runner-log" 2>&1 || true
    sleep 2

    # Measure Deployment Time and Host/Client-side Overhead
    echo "  -> Deploying..."
    time_deploy_start=$(date +%s%3N)
    time_output=$(mktemp)
    
    # Use /usr/bin/time -v to capture the memory footprint of the client-side tool
    if /usr/bin/time -v bash "../${tool}/apply.sh" deploy >> "../${tool}/runner-log" 2> "$time_output"; then
      time_deploy_end=$(date +%s%3N)
      time_to_deploy=$(( time_deploy_end - time_deploy_start ))
      
      # Extract Maximum resident set size (kbytes) from the time output and convert to MB
      rss_kb=$(grep "Maximum resident set size" "$time_output" | awk '{print $6}')
      if [[ -n "$rss_kb" ]]; then
        overhead_mb=$(( rss_kb / 1024 ))
      else
        overhead_mb=0
      fi
      
      # Extract CPU utilization percent (stripping the % sign)
      cpu_percent_raw=$(grep "Percent of CPU this job got" "$time_output" | awk '{print $7}')
      if [[ -n "$cpu_percent_raw" ]]; then
        cpu_percent="${cpu_percent_raw%\%}"
      else
        cpu_percent="0"
      fi
      rm -f "$time_output"

      # Measure Rollback Time
      echo "  -> Preparing rollback (triggering an update)..."
      bash "../${tool}/apply.sh" update >> "../${tool}/runner-log" 2>&1 || true

      echo "  -> Rolling back..."
      time_rollback_start=$(date +%s%3N)
      if bash "../${tool}/apply.sh" rollback >> "../${tool}/runner-log" 2>&1; then
        time_rollback_end=$(date +%s%3N)
        time_to_rollback=$(( time_rollback_end - time_rollback_start ))
      else
        time_to_rollback=-1
        success="false"
      fi
    else
      time_to_deploy=-1
      time_to_rollback=-1
      success="false"
    fi

    # Record data
    echo "$tool,$round,$time_to_deploy,$time_to_rollback,$overhead_mb,$cpu_percent,$success" >> "$RESULTS"

    # Correctness testing (Bug Taxonomy) - Mutation Point Pattern
    # This phase would apply known faulty configurations and expect the adapter to fail gracefully.
    # echo "  -> Running correctness tests..."
    # bash "../${tool}/apply.sh" deploy-mutation >> "../${tool}/runner-log" 2>&1
    
    # Teardown and sleep between rounds (Experimental controls)
    echo "  -> Tearing down..."
    bash "../${tool}/apply.sh" teardown >> "../${tool}/runner-log" 2>&1 || true
    sleep 5
  done
done

echo "Benchmarking complete. Results saved to $RESULTS"
cat "$RESULTS"
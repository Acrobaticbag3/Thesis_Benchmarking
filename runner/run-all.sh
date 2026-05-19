#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

# This is the central runner for the benchmarking tool.
# It measures deployment time, resource overhead, and evaluates correctness.

RESULTS="results.csv"
echo "tool_name,test_round,time_to_deploy_ms,time_to_rollback_ms,resource_overhead_mb,cpu_utilization_percent,successfull_run,caught_type_mismatch,caught_invalid_port,caught_missing_image,caught_typo_field" > "$RESULTS"

TOOLS=("helm_tool" "kustomize_tool" "timoni_tool" "cdk8s_tool")
ROUNDS=10 # Increased to 10 as requested

NAMESPACE="test-namespace"
IMAGE="nginx:latest"

# Experimental controls: Image pre-pulling (Assuming 'kind' cluster named 'thesis')
echo "=== Pre-pulling image to cluster nodes for deterministic startup ==="
docker pull $IMAGE > /dev/null 2>&1 || true
kind load docker-image $IMAGE --name thesis > /dev/null 2>&1 || true

get_time_ms() {
  local t
  t=$(date +%s%3N 2>/dev/null || echo "")
  if [[ -z "$t" || "$t" == *N* ]]; then
    # MacOS fallback (seconds precision multiplied to ms)
    echo $(($(date +%s) * 1000))
  else
    echo "$t"
  fi
}

if [ "$(uname)" = "Darwin" ]; then
  TIME_CMD="/usr/bin/time -l"
else
  TIME_CMD="/usr/bin/time -v"
fi

for tool in "${TOOLS[@]}"; do 
  echo "========================================="
  echo "Evaluating tool: $tool"
  echo "========================================="
  
  # Bug Taxonomy Testing (Runs once per tool before performance iterations)
  echo "=== $tool - Bug Taxonomy Testing ==="
  MUTATIONS=("type-mismatch" "invalid-port" "missing-image" "typo-field")
  declare -A caught_results
  for mut in "${MUTATIONS[@]}"; do
    echo "  -> Running correctness tests ($mut)..."
    bash "../${tool}/apply.sh" teardown >> "../${tool}/runner-log" 2>&1 || true
    if bash "../${tool}/apply.sh" deploy-mutation "$mut" >> "../${tool}/runner-log" 2>&1; then
      echo "     [FAIL] Tool allowed invalid configuration or failed at Kubernetes API level ($mut)"
      caught_results[$mut]="false"
    else
      echo "     [PASS] Tool correctly rejected invalid configuration ($mut)"
      caught_results[$mut]="true"
    fi
  done
  # Ensure clean state after taxonomy tests
  bash "../${tool}/apply.sh" teardown >> "../${tool}/runner-log" 2>&1 || true

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
    time_deploy_start=$(get_time_ms)
    time_output=$(mktemp)
    
    # Check if TIME_CMD exists (e.g. Arch Linux often lacks /usr/bin/time)
    if [ -x "$(command -v $(echo $TIME_CMD | awk '{print $1}'))" ] || [ -f "$(echo $TIME_CMD | awk '{print $1}')" ]; then
      DEPLOY_CMD="$TIME_CMD bash ../${tool}/apply.sh deploy"
    else
      DEPLOY_CMD="bash ../${tool}/apply.sh deploy"
    fi

    if $DEPLOY_CMD >> "../${tool}/runner-log" 2> "$time_output"; then
      time_deploy_end=$(get_time_ms)
      time_to_deploy=$(( time_deploy_end - time_deploy_start ))
      
      if [[ "$DEPLOY_CMD" == *"/usr/bin/time"* ]]; then
        if [ "$(uname)" = "Darwin" ]; then
          rss_bytes=$(grep "maximum resident set size" "$time_output" | awk '{print $1}')
          if [[ -n "$rss_bytes" ]]; then
            overhead_mb=$(( rss_bytes / 1048576 ))
          else
            overhead_mb=0
          fi
          cpu_percent="0" # Not easily extracted from MacOS time -l without math
        else
          rss_kb=$(grep "Maximum resident set size" "$time_output" | awk '{print $6}')
          if [[ -n "$rss_kb" ]]; then
            overhead_mb=$(( rss_kb / 1024 ))
          else
            overhead_mb=0
          fi
          cpu_percent_raw=$(grep "Percent of CPU this job got" "$time_output" | awk '{print $7}')
          if [[ -n "$cpu_percent_raw" ]]; then
            cpu_percent="${cpu_percent_raw%\%}"
          else
            cpu_percent="0"
          fi
        fi
      else
        overhead_mb=0
        cpu_percent="0"
      fi
      rm -f "$time_output"

      # Measure Rollback Time
      echo "  -> Preparing rollback (triggering an update)..."
      bash "../${tool}/apply.sh" update >> "../${tool}/runner-log" 2>&1 || true

      echo "  -> Rolling back..."
      time_rollback_start=$(get_time_ms)
      if bash "../${tool}/apply.sh" rollback >> "../${tool}/runner-log" 2>&1; then
        time_rollback_end=$(get_time_ms)
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
    echo "$tool,$round,$time_to_deploy,$time_to_rollback,$overhead_mb,$cpu_percent,$success,${caught_results[type-mismatch]},${caught_results[invalid-port]},${caught_results[missing-image]},${caught_results[typo-field]}" >> "$RESULTS"
    
    # Teardown and sleep between rounds (Experimental controls)
    echo "  -> Tearing down..."
    bash "../${tool}/apply.sh" teardown >> "../${tool}/runner-log" 2>&1 || true
    sleep 5
  done
done

echo "Benchmarking complete. Results saved to $RESULTS"
cat "$RESULTS"
echo ""

echo "=== Calculating Averages ==="
AVERAGES="averages.csv"
echo "tool_name,avg_time_to_deploy_ms,avg_time_to_rollback_ms,avg_resource_overhead_mb,avg_cpu_utilization_percent" > "$AVERAGES"

awk -F',' '
  NR > 1 && $7 == "true" {
    tool=$1
    deploy[tool] += $3
    rollback[tool] += $4
    ram[tool] += $5
    cpu[tool] += $6
    count[tool]++
  }
  END {
    for (t in count) {
      if (count[t] > 0) {
        printf "%s,%.0f,%.0f,%.0f,%.0f\n", t, deploy[t]/count[t], rollback[t]/count[t], ram[t]/count[t], cpu[t]/count[t]
      }
    }
  }
' "$RESULTS" >> "$AVERAGES"

echo "Averages saved to $AVERAGES"
cat "$AVERAGES"
# Kubernetes Abstraction Layers: Benchmarking Proof-of-Concept

This repository contains a benchmarking demonstration tool designed to evaluate and compare different Kubernetes abstraction layers. The tools evaluated in this proof-of-concept are:
- **Helm**: Template-based packaging
- **Kustomize**: Declarative overlay composition
- **Timoni**: Typed, schema-enforced configuration (via CUE)
- **cdk8s**: Imperative, code-driven manifest synthesis (TypeScript)

The benchmark assesses these tools across three main metrics: deployment time, resource overhead, and correctness/bug taxonomy (scaffolded).

## Architecture

The architecture enforces a strict separation between orchestration logic and tool-specific behavior:

- **Central Runner (`runner/run-all.sh`)**: Responsible for millisecond-precision timing, tracking performance, experimental controls (e.g., node image pre-pulling, isolating runs via sleeps), and data collection to `results.csv`.
- **Adapters (`<tool>_tool/apply.sh`)**: Each tool is encapsulated in its own shell-based adapter. The adapter must expose three operations: `deploy`, `rollback`, and `teardown`.

This design guarantees that each tool is tested under identical experimental conditions and allows easy extension to new abstraction tools.

## The Workload

To ensure that performance variations are strictly tied to tool behavior rather than application performance, a minimal, uniform workload is applied across all adapters. It consists of:
- A single `Deployment` running `nginx:latest` (4 replicas).
- A corresponding Kubernetes `Service`.

## Prerequisites

To run this benchmark locally from scratch, ensure your system has the following core dependencies installed:
1. **Docker** and **Kind** (Kubernetes IN Docker) to spin up the local cluster.
2. **kubectl** for cluster interaction.
3. **Node.js** & **npm** (required for cdk8s).

You will also need the CLIs for the four tools being benchmarked:
- **Helm**: `curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 && bash get_helm.sh`
- **Kustomize**: Built natively into `kubectl`, but standalone can be used.
- **Timoni**: `brew install stefanprodan/tap/timoni` (or via Go: `go install github.com/stefanprodan/timoni/cmd/timoni@latest`)
- **cdk8s-cli**: `npm install -g cdk8s-cli`

## Setup and Running

Follow these exact steps to ensure a flawless benchmarking run:

1. **Start the local Kubernetes cluster**
   We use Kind to create a clean, reproducible environment:
   ```bash
   kind create cluster --name Thesis
   ```

2. **Install local dependencies for CDK8s**
   Because CDK8s synthesizes manifests from TypeScript code, you must install the local Node packages before running the benchmark:
   ```bash
   cd cdk8s_tool
   npm install
   cd ..
   ```

3. **Ensure scripts have execution permissions**
   Make sure the runner and all tool adapters are strictly executable:
   ```bash
   chmod +x runner/run-all.sh
   chmod +x helm_tool/apply.sh
   chmod +x kustomize_tool/apply.sh
   chmod +x timoni_tool/apply.sh
   chmod +x cdk8s_tool/apply.sh
   ```

4. **Run the Benchmark**
   Execute the orchestration script. The script will pre-pull the NGINX image to the Kind nodes to eliminate pull latency, evaluate the Bug Taxonomy, and then execute the performance iterations:
   ```bash
   ./runner/run-all.sh
   ```

5. **View the Results**
   The output generates two incredibly useful CSV files for your thesis:
   - `runner/results.csv`: Contains the highly granular raw data (millisecond-precision timings, CPU %, Memory footprint, and pass/fail bug taxonomy checks per round).
   - `runner/averages.csv`: A mathematically clean summary that automatically averages the performance metrics for each tool (excluding failed runs).

## Experimental Controls

To preserve deterministic accuracy, the following controls are implemented by the central runner:
- **Image Pre-pulling**: The target image is explicitly downloaded and side-loaded into the Kind cluster nodes before operations start.
- **Dedicated Namespaces**: All assets are applied strictly within a dedicated `test-namespace` that is aggressively torn down.
- **Cool-down periods**: Sleeps are applied between rounds to stabilize cluster resource consumption metrics.
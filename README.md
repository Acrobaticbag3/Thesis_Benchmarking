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

To run this benchmark locally, ensure you have the following installed:
1. **Docker** and **Kind** (Kubernetes IN Docker) to spin up a local cluster.
2. **kubectl** for cluster interaction.
3. The abstraction tools being benchmarked:
   - [Helm](https://helm.sh/docs/intro/install/)
   - Kustomize (typically bundled with `kubectl` via `-k`, but standalone can be used)
   - [Timoni](https://timoni.sh/)
   - [Node.js](https://nodejs.org/) & `npx` (required for cdk8s synthesis)

## Setup and Running

1. **Start your local Kubernetes cluster**
   We use Kind to create a clean, reproducible environment:
   ```bash
   kind create cluster --name kind
   ```

2. **Run the Benchmark**
   Navigate to the runner directory and execute the orchestration script. The script automatically pre-pulls the NGINX image to the Kind nodes to eliminate first-time image pull latency.
   ```bash
   cd runner
   ./run-all.sh
   ```

3. **View the Results**
   As the runner tests each tool, progress will be streamed to the terminal. Once finished, a comma-separated values file will be generated containing the millisecond-precision timing and outcome of each round.
   ```bash
   cat results.csv
   ```

## Experimental Controls

To preserve deterministic accuracy, the following controls are implemented by the central runner:
- **Image Pre-pulling**: The target image is explicitly downloaded and side-loaded into the Kind cluster nodes before operations start.
- **Dedicated Namespaces**: All assets are applied strictly within a dedicated `test-namespace` that is aggressively torn down.
- **Cool-down periods**: Sleeps are applied between rounds to stabilize cluster resource consumption metrics.
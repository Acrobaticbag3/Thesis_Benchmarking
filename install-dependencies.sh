#!/usr/bin/env bash
set -euo pipefail

echo "======================================================="
echo " Kubernetes Abstraction Benchmarking - Setup Script"
echo "======================================================="

# 1. Check for core system dependencies
echo "--> Checking for core dependencies..."
for cmd in docker node npm; do
  if ! command -v $cmd &> /dev/null; then
    echo "[ERROR] $cmd is not installed. Please install $cmd manually before running this script."
    exit 1
  fi
done
echo "Core dependencies (Docker, Node, NPM) found."

# 2. Install kubectl
if ! command -v kubectl &> /dev/null; then
  echo "--> Installing kubectl..."
  curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
  chmod +x kubectl
  sudo mv kubectl /usr/local/bin/
else
  echo "--> kubectl is already installed."
fi

# 3. Install Kind (Kubernetes IN Docker)
if ! command -v kind &> /dev/null; then
  echo "--> Installing Kind..."
  # Fetch latest stable kind for linux-amd64
  curl -Lo ./kind https://kind.sigs.k8s.io/dl/v0.22.0/kind-linux-amd64
  chmod +x ./kind
  sudo mv ./kind /usr/local/bin/kind
else
  echo "--> Kind is already installed."
fi

# 4. Install Helm
if ! command -v helm &> /dev/null; then
  echo "--> Installing Helm..."
  curl -fsSL -o get_helm.sh https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3
  bash get_helm.sh
  rm get_helm.sh
else
  echo "--> Helm is already installed."
fi

# 5. Install Kustomize
if ! command -v kustomize &> /dev/null; then
  echo "--> Installing Kustomize..."
  curl -s "https://raw.githubusercontent.com/kubernetes-sigs/kustomize/master/hack/install_kustomize.sh" | bash
  sudo mv kustomize /usr/local/bin/
else
  echo "--> Kustomize is already installed."
fi

# 6. Install Timoni
if ! command -v timoni &> /dev/null; then
  echo "--> Installing Timoni..."
  curl -sS https://timoni.sh/install.sh | sudo bash
else
  echo "--> Timoni is already installed."
fi

# 7. Install cdk8s-cli
if ! command -v cdk8s &> /dev/null; then
  echo "--> Installing cdk8s-cli globally..."
  sudo npm install -g cdk8s-cli
else
  echo "--> cdk8s-cli is already installed."
fi

# 8. Initialize Local CDK8s Dependencies
echo "--> Initializing local CDK8s project dependencies..."
cd "$(dirname "$0")/cdk8s_tool"
npm install
cd ..

# 9. Ensure Execution Permissions for all scripts
echo "--> Setting execution permissions for bash scripts..."
chmod +x install-dependencies.sh || true
chmod +x runner/run-all.sh
chmod +x helm_tool/apply.sh
chmod +x kustomize_tool/apply.sh
chmod +x timoni_tool/apply.sh
chmod +x cdk8s_tool/apply.sh

echo ""
echo "======================================================="
echo " Setup Complete! "
echo "======================================================="
echo "You can now run the benchmark orchestrator:"
echo "  1. Start the cluster:   kind create cluster --name kind"
echo "  2. Run the benchmarks:  ./runner/run-all.sh"
